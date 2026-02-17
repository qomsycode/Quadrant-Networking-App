import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/app_theme.dart';
import '../../controllers/job_controller.dart';
import '../../models/job_model.dart';
import 'post_job_dialog.dart';

class JobsPage extends StatelessWidget {
  const JobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Ensure controller is initialized
    final jobController = Get.find<JobController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const PostJobDialog(),
          );
        },
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.add),
        label: const Text("Post Job"),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  onChanged: (val) => jobController.searchQuery.value = val,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: "Search jobs, companies...",
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.grey),
                    filled: true,
                    fillColor: isDark ? Colors.white.withAlpha(15) : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Remote', 'Hybrid', 'Onsite'].map((type) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Obx(() {
                          final isSelected = jobController.selectedType.value == type;
                          return FilterChip(
                            label: Text(type),
                            selected: isSelected,
                            onSelected: (bool selected) {
                              if (selected) jobController.selectedType.value = type;
                            },
                            backgroundColor: isDark ? Colors.white10 : Colors.white,
                            selectedColor: AppTheme.primaryBlue.withAlpha(50),
                            labelStyle: TextStyle(
                              color: isSelected ? AppTheme.primaryBlue : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected ? AppTheme.primaryBlue : (isDark ? Colors.white10 : Colors.grey[300]!),
                              ),
                            ),
                            showCheckmark: false,
                          );
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Job List
          Expanded(
            child: Obx(() {
              if (jobController.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final jobs = jobController.filteredJobs;
              
              if (jobs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.work_outline, size: 64, color: isDark ? Colors.white24 : Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        "No jobs found",
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.grey[500],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  return _JobCard(job: jobs[index], controller: jobController);
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final JobModel job;
  final JobController controller;

  const _JobCard({required this.job, required this.controller});

  // Helper to format usage of DateTime
  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  void _confirmDelete(BuildContext context, String jobId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Job"),
        content: const Text("Are you sure you want to delete this job listing?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.deleteJob(jobId);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Simple logic to pick a color based on company name
    final Color logoColor = Colors.primaries[job.company.hashCode % Colors.primaries.length];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
          width: 1.5,
        ),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: logoColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  job.company.isNotEmpty ? job.company[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: logoColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : AppTheme.deepNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.company,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.isMyJob(job))
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _confirmDelete(context, job.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: isDark ? Colors.white38 : Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                job.location,
                style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(width: 12),
              Icon(Icons.work_outline, size: 14, color: isDark ? Colors.white38 : Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                job.type,
                style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 13),
              ),
              const Spacer(),
              Text(
                _formatTime(job.createdAt),
                style: TextStyle(color: isDark ? Colors.white30 : Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
          Divider(height: 24, color: isDark ? Colors.white10 : Colors.grey.shade200),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                job.salary,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                  fontSize: 14,
                ),
              ),
              Obx(() {
                final hasApplied = controller.hasApplied(job);
                return TextButton(
                  onPressed: hasApplied ? null : () => controller.applyToJob(job.id),
                  style: TextButton.styleFrom(
                    backgroundColor: hasApplied 
                        ? (isDark ? Colors.white10 : Colors.grey[200])
                        : AppTheme.primaryBlue.withAlpha(30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(
                    hasApplied ? "Applied" : "Apply Now",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: hasApplied 
                          ? (isDark ? Colors.white38 : Colors.grey)
                          : AppTheme.primaryBlue,
                    ),
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
