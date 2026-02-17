import 'package:cloud_firestore/cloud_firestore.dart';

class ConnectionRequestModel {
  final String id;
  final String fromUid; // Person sending the request
  final String toUid; // Person receiving the request
  final String fromName;
  final String fromUsername;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime createdAt;
  final DateTime? respondedAt;

  ConnectionRequestModel({
    required this.id,
    required this.fromUid,
    required this.toUid,
    required this.fromName,
    required this.fromUsername,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  // Convert from Firestore document
  factory ConnectionRequestModel.fromMap(
    Map<String, dynamic> data,
    String docId,
  ) {
    return ConnectionRequestModel(
      id: docId,
      fromUid: data['fromUid'] ?? '',
      toUid: data['toUid'] ?? '',
      fromName: data['fromName'] ?? 'User',
      fromUsername: data['fromUsername'] ?? 'user',
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'fromUid': fromUid,
      'toUid': toUid,
      'fromName': fromName,
      'fromUsername': fromUsername,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null
          ? Timestamp.fromDate(respondedAt!)
          : null,
    };
  }
}
