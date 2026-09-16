import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../models/feed.dart';
import '../models/config.dart';

/// 应用数据的唯一真相来源，同时是驱动 UI 重建的 [ChangeNotifier]。
///
/// 接口约定（调用方需要知道的事）：
/// - **读是同步的**：直接从内存取，不需要 `await`，也不会失败。
/// - **写会立即返回**：状态先在内存里生效并触发 [notifyListeners]，
///   落盘在后台按提交顺序排队进行。因此调用方**不需要**在写完之后
///   手工刷新界面，也不应该依赖「返回时已落盘」。
/// - 需要确保落盘完成时（测试、退出前）调 [flush]。
/// - 对外暴露的列表都是副本，改它们不影响内部状态。
///
/// 未读数在内部增量维护，调用方用 [unreadCountOf] 取，不要自己遍历文章
/// 去数 —— 那样是 O(订阅源数 × 文章数)。
class StorageService extends ChangeNotifier {
  static const String _feedsKey = 'feeds';
  static const String _articlesKey = 'articles';
  static const String _configKey = 'config';

  SharedPreferences? _prefs;
  List<Feed> _feeds = [];
  List<Article> _articles = [];
  AppConfig _config = AppConfig();

  /// feedId → 未读数。随写入增量更新，避免每次查询都全量遍历。
  final Map<String, int> _unreadCounts = {};

  bool _loaded = false;

  /// 串行化落盘的队列。并发写会让旧快照后落盘从而覆盖新数据，
  /// 所以每次写都接到上一次之后。
  Future<void> _pendingWrite = Future<void>.value();

  /// 等待所有已提交的写入落盘。
  Future<void> flush() => _pendingWrite;

  /// 数据是否已从本地读出。false 时 [feeds] 等返回空集合。
  bool get isLoaded => _loaded;

  /// 初始化存储。必须在读取任何数据前调用一次。
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadFromPrefs();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _loadFromPrefs() async {
    final feedsJson = _prefs?.getStringList(_feedsKey) ?? [];
    _feeds = feedsJson.map((f) => Feed.fromJson(jsonDecode(f))).toList();

    final articlesJson = _prefs?.getStringList(_articlesKey) ?? [];
    _articles = articlesJson.map((a) => Article.fromJson(jsonDecode(a))).toList();

    final configJson = _prefs?.getString(_configKey);
    if (configJson != null) {
      _config = AppConfig.fromJson(jsonDecode(configJson));
    }

    _rebuildUnreadCounts();
    debugPrint('[加载] feeds: ${_feeds.length}, articles: ${_articles.length}');
  }

  void _rebuildUnreadCounts() {
    _unreadCounts.clear();
    for (final article in _articles) {
      if (!article.isRead) {
        _unreadCounts.update(article.feedId, (n) => n + 1, ifAbsent: () => 1);
      }
    }
  }

  void _saveAndNotify() {
    // 落盘排队不等：状态已在内存里，UI 可以立即重建；
    // 写失败也不该阻塞交互。
    _pendingWrite = _pendingWrite
        .then((_) => _saveToPrefs())
        .catchError((Object e) => debugPrint('[保存] 失败: $e'));
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    await _prefs?.setStringList(
      _feedsKey,
      _feeds.map((f) => jsonEncode(f.toJson())).toList(),
    );
    await _prefs?.setStringList(
      _articlesKey,
      _articles.map((a) => jsonEncode(a.toJson())).toList(),
    );
    await _prefs?.setString(_configKey, jsonEncode(_config.toJson()));
  }

  // ============ 读 ============

  /// 全部订阅源，已排序：置顶优先，其次按添加时间倒序。
  ///
  /// 排序在这里做，调用方不必（也不应）再排一次。
  List<Feed> get feeds {
    final sorted = List<Feed>.of(_feeds)
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.addedAt.compareTo(a.addedAt);
      });
    return sorted;
  }

  Feed? feedById(String id) {
    for (final feed in _feeds) {
      if (feed.id == id) return feed;
    }
    return null;
  }

  /// 某个订阅源的未读文章数。
  int unreadCountOf(String feedId) => _unreadCounts[feedId] ?? 0;

  /// 某个订阅源的文章，按发布时间倒序。
  List<Article> articlesOf(String feedId) {
    final result = _articles.where((a) => a.feedId == feedId).toList()
      ..sort((a, b) => b.pubDate.compareTo(a.pubDate));
    return result;
  }

  /// 全部文章，按发布时间倒序。
  List<Article> get allArticles =>
      List<Article>.of(_articles)
        ..sort((a, b) => b.pubDate.compareTo(a.pubDate));

  Article? articleById(String id) {
    for (final article in _articles) {
      if (article.id == id) return article;
    }
    return null;
  }

  AppConfig get config => _config;

  // ============ 写 ============

  Future<void> addFeed(Feed feed) async {
    _feeds.add(feed);
    _saveAndNotify();
  }

  /// 添加订阅源，按 url 去重。返回是否真的新增了。
  Future<bool> addFeedWithDuplicateCheck(Feed feed) async {
    if (_feeds.any((f) => f.url == feed.url)) {
      debugPrint('[导入] 订阅源已存在，跳过: ${feed.url}');
      return false;
    }
    _feeds.add(feed);
    _saveAndNotify();
    return true;
  }

  Future<void> updateFeed(Feed feed) async {
    final index = _feeds.indexWhere((f) => f.id == feed.id);
    if (index < 0) return;
    _feeds[index] = feed;
    _saveAndNotify();
  }

  /// 删除订阅源及其全部文章。
  Future<void> deleteFeed(String id) async {
    _feeds.removeWhere((f) => f.id == id);
    _articles.removeWhere((a) => a.feedId == id);
    _unreadCounts.remove(id);
    _saveAndNotify();
  }

  /// 批量追加文章，按 id 去重。
  Future<void> addArticles(List<Article> articles) async {
    for (final article in articles) {
      if (_articles.any((a) => a.id == article.id)) continue;
      _articles.add(article);
      if (!article.isRead) {
        _unreadCounts.update(article.feedId, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    _saveAndNotify();
  }

  Future<void> markAsRead(String id) async {
    final index = _articles.indexWhere((a) => a.id == id);
    if (index < 0) return;
    final article = _articles[index];
    if (article.isRead) return;

    _articles[index] = article.copyWith(isRead: true, readAt: DateTime.now());
    _unreadCounts.update(article.feedId, (n) => n > 0 ? n - 1 : 0);
    _saveAndNotify();
  }

  Future<void> toggleFavorite(String id) async {
    final index = _articles.indexWhere((a) => a.id == id);
    if (index < 0) return;
    _articles[index] =
        _articles[index].copyWith(isFavorite: !_articles[index].isFavorite);
    _saveAndNotify();
  }

  Future<void> clearArticlesByFeed(String feedId) async {
    _articles.removeWhere((a) => a.feedId == feedId);
    _unreadCounts.remove(feedId);
    _saveAndNotify();
  }

  Future<void> updateConfig(AppConfig config) async {
    _config = config;
    _saveAndNotify();
  }
}