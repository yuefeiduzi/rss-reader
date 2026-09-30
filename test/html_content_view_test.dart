import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:rss_reader/ui/components/html_content_view.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('cssColor', () {
    test('不透明颜色输出 #rrggbb', () {
      expect(cssColor(const Color(0xFF1A2B3C)), '#1a2b3c');
      expect(cssColor(const Color(0xFF000000)), '#000000');
      expect(cssColor(const Color(0xFFFFFFFF)), '#ffffff');
    });

    test('半透明颜色输出 rgba()', () {
      expect(cssColor(const Color(0x80FF0000)), 'rgba(255,0,0,0.502)');
    });

    test('个位数分量补零', () {
      expect(cssColor(const Color(0xFF010203)), '#010203');
    });
  });

  group('stylesForElement', () {
    final theme = ThemeData(useMaterial3: true);

    dom.Element elementOf(String html) =>
        html_parser.parse(html).body!.firstChild! as dom.Element;

    test('链接跟随主题色并保留下划线', () {
      final styles = stylesForElement(elementOf('<a href="x">链接</a>'), theme);

      expect(styles!['text-decoration'], 'underline');
      expect(styles['color'], cssColor(theme.colorScheme.primary));
    });

    test('代码块使用等宽字体与浅底色', () {
      final styles = stylesForElement(elementOf('<pre>code</pre>'), theme);

      expect(styles!['font-family'], 'monospace');
      expect(styles['background-color'],
          cssColor(theme.colorScheme.surfaceContainerHighest));
    });

    test('pre 内部的 code 不叠加第二层底色', () {
      // 叠底会渲染出双色块
      final code =
          html_parser.parse('<pre><code>x</code></pre>').querySelector('code')!;

      expect(stylesForElement(code, theme), isNull);
    });

    test('独立的 code 有自己的底色', () {
      final styles = stylesForElement(elementOf('<code>x</code>'), theme);

      expect(styles!['background-color'], isNotNull);
    });

    test('引文跟随次要文字色', () {
      final styles =
          stylesForElement(elementOf('<blockquote>引用</blockquote>'), theme);

      expect(styles!['font-style'], 'italic');
      expect(styles['color'], cssColor(theme.colorScheme.onSurfaceVariant));
    });

    test('未特殊处理的标签返回 null（交给引擎默认样式）', () {
      expect(stylesForElement(elementOf('<span>x</span>'), theme), isNull);
      expect(stylesForElement(elementOf('<ul><li>x</li></ul>'), theme), isNull);
      expect(
          stylesForElement(
              elementOf('<table><tr><td>x</td></tr></table>'), theme),
          isNull);
    });

    test('标题有明确的字号与加粗', () {
      for (final (tag, size) in [
        ('h1', '24px'),
        ('h2', '20px'),
        ('h3', '18px')
      ]) {
        final styles = stylesForElement(elementOf('<$tag>标题</$tag>'), theme);
        expect(styles!['font-size'], size, reason: tag);
        expect(styles['font-weight'], 'bold', reason: tag);
      }
    });

    test('暗色主题下取的是暗色配色', () {
      final dark = ThemeData(useMaterial3: true, brightness: Brightness.dark);

      final lightColor =
          stylesForElement(elementOf('<a>x</a>'), theme)!['color'];
      final darkColor = stylesForElement(elementOf('<a>x</a>'), dark)!['color'];

      expect(darkColor, isNot(lightColor));
    });
  });

  group('HtmlContentView.onRenderError', () {
    // 引擎对两种失败传的元素不同（见 core_build_tree.dart）：
    // 整篇构建失败 → 合成根元素 'root'；图片加载失败 → 'img'。
    // 降级只应对前者生效，否则一张图 404 就会把整篇文章换成纯文本。
    Future<void> triggerError(
      WidgetTester tester,
      dom.Element element,
      void Function() onError,
    ) async {
      await tester.pumpWidget(_wrap(HtmlContentView(
        html: '<p>hi</p>',
        link: 'https://example.com/a',
        onRenderError: onError,
      )));

      final htmlWidget = tester.widget<HtmlWidget>(find.byType(HtmlWidget));
      final context = tester.element(find.byType(HtmlWidget));
      htmlWidget.onErrorBuilder!(context, element, Exception('boom'));
    }

    testWidgets('整篇构建失败（root）时回调', (tester) async {
      var failed = 0;

      await triggerError(tester, dom.Element.tag('root'), () => failed++);

      expect(failed, 1);
    });

    testWidgets('图片加载失败（img）不回调', (tester) async {
      var failed = 0;

      await triggerError(tester, dom.Element.tag('img'), () => failed++);

      expect(failed, 0);
    });

    testWidgets('没传 onRenderError 时不崩', (tester) async {
      await tester.pumpWidget(_wrap(const HtmlContentView(
        html: '<p>hi</p>',
        link: 'https://example.com/a',
      )));

      final htmlWidget = tester.widget<HtmlWidget>(find.byType(HtmlWidget));

      expect(htmlWidget.onErrorBuilder, isNull);
    });
  });

  group('图片居中', () {
    // 1×1 的透明 PNG：用 data URI 就不经过网络，测试里能真正解码出 Image
    const tinyPng = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAA'
        'AABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

    Future<void> pumpHtml(WidgetTester tester, String html) async {
      await tester.pumpWidget(_wrap(HtmlContentView(
        html: html,
        link: 'https://example.com/post',
      )));
      for (var i = 0; i < 10 && find.byType(Image).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('只有图片的容器：图片水平居中', (tester) async {
      await pumpHtml(tester, '<p><img src="$tinyPng"></p>');

      expect(find.byType(Image), findsOneWidget, reason: '图片应真的渲染出来');
      final image = tester.getRect(find.byType(Image));
      final content = tester.getRect(find.byType(HtmlContentView));

      expect((image.center.dx - content.center.dx).abs(), lessThan(1.5));
    });

    testWidgets('夹在文字里的图片：保持行内，不被居中', (tester) async {
      await pumpHtml(tester, '<p>看图：<img src="$tinyPng"> 就是这样</p>');

      expect(find.byType(Image), findsOneWidget);
      final image = tester.getRect(find.byType(Image));
      final content = tester.getRect(find.byType(HtmlContentView));

      expect((image.center.dx - content.center.dx).abs(), greaterThan(10),
          reason: '有正文的段落不该被居中');
    });
  });

  group('HtmlRenderFallback', () {
    testWidgets('剥掉标签显示纯文本，还原实体，按钮可点', (tester) async {
      var opened = 0;

      await tester.pumpWidget(_wrap(HtmlRenderFallback(
        content: '<h1>标题</h1><p>正文 &amp; 更多</p>',
        onOpenInBrowser: () => opened++,
      )));

      expect(find.text('内容渲染异常，已显示纯文本版本'), findsOneWidget);
      expect(find.textContaining('标题 正文 & 更多'), findsOneWidget);
      expect(find.textContaining('<h1>'), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, '在浏览器中打开原文'));
      expect(opened, 1);
    });
  });
}
