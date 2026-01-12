import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../models/feed.dart';
import '../models/config.dart';

class StorageService {
  static const String _feedsKey = 'feeds';
  static const String _articlesKey = 'articles';
  static const String _configKey = 'config';

  SharedPreferences? _prefs;
  List<Feed> _feeds = [];
  List<Article> _articles = [];
  AppConfig _config = AppConfig();

  /// 初始化存储
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    // 加载 feeds
    final feedsJson = _prefs?.getStringList(_feedsKey) ?? [];
    _feeds = feedsJson.map((f) => Feed.fromJson(jsonDecode(f))).toList();

    // 加载 articles
    final articlesJson = _prefs?.getStringList(_articlesKey) ?? [];
    _articles = articlesJson.map((a) => Article.fromJson(jsonDecode(a))).toList();

    // 加载 config
    final configJson = _prefs?.getString(_configKey);
    if (configJson != null) {
      _config = AppConfig.fromJson(jsonDecode(configJson));
    }
  }

  Future<void> _saveToPrefs() async {
    // 保存 feeds
    await _prefs?.setStringList(
      _feedsKey,
      _feeds.map((f) => jsonEncode(f.toJson())).toList(),
    );

    // 保存 articles
    await _prefs?.setStringList(
      _articlesKey,
      _articles.map((a) => jsonEncode(a.toJson())).toList(),
    );

    // 保存 config
    await _prefs?.setString(_configKey, jsonEncode(_config.toJson()));
  }

  // ============ Feed 操作 ============

  Future<List<Feed>> getAllFeeds() async {
    return _feeds;
  }

  Future<Feed?> getFeed(String id) async {
    try {
      return _feeds.firstWhere((f) => f.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> addFeed(Feed feed) async {
    _feeds.add(feed);
    await _saveToPrefs();
  }

  Future<void> updateFeed(Feed feed) async {
    final index = _feeds.indexWhere((f) => f.id == feed.id);
    if (index >= 0) {
      _feeds[index] = feed;
      await _saveToPrefs();
    }
  }

  Future<void> deleteFeed(String id) async {
    _feeds.removeWhere((f) => f.id == id);
    _articles.removeWhere((a) => a.feedId == id);
    await _saveToPrefs();
  }

  // ============ Article 操作 ============

  Future<List<Article>> getArticlesByFeed(String feedId) async {
    return _articles
        .where((a) => a.feedId == feedId)
        .toList()
      ..sort((a, b) => b.pubDate.compareTo(a.pubDate));
  }

  Future<List<Article>> getAllArticles({int limit = 100}) async {
    return _articles
        .toList()
      ..sort((a, b) => b.pubDate.compareTo(a.pubDate))
      ..take(limit);
  }

  Future<List<Article>> getUnreadArticles() async {
    return _articles
        .where((a) => !a.isRead)
        .toList()
      ..sort((a, b) => b.pubDate.compareTo(a.pubDate));
  }

  Future<List<Article>> getFavoriteArticles() async {
    return _articles
        .where((a) => a.isFavorite)
        .toList()
      ..sort((a, b) => b.pubDate.compareTo(a.pubDate));
  }

  Future<Article?> getArticle(String id) async {
    try {
      return _articles.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> addArticle(Article article) async {
    if (!_articles.any((a) => a.id == article.id)) {
      _articles.add(article);
      await _saveToPrefs();
    }
  }

  Future<void> addArticles(List<Article> articles) async {
    for (var article in articles) {
      if (!_articles.any((a) => a.id == article.id)) {
        _articles.add(article);
      }
    }
    await _saveToPrefs();
  }

  Future<void> updateArticle(Article article) async {
    final index = _articles.indexWhere((a) => a.id == article.id);
    if (index >= 0) {
      _articles[index] = article;
      await _saveToPrefs();
    }
  }

  Future<void> markAsRead(String id) async {
    final index = _articles.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _articles[index] = _articles[index].copyWith(
        isRead: true,
        readAt: DateTime.now(),
      );
      await _saveToPrefs();
    }
  }

  Future<void> toggleFavorite(String id) async {
    final index = _articles.indexWhere((a) => a.id == id);
    if (index >= 0) {
      _articles[index] = _articles[index].copyWith(
        isFavorite: !_articles[index].isFavorite,
      );
      await _saveToPrefs();
    }
  }

  Future<void> deleteArticle(String id) async {
    _articles.removeWhere((a) => a.id == id);
    await _saveToPrefs();
  }

  // ============ Config 操作 ============

  Future<AppConfig> getConfig() async {
    return _config;
  }

  Future<void> updateConfig(AppConfig config) async {
    _config = config;
    await _saveToPrefs();
  }

  // ============ 清理操作 ============

  Future<void> clearOldArticles({int keepDays = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: keepDays));
    _articles.removeWhere((a) => a.pubDate.isBefore(cutoff) && !a.isFavorite);
    await _saveToPrefs();
  }
}
