import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/post_controller.dart';
import '../../core/app_theme.dart';
import '../../models/post_model.dart';

class BookmarksPage extends StatelessWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final PostController postController = Get.find<PostController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Bookmarks",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<List<PostModel>>(
        stream: postController.getBookmarkedPostsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_outline,
                    size: 80,
                    color: isDark ? Colors.white.withAlpha(76) : Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No bookmarks yet",
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white.withAlpha(179) : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Save posts you want to read later",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white.withAlpha(128) : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          final bookmarkedPosts = snapshot.data!;

          return ListView.separated(
            itemCount: bookmarkedPosts.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final post = bookmarkedPosts[index];
              return _buildBookmarkedPostCard(
                context,
                post,
                isDark,
                postController,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBookmarkedPostCard(
    BuildContext context,
    PostModel post,
    bool isDark,
    PostController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with avatar and name
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryBlue,
                child: Text(
                  post.profileInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      "@${post.username}",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Content
          Text(
            post.content,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white.withAlpha(222) : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          // Engagement metrics
          Row(
            children: [
              Icon(Icons.chat_bubble_outline, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                "${post.commentCount}",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(width: 16),
              Icon(Icons.repeat, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                "${post.reposts.length}",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(width: 16),
              Icon(Icons.favorite_border, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                "${post.likes}",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const Spacer(),
              const Icon(
                Icons.bookmark,
                size: 18,
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
