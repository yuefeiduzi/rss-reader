import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/utils/opml.dart';

void main() {
  group('parseOpmlSubscriptions', () {
    test('解析 BackupService 自己导出的格式（xmlUrl 在最后）', () {
      // 与 BackupService.exportToOpml 的输出顺序一致：text/title 在前，xmlUrl 在后
      const opml = '''
<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
  <head>
    <title>RSS Reader Subscriptions</title>
  </head>
  <body>
      <outline type="rss" text="少数派" title="少数派" xmlUrl="https://sspai.com/feed" />
  </body>
</opml>''';

      final subscriptions = parseOpmlSubscriptions(opml);

      expect(subscriptions, hasLength(1));
      expect(subscriptions.single.url, 'https://sspai.com/feed');
      expect(subscriptions.single.title, '少数派');
    });

    test('不依赖属性顺序', () {
      const opml = '''
<body>
  <outline xmlUrl="https://a.example/feed" text="A" />
  <outline text="B" xmlUrl="https://b.example/feed" />
  <outline title="C" type="rss" xmlUrl="https://c.example/feed" text="C" />
</body>''';

      final urls = parseOpmlSubscriptions(opml).map((s) => s.url).toList();

      expect(urls, [
        'https://a.example/feed',
        'https://b.example/feed',
        'https://c.example/feed',
      ]);
    });

    test('属性名大小写不敏感（xmlUrl / xmlurl）', () {
      const opml = '<outline text="A" xmlurl="https://a.example/feed" />';

      expect(parseOpmlSubscriptions(opml).single.url, 'https://a.example/feed');
    });

    test('跳过分组 outline（没有 xmlUrl）', () {
      const opml = '''
<body>
  <outline text="技术" title="技术">
    <outline text="A" xmlUrl="https://a.example/feed" />
  </outline>
</body>''';

      final subscriptions = parseOpmlSubscriptions(opml);

      expect(subscriptions, hasLength(1));
      expect(subscriptions.single.url, 'https://a.example/feed');
    });

    test('还原 &amp; 等实体转义', () {
      const opml =
          '<outline text="A" xmlUrl="https://a.example/feed?a=1&amp;b=2" />';

      expect(parseOpmlSubscriptions(opml).single.url,
          'https://a.example/feed?a=1&b=2');
    });

    test('重复 url 只保留首次出现', () {
      const opml = '''
<body>
  <outline text="A" xmlUrl="https://a.example/feed" />
  <outline text="A 重复" xmlUrl="https://a.example/feed" />
</body>''';

      final subscriptions = parseOpmlSubscriptions(opml);

      expect(subscriptions, hasLength(1));
      expect(subscriptions.single.title, 'A');
    });

    test('缺少 text/title 时回退到 url 作为标题', () {
      const opml = '<outline xmlUrl="https://a.example/feed" />';

      expect(parseOpmlSubscriptions(opml).single.title,
          'https://a.example/feed');
    });

    test('空内容返回空列表', () {
      expect(parseOpmlSubscriptions(''), isEmpty);
      expect(parseOpmlSubscriptions('<opml><body></body></opml>'), isEmpty);
    });
  });

  group('escapeXml / unescapeXml', () {
    test('互为逆操作', () {
      const original = 'https://a.example/feed?a=1&b=<x>"y"\'z\'';
      expect(unescapeXml(escapeXml(original)), original);
    });

    test('还原数字实体', () {
      expect(unescapeXml('a&#38;b'), 'a&b');
      expect(unescapeXml('a&#x26;b'), 'a&b');
    });
  });
}