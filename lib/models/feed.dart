class Feed {
  final String id;
  final String title;
  final String? customName; // 用户自定义名称
  final String url;
  final String? description;
  final String? imageUrl;
  final DateTime lastUpdated;
  final String? group;
  final DateTime addedAt;
  final bool isPinned;

  // 显示名称：优先使用自定义名称
  String get displayTitle => customName?.isNotEmpty == true ? customName! : title;

  Feed({
    required this.id,
    required this.title,
    this.customName,
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
      customName: json['customName'],
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
      'customName': customName,
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
    String? customName,
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
      customName: customName ?? this.customName,
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
