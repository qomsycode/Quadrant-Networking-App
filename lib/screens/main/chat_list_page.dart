import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/chat_controller.dart';
import '../../core/app_theme.dart';
import '../../controllers/theme_controller.dart';
import '../../models/chat_model.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/skeleton_loader.dart';
import 'chat_page.dart';

/// Displays a list of all conversations for the current user.
///
/// Each row shows the other user's avatar, name, last message preview,
/// timestamp, and an unread indicator.
class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final chatController = Get.find<ChatController>();
    final themeController = Get.find<ThemeController>();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Obx(() {
      final isDark = themeController.isDarkMode;

      return Scaffold(
        backgroundColor: isDark ? AppTheme.deepNavy : Colors.grey[50],
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.deepNavy : AppTheme.primaryBlue,
          title: const Text(
            'Messages',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: chatController.chats.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: isDark ? Colors.white30 : Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No messages yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start a conversation from someone\'s profile',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white30 : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: chatController.chats.length,
                itemBuilder: (context, index) {
                  final chat = chatController.chats[index];
                  return _ChatTile(
                    chat: chat,
                    currentUid: currentUid,
                    isDark: isDark,
                  );
                },
              ),
      );
    });
  }
}

class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  final String currentUid;
  final bool isDark;

  const _ChatTile({
    required this.chat,
    required this.currentUid,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final otherUid = chat.otherUserId(currentUid);
    final unread = chat.unreadCountFor(currentUid);
    final hasUnread = unread > 0;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(otherUid).get(),
      builder: (context, snapshot) {
        String name = 'Loading...';
        String? profileImageUrl;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['fullName'] ?? 'Unknown';
          profileImageUrl = data['profileImageUrl'];
        }

        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  chatId: chat.chatId,
                  otherUserId: otherUid,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryBlue,
                  child: (profileImageUrl != null && profileImageUrl.isNotEmpty)
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: CloudinaryService.optimizeUrl(profileImageUrl, width: 100),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => SkeletonLoader.circle(size: 48),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.person, color: Colors.white),
                          ),
                        )
                      : Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                // Name + Last message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                          color: isDark ? Colors.white : AppTheme.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chat.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                          color: hasUnread
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark ? Colors.white54 : Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ),
                // Timestamp + unread badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(chat.lastMessageTime),
                      style: TextStyle(
                        fontSize: 11,
                        color: hasUnread
                            ? AppTheme.primaryBlue
                            : (isDark ? Colors.white38 : Colors.grey[500]),
                      ),
                    ),
                    if (hasUnread) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}';
  }
}
