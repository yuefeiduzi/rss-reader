import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/models/feed.dart';
import 'package:rss_reader/services/rss_service.dart';

/// 这些测试直接调用 RssService 的纯解析函数，不触网。
void main() {
  final service = RssService();
  final feed = Feed(
    id: 'test-feed',
    title: '测试源',
    url: 'https://blog.example.com/feed.xml',
    lastUpdated: DateTime(2026),
    addedAt: DateTime(2026),
  );

  group('RSS 解析', () {
    const rss = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/"
     xmlns:content="http://purl.org/rss/1.0/modules/content/">
  <channel>
    <title>示例博客</title>
    <link>https://blog.example.com/</link>
    <description>描述</description>
    <item>
      <title>文章 A</title>
      <link>https://blog.example.com/posts/a</link>
      <guid>https://blog.example.com/posts/a</guid>
      <pubDate>Wed, 16 Sep 2026 08:00:00 +0800</pubDate>
      <dc:creator>作者甲</dc:creator>
      <description><![CDATA[<p>摘要</p>]]></description>
      <content:encoded><![CDATA[<p>正文</p><img src="/images/a.jpg">]]></content:encoded>
    </item>
  </channel>
</rss>''';

    test('解析订阅源元信息', () {
      final parsed = service.parseFeed(rss, feed.url);

      expect(parsed.title, '示例博客');
      expect(parsed.description, '描述');
    });

    test('解析文章基本字段', () {
      final articles = service.parseArticles(rss, feed);

      expect(articles, hasLength(1));
      expect(articles.single.title, '文章 A');
      expect(articles.single.link, 'https://blog.example.com/posts/a');
      expect(articles.single.feedId, feed.id);
      expect(articles.single.author, '作者甲');
    });

    test('pubDate 能被解析', () {
      final article = service.parseArticles(rss, feed).single;

      // 08:00 +0800 == 00:00 UTC
      expect(article.pubDate.toUtc(), DateTime.utc(2026, 9, 16, 0, 0));
    });

    test('头图相对路径按文章链接补全', () {
      final article = service.parseArticles(rss, feed).single;

      expect(article.imageUrl, 'https://blog.example.com/images/a.jpg');
    });

    test('标题/链接缺失的条目被跳过', () {
      const xml = '''
<rss version="2.0"><channel><title>t</title>
  <item><title>没有链接</title></item>
  <item><link>https://example.com/x</link></item>
</channel></rss>''';

      expect(service.parseArticles(xml, feed), isEmpty);
    });
  });

  group('dc:date 回退（曾经是文档声称但未实现的功能）', () {
    const dcDateOnly = '''
<?xml version="1.0"?>
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>只用 dc:date 的源</title>
    <item>
      <title>文章</title>
      <link>https://example.com/a</link>
      <dc:date>2020-01-02T03:04:05+08:00</dc:date>
    </item>
  </channel>
</rss>''';

    test('没有 pubDate 时用 dc:date，而不是 DateTime.now()', () {
      final article = service.parseArticles(dcDateOnly, feed).single;

      // 旧实现回退成 DateTime.now()，这里会得到「当前时间」而非 2020 年
      expect(article.pubDate.toUtc(), DateTime.utc(2020, 1, 1, 19, 4, 5));
    });

    test('pubDate 优先于 dc:date', () {
      const both = '''
<rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel><title>t</title>
    <item>
      <title>文章</title>
      <link>https://example.com/a</link>
      <pubDate>Mon, 01 Jan 2024 00:00:00 +0000</pubDate>
      <dc:date>2026-09-16T08:00:00+08:00</dc:date>
    </item>
  </channel>
</rss>''';

      expect(
        service.parseArticles(both, feed).single.pubDate.toUtc(),
        DateTime.utc(2024, 1, 1),
      );
    });
  });

  group('Atom 解析', () {
    const atom = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Atom 示例</title>
  <subtitle>副标题</subtitle>
  <entry>
    <title>条目一</title>
    <id>tag:example.com,2026:1</id>
    <link href="https://example.com/atom/1"/>
    <updated>2026-09-16T08:00:00Z</updated>
    <author><name>作者乙</name></author>
    <summary>摘要</summary>
    <content type="html">&lt;p&gt;正文&lt;/p&gt;</content>
  </entry>
</feed>''';

    test('解析订阅源元信息', () {
      final parsed = service.parseFeed(atom, feed.url);

      expect(parsed.title, 'Atom 示例');
      expect(parsed.description, '副标题');
    });

    test('解析条目', () {
      final articles = service.parseArticles(atom, feed);

      expect(articles, hasLength(1));
      expect(articles.single.title, '条目一');
      expect(articles.single.link, 'https://example.com/atom/1');
      expect(articles.single.author, '作者乙');
      expect(articles.single.pubDate.toUtc(), DateTime.utc(2026, 9, 16, 8, 0));
    });

    test('只有 updated、没有 published 时不炸（曾经会抛类型错误）', () {
      const onlyUpdated = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>只有 updated</title>
  <entry>
    <title>条目</title>
    <link href="https://example.com/1"/>
    <updated>2026-09-16T08:00:00Z</updated>
  </entry>
</feed>''';

      final articles = service.parseArticles(onlyUpdated, feed);

      expect(articles, hasLength(1));
      expect(articles.single.pubDate.toUtc(), DateTime.utc(2026, 9, 16, 8, 0));
    });

    test('published 优先于 updated', () {
      const both = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>t</title>
  <entry>
    <title>条目</title>
    <link href="https://example.com/1"/>
    <published>2024-01-01T00:00:00Z</published>
    <updated>2026-09-16T08:00:00Z</updated>
  </entry>
</feed>''';

      expect(service.parseArticles(both, feed).single.pubDate.toUtc(),
          DateTime.utc(2024, 1, 1));
    });

    test('两个日期都缺失时回退到最后更新时间，而不是抛异常', () {
      const noDate = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>t</title>
  <entry>
    <title>条目</title>
    <link href="https://example.com/1"/>
  </entry>
</feed>''';

      expect(service.parseArticles(noDate, feed).single.pubDate,
          isA<DateTime>());
    });
  });

  group('ID 生成', () {
    test('同一个源链接产生稳定的 feed id', () {
      expect(service.parseFeed('<rss version="2.0"><channel><title>a</title></channel></rss>',
              'https://x.example/feed').id,
          service.parseFeed('<rss version="2.0"><channel><title>b</title></channel></rss>',
              'https://x.example/feed').id);
    });

    test('不同源的 feed id 不同', () {
      const xml = '<rss version="2.0"><channel><title>a</title></channel></rss>';
      expect(service.parseFeed(xml, 'https://x.example/feed').id,
          isNot(service.parseFeed(xml, 'https://y.example/feed').id));
    });
  });
}