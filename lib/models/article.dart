class Article {
  final String id;
  final String feedId;
  final String title;
  final String link;
  final String? content;
  final String? summary;
  final String? author;
  final DateTime pubDate;
  final bool isRead;
  final bool isFavorite;
  final bool isCached;
  final String? imageUrl;
  final DateTime? readAt;
  final DateTime cachedAt;

  Article({
    required this.id,
    required this.feedId,
    required this.title,
    required this.link,
    this.content,
    this.summary,
    this.author,
    required this.pubDate,
    this.isRead = false,
    this.isFavorite = false,
    this.isCached = false,
    this.imageUrl,
    this.readAt,
    required this.cachedAt,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] ?? '',
      feedId: json['feedId'] ?? '',
      title: json['title'] ?? '',
      link: json['link'] ?? '',
      content: json['content'],
      summary: json['summary'],
      author: json['author'],
      pubDate: DateTime.tryParse(json['pubDate'] ?? '') ?? DateTime.now(),
      isRead: json['isRead'] ?? false,
      isFavorite: json['isFavorite'] ?? false,
      isCached: json['isCached'] ?? false,
      imageUrl: json['imageUrl'],
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt']) : null,
      cachedAt: DateTime.tryParse(json['cachedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'feedId': feedId,
      'title': title,
      'link': link,
      'content': content,
      'summary': summary,
      'author': author,
      'pubDate': pubDate.toIso8601String(),
      'isRead': isRead,
      'isFavorite': isFavorite,
      'isCached': isCached,
      'imageUrl': imageUrl,
      'readAt': readAt?.toIso8601String(),
      'cachedAt': cachedAt.toIso8601String(),
    };
  }

  Article copyWith({
    String? id,
    String? feedId,
    String? title,
    String? link,
    String? content,
    String? summary,
    String? author,
    DateTime? pubDate,
    bool? isRead,
    bool? isFavorite,
    bool? isCached,
    String? imageUrl,
    DateTime? readAt,
    DateTime? cachedAt,
  }) {
    return Article(
      id: id ?? this.id,
      feedId: feedId ?? this.feedId,
      title: title ?? this.title,
      link: link ?? this.link,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      author: author ?? this.author,
      pubDate: pubDate ?? this.pubDate,
      isRead: isRead ?? this.isRead,
      isFavorite: isFavorite ?? this.isFavorite,
      isCached: isCached ?? this.isCached,
      imageUrl: imageUrl ?? this.imageUrl,
      readAt: readAt ?? this.readAt,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}
