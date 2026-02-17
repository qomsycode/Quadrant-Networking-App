import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/user_model.dart';
import '../models/experience_model.dart';
import '../models/education_model.dart';
import '../models/project_model.dart';
import '../core/snackbar_util.dart';

/// ==========================================
/// PROFILE CONTROLLER (GetX)
/// ==========================================
///
/// This controller manages all logic related to user profiles, 
/// professional meta-data (experience, education, projects), 
/// and social relationships (followers/following).
///
/// KEY RESPONSIBILITIES:
/// ------------------------------------------
/// 1. Session Management: Exposes 'currentUser' as a reactive stream 
///    linked directly to Firestore.
/// 2. Social Graph: Orchestrates follow/unfollow operations using 
///    Firestore transactions for data consistency.
/// 3. Data Sync: When a user updates their name or photo, this controller
///    background-syncs those changes to all their past posts.
/// 4. CRUD Operations: Manages additions and removals of professional 
///    history items (lists like Experiences and Projects).
///
/// STATE ARCHITECTURE:
/// ------------------------------------------
/// - obs (Observables): Used for UI loading states and simple counts.
/// - bindStream: Used for the primary user profile to ensure the UI
///   auto-refreshes whenever the backend document changes.
///
class ProfileController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  // --- PUBLIC OBSERVABLES ---
  /// Reactive current user profile - auto-updates when Firestore data changes
  var currentUser = Rxn<UserModel>();

  /// Another user's profile being viewed (for profile viewing page)
  var selectedUser = Rxn<UserModel>();

  /// Whether current user follows the selected user
  var isFollowing = false.obs;

  /// Live follower count for the selected user
  var followerCount = 0.obs;

  /// Live following count for the selected user
  var followingCount = 0.obs;

  /// Loading state for profile updates
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Auto-fix missing followers/following arrays on app startup
    _ensureUserFieldsExist();
    // Load current user's profile from Firestore with real-time updates
    _loadCurrentUserProfile();
  }

  /// Ensures the current user document has all required fields
  /// (auto-fixes missing followers/following arrays)
  Future<void> _ensureUserFieldsExist() async {
    if (_currentUid == null || _currentUid!.isEmpty) return;

    try {
      final userDoc = await _db.collection('users').doc(_currentUid).get();
      if (!userDoc.exists) return;

      final data = userDoc.data();
      final updates = <String, dynamic>{};

      // Add missing followers array
      if (data?['followers'] == null) {
        updates['followers'] = [];
        debugPrint("Adding missing 'followers' field to user document");
      }

      // Add missing following array
      if (data?['following'] == null) {
        updates['following'] = [];
        debugPrint("Adding missing 'following' field to user document");
      }

      // Add missing connections array
      if (data?['connections'] == null) {
        updates['connections'] = [];
        debugPrint("Adding missing 'connections' field to user document");
      }

      // Apply updates if any fields were missing
      if (updates.isNotEmpty) {
        await _db.collection('users').doc(_currentUid).update(updates);
        debugPrint("User document fields auto-fixed");
      }
    } catch (e) {
      debugPrint("Error ensuring user fields exist: $e");
    }
  }

  /// Load current user's profile data
  void _loadCurrentUserProfile() {
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) {
      debugPrint(
        "_loadCurrentUserProfile: No authenticated user, binding empty stream",
      );
      currentUser.bindStream(Stream.value(null));
      return;
    }

    debugPrint("_loadCurrentUserProfile: Loading profile for uid=$uid");
    currentUser.bindStream(
      _db
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((snapshot) {
            if (snapshot.exists) {
              final user = UserModel.fromMap(snapshot.data()!);
              debugPrint(
                "_loadCurrentUserProfile: Profile loaded for ${user.fullName}",
              );
              return user;
            }
            debugPrint(
              "_loadCurrentUserProfile: User document doesn't exist for uid=$uid",
            );
            return null;
          })
          .handleError((error) {
            debugPrint(
              "_loadCurrentUserProfile: Error loading profile - $error",
            );
            return null;
          }),
    );
  }

  StreamSubscription? _followCountsSubscription;

  @override
  void onClose() {
    _followCountsSubscription?.cancel();
    super.onClose();
  }

  /// Load another user's profile by UID
  Future<void> loadUserProfile(String userId) async {
    isLoading.value = true;
    try {
      final userDoc = await _db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        selectedUser.value = UserModel.fromMap(userDoc.data()!);
        _updateFollowStatus(userId);
        _updateFollowCounts(userId);
      }
    } catch (e) {
      debugPrint("Load Profile Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  /// Load a user's profile by username (for @mention navigation)
  Future<void> loadUserProfileByUsername(String username) async {
    isLoading.value = true;
    try {
      final query = await _db
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        selectedUser.value = UserModel.fromMap(query.docs.first.data());
      }
    } catch (e) {
      debugPrint("Load Profile By Username Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  /// Check if current user follows the selected user
  /// Updates the isFollowing observable based on currentUser's following list
  void _updateFollowStatus(String userId) {
    if (currentUser.value != null) {
      isFollowing.value = currentUser.value!.following.contains(userId);
    }
  }

  /// Get live follower and following counts for a user
  /// Listens to changes in another user's followers/following arrays
  /// and updates followerCount and followingCount observables in real-time
  void _updateFollowCounts(String userId) {
    _followCountsSubscription?.cancel();
    _followCountsSubscription = _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            // Extract array lengths - defaults to 0 if arrays don't exist
            followerCount.value = (data['followers'] as List?)?.length ?? 0;
            followingCount.value = (data['following'] as List?)?.length ?? 0;
          }
        });
  }

  /// Follow a user (Twitter-style)
  /// - Adds current user to target user's followers array
  /// - Adds target user to current user's following array
  /// - Uses Firestore transaction for atomic operation (all-or-nothing)
  /// - Updates UI state immediately after success
  Future<void> followUser(String userId) async {
    if (_currentUid == userId) {
      SnackbarUtil.info('Info', 'You cannot follow yourself');
      return;
    }
    final uid = _currentUid;
    if (uid == null) {
      SnackbarUtil.error('Error', 'You must be signed in to follow users.');
      return;
    }

    try {
      // FIRESTORE TRANSACTION: Ensures both updates succeed or both fail
      // This prevents cases where one user is followed but the other isn't updated
      await _db.runTransaction((tx) async {
        final currentRef = _db.collection('users').doc(uid);
        final targetRef = _db.collection('users').doc(userId);

        // Fetch both documents first to verify they exist
        final currentSnap = await tx.get(currentRef);
        final targetSnap = await tx.get(targetRef);

        if (!currentSnap.exists || !targetSnap.exists) {
          throw Exception('One of the user profiles does not exist');
        }

        // SAFETY CHECK: Document Size Limit
        // a 1MB document can hold roughly 20k-30k UIDs.
        // We cap it at 20,000 to be safe.
        final targetFollowers = targetSnap.data()?['followers'] as List? ?? [];
        if (targetFollowers.length >= 20000) {
          throw Exception('User has reached the maximum number of followers (20k).');
        }

        // Add target user to current user's "following" array
        tx.update(currentRef, {
          'following': FieldValue.arrayUnion([userId]),
        });

        // Add current user to target user's "followers" array
        tx.update(targetRef, {
          'followers': FieldValue.arrayUnion([uid]),
        });
      });

      // Update UI state - button will show "Following" immediately
      isFollowing.value = true;
      SnackbarUtil.success('Success', 'Now following');
    } catch (e) {
      debugPrint('Follow Error: $e');
      SnackbarUtil.error('Error', 'Failed to follow user: $e');
    }
  }

  /// Unfollow a user (Logic only, UI confirmation handled by view)
  /// - Removes current user from target user's followers array
  /// - Removes target user from current user's following array
  /// - Shows confirmation dialog before execution
  Future<void> unfollowUser(String userId) async {
    final uid = _currentUid;
    if (uid == null) {
      SnackbarUtil.error('Error', 'You must be signed in to unfollow users.');
      return;
    }

    try {
      await _db.runTransaction((tx) async {
        final currentRef = _db.collection('users').doc(uid);
        final targetRef = _db.collection('users').doc(userId);

        final currentSnap = await tx.get(currentRef);
        final targetSnap = await tx.get(targetRef);

        if (!currentSnap.exists || !targetSnap.exists) {
          throw Exception('One of the user profiles does not exist');
        }

        tx.update(currentRef, {
          'following': FieldValue.arrayRemove([userId]),
        });

        tx.update(targetRef, {
          'followers': FieldValue.arrayRemove([uid]),
        });
      });

      isFollowing.value = false;
      SnackbarUtil.success('Success', 'Unfollowed');
    } catch (e) {
      debugPrint('Unfollow Error: $e');
      SnackbarUtil.error('Error', 'Failed to unfollow user: $e');
    }
  }

  /// Update current user's profile
  Future<void> updateProfile({
    required String fullName,
    String? bio,
    String? headline,
    String? location,
    String? profileImageUrl,
  }) async {
    isLoading.value = true;
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) {
      debugPrint("Update Profile Error: User UID is null or empty");
      Get.snackbar(
        'Error',
        'User session not found. Please sign in again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      isLoading.value = false;
      return;
    }

    try {
      final updatedData = {
        'fullName': fullName,
        if (bio != null) 'bio': bio,
        if (headline != null) 'headline': headline,
        if (location != null) 'location': location,
        if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      };

      await _db.collection('users').doc(uid).update(updatedData);

      // Determine the final values to sync to posts
      // We use the new values if provided, otherwise fall back to current cached values
      final String finalName = fullName;
      final String finalUsername = currentUser.value?.username ?? '';
      final String? finalImageUrl = profileImageUrl ?? currentUser.value?.profileImageUrl;

      // SYNC: Update all past posts with the merged latest data
      await _updateUserPosts(
        uid,
        fullName: finalName,
        username: finalUsername,
        profileImageUrl: finalImageUrl,
      );

      debugPrint("Profile updated successfully for uid=$uid");
      Get.snackbar(
        'Success',
        'Profile updated successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint("Update Profile Error: $e");
      Get.snackbar(
        'Error',
        'Failed to update profile: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Helper to update user details in all their past posts
  /// Handles batching to respect Firestore limits
  Future<void> _updateUserPosts(
    String uid, {
    required String fullName,
    String? username,
    String? profileImageUrl,
  }) async {
    try {
      debugPrint("Syncing profile changes to posts...");
      
      // Calculate profile initial on the fly
      final String initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';

      // Get all posts by this user
      final querySnapshot = await _db
          .collection('posts')
          .where('uid', isEqualTo: uid)
          .get();

      if (querySnapshot.docs.isEmpty) return;

      // Firestore batches are limited to 500 operations
      final int batchSize = 450;
      List<QueryDocumentSnapshot> docs = querySnapshot.docs;

      for (var i = 0; i < docs.length; i += batchSize) {
        final batch = _db.batch();
        var end = (i + batchSize < docs.length) ? i + batchSize : docs.length;
        var chunk = docs.sublist(i, end);

        bool hasUpdates = false;
        for (var doc in chunk) {
          final updates = <String, dynamic>{
            'name': fullName,
            'profileInitial': initial,
          };
          if (profileImageUrl != null) {
            updates['profileImageUrl'] = profileImageUrl;
          }
          if (username != null && username.isNotEmpty) {
            updates['username'] = username;
          }
          
          batch.update(doc.reference, updates);
          hasUpdates = true;
        }

        if (hasUpdates) {
          await batch.commit();
          debugPrint("Updated batch of ${chunk.length} posts");
        }
      }
      debugPrint("All user posts synced with new profile data.");
    } catch (e) {
      debugPrint("Error syncing user posts: $e");
    }
  }

  /// Manually trigger a full sync of the current profile to all posts.
  /// Useful if data became desynced during a crash or network error.
  Future<void> forceSyncProfileToPosts() async {
    final user = currentUser.value;
    if (user == null) return;
    
    isLoading.value = true;
    try {
      await _updateUserPosts(
        user.uid,
        fullName: user.fullName,
        username: user.username,
        profileImageUrl: user.profileImageUrl,
      );
      SnackbarUtil.success('Success', 'Profile data synced to all posts');
    } catch (e) {
      debugPrint("Force Sync Error: $e");
      SnackbarUtil.error('Error', 'Failed to sync data');
    } finally {
      isLoading.value = false;
    }
  }

  /// Get list of all users (for discovery)
  Stream<List<UserModel>> getAllUsersStream() {
    return _db.collection('users').snapshots().map((snapshot) {
      final users = snapshot.docs
          .map((doc) {
            try {
              final Map<String, dynamic> data = Map<String, dynamic>.from(
                doc.data(),
              );
              if (data['uid'] == null || (data['uid'] as String).isEmpty) {
                data['uid'] = doc.id;
              }
              return UserModel.fromMap(data);
            } catch (e) {
              debugPrint(
                'getAllUsersStream: Skipping malformed user doc ${doc.id}: $e',
              );
              return null;
            }
          })
          .where((u) => u != null)
          .cast<UserModel>()
          .where((user) => user.uid != _currentUid)
          .toList();

      return users;
    });
  }

  /// Get suggested users (not following)
  Stream<List<UserModel>> getSuggestedUsersStream() {
    return _db.collection('users').snapshots().map((snapshot) {
      final allUsers = snapshot.docs
          .map((doc) {
            try {
              final Map<String, dynamic> data = Map<String, dynamic>.from(
                doc.data(),
              );
              if (data['uid'] == null || (data['uid'] as String).isEmpty) {
                data['uid'] = doc.id;
              }
              return UserModel.fromMap(data);
            } catch (e) {
              debugPrint(
                'getSuggestedUsersStream: Skipping malformed user doc ${doc.id}: $e',
              );
              return null;
            }
          })
          .where((u) => u != null)
          .cast<UserModel>()
          .toList();

      if (currentUser.value == null) return [];

      return allUsers
          .where(
            (user) =>
                user.uid != _currentUid &&
                !currentUser.value!.following.contains(user.uid),
          )
          .toList();
    });
  }

  /// Get followers of a user
  Future<List<UserModel>> getUserFollowers(String userId) async {
    try {
      // Safety: reject empty UIDs
      if (userId.isEmpty) {
        debugPrint("getUserFollowers: Invalid UID (empty)");
        return [];
      }

      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];

      final data = userDoc.data();
      if (data == null) return [];

      final followers = (data['followers'] as List?)?.cast<String>() ?? [];

      if (followers.isEmpty) return [];

      final followerDocs = await _db
          .collection('users')
          .where('uid', whereIn: followers)
          .get();
      return followerDocs.docs
          .map((doc) {
            try {
              final Map<String, dynamic> data = Map<String, dynamic>.from(
                doc.data(),
              );
              if (data['uid'] == null || (data['uid'] as String).isEmpty) {
                data['uid'] = doc.id;
              }
              return UserModel.fromMap(data);
            } catch (e) {
              debugPrint(
                'getUserFollowers: Skipping malformed user doc ${doc.id}: $e',
              );
              return null;
            }
          })
          .where((u) => u != null)
          .cast<UserModel>()
          .toList();
    } catch (e) {
      debugPrint("Get Followers Error: $e");
      return [];
    }
  }

  /// Get following of a user
  Future<List<UserModel>> getUserFollowing(String userId) async {
    try {
      // Safety: reject empty UIDs
      if (userId.isEmpty) {
        debugPrint("getUserFollowing: Invalid UID (empty)");
        return [];
      }

      final userDoc = await _db.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];

      final data = userDoc.data();
      if (data == null) return [];

      final following = (data['following'] as List?)?.cast<String>() ?? [];

      if (following.isEmpty) return [];

      final followingDocs = await _db
          .collection('users')
          .where('uid', whereIn: following)
          .get();
      return followingDocs.docs
          .map((doc) {
            try {
              final Map<String, dynamic> data = Map<String, dynamic>.from(
                doc.data(),
              );
              if (data['uid'] == null || (data['uid'] as String).isEmpty) {
                data['uid'] = doc.id;
              }
              return UserModel.fromMap(data);
            } catch (e) {
              debugPrint(
                'getUserFollowing: Skipping malformed user doc ${doc.id}: $e',
              );
              return null;
            }
          })
          .where((u) => u != null)
          .cast<UserModel>()
          .toList();
    } catch (e) {
      debugPrint("Get Following Error: $e");
      return [];
    }
  }

  // ============= PHASE 1: RICH PROFILE MANAGEMENT =============

  /// Add a new experience to the current user's profile
  Future<void> addExperience({
    required String title,
    required String company,
    required String location,
    required DateTime startDate,
    DateTime? endDate,
    String? description,
    required bool isCurrentRole,
  }) async {
    isLoading.value = true;
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) {
      SnackbarUtil.error('Error', 'User session not found.');
      isLoading.value = false;
      return;
    }

    try {
      final experienceId = DateTime.now().millisecondsSinceEpoch.toString();
      final experience = Experience(
        id: experienceId,
        title: title,
        company: company,
        location: location,
        startDate: startDate,
        endDate: endDate,
        description: description,
        isCurrentRole: isCurrentRole,
      );

      debugPrint('📝 Adding experience: $title at $company');
      debugPrint('📝 Experience data: ${experience.toMap()}');

      final updateData = {
        'experiences': FieldValue.arrayUnion([experience.toMap()]),
      };
      debugPrint('📝 Update payload: $updateData');

      await _db.collection('users').doc(uid).update(updateData);

      debugPrint('✅ Experience added to Firestore');
      SnackbarUtil.success('Success', 'Experience added');

      // IMPORTANT: Reload AFTER ensuring Firestore has confirmed the write
      // Use _loadCurrentUserProfile() instead of manual update to avoid stream conflicts
      await Future.delayed(const Duration(milliseconds: 1000));
      _loadCurrentUserProfile();
    } catch (e) {
      debugPrint('❌ Add Experience Error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      SnackbarUtil.error('Error', 'Failed to add experience: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  /// Update an existing experience
  Future<void> updateExperience({
    required String experienceId,
    required String title,
    required String company,
    required String location,
    required DateTime startDate,
    DateTime? endDate,
    String? description,
    required bool isCurrentRole,
  }) async {
    isLoading.value = true;
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) {
      Get.snackbar('Error', 'User session not found.');
      isLoading.value = false;
      return;
    }

    try {
      final updatedUser = currentUser.value;
      if (updatedUser == null) return;

      // Remove old experience and add updated one
      final oldExperience = updatedUser.experiences.firstWhere(
        (e) => e.id == experienceId,
        orElse: () => Experience(
          id: '',
          title: '',
          company: '',
          location: '',
          startDate: DateTime.now(),
        ),
      );

      final newExperience = Experience(
        id: experienceId,
        title: title,
        company: company,
        location: location,
        startDate: startDate,
        endDate: endDate,
        description: description,
        isCurrentRole: isCurrentRole,
      );

      await _db.collection('users').doc(uid).update({
        'experiences': FieldValue.arrayRemove([oldExperience.toMap()]),
      });

      await _db.collection('users').doc(uid).update({
        'experiences': FieldValue.arrayUnion([newExperience.toMap()]),
      });

      Get.snackbar('Success', 'Experience updated');
      _loadCurrentUserProfile();
    } catch (e) {
      debugPrint('Update Experience Error: $e');
      Get.snackbar('Error', 'Failed to update experience: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Delete an experience
  Future<void> deleteExperience(String experienceId) async {
    isLoading.value = true;
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) {
      Get.snackbar('Error', 'User session not found.');
      isLoading.value = false;
      return;
    }

    try {
      final updatedUser = currentUser.value;
      if (updatedUser == null) return;

      final experienceToDelete = updatedUser.experiences.firstWhere(
        (e) => e.id == experienceId,
        orElse: () => Experience(
          id: '',
          title: '',
          company: '',
          location: '',
          startDate: DateTime.now(),
        ),
      );

      await _db.collection('users').doc(uid).update({
        'experiences': FieldValue.arrayRemove([experienceToDelete.toMap()]),
      });

      Get.snackbar('Success', 'Experience deleted');
      _loadCurrentUserProfile();
    } catch (e) {
      debugPrint('Delete Experience Error: $e');
      Get.snackbar('Error', 'Failed to delete experience: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Add a new project
  Future<void> addProject({
    required String title,
    required String description,
    String? link,
    List<String> imageUrls = const [],
  }) async {
    isLoading.value = true;
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) {
      Get.snackbar('Error', 'User session not found.');
      isLoading.value = false;
      return;
    }

    try {
      final projectId = DateTime.now().millisecondsSinceEpoch.toString();
      final project = Project(
        id: projectId,
        title: title,
        description: description,
        link: link,
        imageUrls: imageUrls,
      );

      debugPrint('📦 Adding project: $title');
      debugPrint('📦 Project data: ${project.toMap()}');

      final updateData = {
        'projects': FieldValue.arrayUnion([project.toMap()]),
      };
      debugPrint('📦 Update payload: $updateData');

      await _db.collection('users').doc(uid).update(updateData);

      debugPrint('✅ Project added to Firestore');
      Get.snackbar('Success', 'Project added');
      // Wait a moment before reloading
      await Future.delayed(const Duration(milliseconds: 500));
      _loadCurrentUserProfile();
    } catch (e) {
      debugPrint('❌ Add Project Error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      Get.snackbar('Error', 'Failed to add project: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  /// Delete a project
  Future<void> deleteProject(String projectId) async {
    isLoading.value = true;
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) {
      Get.snackbar('Error', 'User session not found.');
      isLoading.value = false;
      return;
    }

    try {
      final updatedUser = currentUser.value;
      if (updatedUser == null) return;

      final projectToDelete = updatedUser.projects.firstWhere(
        (p) => p.id == projectId,
        orElse: () => Project(id: '', title: '', description: ''),
      );

      await _db.collection('users').doc(uid).update({
        'projects': FieldValue.arrayRemove([projectToDelete.toMap()]),
      });

      Get.snackbar('Success', 'Project deleted');
      _loadCurrentUserProfile();
    } catch (e) {
      debugPrint('Delete Project Error: $e');
      Get.snackbar('Error', 'Failed to delete project: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Add a new education
  Future<void> addEducation({
    required String school,
    required String degree,
    required String fieldOfStudy,
    required DateTime startDate,
    DateTime? endDate,
    String? description,
    required bool isCurrent,
  }) async {
    isLoading.value = true;
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) {
      Get.snackbar('Error', 'User session not found.');
      isLoading.value = false;
      return;
    }

    try {
      final educationId = DateTime.now().millisecondsSinceEpoch.toString();
      final education = Education(
        id: educationId,
        school: school,
        degree: degree,
        fieldOfStudy: fieldOfStudy,
        startDate: startDate,
        endDate: endDate,
        description: description,
        isCurrent: isCurrent,
      );

      debugPrint('🎓 Adding education: $school');
      
      await _db.collection('users').doc(uid).update({
        'education': FieldValue.arrayUnion([education.toMap()]),
      });

      Get.snackbar('Success', 'Education added');
      await Future.delayed(const Duration(milliseconds: 500));
      _loadCurrentUserProfile();
    } catch (e) {
      debugPrint('Add Education Error: $e');
      Get.snackbar('Error', 'Failed to add education: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Delete an education
  Future<void> deleteEducation(String educationId) async {
    isLoading.value = true;
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) {
      Get.snackbar('Error', 'User session not found.');
      isLoading.value = false;
      return;
    }

    try {
      final updatedUser = currentUser.value;
      if (updatedUser == null) return;

      // Find the education object to remove (need exact match for arrayRemove)
      final educationToDelete = updatedUser.education.firstWhere(
        (e) => e.id == educationId,
        orElse: () => Education(
          id: '',
          school: '',
          degree: '',
          fieldOfStudy: '',
          startDate: DateTime.now(),
        ),
      );

      if (educationToDelete.id.isEmpty) {
        debugPrint("Education not found to delete");
        return;
      }

      await _db.collection('users').doc(uid).update({
        'education': FieldValue.arrayRemove([educationToDelete.toMap()]),
      });

      Get.snackbar('Success', 'Education deleted');
      _loadCurrentUserProfile();
    } catch (e) {
      debugPrint('Delete Education Error: $e');
      Get.snackbar('Error', 'Failed to delete education: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Add a skill
  Future<void> addSkill(String skill) async {
    isLoading.value = true;
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) {
      SnackbarUtil.error('Error', 'User session not found.');
      isLoading.value = false;
      return;
    }

    try {
      final trimmedSkill = skill.trim().toLowerCase();

      // Check if skill already exists
      if (currentUser.value?.skills.contains(trimmedSkill) ?? false) {
        SnackbarUtil.info('Info', 'Skill already added');
        isLoading.value = false;
        return;
      }

      debugPrint('⭐ Adding skill: $trimmedSkill');

      final updateData = {
        'skills': FieldValue.arrayUnion([trimmedSkill]),
      };
      debugPrint('⭐ Update payload: $updateData');

      await _db.collection('users').doc(uid).update(updateData);

      debugPrint('✅ Skill added to Firestore');
      SnackbarUtil.success('Success', 'Skill added');

      // Wait for write confirmation and reload profile
      await Future.delayed(const Duration(milliseconds: 1000));
      _loadCurrentUserProfile();
    } catch (e) {
      debugPrint('❌ Add Skill Error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      SnackbarUtil.error('Error', 'Failed to add skill: ${e.toString()}');
    } finally {
      isLoading.value = false;
    }
  }

  /// Remove a skill
  Future<void> removeSkill(String skill) async {
    isLoading.value = true;
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) {
      Get.snackbar('Error', 'User session not found.');
      isLoading.value = false;
      return;
    }

    try {
      await _db.collection('users').doc(uid).update({
        'skills': FieldValue.arrayRemove([skill.toLowerCase()]),
      });

      Get.snackbar('Success', 'Skill removed');
      _loadCurrentUserProfile();
    } catch (e) {
      debugPrint('Remove Skill Error: $e');
      Get.snackbar('Error', 'Failed to remove skill: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Send a connection request to another user
  /// This creates a document in connectionRequests collection
  Future<void> sendConnectionRequest(String toUid) async {
    final fromUid = _currentUid;
    if (fromUid == null) {
      SnackbarUtil.error('Error', 'Not authenticated');
      return;
    }

    if (fromUid == toUid) {
      SnackbarUtil.info('Info', 'You cannot connect with yourself');
      return;
    }

    isLoading.value = true;
    try {
      // Check if request already exists
      final existingRequest = await _db
          .collection('connectionRequests')
          .where('fromUid', isEqualTo: fromUid)
          .where('toUid', isEqualTo: toUid)
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        SnackbarUtil.info('Info', 'Connection request already sent');
        isLoading.value = false;
        return;
      }

      // Check if already connected
      final toUserDoc = await _db.collection('users').doc(toUid).get();
      if (toUserDoc.exists) {
        final followers = List<String>.from(toUserDoc['followers'] ?? []);
        if (followers.contains(fromUid)) {
          SnackbarUtil.info('Info', 'Already connected');
          isLoading.value = false;
          return;
        }
      }

      // Create connection request
      await _db.collection('connectionRequests').add({
        'fromUid': fromUid,
        'toUid': toUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'fromUser':
            (await _db.collection('users').doc(fromUid).get())
                .data()?['fullName'] ??
            'Unknown User',
      });

      SnackbarUtil.success('Success', 'Connection request sent!');
    } catch (e) {
      debugPrint('Send connection request error: $e');
      SnackbarUtil.error('Error', 'Failed to send request: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Accept a connection request
  Future<void> acceptConnectionRequest(String requestId, String fromUid) async {
    final toUid = _currentUid;
    if (toUid == null) return;

    isLoading.value = true;
    try {
      // Use a transaction to ensure both users are updated atomically
      await _db.runTransaction((txn) async {
        // Update connection request status
        txn.update(_db.collection('connectionRequests').doc(requestId), {
          'status': 'accepted',
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Add toUid to fromUser's following list
        txn.update(_db.collection('users').doc(fromUid), {
          'following': FieldValue.arrayUnion([toUid]),
        });

        // Add fromUid to toUser's followers list
        txn.update(_db.collection('users').doc(toUid), {
          'followers': FieldValue.arrayUnion([fromUid]),
        });
      });

      SnackbarUtil.success('Success', 'Connection accepted!');
      _loadCurrentUserProfile();
    } catch (e) {
      debugPrint('Accept connection request error: $e');
      SnackbarUtil.error('Error', 'Failed to accept request');
    } finally {
      isLoading.value = false;
    }
  }

  /// Reject/delete a connection request
  Future<void> rejectConnectionRequest(String requestId) async {
    isLoading.value = true;
    try {
      await _db.collection('connectionRequests').doc(requestId).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      SnackbarUtil.info('Info', 'Connection request declined');
    } catch (e) {
      debugPrint('Reject connection request error: $e');
      SnackbarUtil.error('Error', 'Failed to decline request');
    } finally {
      isLoading.value = false;
    }
  }

  /// Get pending connection requests for current user
  Stream<List<Map<String, dynamic>>> getPendingConnectionRequests() {
    final uid = _currentUid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('connectionRequests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        });
  }
}
