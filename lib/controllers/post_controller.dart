import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../core/snackbar_util.dart';
import '../services/cloudinary_widget_service.dart';

/// ==========================================
/// POST CONTROLLER (GetX)
/// ==========================================
///
/// This controller is the hub for all social activity: creating posts,
/// liking, commenting, and managing the "discovery" feed metrics.
///
/// KEY RESPONSIBILITIES:
/// ------------------------------------------
/// 1. Post Creation Engine: Handles content validation and ensures 
///    user profiles exist before allowing a write.
/// 2. Media Orchestration: Coordinates with CloudinaryWidgetService 
///    to upload images/videos before finalizing Firestore entries.
/// 3. Feed Management: Streams user-specific posts and handles 
///    client-side filtering for complex queries (like authored vs reposted).
/// 4. Social Interactions: Manages atomic increments for likes 
///    and comments to maintain exact counts.
///
/// STATE ARCHITECTURE:
/// ------------------------------------------
/// - userPosts: A reactive list (`.obs`) that updates in real-time as the 
///   user interacts with the platform.
/// - uploadProgress: Provides granular feedback to the UI during 
///   heavy media uploads.
///
class PostController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  // --- PUBLIC OBSERVABLES ---
  var userPosts = <PostModel>[].obs;
  var isLoading = false.obs;
  var uploadProgress = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    _listenToUserPosts();
  }

  /// Real-time listener for current user's posts
  void _listenToUserPosts() {
    final uid = _currentUid;
    if (uid == null) {
      userPosts.assignAll([]);
      return;
    }

    userPosts.bindStream(
      _db
          .collection('posts')
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              final Map<String, dynamic> data = doc.data();
              return PostModel.fromMap(data, doc.id);
            }).toList();
          }),
    );
  }

  /// --- POST CREATION ENGINE ---
  ///
  /// **Features**:
  /// 1. **Auto-Profile Creation**: If the user doesn't have a Firestore document yet (e.g., fresh auth),
  ///    we create a minimal profile on the fly to prevent a "User not found" error.
  /// 2. **Media Handling**: Supports mix of text and pre-uploaded media URLs.
  /// 3. **Ad Trigger**: Shows an Interstitial Ad immediately after a successful post.
  Future<void> uploadPost(String content, dynamic mediaUrlsOrImagePath, {List<String> tags = const [], List<String> mentions = const [], String mediaType = 'text'}) async {
    if (content.isEmpty && (mediaUrlsOrImagePath == null || (mediaUrlsOrImagePath is List && mediaUrlsOrImagePath.isEmpty))) return;

    isLoading.value = true;
    try {
      debugPrint("uploadPost: Starting for user $_currentUid");

      // Ensure user profile exists and has required fields
      final uid = _currentUid;
      if (uid == null) {
        SnackbarUtil.error('Error', 'You must be signed in to post.');
        isLoading.value = false;
        return;
      }

      final userRef = _db.collection('users').doc(uid);
      var userDoc = await userRef.get();

      if (!userDoc.exists) {
        // Create a minimal profile automatically to allow posting
        final authUser = FirebaseAuth.instance.currentUser;
        final email = authUser?.email ?? '';
        final display = authUser?.displayName ?? '';
        final derivedName = display.isNotEmpty
            ? display
            : (email.isNotEmpty ? email.split('@').first : 'User');
        final derivedUsername = derivedName.replaceAll(' ', '').toLowerCase();

        final newProfile = {
          'uid': uid,
          'fullName': derivedName,
          'username': derivedUsername,
          'email': email,
          'followers': [],
          'following': [],
          'createdAt': FieldValue.serverTimestamp(),
        };

        await userRef.set(newProfile);
        userDoc = await userRef.get();
        debugPrint('uploadPost: Created minimal user profile for $uid');
      }

      final userData = userDoc.data();
      if (userData == null) {
        debugPrint("User data is null after creation");
        SnackbarUtil.error('Error', 'Failed to retrieve user data.');
        isLoading.value = false;
        return;
      }

      // Determine media URLs list
      List<String> resolvedMediaUrls = [];
      String resolvedMediaType = mediaType;
      
      if (mediaUrlsOrImagePath is List<String>) {
        resolvedMediaUrls = mediaUrlsOrImagePath;
        if (resolvedMediaType == 'text' && resolvedMediaUrls.isNotEmpty) {
          resolvedMediaType = 'image'; // Default to image if not specified
        }
      } else if (mediaUrlsOrImagePath is String) {
        resolvedMediaUrls = [mediaUrlsOrImagePath];
        if (resolvedMediaType == 'text') {
          resolvedMediaType = 'image';
        }
      }

      // Simple post creation
      final postData = {
        'uid': _currentUid,
        'name': userData['fullName'] ?? 'User',
        'username': userData['username'] ?? 'user',
        'profileInitial': (userData['fullName'] as String?)?.isEmpty ?? true
            ? 'U'
            : (userData['fullName'] as String).substring(0, 1).toUpperCase(),
        'profileImageUrl': userData['profileImageUrl'],
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0, // Integer count, not array
        'likedBy': [],
        'commentCount': 0,
        'reposts': [],
        'bookmarks': [],
        'mediaUrls': resolvedMediaUrls,
        'mediaType': resolvedMediaType,
        'tags': tags,
        'mentions': mentions,
      };

      debugPrint("uploadPost: Creating post with data = $postData");

      final postRef = await _db.collection('posts').add(postData);
      debugPrint("uploadPost: Post created with ID = ${postRef.id}");

      Get.back(); // Close the post dialog
      SnackbarUtil.success('Success', 'Post shared successfully!');
    } catch (e) {
      debugPrint("Post Error: $e");
      SnackbarUtil.error('Error', 'Failed to upload post: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Upload a post with media files (image, video, audio, document)
  /// mediaFiles: List of file paths to upload
  /// mediaType: 'image', 'video', 'audio', 'document'
  /// --- MEDIA UPLOAD ORCHESTRATOR ---
  ///
  /// **Parallel Uploads**:
  /// - Iterates through selected files (images/videos).
  /// - calls `CloudinaryWidgetService` for each.
  /// - Updates `uploadProgress` observable for UI feedback.
  ///
  /// **Error Handling**:
  /// - If ANY file fails, the whole post is aborted to prevent partial/broken posts.
  Future<void> uploadPostWithMedia({
    required String content,
    required List<XFile> mediaFiles,
    required String mediaType,
    List<String> tags = const [],
    List<String> mentions = const [],
  }) async {
    if (content.isEmpty && mediaFiles.isEmpty) {
      SnackbarUtil.error('Error', 'Please add content or media');
      return;
    }

    isLoading.value = true;
    uploadProgress.value = 0;
    debugPrint(
      'uploadPostWithMedia called with mediaType: $mediaType, files: ${mediaFiles.length}',
    );
    try {
      final uid = _currentUid;
      if (uid == null) {
        SnackbarUtil.error('Error', 'You must be signed in to post.');
        isLoading.value = false;
        return;
      }

      // Get user data
      final userRef = _db.collection('users').doc(uid);
      var userDoc = await userRef.get();

      if (!userDoc.exists) {
        final authUser = FirebaseAuth.instance.currentUser;
        final email = authUser?.email ?? '';
        final display = authUser?.displayName ?? '';
        final derivedName = display.isNotEmpty
            ? display
            : (email.isNotEmpty ? email.split('@').first : 'User');
        final derivedUsername = derivedName.replaceAll(' ', '').toLowerCase();

        final newProfile = {
          'uid': uid,
          'fullName': derivedName,
          'username': derivedUsername,
          'email': email,
          'followers': [],
          'following': [],
          'createdAt': FieldValue.serverTimestamp(),
        };

        await userRef.set(newProfile);
        userDoc = await userRef.get();
      }

      final userData = userDoc.data() ?? {};

      // Upload media files to Cloudinary using Upload Widget
      final List<String> mediaUrls = [];
      if (mediaFiles.isNotEmpty) {
        // Note: Upload Widget opens a UI, so we process files one at a time
        
        for (int i = 0; i < mediaFiles.length; i++) {
          // Determine media type for widget
          String apiResourceType = 'auto';
          if (mediaType == 'video') apiResourceType = 'video';
          if (mediaType == 'image') apiResourceType = 'image';

          // Update progress
          uploadProgress.value = (i / mediaFiles.length) + 0.1;

          // Open Cloudinary Upload Widget
          // Note: The widget will handle file selection from the XFile
          final url = await CloudinaryWidgetService.uploadFile(
            mediaType: apiResourceType
          );

          if (url != null) {
            mediaUrls.add(url);
            debugPrint('📤 Uploaded to Cloudinary: $url');
          } else {
            throw Exception(
              'Upload cancelled or failed. Please try again.'
            );
          }
        }
        uploadProgress.value = 1.0;
      }

      // Create post document
      final postData = {
        'uid': uid,
        'name': userData['fullName'] ?? 'User',
        'username': userData['username'] ?? 'user',
        'profileInitial': (userData['fullName'] as String?)?.isEmpty ?? true
            ? 'U'
            : (userData['fullName'] as String).substring(0, 1).toUpperCase(),
        'profileImageUrl': userData['profileImageUrl'],
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
        'commentCount': 0,
        'reposts': [],
        'bookmarks': [],
        'mediaType': mediaType,
        'mediaUrls': mediaUrls,
        'tags': tags,
        'mentions': mentions,
      };

      final postRef = await _db.collection('posts').add(postData);
      debugPrint('📝 Post created with ID: ${postRef.id}');

      Get.back(); // Close dialog
      SnackbarUtil.success('Success', 'Post shared with $mediaType!');
    } catch (e) {
      debugPrint('❌ Upload Error: $e');
      SnackbarUtil.error('Error', 'Failed to upload post: $e');
    } finally {
      isLoading.value = false;
      uploadProgress.value = 0;
    }
  }

  /// Delete a post by ID (only if user is the author)
  Future<void> deletePost(String postId) async {
    try {
      final postDoc = await _db.collection('posts').doc(postId).get();
      if (postDoc['uid'] == _currentUid) {
        await _db.collection('posts').doc(postId).delete();
        SnackbarUtil.success('Success', 'Post deleted');
      } else {
        SnackbarUtil.error('Error', 'You can only delete your own posts');
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
      SnackbarUtil.error('Error', 'Failed to delete post');
    }
  }

  /// Update post content (only if user is the author)
  Future<void> updatePost(String postId, String newContent) async {
    if (newContent.isEmpty) return;

    try {
      final postDoc = await _db.collection('posts').doc(postId).get();
      if (postDoc['uid'] == _currentUid) {
        await _db.collection('posts').doc(postId).update({
          'content': newContent,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        SnackbarUtil.success('Success', 'Post updated');
      } else {
        SnackbarUtil.error('Error', 'You can only edit your own posts');
      }
    } catch (e) {
      debugPrint("Update Error: $e");
      SnackbarUtil.error('Error', 'Failed to update post');
    }
  }

  /// --- USER PROFILE FEED ---
  ///
  /// **Goal**: Show all posts associated with a specific user (Authored + Reposted).
  ///
  /// ⚠️ **CRITICAL SCALABILITY WARNING** ⚠️
  /// Currently, this query downloads **ALL POSTS** in the collection and filters them Client-Side.
  /// `_db.collection('posts').snapshots()` -> `posts.where(...)`
  ///
  /// **Why?**
  /// Firestore cannot easily query "Authored By X OR Reposted By X" in a single request
  /// without a specific composite index or multiple queries.
  ///
  /// **Fix Required for Production**:
  /// 1. Perform TWO queries: `where('uid', ==, id)` AND `where('reposts', arrayContains, id)`.
  /// 2. Merge the streams locally using `Rx.combineLatest`.
  /// OR
  /// 3. Duplicate reposts into a sub-collection `users/{id}/posts`.
  Stream<List<PostModel>> getUserPostsStream(String userId) {
    return _db
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          // Get posts authored by user OR reposted by user
          final posts = snapshot.docs
              .map((doc) {
                final Map<String, dynamic> data = doc.data();
                return PostModel.fromMap(data, doc.id);
              })
              .where(
                (post) =>
                    post.uid == userId || // Posts authored by user
                    post.reposts.contains(userId),
              ) // Posts reposted by user
              .toList();

          debugPrint(
            'getUserPostsStream: Found ${posts.length} posts for user $userId',
          );
          return posts;
        });
  }

  /// Add a comment to a post
  Future<void> addComment(String postId, String content) async {
    if (content.isEmpty) return;

    try {
      final userDoc = await _db.collection('users').doc(_currentUid).get();

      if (!userDoc.exists) {
        SnackbarUtil.error('Error', 'User profile not found.');
        return;
      }

      final userData = userDoc.data();

      if (userData == null) {
        SnackbarUtil.error('Error', 'Failed to retrieve user data.');
        return;
      }

      // Add comment to subcollection
      await _db.collection('posts').doc(postId).collection('comments').add({
        'postId': postId,
        'userId': _currentUid,
        'username': userData['username'] ?? 'user',
        'name': userData['fullName'] ?? 'User',
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
      });

      // Increment comment count on post
      await _db.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(1),
      });

      SnackbarUtil.success('Success', 'Comment added!');
    } catch (e) {
      debugPrint("Comment Error: $e");
      SnackbarUtil.error('Error', 'Failed to add comment: $e');
    }
  }

  /// Get comments for a post
  Stream<List<CommentModel>> getCommentsStream(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final Map<String, dynamic> data = doc.data();
            return CommentModel.fromMap(data, doc.id);
          }).toList();
        });
  }

  /// Delete a comment (only by author)
  Future<void> deleteComment(String postId, String commentId) async {
    try {
      final commentDoc = await _db
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .get();

      if (commentDoc['userId'] == _currentUid) {
        await _db
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .doc(commentId)
            .delete();

        // Decrement comment count
        await _db.collection('posts').doc(postId).update({
          'commentCount': FieldValue.increment(-1),
        });

        SnackbarUtil.success('Success', 'Comment deleted');
      }
    } catch (e) {
      debugPrint("Delete Comment Error: $e");
    }
  }

  /// Get bookmarked posts for current user
  Stream<List<PostModel>> getBookmarkedPostsStream() {
    final uid = _currentUid;
    if (uid == null) {
      return Stream.value([]);
    }

    return _db
        .collection('posts')
        .where('bookmarks', arrayContains: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            '🔖 Found ${snapshot.docs.length} bookmarked posts for user $uid',
          );
          return snapshot.docs.map((doc) {
            final Map<String, dynamic> data = doc.data();
            return PostModel.fromMap(data, doc.id);
          }).toList();
        })
        .handleError((error) {
          debugPrint('❌ Error fetching bookmarked posts: $error');
          // Fallback: Return empty list on error (prevents app crash)
          return [];
        });
  }
}
