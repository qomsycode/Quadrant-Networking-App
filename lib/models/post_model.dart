import 'package:cloud_firestore/cloud_firestore.dart';

/// ==========================================
/// POST DATA MODEL
/// ==========================================
///
/// This class represents a single update or "tweet" in the networking platform.
/// Location in Firestore: /posts/{postId}
///
/// DOCUMENT SCHEMA:
/// ------------------------------------------
/// uid: String             - Author's Firebase UID
/// name: String            - Author's display name (cached for performance)
/// username: String        - Author's @handle (cached for performance)
/// content: String         - The text body of the post
/// mediaUrls: List<String> - List of Cloudinary links for attachments
/// mediaType: String       - Type of attachment ('text', 'image', 'video')
/// likes: int              - Denormalized like counter
/// likedBy: List<String>   - UIDs of users who liked (to show active state)
/// reposts: List<String>   - UIDs of users who shared this post
/// commentCount: int       - Denormalized counter for comments
/// timestamp: Timestamp    - Server-side time of creation
/// tags: List<String>      - Hashtags extracted from content for search
///
/// PERFORMANCE DESIGN:
/// ------------------------------------------
/// 1. Denormalization: We store Author Name and Username directly in the post.
///    This allows the Home Feed to show thousands of posts without performing
///    thousands of additional "User Profile" lookups (The "N+1 query problem").
/// 2. Counters vs Size: Likes are stored as both an integer (for UI) and a
///    list of UIDs. This allows for both fast counting and checking if the
///    current user has already liked the post.
class PostModel {
  final String id;
  final String uid;
  final String name;
  final String username;
  final String content;
  final String time;
  final String profileInitial;
  final String? profileImageUrl;
  final int likes;
  final int commentCount;
  final List<String> likedBy;
  final List<String> reposts;
  final List<String> bookmarks;
  final List<String> mediaUrls;
  final String mediaType; // 'text', 'image', 'video'
  final DateTime? timestamp; // Add timestamp for relative time calculation
  final List<String> tags;
  final List<String> mentions;

  PostModel({
    required this.id,
    required this.uid,
    required this.name,
    required this.username,
    required this.content,
    required this.time,
    required this.profileInitial,
    this.profileImageUrl,
    required this.likes,
    required this.commentCount,
    required this.likedBy,
    required this.reposts,
    required this.bookmarks,
    required this.mediaUrls,
    required this.mediaType,
    this.timestamp,
    this.tags = const [],
    this.mentions = const [],
  });

  /// Get Twitter-style relative time (e.g., "2h ago", "3d ago")
  String getTimeAgo() {
    if (timestamp == null) return time;
    
    final now = DateTime.now();
    final difference = now.difference(timestamp!);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y';
    }
  }

  factory PostModel.fromMap(Map<String, dynamic> map, String documentId) {
    // Parse timestamp from Firestore
    DateTime? parsedTimestamp;
    if (map['timestamp'] != null) {
      try {
        parsedTimestamp = (map['timestamp'] as dynamic).toDate();
      } catch (e) {
        parsedTimestamp = null;
      }
    }

    return PostModel(
      id: documentId,
      uid: map['uid'] ?? '',
      name: map['name'] ?? 'User',
      username: map['username'] ?? 'anonymous',
      content: map['content'] ?? '',
      time: map['time'] ?? 'Just now',
      profileInitial: map['profileInitial'] ?? 'Q',
      profileImageUrl: map['profileImageUrl'],
      // Casting numeric values safely
      likes: (map['likes'] ?? 0).toInt(),
      commentCount: (map['commentCount'] ?? 0).toInt(),
      likedBy: List<String>.from(map['likedBy'] ?? []),
      // CRITICAL FIX: Explicitly cast dynamic lists from Firestore
      reposts: List<String>.from(map['reposts'] ?? []),
      bookmarks: List<String>.from(map['bookmarks'] ?? []),
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      mediaType: map['mediaType'] ?? 'text',
      timestamp: parsedTimestamp,
      tags: List<String>.from(map['tags'] ?? []),
      mentions: List<String>.from(map['mentions'] ?? []),
    );
  }
}
