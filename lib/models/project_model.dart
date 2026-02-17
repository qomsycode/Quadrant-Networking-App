class Project {
  final String id;
  final String title;
  final String description;
  final String? link;
  final List<String> imageUrls;

  Project({
    required this.id,
    required this.title,
    required this.description,
    this.link,
    this.imageUrls = const [],
  });

  /// Convert Project to Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'link': link,
      'imageUrls': imageUrls,
    };
  }

  /// Create Project from Firestore document
  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      link: map['link'],
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
    );
  }
}
