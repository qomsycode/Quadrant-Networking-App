import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

/// Service for all Firestore chat/DM operations.
///
/// Firestore Structure:
/// ```
/// chats/{chatId}             ← ChatModel
///   └── messages/{messageId} ← MessageModel
/// ```
class ChatService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Generates a deterministic, unique chat ID for any two users.
  /// Sorting UIDs ensures the same ID regardless of who initiates.
  static String getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Gets or creates a chat between two users.
  /// Returns the chatId.
  ///
  /// Note: Firestore read rules check `resource.data.participants`, which fails
  /// on non-existent documents (resource.data is null). So if the read fails
  /// with permission-denied, we know the chat doesn't exist and create it.
  static Future<String> getOrCreateChat(String otherUserId) async {
    final currentUid = _auth.currentUser!.uid;
    final chatId = getChatId(currentUid, otherUserId);
    final chatRef = _db.collection('chats').doc(chatId);

    try {
      // Try to read the chat (succeeds only if it exists AND we're a participant)
      final doc = await chatRef.get();
      if (!doc.exists) {
        // This branch shouldn't normally be reached due to rules,
        // but handle it just in case
        await _createChat(chatRef, currentUid, otherUserId);
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Read failed because the document doesn't exist (resource.data is null
        // in Firestore rules, so the participant check fails). Create it now.
        await _createChat(chatRef, currentUid, otherUserId);
      } else {
        rethrow;
      }
    }

    return chatId;
  }

  /// Helper to create a new chat document.
  static Future<void> _createChat(
    DocumentReference chatRef,
    String currentUid,
    String otherUserId,
  ) async {
    await chatRef.set({
      'participants': [currentUid, otherUserId],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': '',
      'unreadCounts': {currentUid: 0, otherUserId: 0},
    });
    debugPrint('ChatService: Created new chat ${chatRef.id}');
  }

  /// Sends a message in an existing chat.
  /// Also updates the chat document's lastMessage, timestamp, and unread count.
  static Future<void> sendMessage(String chatId, String text) async {
    final currentUid = _auth.currentUser!.uid;

    // Add the message to the subcollection
    await _db.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [currentUid],
    });

    // Get the chat doc to find the other participant
    final chatDoc = await _db.collection('chats').doc(chatId).get();
    final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
    final otherUid = participants.firstWhere((uid) => uid != currentUid, orElse: () => '');

    // Update the chat document with last message info and increment unread for other user
    await _db.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUid,
      'unreadCounts.$otherUid': FieldValue.increment(1),
    });
  }

  /// Returns a real-time stream of all chats the current user participates in,
  /// ordered by most recent message.
  static Stream<List<ChatModel>> getChatsStream() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return const Stream.empty();

    // Note: We avoid using .orderBy() with .where(arrayContains:) because
    // it requires a composite index in Firestore. Instead, we sort client-side.
    return _db
        .collection('chats')
        .where('participants', arrayContains: currentUid)
        .snapshots()
        .map((snapshot) {
      final chats = snapshot.docs
          .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
          .toList();
      // Sort by lastMessageTime descending (most recent first)
      chats.sort((a, b) {
        final aTime = a.lastMessageTime ?? DateTime(2000);
        final bTime = b.lastMessageTime ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      return chats;
    });
  }

  /// Returns a real-time stream of messages for a specific chat,
  /// ordered chronologically (oldest first).
  static Stream<List<MessageModel>> getMessagesStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Marks all messages in a chat as read for the current user.
  /// Resets the unread counter to 0.
  static Future<void> markAsRead(String chatId) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return;

    await _db.collection('chats').doc(chatId).update({
      'unreadCounts.$currentUid': 0,
    });
  }

  /// Returns total unread message count across all chats for badge display.
  static Stream<int> getTotalUnreadStream() {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return const Stream.empty();

    return _db
        .collection('chats')
        .where('participants', arrayContains: currentUid)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (var doc in snapshot.docs) {
        final unread = doc.data()['unreadCounts'] as Map<String, dynamic>?;
        if (unread != null && unread.containsKey(currentUid)) {
          total += (unread[currentUid] as num).toInt();
        }
      }
      return total;
    });
  }
}
