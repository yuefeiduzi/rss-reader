import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/utils/html_content.dart';

void main() {
  const base = 'https://blog.example.com/posts/hello';

  group('extractImageUrls', () {
    test('提取普通 src', () {
      expect(
        extractImageUrls('<p><img src="https://cdn.example.com/a.jpg"></p>'),
        ['https://cdn.example.com/a.jpg'],
      );
    });

    test('优先取懒加载的 data-src 而不是占位图', () {
      expect(
        extractImageUrls(
            '<img src="/placeholder.gif" data-src="/real.jpg">'),
        ['/real.jpg'],
      );
    });

    test('data-original 同样识别', () {
      expect(
        extractImageUrls('<img src="/p.gif" data-original="/o.jpg">'),
        ['/o.jpg'],
      );
    });

    test('不把 data-src 误当成 src', () {
      // 只有 data-src、没有 src 时，应取 data-src 而不是匹配到 "-src" 里的东西
      expect(extractImageUrls('<img data-src="/only.jpg">'), ['/only.jpg']);
    });

    test('去重且保持顺序', () {
      expect(
        extractImageUrls('<img src="a.jpg"><img src="b.jpg"><img src="a.jpg">'),
        ['a.jpg', 'b.jpg'],
      );
    });

    test('没有图片返回空', () {
      expect(extractImageUrls('<p>没有图</p>'), isEmpty);
      expect(extractImageUrls(''), isEmpty);
    });
  });

  group('absolutizeImageUrls', () {
    test('相对路径按文章链接补全（修掉 404 的根因）', () {
      expect(
        absolutizeImageUrls('<img src="/images/a.jpg">', base),
        '<img src="https://blog.example.com/images/a.jpg">',
      );
    });

    test('相对路径相对于文章目录解析', () {
      expect(
        absolutizeImageUrls('<img src="a.jpg">', base),
        '<img src="https://blog.example.com/posts/a.jpg">',
      );
    });

    test('协议相对地址继承 base 的 scheme', () {
      expect(
        absolutizeImageUrls('<img src="//cdn.example.com/a.jpg">', base),
        '<img src="https://cdn.example.com/a.jpg">',
      );
    });

    test('绝对地址保持原样', () {
      const html = '<img src="https://cdn.example.com/a.jpg">';
      expect(absolutizeImageUrls(html, base), html);
    });

    test('懒加载的真实地址被写回 src', () {
      expect(
        absolutizeImageUrls(
            '<img src="/placeholder.gif" data-src="/real.jpg">', base),
        '<img src="https://blog.example.com/real.jpg" data-src="/real.jpg">',
      );
    });

    test('没有 src 时补一个，否则 flutter_html 不渲染', () {
      expect(
        absolutizeImageUrls('<img class="x" data-src="/a.jpg">', base),
        '<img src="https://blog.example.com/a.jpg" class="x" data-src="/a.jpg">',
      );
    });

    test('保留其他属性', () {
      expect(
        absolutizeImageUrls('<img alt="图" src="/a.jpg" width="10">', base),
        '<img alt="图" src="https://blog.example.com/a.jpg" width="10">',
      );
    });

    test('data: URI 不被破坏', () {
      const html = '<img src="data:image/png;base64,AAAA">';
      expect(absolutizeImageUrls(html, base), html);
    });

    test('baseUrl 为空时原样返回', () {
      const html = '<img src="/a.jpg">';
      expect(absolutizeImageUrls(html, null), html);
    });

    test('无 img 的 HTML 原样返回', () {
      const html = '<p>纯文字</p>';
      expect(absolutizeImageUrls(html, base), html);
    });
  });
}