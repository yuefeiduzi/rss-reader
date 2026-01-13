import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/article.dart';
import '../models/feed.dart';

class RssService {
  final Dio _dio = Dio();

  /// 解析 RSS/Atom 订阅源
  Future<Feed> fetchFeed(String url) async {
    try {
      final response = await _dio.get(url, options: Options(responseType: ResponseType.bytes));
      final decoder = utf8.decode(response.data);

      if (decoder.contains('<feed')) {
        // Atom 解析
        return _parseAtomFeed(decoder, url);
      } else {
        // RSS 解析
        return _parseRssFeed(decoder, url);
      }
    } catch (e) {
      throw Exception('Failed to parse feed: $e');
    }
  }

  Feed _parseAtomFeed(String xml, String url) {
    // 简单 Atom 解析
    final titleMatch = RegExp(r'<title[^>]*>([^<]+)</title>').firstMatch(xml);
    final title = titleMatch?.group(1) ?? 'Unknown Feed';

    return Feed(
      id: _generateId(url),
      title: title.trim(),
      url: url,
      description: null,
      imageUrl: null,
      lastUpdated: DateTime.now(),
      group: null,
      addedAt: DateTime.now(),
    );
  }

  Feed _parseRssFeed(String xml, String url) {
    // 简单 RSS 解析
    final titleMatch = RegExp(r'<title[^>]*>([^<]+)</title>').firstMatch(xml);
    final title = titleMatch?.group(1) ?? 'Unknown Feed';

    final descMatch = RegExp(r'<description[^>]*>([^<]+)</description>').firstMatch(xml);
    final description = descMatch?.group(1);

    return Feed(
      id: _generateId(url),
      title: title.trim(),
      url: url,
      description: description?.trim(),
      imageUrl: null,
      lastUpdated: DateTime.now(),
      group: null,
      addedAt: DateTime.now(),
    );
  }

  /// 获取订阅源文章列表
  Future<List<Article>> fetchArticles(Feed feed, {bool forceFullContent = false}) async {
    try {
      final response = await _dio.get(feed.url, options: Options(responseType: ResponseType.bytes));
      final decoder = utf8.decode(response.data);

      List<Article> articles = [];

      if (decoder.contains('<feed')) {
        articles = _parseAtomArticles(decoder, feed);
      } else {
        articles = _parseRssArticles(decoder, feed);
      }

      return articles;
    } catch (e) {
      throw Exception('Failed to fetch articles: $e');
    }
  }

  List<Article> _parseAtomArticles(String xml, Feed feed) {
    final articles = <Article>[];
    final itemRegex = RegExp(r'<entry[^>]*>([\s\S]*?)</entry>');

    for (var match in itemRegex.allMatches(xml)) {
      final itemXml = match.group(1) ?? '';
      if (itemXml.isEmpty) continue;

      final titleMatch = RegExp(r'<title[^>]*>([^<]+)</title>').firstMatch(itemXml);
      final linkMatch = RegExp(r'<link[^>]*href="([^"]+)"').firstMatch(itemXml);
      final idMatch = RegExp(r'<id[^>]*>([^<]+)</id>').firstMatch(itemXml);
      final summaryMatch = RegExp(r'<summary[^>]*>([^<]+)</summary>').firstMatch(itemXml);
      final publishedMatch = RegExp(r'<published[^>]*>([^<]+)</published>').firstMatch(itemXml);
      final updatedMatch = RegExp(r'<updated[^>]*>([^<]+)</updated>').firstMatch(itemXml);
      final authorMatch = RegExp(r'<author[^>]*><name[^>]*>([^<]+)</name>').firstMatch(itemXml);

      final title = titleMatch?.group(1) ?? 'Untitled';
      final link = linkMatch?.group(1) ?? '';
      final id = idMatch?.group(1) ?? link;

      if (title.isEmpty || link.isEmpty) continue;

      final pubDateStr = publishedMatch?.group(1) ?? updatedMatch?.group(1);
      final pubDate = pubDateStr != null ? DateTime.tryParse(pubDateStr) : DateTime.now();

      articles.add(Article(
        id: _generateArticleId(feed.id, id),
        feedId: feed.id,
        title: title.trim(),
        link: link,
        content: null,
        summary: summaryMatch?.group(1)?.trim(),
        author: authorMatch?.group(1),
        pubDate: pubDate ?? DateTime.now(),
        isRead: false,
        isFavorite: false,
        isCached: false,
        imageUrl: null,
        cachedAt: DateTime.now(),
      ));
    }

    return articles;
  }

