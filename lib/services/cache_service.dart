import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';

/// 缓存服务 - 存储文章内容和图片
/// 桌面端: 使用 SharedPreferences (简单实现，可扩展为 Hive)
/// Web端: 使用 SharedPreferences (基于浏览器 localStorage)
class CacheService {
  static const String _articleCacheKey = 'article_cache';
  static const String _imageCacheKey = 'image_cache';
  static const Duration _cacheExpiry = Duration(days: 7);

  SharedPreferences? _prefs;
  Map<String, dynamic> _articleCache = {};
  Map<String, dynamic> _imageCache = {};

  /// 初始化缓存服务
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadCache();
  }

  void _loadCache() {
    final articleJson = _prefs?.getString(_articleCacheKey);
    if (articleJson != null) {
      try {
        _articleCache = jsonDecode(articleJson);
      } catch (e) {
        debugPrint('Failed to load article cache: $e');
      }
    }

    final imageJson = _prefs?.getString(_imageCacheKey);
    if (imageJson != null) {
      try {
        _imageCache = jsonDecode(imageJson);
      } catch (e) {
        debugPrint('Failed to load image cache: $e');
      }
    }
  }

  Future<void> _saveCache() async {
    await _prefs?.setString(_articleCacheKey, jsonEncode(_articleCache));
    await _prefs?.setString(_imageCacheKey, jsonEncode(_imageCache));
  }

  /// 获取缓存的文章内容
  String? getArticleContent(String articleId) {
    final data = _articleCache[articleId];
    if (data == null) return null;

    // 检查是否过期
    final cachedAt = DateTime.tryParse(data['cachedAt'] ?? '');
    if (cachedAt != null && DateTime.now().isAfter(cachedAt.add(_cacheExpiry))) {
      _articleCache.remove(articleId);
      return null;
    }

    return data['content'];
  }

  /// 缓存文章内容
  Future<void> cacheArticleContent(String articleId, String content) async {
    _articleCache[articleId] = {
      'content': content,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await _saveCache();
  }

  /// 获取缓存的图片数据 (Base64)
  String? getCachedImage(String url) {
    final data = _imageCache[url];
    if (data == null) return null;

    // 检查是否过期
    final cachedAt = DateTime.tryParse(data['cachedAt'] ?? '');
    if (cachedAt != null && DateTime.now().isAfter(cachedAt.add(_cacheExpiry))) {
      _imageCache.remove(url);
      return null;
    }

    return data['data'];
  }

  /// 缓存图片数据 (Base64)
  Future<void> cacheImage(String url, String base64Data) async {
    _imageCache[url] = {
      'data': base64Data,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await _saveCache();
  }

  /// 获取缓存的完整文章
  Article? getCachedArticle(String articleId, String feedId) {
    final content = getArticleContent(articleId);
    if (content == null) return null;

    return Article(
      id: articleId,
      feedId: feedId,
      title: '',
      link: '',
      content: content,
      summary: null,
      author: null,
      pubDate: DateTime.now(),
      isRead: false,
      isFavorite: false,
      isCached: true,
      imageUrl: null,
      cachedAt: DateTime.now(),
    );
  }

  /// 清除特定文章缓存
  Future<void> clearArticleCache(String articleId) async {
    _articleCache.remove(articleId);
    await _saveCache();
  }

  /// 清除所有缓存
  Future<void> clearAllCache() async {
    _articleCache.clear();
    _imageCache.clear();
    await _prefs?.remove(_articleCacheKey);
    await _prefs?.remove(_imageCacheKey);
  }

  /// 获取缓存统计信息
  Map<String, int> getCacheStats() {
    final now = DateTime.now();
    int validArticles = 0;
    int validImages = 0;

    _articleCache.forEach((key, value) {
      final cachedAt = DateTime.tryParse(value['cachedAt'] ?? '');
      if (cachedAt != null && !now.isAfter(cachedAt.add(_cacheExpiry))) {
        validArticles++;
      }
    });

    _imageCache.forEach((key, value) {
      final cachedAt = DateTime.tryParse(value['cachedAt'] ?? '');
      if (cachedAt != null && !now.isAfter(cachedAt.add(_cacheExpiry))) {
        validImages++;
      }
    });

    return {
      'articles': validArticles,
      'images': validImages,
    };
  }
}
