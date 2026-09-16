import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:html/dom.dart' as dom;

/// 文章正文的 HTML 渲染。
///
/// 单独成文件的原因：这段渲染逻辑原本内联在 `article_detail_screen.dart`
/// 的 `ErrorBoundary` 里，和页面的加载/收藏/分享逻辑混在一起，
/// 既没法单独测试也没法复用。
///
/// 渲染引擎从已停更的 `flutter_html` 换成了 `flutter_widget_from_html_core`：
/// 后者只需要 csslib / html / logging 三个依赖，且仍在活跃维护。
class HtmlContentView extends StatelessWidget {
  /// 已经过 `absolutizeImageUrls` 处理的正文 HTML
  final String html;

  /// 文章原文地址，用于解析 HTML 里残留的相对链接
  final String link;

  /// 点击链接
  final void Function(String url)? onTapLink;

  /// 点击图片（参数是图片地址）
  final void Function(String url)? onTapImage;

  const HtmlContentView({
    super.key,
    required this.html,
    required this.link,
    this.onTapLink,
    this.onTapImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return HtmlWidget(
      html,
      // baseUrl 让引擎自行解析相对链接；正文里的图片地址一般已被
      // absolutizeImageUrls 补全，这里是兜底。
      baseUrl: Uri.tryParse(link),
      // 使用引擎默认的 NetworkImage。曾经试过用 factoryBuilder 换成
      // cached_network_image 的 provider，但在 Web 上关闭图片画廊后
      // 正文里的同一张图会渲染成黑块，故放弃（见 TODO）。
      textStyle: theme.textTheme.bodyMedium?.copyWith(
        fontSize: 16,
        height: 1.6,
        color: theme.colorScheme.onSurface,
      ),
      customStylesBuilder: (element) => stylesForElement(element, theme),
      onTapUrl: (url) {
        onTapLink?.call(url);
        // 返回 true 表示已处理，引擎不再走自己的默认行为
        return true;
      },
      onTapImage: onTapImage == null
          ? null
          : (metadata) {
              final source =
                  metadata.sources.isNotEmpty ? metadata.sources.first : null;
              if (source != null) onTapImage!(source.url);
            },
    );
  }
}

/// 把原来 `flutter_html` 的 Style 映射成 CSS 声明。
///
/// 只覆盖需要跟随主题的部分，标题尺寸与列表缩进等交给引擎默认值。
Map<String, String>? stylesForElement(dom.Element element, ThemeData theme) {
  switch (element.localName) {
    case 'a':
      return {
        'color': cssColor(theme.colorScheme.primary),
        'text-decoration': 'underline',
      };
    case 'pre':
      return {
        'background-color':
            cssColor(theme.colorScheme.surfaceContainerHighest),
        'color': cssColor(theme.colorScheme.onSurfaceVariant),
        'padding': '12px',
        'margin': '8px 0',
        'font-family': 'monospace',
        'font-size': '13px',
        'white-space': 'pre',
      };
    case 'code':
      // <pre><code> 嵌套时不再叠一层底色
      if (element.parent?.localName == 'pre') return null;
      return {
        'background-color':
            cssColor(theme.colorScheme.surfaceContainerHighest),
        'font-family': 'monospace',
        'font-size': '13px',
        'padding': '2px 4px',
      };
    case 'blockquote':
      return {
        'color': cssColor(theme.colorScheme.onSurfaceVariant),
        'font-style': 'italic',
        'margin': '8px 16px',
      };
    case 'p':
      return {'margin': '0 0 8px 0'};
    case 'h1':
      return {'font-size': '24px', 'font-weight': 'bold', 'margin': '16px 0 8px'};
    case 'h2':
      return {'font-size': '20px', 'font-weight': 'bold', 'margin': '14px 0 6px'};
    case 'h3':
      return {'font-size': '18px', 'font-weight': 'bold', 'margin': '12px 0 6px'};
    default:
      return null;
  }
}

/// `Color` → CSS 颜色值。
///
/// 渲染引擎的样式表只接受 CSS 字符串，不接受 Flutter 的 `Color`。
String cssColor(Color color) {
  final argb = color.toARGB32();
  final alpha = (argb >> 24) & 0xff;
  final red = (argb >> 16) & 0xff;
  final green = (argb >> 8) & 0xff;
  final blue = argb & 0xff;

  if (alpha == 0xff) {
    return '#'
        '${red.toRadixString(16).padLeft(2, '0')}'
        '${green.toRadixString(16).padLeft(2, '0')}'
        '${blue.toRadixString(16).padLeft(2, '0')}';
  }
  return 'rgba($red,$green,$blue,${(alpha / 255).toStringAsFixed(3)})';
}