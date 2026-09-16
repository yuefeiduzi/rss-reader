import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:rss_reader/ui/components/html_content_view.dart';

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
      final code = html_parser
          .parse('<pre><code>x</code></pre>')
          .querySelector('code')!;

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
      expect(stylesForElement(elementOf('<table><tr><td>x</td></tr></table>'),
              theme),
          isNull);
    });

    test('标题有明确的字号与加粗', () {
      for (final (tag, size) in [('h1', '24px'), ('h2', '20px'), ('h3', '18px')]) {
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
}