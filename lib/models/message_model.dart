import 'package:cloud_firestore/cloud_firestore.dart';

/// ==========================================
/// MESSAGE DATA MODEL
/// ==========================================
///
/// Represents a single text message within a chat thread.
/// Location in Firestore: /chats/{chatId}/messages/{messageId}
///
/// DOCUMENT SCHEMA:
/// ------------------------------------------
/// senderId: String    - UID of the user who sent this message.
/// text: String        - The message content.
/// timestamp: Timestamp- Server-side creation time.
/// readBy: List<String>- Array of UIDs who have seen the message.
///
/// SUBCOLLECTION DESIGN:
/// ------------------------------------------
/// Messages are stored as a subcollection of a specific Chat. 
/// This keeps message history isolated and prevents a single document
/// from growing too large (respecting the 1MB Firestore limit).
///
class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final List<String> readBy;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.readBy = const [],
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String docId) {
    return MessageModel(
      id: docId,
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: List<String>.from(map['readBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': readBy,
    };
  }
}
