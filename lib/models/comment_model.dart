class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String username;
  final String name;
  final String content;
  final String time;
  final int likes;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    required this.name,
    required this.content,
    required this.time,
    this.likes = 0,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return CommentModel(
      id: documentId,
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? 'anonymous',
      name: map['name'] ?? 'User',
      content: map['content'] ?? '',
      time: map['time'] ?? 'Just now',
      likes: (map['likes'] ?? 0).toInt(),
    );
  }
}
