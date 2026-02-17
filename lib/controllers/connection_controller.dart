import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/connection_request_model.dart';
import '../models/user_model.dart';

class ConnectionController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  // --- PUBLIC OBSERVABLES ---
  var pendingRequests = <ConnectionRequestModel>[].obs;
  var sentRequests = <ConnectionRequestModel>[].obs;
  var connections = <UserModel>[].obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _listenToPendingRequests();
    _listenToSentRequests();
    _listenToConnections();
  }

  /// Listen to pending connection requests for current user
  void _listenToPendingRequests() {
    final uid = _currentUid;
    if (uid == null) return;

    _db
        .collection('connectionRequests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            final requests = snapshot.docs.map((doc) {
              return ConnectionRequestModel.fromMap(doc.data(), doc.id);
            }).toList();
            pendingRequests.assignAll(requests);
          },
          onError: (e) => debugPrint('Error listening to pending requests: $e'),
        );
  }

  /// Listen to sent connection requests
  void _listenToSentRequests() {
    final uid = _currentUid;
    if (uid == null) return;

    _db
        .collection('connectionRequests')
        .where('fromUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          final requests = snapshot.docs.map((doc) {
            return ConnectionRequestModel.fromMap(doc.data(), doc.id);
          }).toList();
          sentRequests.assignAll(requests);
        }, onError: (e) => debugPrint('Error listening to sent requests: $e'));
  }

  /// Listen to accepted connections (both directions)
  void _listenToConnections() {
    final uid = _currentUid;
    if (uid == null) return;

    // Get accepted connections where user is the recipient
    _db
        .collection('connectionRequests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .listen((snapshot) async {
          final connectedUids = snapshot.docs
              .map((doc) => doc['fromUid'] as String)
              .toList();

          // Also get connections where user is the sender
          final sentSnapshot = await _db
              .collection('connectionRequests')
              .where('fromUid', isEqualTo: uid)
              .where('status', isEqualTo: 'accepted')
              .get();

          connectedUids.addAll(
            sentSnapshot.docs.map((doc) => doc['toUid'] as String).toList(),
          );

          // Remove duplicates
          connectedUids.toSet().forEach((connectedUid) async {
            final userDoc = await _db
                .collection('users')
                .doc(connectedUid)
                .get();
            if (userDoc.exists) {
              final user = UserModel.fromMap(userDoc.data()!);
              if (!connections.any((c) => c.uid == user.uid)) {
                connections.add(user);
              }
            }
          });
        }, onError: (e) => debugPrint('Error listening to connections: $e'));
  }

  /// Send a connection request
  Future<void> sendConnectionRequest(String toUid, UserModel targetUser) async {
    if (_currentUid == null) return;
    if (_currentUid == toUid) {
      Get.snackbar('Error', 'You cannot send a request to yourself');
      return;
    }

    try {
      // Check if request already exists
      final existing = await _db
          .collection('connectionRequests')
          .where('fromUid', isEqualTo: _currentUid)
          .where('toUid', isEqualTo: toUid)
          .get();

      if (existing.docs.isNotEmpty) {
        Get.snackbar('Info', 'Request already sent to this user');
        return;
      }

      // Get current user data
      final currentUserDoc = await _db
          .collection('users')
          .doc(_currentUid)
          .get();
      final currentUserData = currentUserDoc.data() ?? {};
      final String currentName = currentUserData['fullName'] ?? 'User';
      final String currentUsername = currentUserData['username'] ?? 'user';

      // Create connection request
      await _db.collection('connectionRequests').add({
        'fromUid': _currentUid,
        'toUid': toUid,
        'fromName': currentName,
        'fromUsername': currentUsername,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
      });

      Get.snackbar(
        'Success',
        'Connection request sent to ${targetUser.fullName}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('Send request error: $e');
      Get.snackbar('Error', 'Failed to send connection request');
    }
  }

  /// Accept a connection request
  Future<void> acceptConnectionRequest(ConnectionRequestModel request) async {
    if (_currentUid == null) return;

    try {
      isLoading.value = true;

      // Update request status
      await _db.collection('connectionRequests').doc(request.id).update({
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Add to 1st degree connections for both users
      await _db.collection('users').doc(_currentUid).update({
        'connections': FieldValue.arrayUnion([request.fromUid]),
      });

      await _db.collection('users').doc(request.fromUid).update({
        'connections': FieldValue.arrayUnion([_currentUid]),
      });

      Get.snackbar(
        'Success',
        'You are now connected with ${request.fromName}',
        snackPosition: SnackPosition.BOTTOM,
      );

      _listenToConnections(); // Refresh connections list
    } catch (e) {
      debugPrint('Accept request error: $e');
      Get.snackbar('Error', 'Failed to accept connection request');
    } finally {
      isLoading.value = false;
    }
  }

  /// Reject a connection request
  Future<void> rejectConnectionRequest(ConnectionRequestModel request) async {
    if (_currentUid == null) return;

    try {
      isLoading.value = true;

      // Update request status
      await _db.collection('connectionRequests').doc(request.id).update({
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      Get.snackbar(
        'Done',
        'Connection request rejected',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('Reject request error: $e');
      Get.snackbar('Error', 'Failed to reject connection request');
    } finally {
      isLoading.value = false;
    }
  }

  /// Cancel a sent connection request
  Future<void> cancelConnectionRequest(String requestId) async {
    try {
      await _db.collection('connectionRequests').doc(requestId).delete();
      Get.snackbar(
        'Done',
        'Connection request cancelled',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('Cancel request error: $e');
      Get.snackbar('Error', 'Failed to cancel connection request');
    }
  }

  /// Check connection status with a user
  Future<String> getConnectionStatus(String userId) async {
    if (_currentUid == null) return 'none';

    try {
      // Check if connected
      final currentUserDoc = await _db
          .collection('users')
          .doc(_currentUid)
          .get();
      final connections = List<String>.from(
        currentUserDoc['connections'] ?? [],
      );

      if (connections.contains(userId)) {
        return 'connected';
      }

      // Check if pending request from current user
      final sentRequest = await _db
          .collection('connectionRequests')
          .where('fromUid', isEqualTo: _currentUid)
          .where('toUid', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (sentRequest.docs.isNotEmpty) {
        return 'pending';
      }

      // Check if pending request to current user
      final receivedRequest = await _db
          .collection('connectionRequests')
          .where('fromUid', isEqualTo: userId)
          .where('toUid', isEqualTo: _currentUid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (receivedRequest.docs.isNotEmpty) {
        return 'received';
      }

      return 'none';
    } catch (e) {
      debugPrint('Get connection status error: $e');
      return 'none';
    }
  }

  /// Get stream of connection status
  Stream<String> getConnectionStatusStream(String userId) async* {
    if (_currentUid == null) {
      yield 'none';
      return;
    }

    try {
      yield* _db.collection('users').doc(_currentUid).snapshots().asyncExpand((
        userSnapshot,
      ) {
        final connections = List<String>.from(
          userSnapshot['connections'] ?? [],
        );
        if (connections.contains(userId)) {
          return Stream.value('connected');
        }

        return _db
            .collection('connectionRequests')
            .where('status', isEqualTo: 'pending')
            .snapshots()
            .map((snapshot) {
              for (var doc in snapshot.docs) {
                if (doc['fromUid'] == _currentUid && doc['toUid'] == userId) {
                  return 'pending';
                }
                if (doc['fromUid'] == userId && doc['toUid'] == _currentUid) {
                  return 'received';
                }
              }
              return 'none';
            });
      });
    } catch (e) {
      debugPrint('Get connection status stream error: $e');
      yield 'none';
    }
  }
}
