import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import '../core/snackbar_util.dart';

class FeedController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  // --- PUBLIC OBSERVABLES ---

  /// Whether current user has any followings
  var hasFollowings = true.obs;

  /// List of all posts shown in feed (can be filtered by showAllPosts toggle)
  var allPosts = <PostModel>[].obs;

  /// When `true` the feed shows global 'All Posts'. When `false` it shows only following posts.
  /// Defaults to true so users always see posts, even if they have no followings
  var showAllPosts = true.obs;

  /// Users suggested for connecting
  var suggestedConnections = <UserModel>[].obs;

  /// Real-time notifications for user actions
  var notifications = <NotificationModel>[].obs;

  // Stream subscriptions to manage cleanup on controller disposal
  StreamSubscription? _authSubscription;
  StreamSubscription? _userFollowingSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadInitialData();

    // Re-bind posts when the user flips the showAllPosts toggle
    // If showing all posts, bind getAllPostsStream; if showing following, bind getFollowingPostsStream
    ever(showAllPosts, (_) {
      final followingPresent = hasFollowings.value;
      debugPrint('onInit: showAllPosts toggled to ${showAllPosts.value}');
      if (showAllPosts.value) {
        allPosts.bindStream(getAllPostsStream());
      } else {
        if (!followingPresent) {
          // No followings = show empty stream
          allPosts.bindStream(Stream.value(<PostModel>[]));
        } else {
          // Show only posts from users this user follows
          allPosts.bindStream(getFollowingPostsStream());
        }
      }
    });

    // Listen to auth state changes and reinitialize feed when user logs in/out
    // This ensures UI updates properly if user's session changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      debugPrint('FeedController: Auth state changed - user=${user?.email}');
      _ensureUserFieldsExist();
      _listenToPosts();
    });
  }

  @override
  void onClose() {
    // Clean up subscriptions when controller is disposed
    _authSubscription?.cancel();
    _userFollowingSubscription?.cancel();
    super.onClose();
  }

  /// Auto-fix missing fields on current user's Firestore document
  /// Ensures followers/following/connections arrays exist before operations
  // ignore: unnecessary_null_comparison
  Future<void> _ensureUserFieldsExist() async {
    final uid = _currentUid;
    if (uid == null) return;

    try {
      final userDoc = await _db.collection('users').doc(uid).get();
      if (!userDoc.exists) return;

      final data = userDoc.data();
      final updates = <String, dynamic>{};

      if (data?['followers'] == null) {
        updates['followers'] = [];
      }

      if (data?['following'] == null) {
        updates['following'] = [];
      }

      if (data?['connections'] == null) {
        updates['connections'] = [];
      }

      if (updates.isNotEmpty) {
        await _db.collection('users').doc(uid).update(updates);
      }
    } catch (e) {
      debugPrint("Error ensuring user fields: $e");
    }
  }

  /// Initialize notifications and discovery placeholders
  void _loadInitialData() {
    notifications.assignAll([
      NotificationModel(
        title: "Welcome",
        subtitle: "Start sharing insights with your network",
        time: "Now",
        icon: Icons.auto_awesome,
        color: Colors.amber,
      ),
    ]);
  }

  /// REAL-TIME ENGINE: Scalable for 5000+ users
  /// Uses a stream to ensure the feed updates instantly across all devices.
  void _listenToPosts() {
    final uid = _currentUid;
    if (uid == null) {
      // Not authenticated: empty feed
      debugPrint('_listenToPosts: No authenticated user');
      hasFollowings.value = false;
      allPosts.bindStream(Stream.value(<PostModel>[]));
      _userFollowingSubscription?.cancel();
      _userFollowingSubscription = null;
      return;
    }

    debugPrint('_listenToPosts: Listening for user=$uid');

    // Cancel previous subscription if exists
    _userFollowingSubscription?.cancel();

    // Listen to the current user's following list and bind the feed accordingly.
    // We also react to `showAllPosts` to allow a user toggle between feeds.
    _userFollowingSubscription = _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (userSnap) {
            final Map<String, dynamic> userData = userSnap.data() ?? {};
            final following = List<String>.from(userData['following'] ?? []);

            hasFollowings.value = following.isNotEmpty;
            debugPrint(
              '_listenToPosts: User has ${following.length} followings',
            );

            // Bind the appropriate stream based on the toggle and following state
            if (showAllPosts.value) {
              debugPrint('_listenToPosts: Showing all posts');
              allPosts.bindStream(getAllPostsStream());
            } else {
              if (following.isEmpty) {
                debugPrint('_listenToPosts: No followings, showing empty');
                allPosts.bindStream(Stream.value(<PostModel>[]));
              } else {
                debugPrint('_listenToPosts: Showing following posts');
                allPosts.bindStream(getFollowingPostsStream());
              }
            }
          },
          onError: (e) {
            debugPrint('Error listening to user followings: $e');
            hasFollowings.value = false;
            allPosts.bindStream(Stream.value(<PostModel>[]));
          },
        );
  }

  /// GLOBAL ALL-POSTS STREAM - Gets all posts regardless of following
  /// Sorted by recency (newest first), limited to 100 posts for performance
  Stream<List<PostModel>> getAllPostsStream() {
    return _db
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          debugPrint('getAllPostsStream: Got ${snapshot.docs.length} posts');
          return snapshot.docs.map((doc) {
            final Map<String, dynamic> data = doc.data();
            debugPrint('getAllPostsStream: Post data = $data');
            return PostModel.fromMap(data, doc.id);
          }).toList();
        })
        .handleError((error) {
          debugPrint('Error fetching all posts: $error');
          return <PostModel>[];
        });
  }

  /// Allow UI to set the showAllPosts toggle
  void setShowAll(bool value) => showAllPosts.value = value;

  /// --- DISCOVERY ENGINE ---
  ///
  /// **Goal**: Show users that the current user might want to connect with.
  /// **Logic**:
  /// 1. Fetches the current user's 'following' list.
  /// 2. Fetches a batch of 50 users from Firestore (limited for Scalability).
  /// 3. Filters out:
  ///    - The user themselves.
  ///    - Users already in the 'following' list.
  ///
  /// **Scalability Note**:
  /// In a production app with >50k users, fetching "all users" is impossible.
  /// We limit the fetch to 50. Ideally, this should be replaced by:
  /// - A localized "recommended_users" collection updated by a Cloud Function.
  /// - OR an Algolia/Meilisearch index for randomizing discovery.
  // ignore: unnecessary_null_comparison
  Stream<List<UserModel>> getDiscoveryUsersStream() {
    final uid = _currentUid;
    if (uid == null) {
      return Stream.value(<UserModel>[]);
    }

    return _db.collection('users').doc(uid).snapshots().asyncExpand((
      currentUserDoc,
    ) {
      List<String> following = [];
      if (currentUserDoc.exists) {
        final currentUserData = currentUserDoc.data();
        following = List<String>.from((currentUserData?['following']) ?? []);
      }

      // OPTIMIZATION: Limit to 50 users.
      // In a real production app with 50k users, you would use Algolia
      // or a dedicated 'recommended_users' collection.
      return _db
          .collection('users')
          .limit(50) // <--- CRITICAL SCALABILITY FIX
          .snapshots()
          .map((snapshot) {
            final filtered = snapshot.docs
                .map((doc) {
                  try {
                    final Map<String, dynamic> data = Map<String, dynamic>.from(
                      doc.data(),
                    );
                    if (data['uid'] == null ||
                        (data['uid'] as String).isEmpty) {
                      data['uid'] = doc.id;
                    }
                    return UserModel.fromMap(data);
                  } catch (e) {
                    return null;
                  }
                })
                .where((u) => u != null)
                .cast<UserModel>()
                .where((user) {
                  final isNotSelf = user.uid != uid;
                  final isNotFollowing = !following.contains(user.uid);
                  return isNotSelf && isNotFollowing;
                })
                .toList();
            return filtered;
          })
          .handleError((error) {
            debugPrint("Discovery Error: $error");
            return <UserModel>[];
          });
    });
  }

  /// --- FOLLOWING FEED ENGINE ---
  ///
  /// **Goal**: Show posts ONLY from people the user follows.
  /// **Challenge**: Firestore's `whereIn` query is limited to **30 items**.
  ///
  /// **Logic**:
  /// 1. specific to Firestore NoSQL structure: We cannot simply say "give me posts where uid is in following_list"
  ///    if that list has 500 people. Firestore crashes at 30.
  /// 2. **Workaround**: We slice the following list to the top 30 (most recently followed)
  ///    and query only for them.
  ///
  /// **Production Scalability Solution**:
  /// For a true "Twitter-scale" feed, you cannot use pull-based queries like this.
  /// You must use **Fan-out on Write**:
  /// - When User A posts, a Cloud Function copies that Post ID to every follower's "feed" sub-collection.
  /// - The app then just reads `users/{uid}/feed`.
  Stream<List<PostModel>> getFollowingPostsStream() {
    return _db.collection('users').doc(_currentUid).snapshots().asyncExpand((
      userSnapshot,
    ) {
      if (!userSnapshot.exists) return Stream.value(<PostModel>[]);

      final Map<String, dynamic> userData = Map<String, dynamic>.from(
        userSnapshot.data() ?? {},
      );
      final following = List<String>.from(userData['following'] ?? []);

      // Include own posts plus posts from people you follow
      List<String> uidsToShow = [_currentUid!, ...following];

      // SAFETY CHECK: Firestore 'whereIn' limits to 30 items.
      // If user follows > 29 people, we slice the list to the most recent 30
      // (assuming the list is ordered by add time, or we just take the first 30).
      if (uidsToShow.length > 30) {
        debugPrint(
          "⚠️ SCALABILITY WARNING: Following count (${uidsToShow.length}) exceeds Firestore limit (30). Truncating feed source.",
        );
        uidsToShow = uidsToShow.sublist(0, 30);
      }

      if (uidsToShow.isEmpty) return Stream.value(<PostModel>[]);

      return _db
          .collection('posts')
          .where('uid', whereIn: uidsToShow)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              final Map<String, dynamic> data = doc.data();
              return PostModel.fromMap(data, doc.id);
            }).toList();
          });
    });
  }

  // --- ACTIONS ---

  /// --- INTERACTION: LIKE ---
  ///
  /// **Atomic Operation**:
  /// We use `FieldValue.arrayUnion` and `FieldValue.arrayRemove` to ensure
  /// we don't overwrite other people's likes if they happen at the exact same millisecond.
  ///
  /// **Counters**:
  /// We manually increment/decrement the integer counter.
  /// *Note*: In extremely high traffic (100 likes/sec), this integer might drift.
  /// reliable counts usually require a distributed counter extension, but this is sufficient for <100k users.
  Future<void> toggleLike(String postId, bool isCurrentlyLiked) async {
    try {
      if (isCurrentlyLiked) {
        await _db.collection('posts').doc(postId).update({
          'likedBy': FieldValue.arrayRemove([_currentUid]),
          'likes': FieldValue.increment(-1),
        });
      } else {
        await _db.collection('posts').doc(postId).update({
          'likedBy': FieldValue.arrayUnion([_currentUid]),
          'likes': FieldValue.increment(1),
        });
      }
      debugPrint("Like updated successfully for post $postId");
    } catch (e) {
      debugPrint("❌ LIKE ERROR: $e");
      debugPrint("❌ ERROR TYPE: ${e.runtimeType}");
      SnackbarUtil.error("Like Failed", e.toString());
    }
  }

  /// ATOMIC REPOST: Stores unique UIDs in an array
  /// TOGGLE REPOST: Add or remove current user from `reposts` array
  Future<void> toggleRepost(String postId, bool isCurrentlyReposted) async {
    try {
      if (isCurrentlyReposted) {
        await _db.collection('posts').doc(postId).update({
          'reposts': FieldValue.arrayRemove([_currentUid]),
        });
        Get.snackbar("Unshared", "Removed from your shared items");
      } else {
        await _db.collection('posts').doc(postId).update({
          'reposts': FieldValue.arrayUnion([_currentUid]),
        });
        Get.snackbar("Shared", "Insight shared to your professional network");
      }
    } catch (e) {
      debugPrint("Repost error: $e");
    }
  }

  /// BOOKMARK TOGGLE
  Future<void> toggleBookmark(String postId, bool isBookmarked) async {
    try {
      final postRef = _db.collection('posts').doc(postId);

      // First ensure the post has a bookmarks field
      final postDoc = await postRef.get();
      if (!postDoc.exists) {
        debugPrint('Post not found: $postId');
        return;
      }

      final data = postDoc.data() ?? {};
      if (data['bookmarks'] == null) {
        // Initialize bookmarks field if missing
        await postRef.update({'bookmarks': []});
      }

      // Now toggle the bookmark
      await postRef.update({
        'bookmarks': isBookmarked
            ? FieldValue.arrayRemove([_currentUid])
            : FieldValue.arrayUnion([_currentUid]),
      });

      debugPrint(
        '🔖 Bookmark toggled for post $postId - isBookmarked: $isBookmarked',
      );
    } catch (e) {
      debugPrint("❌ Bookmark error: $e");
    }
  }

  /// POST COMMENT
  Future<void> postComment(String postId, String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _db.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint("Comment error: $e");
    }
  }

  /// UPLOAD POST: Fetches latest user data before writing
  Future<void> uploadPost(String content, String? imagePath) async {
    if (content.trim().isEmpty) return;
    try {
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final userDoc = await _db.collection('users').doc(_currentUid).get();
      final userData = userDoc.data() ?? {};
      final String fullName = userData['fullName'] ?? 'User';

      await _db.collection('posts').add({
        'uid': _currentUid,
        'name': fullName,
        'username': userData['username'] ?? 'user',
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
        'commentCount': 0,
        'reposts': [],
        'bookmarks': [],
        'profileInitial': fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
        'profileImageUrl': userData['profileImageUrl'],
      });

      Get.back(); // Close loading dialog
      Get.back(); // Return to Feed from Post page
      SnackbarUtil.success('Success', 'Insight shared successfully!');
    } catch (e) {
      if (Get.isDialogOpen!) Get.back();
      debugPrint("Upload error: $e");
      SnackbarUtil.error('Error', 'Could not share insight.');
    }
  }

  /// SEARCH POSTS by content
  Future<List<PostModel>> searchPosts(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final snapshot = await _db
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      // Filter posts that contain the search query (case-insensitive)
      final results = snapshot.docs
          .map((doc) => PostModel.fromMap(doc.data(), doc.id))
          .where(
            (post) =>
                post.content.toLowerCase().contains(query.toLowerCase()) ||
                post.name.toLowerCase().contains(query.toLowerCase()) ||
                post.username.toLowerCase().contains(query.toLowerCase()) ||
                post.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase().replaceAll('#', ''))),
          )
          .toList();

      debugPrint('Search for "$query" found ${results.length} results');
      return results;
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    }
  }

  void followUser() => hasFollowings.value = true;
}
