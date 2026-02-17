import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';

import 'package:get/get.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';

/// ==========================================
/// CHAT CONTROLLER (GetX)
/// ==========================================
///
/// This controller acts as a thin reactive layer over ChatService.
/// It provides the UI with live streams of active conversations and
/// global notification counts (unread messages).
///
/// KEY RESPONSIBILITIES:
/// ------------------------------------------
/// 1. Inbox Management: Listens to the 'chats' stream and updates
///    the Inbox UI in real-time.
/// 2. Notification Badge: Exposes 'totalUnread' to power global 
///    app navigation badges.
/// 3. Navigation Orchestration: Facilitates opening/creating chats
///    between users from various contexts (Discovery, Profile, Posts).
///
/// STATE ARCHITECTURE:
/// ------------------------------------------
/// - chats: A reactive list of ChatModel objects.
/// - totalUnread: A reactive integer for global notification state.
///
class ChatController extends GetxController {
  final chats = <ChatModel>[].obs;
  final totalUnread = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _listenToChats();
    _listenToUnread();
  }

  void _listenToChats() {
    ChatService.getChatsStream().listen(
      (chatList) => chats.value = chatList,
      onError: (e) => debugPrint('ChatController: Error listening to chats: $e'),
    );
  }

  void _listenToUnread() {
    ChatService.getTotalUnreadStream().listen(
      (count) => totalUnread.value = count,
      onError: (e) => debugPrint('ChatController: Error listening to unread: $e'),
    );
  }

  /// Open or create a chat with another user and navigate to it.
  Future<String> openChat(String otherUserId) async {
    final chatId = await ChatService.getOrCreateChat(otherUserId);
    return chatId;
  }

  /// Send a message in a chat.
  Future<void> sendMessage(String chatId, String text) async {
    if (text.trim().isEmpty) return;
    await ChatService.sendMessage(chatId, text.trim());
  }

  /// Mark a chat as read.
  Future<void> markAsRead(String chatId) async {
    await ChatService.markAsRead(chatId);
  }
}
