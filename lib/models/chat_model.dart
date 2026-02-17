import 'package:cloud_firestore/cloud_firestore.dart';

/// ==========================================
/// CHAT DATA MODEL
/// ==========================================
///
/// Represents a Private Message (DM) thread between two users.
/// Location in Firestore: /chats/{chatId}
///
/// DETERMINISTIC ID LOGIC:
/// ------------------------------------------
/// To avoid duplicate threads, we calculate the chatId by:
/// 1. Taking the two participant UIDs.
/// 2. Sorting them alphabetically.
/// 3. Joining them with an underscore (e.g., "uid_a_uid_b").
/// This ensures regardless of who starts the chat, they always land in the same doc.
///
/// DOCUMENT SCHEMA:
/// ------------------------------------------
/// participants: List<String> - The two UIDs in the chat.
/// lastMessage: String        - Text of the most recent message (for list view).
/// lastMessageTime: Timestamp - When the thread was last active.
/// lastMessageSenderId: String- UID of the person who sent the last message.
/// unreadCounts: Map<String, int> - Per-user counter for new messages.
///
/// ACCESS CONTROL:
/// ------------------------------------------
/// Security rules ensure only UIDs present in the 'participants' list
/// can read or write to this document or its /messages subcollection.
///
class ChatModel {
  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final Map<String, int> unreadCounts;

  ChatModel({
    required this.chatId,
    required this.participants,
    this.lastMessage = '',
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.unreadCounts = const {},
  });

  /// Returns the other user's UID given the current user's UID.
  String otherUserId(String currentUid) {
    return participants.firstWhere(
      (uid) => uid != currentUid,
      orElse: () => '',
    );
  }

  /// Returns the unread count for a specific user.
  int unreadCountFor(String uid) => unreadCounts[uid] ?? 0;

  factory ChatModel.fromMap(Map<String, dynamic> map, String docId) {
    return ChatModel(
      chatId: docId,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate(),
      lastMessageSenderId: map['lastMessageSenderId'],
      unreadCounts: Map<String, int>.from(map['unreadCounts'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : FieldValue.serverTimestamp(),
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCounts': unreadCounts,
    };
  }
}
