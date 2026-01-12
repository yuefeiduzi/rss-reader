class Feed {
  final String id;
  final String title;
  final String url;
  final String? description;
  final String? imageUrl;
  final DateTime lastUpdated;
  final String? group;
  final DateTime addedAt;

  Feed({
    required this.id,
    required this.title,
    required this.url,
    this.description,
    this.imageUrl,
    required this.lastUpdated,
    this.group,
    required this.addedAt,
  });

  factory Feed.fromJson(Map<String, dynamic> json) {
    return Feed(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      description: json['description'],
      imageUrl: json['imageUrl'],
      lastUpdated: DateTime.tryParse(json['lastUpdated'] ?? '') ?? DateTime.now(),
      group: json['group'],
      addedAt: DateTime.tryParse(json['addedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'description': description,
      'imageUrl': imageUrl,
      'lastUpdated': lastUpdated.toIso8601String(),
      'group': group,
      'addedAt': addedAt.toIso8601String(),
    };
  }
}
