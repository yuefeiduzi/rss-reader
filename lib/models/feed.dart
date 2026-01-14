class Feed {
  final String id;
  final String title;
  final String url;
  final String? description;
  final String? imageUrl;
  final DateTime lastUpdated;
  final String? group;
  final DateTime addedAt;
  final bool isPinned;

  Feed({
    required this.id,
    required this.title,
    required this.url,
    this.description,
    this.imageUrl,
    required this.lastUpdated,
    this.group,
    required this.addedAt,
    this.isPinned = false,
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
      isPinned: json['isPinned'] ?? false,
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
      'isPinned': isPinned,
    };
  }

  Feed copyWith({
    String? id,
    String? title,
    String? url,
    String? description,
    String? imageUrl,
    DateTime? lastUpdated,
    String? group,
    DateTime? addedAt,
    bool? isPinned,
  }) {
    return Feed(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      group: group ?? this.group,
      addedAt: addedAt ?? this.addedAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}
