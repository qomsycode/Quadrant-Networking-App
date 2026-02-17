import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/job_model.dart';
import '../controllers/profile_controller.dart';
import 'package:get/get.dart';

/// ==========================================
/// JOB SERVICE
/// ==========================================
///
/// Handles all Firestore operations for the Job Board.
///
/// KEY LOGIC:
/// ------------------------------------------
/// 1. Denormalization on Post: When a job is posted, we attempt to 
///    fetch the recruiter's name from 'ProfileController' to avoid
///    an extra Firestore read in the list view.
/// 2. Application Tracking: Uses 'applicants' array in the job document. 
///    Any user can apply by adding their UID to this list.
/// 3. Stream-Based Feed: Provides a real-time stream of all jobs 
///    sorted by creation date.
///
class JobService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Post a new job
  static Future<void> postJob({
    required String title,
    required String company,
    required String location,
    required String salary,
    required String description,
    required String type,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Get current user's name for denormalization
    // We try to get it from ProfileController if available, otherwise fetch
    String userName = 'Recruiter';
    try {
      if (Get.isRegistered<ProfileController>()) {
        userName = Get.find<ProfileController>().currentUser.value?.fullName ?? 'Recruiter';
      }
    } catch (_) {}

    await _db.collection('jobs').add({
      'title': title,
      'company': company,
      'location': location,
      'salary': salary,
      'description': description,
      'type': type,
      'postedBy': user.uid,
      'postedByName': userName,
      'applicants': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get stream of all jobs, ordered by newest first
  static Stream<List<JobModel>> getJobsStream() {
    // Note: We avoid orderBy if we combine with where filters to avoid index issues.
    // Since we want ALL jobs (filtered client side usually), we can just order by createdAt.
    return _db
        .collection('jobs')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JobModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Apply to a job
  static Future<void> applyToJob(String jobId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('jobs').doc(jobId).update({
      'applicants': FieldValue.arrayUnion([uid])
    });
  }

  /// Withdraw application
  static Future<void> withdrawApplication(String jobId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('jobs').doc(jobId).update({
      'applicants': FieldValue.arrayRemove([uid])
    });
  }

  /// Delete a job (only if posted by current user)
  static Future<void> deleteJob(String jobId) async {
    await _db.collection('jobs').doc(jobId).delete();
  }
}
