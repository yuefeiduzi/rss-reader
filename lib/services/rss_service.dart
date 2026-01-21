import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:webfeed_plus/webfeed_plus.dart';
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

  /// 解析 RSS/Atom 订阅源
  Future<Feed> fetchFeed(String url) async {
    final response = await _dio.get(url);
    final decoder = utf8.decode(response.data);

    if (decoder.contains('<feed') && decoder.contains('<entry')) {
      return _parseAtomFeed(decoder, url);
    } else {
      return _parseRssFeed(decoder, url);
    }
  }

  Feed _parseAtomFeed(String xml, String url) {
    final atomFeed = AtomFeed.parse(xml);
    return Feed(
      id: _generateId(url),
      title: atomFeed.title ?? 'Unknown Feed',
      url: url,
      description: atomFeed.subtitle,
      imageUrl: atomFeed.logo,
      lastUpdated: DateTime.now(),
      group: null,
      addedAt: DateTime.now(),
    );
  }

  Feed _parseRssFeed(String xml, String url) {
    final rssFeed = RssFeed.parse(xml);
    return Feed(
      id: _generateId(url),
      title: rssFeed.title ?? 'Unknown Feed',
      url: url,
      description: rssFeed.description,
      imageUrl: rssFeed.image?.url,
      lastUpdated: DateTime.now(),
      group: null,
      addedAt: DateTime.now(),
    );
  }

  /// 获取订阅源文章列表
  Future<List<Article>> fetchArticles(Feed feed,
      {bool forceFullContent = false}) async {
    final response = await _dio.get(feed.url,
        options: Options(responseType: ResponseType.bytes));
    final decoder = utf8.decode(response.data);

    if (decoder.contains('<feed') && decoder.contains('<entry')) {
      return _parseAtomArticles(decoder, feed);
    } else {
      return _parseRssArticles(decoder, feed);
    }
  }

  List<Article> _parseAtomArticles(String xml, Feed feed) {
    final atomFeed = AtomFeed.parse(xml);
    final articles = <Article>[];

    for (final entry in atomFeed.items ?? []) {
      // 获取链接
      String? link;
      if (entry.links != null) {
        for (final linkObj in entry.links!) {
          if (linkObj.href != null) {
            link = linkObj.href;
            break;
          }
        }
      }

      if (entry.title == null || link == null) continue;

      // 获取作者
      String? author;
      if (entry.authors != null && entry.authors!.isNotEmpty) {
        author = entry.authors!.first.name;
      }

      // 解析日期
      final pubDate = _parseDate(entry.published ?? entry.updated);

      articles.add(Article(
        id: _generateArticleId(feed.id, entry.id ?? link),
        feedId: feed.id,
        title: entry.title!.trim(),
        link: link,
        content: entry.content,
        summary: entry.summary ?? entry.content,
        author: author,
        pubDate: pubDate,
        isRead: false,
        isFavorite: false,
        isCached: false,
        imageUrl: _extractImage(entry.content ?? entry.summary ?? ''),
        cachedAt: DateTime.now(),
      ));
    }

    return articles;
  }

  List<Article> _parseRssArticles(String xml, Feed feed) {
    final rssFeed = RssFeed.parse(xml);
    final articles = <Article>[];

    for (final item in rssFeed.items ?? []) {
      if (item.title == null || item.link == null) continue;

      articles.add(Article(
        id: _generateArticleId(feed.id, item.guid ?? item.link!),
        feedId: feed.id,
        title: item.title!.trim(),
        link: item.link!,
        content: item.content?.value ?? item.description,
        summary: item.description ?? item.content?.value,
        author: item.author ?? item.dc?.creator,
        pubDate: item.pubDate ?? DateTime.now(),
        isRead: false,
        isFavorite: false,
        isCached: false,
        imageUrl: _extractImage(item.content?.value ?? item.description ?? ''),
        cachedAt: DateTime.now(),
      ));
    }

    return articles;
  }

  /// 解析日期字符串
  DateTime _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }

    // 尝试标准解析
    final parsed = DateTime.tryParse(dateStr);
    if (parsed != null) return parsed;

    // RFC 2822 格式
    final rfc2822Pattern = RegExp(
        r'^([A-Za-z]{3}),\s+(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s*(.*)$');
    final match = rfc2822Pattern.firstMatch(dateStr);
    if (match != null) {
      final months = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
        'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
      };
      final day = int.parse(match.group(2)!);
      final month = months[match.group(3)] ?? 1;
      final year = int.parse(match.group(4)!);
      final hour = int.parse(match.group(5)!);
      final minute = int.parse(match.group(6)!);
      final second = int.parse(match.group(7)!);
      final tz = match.group(8) ?? '';

      var offset = 0;
      if (tz.startsWith('+')) {
        final parts = tz.substring(1).split(':');
        offset = int.parse(parts[0]) * 60 + (parts.length > 1 ? int.parse(parts[1]) : 0);
      } else if (tz.startsWith('-')) {
        final parts = tz.substring(1).split(':');
        offset = -(int.parse(parts[0]) * 60 + (parts.length > 1 ? int.parse(parts[1]) : 0));
      } else if (tz != 'GMT' && tz != 'UTC' && tz.isNotEmpty) {
        final tzOffsets = {'EST': -300, 'EDT': -240, 'CST': -360, 'CDT': -300,
                          'MST': -420, 'MDT': -360, 'PST': -480, 'PDT': -420};
        offset = tzOffsets[tz] ?? 0;
      }

      final utc = DateTime.utc(year, month, day, hour, minute, second);
      return utc.subtract(Duration(minutes: offset));
    }

    return DateTime.now();
  }

  /// 抓取全文内容
  Future<String> fetchFullContent(String url) async {
    try {
      final response = await _dio.get(url);
      final document = html_parser.parse(response.data);

      document
          .querySelectorAll('script, style, nav, footer, header')
          .forEach((e) => e.remove());

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
