import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
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

    test('没有 src 时补一个，否则渲染引擎会忽略这张图', () {
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

  group('isImageOnlyContainer', () {
    dom.Element containerOf(String html) =>
        html_parser.parse(html).body!.children.first;

    test('只有一张图的块级容器为 true', () {
      expect(isImageOnlyContainer(containerOf('<p><img src="a.png"></p>')),
          isTrue);
      expect(
        isImageOnlyContainer(containerOf('<figure><img src="a.png"></figure>')),
        isTrue,
      );
      // 常见于真实源的两种包装
      expect(
        isImageOnlyContainer(
            containerOf('<p><a href="#"><img src="a.png"></a></p>')),
        isTrue,
      );
      expect(
        isImageOnlyContainer(containerOf(
            '<figure><picture><source srcset="a.webp"><img src="a.png"></picture></figure>')),
        isTrue,
      );
    });

    test('容器里有正文时为 false（否则正文也会被居中）', () {
      expect(
        isImageOnlyContainer(containerOf('<p>看图：<img src="a.png"></p>')),
        isFalse,
      );
      expect(
        isImageOnlyContainer(
            containerOf('<div><p>正文</p><img src="a.png"></div>')),
        isFalse,
      );
      expect(
        isImageOnlyContainer(containerOf(
            '<figure><img src="a.png"><figcaption>图注</figcaption></figure>')),
        isFalse,
      );
    });

    test('行内元素不算容器', () {
      expect(
        isImageOnlyContainer(containerOf('<span><img src="a.png"></span>')),
        isFalse,
      );
    });

    test('空白文本（含 &nbsp;）不影响判断', () {
      expect(
        isImageOnlyContainer(containerOf('<p> <img src="a.png"> </p>')),
        isTrue,
      );
      expect(
        isImageOnlyContainer(
            containerOf('<p>&nbsp;<img src="a.png">&nbsp;</p>')),
        isTrue,
      );
    });

    test('多张图也算「只有图片」', () {
      expect(
        isImageOnlyContainer(
            containerOf('<p><img src="a.png"><img src="b.png"></p>')),
        isTrue,
      );
    });

    test('包装里除了图还有文字时为 false', () {
      expect(
        isImageOnlyContainer(
            containerOf('<p><a href="#">看图<img src="a.png"></a></p>')),
        isFalse,
      );
    });
  });
}