import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/utils/feed_url.dart';

void main() {
  group('normalizeFeedUrl', () {
    test('补全缺少 scheme 的裸域名（旧实现直接拒绝这种输入）', () {
      expect(normalizeFeedUrl('example.com/feed.xml'),
          'https://example.com/feed.xml');
      expect(normalizeFeedUrl('example.com'), 'https://example.com');
    });

    test('保留已有的 http/https scheme', () {
      expect(normalizeFeedUrl('http://example.com/rss'), 'http://example.com/rss');
      expect(normalizeFeedUrl('https://example.com/rss'), 'https://example.com/rss');
    });

    test('localhost:端口 不被误判为 scheme', () {
      expect(normalizeFeedUrl('localhost:8080/feed'),
          'https://localhost:8080/feed');
    });

    test('非 http/https 的 scheme 被拒绝，而不是拼成 https://ftp://...', () {
      expect(normalizeFeedUrl('ftp://example.com/feed'), isNull);
      expect(normalizeFeedUrl('file:///tmp/feed.xml'), isNull);
    });

    test('无效输入返回 null', () {
      expect(normalizeFeedUrl(''), isNull);
      expect(normalizeFeedUrl('   '), isNull);
      expect(normalizeFeedUrl('https://'), isNull);
    });

    test('去掉首尾空白', () {
      expect(normalizeFeedUrl('  https://example.com/rss  '),
          'https://example.com/rss');
    });
  });
}