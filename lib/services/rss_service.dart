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
      // 只放行 2xx。旧实现写的是 `status < 500`，于是 404 也被当成成功：
      // 抓全文时会拿“404 Not Found”的错误页当正文渲染并写进缓存，
      // 抓订阅源时会把错误页当成空源解析。
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; RSS Reader/1.0)',
        'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
      },
    ));
  }

  /// 抓取并解析 RSS/Atom 订阅源信息
  Future<Feed> fetchFeed(String url) async {
    final response = await _dio.get(url);
    return parseFeed(_decodeBody(response.data), url);
  }

  /// 从 XML 文本解析订阅源信息（纯函数，不触网，可单测）
  Feed parseFeed(String xml, String url) {
    return _isAtom(xml) ? _parseAtomFeed(xml, url) : _parseRssFeed(xml, url);
  }

  /// 把响应体解码成字符串。
  ///
  /// [_dio] 的 BaseOptions 设的是 [ResponseType.bytes]，所以 `response.data`
  /// 是 `Uint8List` 而非 `String`，必须先解码。
  String _decodeBody(dynamic data) {
    if (data is String) return data;
    if (data is List<int>) return utf8.decode(data, allowMalformed: true);
    return data.toString();
  }

  bool _isAtom(String xml) =>
      xml.contains('<feed') && xml.contains('<entry');

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
  Future<List<Article>> fetchArticles(Feed feed) async {
    final response = await _dio.get(feed.url,
        options: Options(responseType: ResponseType.bytes));
    return parseArticles(_decodeBody(response.data), feed);
  }

  /// 从 XML 文本解析文章列表（纯函数，不触网，可单测）
  List<Article> parseArticles(String xml, Feed feed) {
    return _isAtom(xml)
        ? _parseAtomArticles(xml, feed)
        : _parseRssArticles(xml, feed);
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

      // AtomItem.updated 是 DateTime?，published 是 String?，两者类型不同。
      // 旧实现写的是 `_parseDate(entry.published ?? entry.updated)`，
      // 只带 <updated> 的源（很常见）会把 DateTime 传进期望 String 的形参，
      // 直接抛 TypeError，整个 Atom 源的解析就挂了。
      final pubDate =
          _parseDate(entry.published) ?? entry.updated ?? DateTime.now();

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
        imageUrl: _extractImage(entry.content ?? entry.summary ?? '',
            baseUrl: link),
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
        // 有些源只用 dc:date，webfeed 不会把它填进 pubDate，
        // 旧实现直接回退成 DateTime.now()，导致这类源的文章全部显示「刚刚」且排序错乱
        pubDate: item.pubDate ?? item.dc?.date ?? DateTime.now(),
        isRead: false,
        isFavorite: false,
        isCached: false,
        imageUrl: _extractImage(item.content?.value ?? item.description ?? '',
            baseUrl: item.link),
        cachedAt: DateTime.now(),
      ));
    }

    return articles;
  }

  /// 解析日期字符串。解析不了返回 null，由调用方决定回退策略。
  ///
  /// 只用于 Atom 的 `published`（webfeed 把它留作 String?）。
  /// RSS 路径两个日期源（`pubDate` / `dc:date`）都已经是 DateTime。
  DateTime? _parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return null;
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

    return null;
  }

  /// 抓取全文内容
  ///
  /// 失败时向上抛出而不是返回空串 —— 返回空串会让调用方把「没有内容」
  /// 当成「抓取成功」写进缓存，从而永久毁掉这篇文章的正文。
  Future<String> fetchFullContent(String url) async {
    final response = await _dio.get(url);
    final document = html_parser.parse(_decodeBody(response.data));

    document
        .querySelectorAll('script, style, nav, footer, header')
        .forEach((e) => e.remove());

    final article = document.querySelector(
        'article, .post-content, .article-content, .entry-content, .content, main');

    if (article != null) {
      return article.innerHtml;
    }

    return document.body?.innerHtml ?? '';
  }

  /// 从 HTML 内容中提取图片 URL
  String? _extractImage(String html, {String? baseUrl}) {
    if (html.isEmpty) return null;
    try {
      final document = html_parser.parse(html);
      final img = document.querySelector('img');
      if (img == null) return null;

      // 懒加载站点把真实地址放在 data-src/data-original，src 只是占位图
      final src = img.attributes['data-src'] ??
          img.attributes['data-original'] ??
          img.attributes['src'];
      if (src == null || src.isEmpty) return null;

      return _resolveUrl(src, baseUrl);
    } catch (e) {
      return null;
    }
  }

  /// 把可能是相对路径的地址补全为绝对地址
  String _resolveUrl(String url, String? baseUrl) {
    if (baseUrl == null) return url;
    final base = Uri.tryParse(baseUrl);
    if (base == null) return url;
    return base.resolve(url).toString();
  }

  /// 生成 Feed ID。
  ///
  /// 直接用规范化后的完整地址。两个原因：
  /// 1. 唯一性 —— 早期实现只取 `host + path`，于是
  ///    `example.com/feed` 与 `example.com/feed?cat=x`（以及
  ///    端口不同的两个源）会算出同一个 id，导致按 id 取源、取文章、
  ///    删除、置顶全部作用到错误的源上。
  /// 2. 稳定性 —— id 会被持久化，用 `hashCode` 的话哈希实现一变，
  ///    历史数据就对不上了。
  String _generateId(String url) => url;

  /// 生成文章 ID
  String _generateArticleId(String feedId, String identifier) {
    return '${feedId}_${identifier.hashCode}';
  }
}
