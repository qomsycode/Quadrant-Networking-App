import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feed_controller.dart';
import '../../controllers/post_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../core/app_theme.dart';
import '../../models/post_model.dart';
import '../../services/cloudinary_service.dart'; // Import service
import 'profile_page.dart';
import '../../widgets/mention_text.dart';
import '../../widgets/skeleton_loader.dart';

import '../../widgets/ad_banner.dart';
import '../../screens/main/search_results_page.dart';

class HomeFeedPage extends StatelessWidget {
  const HomeFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final FeedController controller = Get.find<FeedController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Obx(() {
      // Only show discovery if user has no followings AND is not showing all posts
      // Always allow access to "All" feed even if no followings
      if (controller.hasFollowings.value == false &&
          controller.showAllPosts.value == false) {
        // Show discovery, but allow user to still toggle to "All"
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              _buildIdentityHeader(controller),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        "Start following people to see their posts!",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => controller.setShowAll(true),
                        child: const Text("View All Posts"),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            _buildIdentityHeader(controller),
            Expanded(
              child: controller.allPosts.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            "No posts yet. Check back later!",
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      // Add 1 ad for every 10 posts
                      itemCount: controller.allPosts.length + (controller.allPosts.length ~/ 10),
                      itemBuilder: (context, index) {
                        // Logic: Items 0-9 = Posts, 10 = Ad, 11-20 = Posts, 21 = Ad...
                        // If index+1 is divisible by 11, it's an ad slot
                        final isAd = (index + 1) % 11 == 0;

                        if (isAd) {
                          return const Column(
                            children: [
                              Divider(),
                              AdBanner(),
                              Divider(),
                            ],
                          );
                        }

                        // Calculate actual post index
                        // For every 11 items, we have 1 ad, so subtract (index ~/ 11) ads
                        final postIndex = index - (index ~/ 11);
                        
                        // Safety check
                        if (postIndex >= controller.allPosts.length) return const SizedBox();

                        final post = controller.allPosts[postIndex];
                        return Column(
                          children: [
                            _buildFeedCard(
                              context,
                              post,
                              controller,
                              isDark,
                              currentUid,
                            ),
                            const Divider(), // Manual divider since we removed ListView.separated
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildFeedCard(
    BuildContext context,
    PostModel post,
    FeedController controller,
    bool isDark,
    String currentUid,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header with user info
          GestureDetector(
            onTap: () {
              Get.find<ProfileController>().loadUserProfile(post.uid);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfilePage(userId: post.uid),
                ),
              );
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryBlue,
                  backgroundImage: (post.profileImageUrl != null && post.profileImageUrl!.isNotEmpty)
                      ? NetworkImage(post.profileImageUrl!)
                      : null,
                  child: (post.profileImageUrl == null || post.profileImageUrl!.isEmpty)
                      ? Text(
                          post.profileInitial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "@${post.username}",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "· ${post.getTimeAgo()}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // 3-dot menu for post actions
                if (post.uid == currentUid)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: isDark ? Colors.white38 : Colors.grey,
                      size: 20,
                    ),
                    onSelected: (value) {
                      if (value == 'delete') {
                        Get.dialog(
                          AlertDialog(
                            title: const Text('Delete Post'),
                            content: const Text('Are you sure you want to delete this post? This cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Get.back();
                                  Get.find<PostController>().deletePost(post.id);
                                },
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Post content
          MentionText(
            text: post.content,
            baseStyle: Theme.of(context).textTheme.bodyLarge, // Adaptive style
          ),
          if (post.mediaUrls.isNotEmpty && post.mediaType == 'image') ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: CloudinaryService.optimizeUrl(post.mediaUrls.first, width: 800),
                placeholder: (context, url) => SkeletonLoader.square(
                  size: 250,
                  borderRadius: 12,
                ),
                errorWidget: (context, url, error) => Container(
                  height: 250,
                  color: Colors.grey.withAlpha(50),
                  child: const Icon(Icons.error),
                ),
                fit: BoxFit.cover,
                width: double.infinity,
                height: 250,
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Engagement buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIconBtn(
                Icons.chat_bubble_outline,
                "${post.commentCount}",
                isDark,
                () => _showCommentDialog(context, post),
              ),
              _buildIconBtn(
                post.reposts.contains(currentUid)
                    ? Icons.repeat
                    : Icons.repeat_outlined,
                "${post.reposts.length}",
                isDark,
                () => controller.toggleRepost(
                  post.id,
                  post.reposts.contains(currentUid),
                ),
                color: post.reposts.contains(currentUid)
                    ? AppTheme.primaryBlue
                    : null,
              ),
              _buildIconBtn(
                post.likedBy.contains(currentUid)
                    ? Icons.favorite
                    : Icons.favorite_border,
                "${post.likes}",
                isDark,
                () => controller.toggleLike(
                  post.id,
                  post.likedBy.contains(currentUid),
                ),
                color: post.likedBy.contains(currentUid) ? Colors.red : null,
              ),
              _buildIconBtn(
                post.bookmarks.contains(currentUid)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                "",
                isDark,
                () => controller.toggleBookmark(
                  post.id,
                  post.bookmarks.contains(currentUid),
                ),
                color: post.bookmarks.contains(currentUid)
                    ? AppTheme.primaryBlue
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCommentDialog(BuildContext context, PostModel post) {
    final TextEditingController commentController = TextEditingController();
    final PostController postController = Get.find<PostController>();

    Get.dialog(
      Dialog(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Comments (${post.commentCount})",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Comments list
                StreamBuilder(
                  stream: postController.getCommentsStream(post.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    final comments = snapshot.data ?? [];

                    if (comments.isEmpty) {
                      return const Text(
                        "No comments yet. Be the first!",
                        style: TextStyle(color: Colors.grey),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppTheme.primaryBlue
                                        .withAlpha(100),
                                    child: Text(
                                      comment.name.isNotEmpty
                                          ? comment.name[0]
                                          : 'U',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comment.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          "@${comment.username}",
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 40),
                                child: Text(
                                  comment.content,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              const Divider(height: 12),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Add comment field
                TextField(
                  controller: commentController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: "Add a comment...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (commentController.text.trim().isNotEmpty) {
                        postController.addComment(
                          post.id,
                          commentController.text.trim(),
                        );
                        Get.back();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                    ),
                    child: const Text("Post Comment"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconBtn(
    IconData icon,
    String label,
    bool isDark,
    VoidCallback onTap, {
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color ?? (isDark ? Colors.white38 : Colors.grey),
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildIdentityHeader(FeedController controller) {
    final isDark = Get.isDarkMode;
    final backgroundColor = isDark
        ? Colors.black.withOpacity(0.3)
        : Colors.grey.shade200.withOpacity(0.5);

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "The Quadrant",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.search, color: isDark ? Colors.white : Colors.black),
                onPressed: () {
                  Get.to(() => const SearchResultsPage());
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Obx(() {
            final showAll = controller.showAllPosts.value;
            return Row(
              children: [
                GestureDetector(
                  onTap: () => controller.setShowAll(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: showAll
                          ? Colors.transparent
                          : AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Following',
                      style: TextStyle(
                        color: showAll ? Colors.grey : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => controller.setShowAll(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: showAll
                          ? AppTheme.primaryBlue
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'All',
                      style: TextStyle(
                        color: showAll ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