  List<Article> _parseRssArticles(String xml, Feed feed) {
    final articles = <Article>[];
    final itemRegex = RegExp(r'<item[^>]*>([\s\S]*?)</item>');

    for (var match in itemRegex.allMatches(xml)) {
      final itemXml = match.group(1) ?? '';
      if (itemXml.isEmpty) continue;

      final titleMatch = RegExp(r'<title[^>]*>([^<]+)</title>').firstMatch(itemXml);
      final linkMatch = RegExp(r'<link[^>]*>([^<]+)</link>').firstMatch(itemXml);
      final descMatch = RegExp(r'<description[^>]*>([\s\S]*?)</description>').firstMatch(itemXml);
      final guidMatch = RegExp(r'<guid[^>]*>([^<]+)</guid>').firstMatch(itemXml);
      final pubDateMatch = RegExp(r'<pubDate[^>]*>([^<]+)</pubDate>').firstMatch(itemXml);
      final authorMatch = RegExp(r'<author[^>]*>([^<]+)</author>').firstMatch(itemXml);

      final title = titleMatch?.group(1) ?? 'Untitled';
      final link = linkMatch?.group(1) ?? '';
      final guid = guidMatch?.group(1) ?? link;
      final description = descMatch?.group(1);

      if (title.isEmpty || link.isEmpty) continue;

      // 移除 HTML 标签获取纯文本摘要
      final summary = description != null
          ? description.replaceAll(RegExp(r'<[^>]+>'), '').trim()
          : null;

      final pubDate = pubDateMatch?.group(1) != null
          ? DateTime.tryParse(pubDateMatch!.group(1)!)
          : DateTime.now();

      articles.add(Article(
        id: _generateArticleId(feed.id, guid),
        feedId: feed.id,
        title: title.trim(),
        link: link,
        content: description,
        summary: summary,
        author: authorMatch?.group(1),
        pubDate: pubDate ?? DateTime.now(),
        isRead: false,
        isFavorite: false,
        isCached: false,
        imageUrl: _extractImage(description ?? ''),
        cachedAt: DateTime.now(),
      ));
    }

    return articles;
  }

  /// 抓取全文内容
  Future<String> fetchFullContent(String url) async {
    try {
      final response = await _dio.get(url);
      final document = html_parser.parse(response.data);

      // 移除脚本和样式
      document.querySelectorAll('script, style, nav, footer, header').forEach((e) => e.remove());

      // 查找文章内容
      final article = document.querySelector('article, .post-content, .article-content, .entry-content, .content, main');

      if (article != null) {
        return article.innerHtml;
      }

      return document.body?.innerHtml ?? '';
    } catch (e) {
      return '';
    }
  }

  /// 从 HTML 内容中提取图片 URL
  String? _extractImage(String html) {
    if (html.isEmpty) return null;
    try {
      final document = html_parser.parse(html);
      final img = document.querySelector('img');
      return img?.attributes['src'];
    } catch (e) {
      return null;
    }
  }

  /// 生成 Feed ID
  String _generateId(String url) {
    final uri = Uri.parse(url);
    return '${uri.host}${uri.path}'.hashCode.toString();
  }

  /// 生成文章 ID
  String _generateArticleId(String feedId, String identifier) {
    return '${feedId}_${identifier.hashCode}';
  }
}
