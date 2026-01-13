import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/article.dart';
import '../models/feed.dart';

class RssService {
  late final Dio _dio;

  RssService() {
    _dio = Dio(BaseOptions(
      responseType: ResponseType.bytes,
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) => status! < 500,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; RSS Reader/1.0)',
        'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
      },
    ));
  }

  /// 预处理 XML，移除 CDATA 区块
  String _preprocessXml(String xml) {
    // 移除 CDATA 区块
    return xml.replaceAllMapped(RegExp(r'<!\[CDATA\[([\s\S]*?)\]\]>'), (match) {
      return match.group(1) ?? '';
    });
  }

  /// 解析 RSS/Atom 订阅源
  Future<Feed> fetchFeed(String url) async {
    try {
      final response = await _dio.get(url);
      final decoder = utf8.decode(response.data);
      final processedXml = _preprocessXml(decoder);

      if (processedXml.contains('<feed')) {
        // Atom 解析
        return _parseAtomFeed(processedXml, url);
      } else {
        // RSS 解析
        return _parseRssFeed(processedXml, url);
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

    final descMatch =
        RegExp(r'<description[^>]*>([^<]+)</description>').firstMatch(xml);
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
  Future<List<Article>> fetchArticles(Feed feed,
      {bool forceFullContent = false}) async {
    try {
      final response = await _dio.get(feed.url,
          options: Options(responseType: ResponseType.bytes));
      final decoder = utf8.decode(response.data);
      final processedXml = _preprocessXml(decoder);

      List<Article> articles = [];

      // 判断格式：优先检查 <rss> 或 <item> 标签
      final isAtom =
          processedXml.contains('<feed') && processedXml.contains('<entry');
      if (isAtom) {
        articles = _parseAtomArticles(processedXml, feed);
      } else {
        articles = _parseRssArticles(processedXml, feed);
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

      final titleMatch = _extractTagContent(itemXml, 'title');
      final linkMatch = _extractTagContent(itemXml, 'link', attribute: 'href');
      final idMatch = _extractTagContent(itemXml, 'id');
      final summaryMatch =
          _extractTagContent(itemXml, 'summary', multiline: true);
      final contentMatch =
          _extractTagContent(itemXml, 'content', multiline: true);
      final publishedMatch = _extractTagContent(itemXml, 'published');
      final updatedMatch = _extractTagContent(itemXml, 'updated');
      final authorMatch = _extractTagContent(itemXml, 'author') ??
          _extractNestedTagContent(itemXml, 'author', 'name');

      final title = titleMatch ?? 'Untitled';
      final link = linkMatch ?? '';
      final id = idMatch ?? link;

      if (title.isEmpty || link.isEmpty) continue;

      final pubDateStr = publishedMatch ?? updatedMatch;
      final pubDate =
          pubDateStr != null ? DateTime.tryParse(pubDateStr) : DateTime.now();

      articles.add(Article(
        id: _generateArticleId(feed.id, id),
        feedId: feed.id,
        title: title.trim(),
        link: link,
        content: null,
        summary: summaryMatch ?? contentMatch,
        author: authorMatch,
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

  /// 从 XML 中提取带属性的标签内容
  String? _extractTagContent(String xml, String tagName,
      {bool multiline = false, String? attribute}) {
    if (attribute != null) {
      // 提取属性值
      final pattern =
          RegExp('<$tagName[^>]*$attribute="([^"]+)"', caseSensitive: false);
      final match = pattern.firstMatch(xml);
      return match?.group(1);
    }
    final pattern = multiline
        ? RegExp('<$tagName[^>]*>([\\s\\S]*?)</$tagName>', caseSensitive: false)
        : RegExp('<$tagName[^>]*>([^<]+)</$tagName>', caseSensitive: false);
    final match = pattern.firstMatch(xml);
    return match?.group(1)?.trim();
  }

  /// 从嵌套标签中提取内容
  String? _extractNestedTagContent(
      String xml, String parentTag, String childTag) {
    final pattern = RegExp('<$parentTag[^>]*>([\\s\\S]*?)</$parentTag>',
        caseSensitive: false);
    final match = pattern.firstMatch(xml);
    if (match == null) return null;
    final parentContent = match.group(1) ?? '';
    final childPattern =
        RegExp('<$childTag[^>]*>([^<]+)</$childTag>', caseSensitive: false);
    final childMatch = childPattern.firstMatch(parentContent);
    return childMatch?.group(1);
  }

  List<Article> _parseRssArticles(String xml, Feed feed) {
    final articles = <Article>[];
    final itemRegex = RegExp(r'<item[^>]*>([\s\S]*?)</item>');

    for (var match in itemRegex.allMatches(xml)) {
      final itemXml = match.group(1) ?? '';
      if (itemXml.isEmpty) continue;

      // 使用更健壮的正则来匹配标签内容
      final titleMatch = _extractTagContent(itemXml, 'title');
      final linkMatch = _extractTagContent(itemXml, 'link');
      final descMatch =
          _extractTagContent(itemXml, 'description', multiline: true);
      final guidMatch = _extractTagContent(itemXml, 'guid');
      final pubDateMatch = _extractTagContent(itemXml, 'pubDate');
      final authorMatch = _extractTagContent(itemXml, 'dc:creator') ??
          _extractTagContent(itemXml, 'author');

      final title = titleMatch ?? 'Untitled';
      final link = linkMatch ?? '';
      final guid = guidMatch ?? link;

      if (title.isEmpty || link.isEmpty) continue;

      // 解码 HTML 实体
      final decodedDescription = _decodeHtmlEntities(descMatch ?? '');

      final pubDate = pubDateMatch != null
          ? DateTime.tryParse(pubDateMatch)
          : DateTime.now();

      articles.add(Article(
        id: _generateArticleId(feed.id, guid),
        feedId: feed.id,
        title: title.trim(),
        link: link,
        content: decodedDescription,
        summary: decodedDescription,
        author: authorMatch,
        pubDate: pubDate ?? DateTime.now(),
        isRead: false,
        isFavorite: false,
        isCached: false,
        imageUrl: _extractImage(decodedDescription),
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
      document
          .querySelectorAll('script, style, nav, footer, header')
          .forEach((e) => e.remove());

      // 查找文章内容
      final article = document.querySelector(
          'article, .post-content, .article-content, .entry-content, .content, main');

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

  /// 解码 HTML 实体
  String _decodeHtmlEntities(String html) {
    if (html.isEmpty) return '';
    return html
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      return code != null ? String.fromCharCode(code) : m.group(0)!;
    });
  }

  /// 移除 HTML 标签并解码实体
  String _stripHtmlTags(String html) {
    // 先解码 HTML 实体
    var text = html
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&#\d+;'), '')
        .replaceAll(RegExp(r'&apos;'), "'");

    // 移除所有 HTML 标签（包括跨行标签）
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // 移除多余空白
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
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
