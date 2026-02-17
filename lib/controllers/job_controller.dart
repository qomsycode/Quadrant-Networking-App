import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/job_model.dart';
import '../services/job_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ==========================================
/// JOB CONTROLLER (GetX)
/// ==========================================
///
/// This controller manages the "Job Board" feature, handling listing 
/// discovery, filtering, and recruitment actions (applying/posting).
///
/// KEY RESPONSIBILITIES:
/// ------------------------------------------
/// 1. Feed Orchestration: Binds to the global jobs stream from Firestore.
/// 2. Multi-Criteria Filtering: Performs client-side filtering on 
///    Job Type (Remote/Hybrid) and search keywords for instant UI feedback.
/// 3. Recruitment Logic: Manages application state and verification 
///    (e.g., has user already applied?).
///
/// STATE ARCHITECTURE:
/// ------------------------------------------
/// - jobs: Reactive list of all available job listings.
/// - searchQuery/selectedType: Reactive filtering parameters that
///   trigger immediate re-calculation of 'filteredJobs'.
///
class JobController extends GetxController {
  final jobs = <JobModel>[].obs;
  final isLoading = false.obs;
  
  // Filters
  final searchQuery = ''.obs;
  final selectedType = 'All'.obs; // All, Remote, Hybrid, Onsite

  @override
  void onInit() {
    super.onInit();
    _bindJobs();
  }

  void _bindJobs() {
    isLoading.value = true;
    JobService.getJobsStream().listen((jobList) {
      jobs.value = jobList;
      isLoading.value = false;
    }, onError: (e) {
      debugPrint("JobController Error: $e");
      isLoading.value = false;
    });
  }

  /// Filtered jobs based on search query and type
  List<JobModel> get filteredJobs {
    return jobs.where((job) {
      // 1. Filter by type
      if (selectedType.value != 'All') {
        if (job.type.toLowerCase() != selectedType.value.toLowerCase()) {
          return false;
        }
      }

      // 2. Filter by search query
      if (searchQuery.value.isNotEmpty) {
        final query = searchQuery.value.toLowerCase();
        final matchesTitle = job.title.toLowerCase().contains(query);
        final matchesCompany = job.company.toLowerCase().contains(query);
        if (!matchesTitle && !matchesCompany) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> postJob({
    required String title,
    required String company,
    required String location,
    required String salary,
    required String description,
    required String type,
  }) async {
    try {
      isLoading.value = true;
      await JobService.postJob(
        title: title,
        company: company,
        location: location,
        salary: salary,
        description: description,
        type: type,
      );
      Get.snackbar('Success', 'Job posted successfully!',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', 'Failed to post job: $e',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> applyToJob(String jobId) async {
    try {
      await JobService.applyToJob(jobId);
      Get.snackbar('Applied', 'Application sent successfully!',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', 'Failed to apply: $e',
          snackPosition: SnackPosition.BOTTOM);
    }
  }
  
  bool hasApplied(JobModel job) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    return job.applicants.contains(uid);
  }

  bool isMyJob(JobModel job) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && job.postedBy == uid;
  }
  
  Future<void> deleteJob(String jobId) async {
    try {
      await JobService.deleteJob(jobId);
      Get.snackbar('Deleted', 'Job listing removed', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete job: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }
}
