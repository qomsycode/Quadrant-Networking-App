import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feed_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../core/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/cloudinary_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/skeleton_loader.dart';

/// Discovery Page - "Expand Your Network"
/// Shows grid of users available to follow
/// - Fetches users not already being followed by current user
/// - Shows Follow/Following buttons with real-time state updates
/// - Displays unfollow confirmation dialog when clicking "Following"
class DiscoveryPage extends StatelessWidget {
  const DiscoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final FeedController feedController = Get.find<FeedController>();
    final ProfileController profileController = Get.find<ProfileController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Expand Your Network",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<List<UserModel>>(
        // Get list of users that current user is not yet following
        stream: feedController.getDiscoveryUsersStream(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Empty state - user is following everyone
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 80,
                    color: isDark ? Colors.white30 : Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "You're all caught up!",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "You're already connected with everyone",
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          final discoveryUsers = snapshot.data!;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: discoveryUsers.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 0.8,
            ),
            itemBuilder: (context, index) {
              final user = discoveryUsers[index];
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(10) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.withAlpha(30),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: AppTheme.primaryBlue.withAlpha(30),
                      child: (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty)
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: CloudinaryService.optimizeUrl(
                                  user.profileImageUrl!,
                                  width: 200,
                                ),
                                width: 70, // radius * 2
                                height: 70,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => SkeletonLoader.circle(size: 70),
                                errorWidget: (context, url, error) => const Icon(Icons.person),
                              ),
                            )
                          : Text(
                              user.fullName.isNotEmpty ? user.fullName[0] : "U",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        user.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        "@${user.username}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Obx(() {
                      // Check if current user is following this user
                      final isFollowing =
                          profileController.currentUser.value?.following
                              .contains(user.uid) ??
                          false;

                      return ElevatedButton(
                        onPressed: () {
                          if (isFollowing) {
                            // Show unfollow confirmation dialog
                            _showUnfollowConfirmation(
                              context,
                              user.fullName,
                              profileController,
                              user.uid,
                            );
                          } else {
                            // Follow immediately
                            profileController.followUser(user.uid);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? Colors.transparent
                              : AppTheme.primaryBlue,
                          foregroundColor: isFollowing
                              ? AppTheme.primaryBlue
                              : Colors.white,
                          side: BorderSide(
                            color: AppTheme.primaryBlue,
                            width: isFollowing ? 1.5 : 0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: Text(
                          isFollowing ? "Following" : "Follow",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Twitter-style unfollow confirmation dialog
  void _showUnfollowConfirmation(
    BuildContext context,
    String userName,
    ProfileController profileController,
    String userId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text("Unfollow User?"),
        content: Text(
          "Do you want to unfollow $userName? You won't see their posts in your feed, and they won't know you unfollowed them.",
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              profileController.unfollowUser(userId);
              Get.back();
            },
            child: const Text("Unfollow", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
