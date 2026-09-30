import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 文章全文内容缓存（7 天过期）。
///
/// 只缓存正文，不缓存图片：曾经有一套 Base64 图片缓存（`cacheImage` /
/// `getCachedImage`），但全项目没有任何地方调用，只会把空 map 反复写进
/// prefs。正文图片现在走 `NetworkImage`，要加缓存得另找方案，
/// 见 docs/known-issues.md 2.4.1。
class CacheService {
  static const String _articleCacheKey = 'article_cache';
  static const Duration _cacheExpiry = Duration(days: 7);

  SharedPreferences? _prefs;
  Map<String, dynamic> _articleCache = {};

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
  }

  Future<void> _saveCache() async {
    await _prefs?.setString(_articleCacheKey, jsonEncode(_articleCache));
  }

  /// 获取缓存的文章正文。不存在或已过期时返回 null。
  String? getArticleContent(String articleId) {
    final data = _articleCache[articleId];
    if (data == null) return null;

    // 检查是否过期
    final cachedAt = DateTime.tryParse(data['cachedAt'] ?? '');
    if (cachedAt != null &&
        DateTime.now().isAfter(cachedAt.add(_cacheExpiry))) {
      _articleCache.remove(articleId);
      return null;
    }

    return data['content'];
  }

  /// 缓存文章正文
  Future<void> cacheArticleContent(String articleId, String content) async {
    _articleCache[articleId] = {
      'content': content,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await _saveCache();
  }
}
