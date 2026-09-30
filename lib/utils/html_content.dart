/// HTML 正文里的图片地址处理。
///
/// 两个问题会一起出现，所以放在一起解决：
/// 1. 博客站的正文常写 `<img src="/images/a.jpg">`。相对地址如果不补全，
///    渲染引擎会相对**应用自身**的域名去取图，必然 404。
/// 2. 懒加载站点把真实地址放在 `data-src`/`data-original`，`src` 只是占位图；
///    而渲染引擎只认 `src`，于是永远只显示占位图。
///
/// 图片排版（居中）的容器判断也放在这里，见 [isImageOnlyContainer]。
library;

import 'package:html/dom.dart' as dom;

final RegExp _imgTag = RegExp(r'<img\b[^>]*>', caseSensitive: false);

/// 前面不能是 `-` 或字母数字，否则会匹配到 `data-src` 里的 `src`。
final RegExp _srcAttr =
    RegExp(r'''(?<![\w-])src\s*=\s*["']([^"']*)["']''', caseSensitive: false);

final RegExp _lazySrcAttr = RegExp(
  r'''[\w-]*data-(?:src|original)\s*=\s*["']([^"']*)["']''',
  caseSensitive: false,
);

/// 提取 HTML 中的所有图片地址（优先懒加载的真实地址），保持出现顺序并去重。
List<String> extractImageUrls(String html) {
  if (html.isEmpty) return const [];

  final urls = <String>[];
  for (final tag in _imgTag.allMatches(html)) {
    final raw = tag.group(0)!;
    final lazy = _lazySrcAttr.firstMatch(raw)?.group(1);
    final src = _srcAttr.firstMatch(raw)?.group(1);
    final chosen = (lazy != null && lazy.isNotEmpty) ? lazy : src;
    if (chosen == null || chosen.isEmpty) continue;
    if (urls.contains(chosen)) continue;
    urls.add(chosen);
  }
  return urls;
}

/// 把 `<img>` 的地址补全为绝对地址，并把懒加载的真实地址写回 `src`。
///
/// [baseUrl] 传文章自身的链接；无法解析时原样返回。
String absolutizeImageUrls(String html, String? baseUrl) {
  if (html.isEmpty || baseUrl == null) return html;

  final base = Uri.tryParse(baseUrl);
  if (base == null) return html;

  return html.replaceAllMapped(_imgTag, (tag) {
    final raw = tag.group(0)!;

    final lazy = _lazySrcAttr.firstMatch(raw)?.group(1);
    final src = _srcAttr.firstMatch(raw)?.group(1);
    final chosen = (lazy != null && lazy.isNotEmpty) ? lazy : src;
    if (chosen == null || chosen.isEmpty) return raw;

    final absolute = base.resolve(chosen).toString();

    if (_srcAttr.hasMatch(raw)) {
      return raw.replaceFirst(_srcAttr, 'src="$absolute"');
    }
    // 完全没有 src 时补一个，否则渲染引擎会忽略这张图
    return '<img src="$absolute"${raw.substring('<img'.length)}';
  });
}
/// 块级容器标签（HTML 默认 `display: block` 的那一批）。
///
/// 只有这些标签里的图片才会按「独占一行」处理。
const Set<String> _blockContainerTags = {
  'article',
  'aside',
  'blockquote',
  'body',
  'dd',
  'details',
  'div',
  'dl',
  'dt',
  'figcaption',
  'figure',
  'footer',
  'header',
  'li',
  'main',
  'nav',
  'p',
  'section',
  'td',
  'th',
};

/// 只用来挂链接/样式的行内包装，判断图片所在行时可以跳过它。
const Set<String> _imageWrapperTags = {'a', 'picture', 'span'};

/// 容器里是不是「只有图片」—— 决定要不要给整个容器加 `text-align: center`。
///
/// 图片在渲染引擎里是**行内**元素，`text-align` 只有落在容器上才生效；
/// 反过来说，容器里只要还有正文，居中就会把正文一起带上，所以这里严格要求
/// 容器里除图片外没有别的内容：
///
/// - `<p><img></p>`、`<figure><img></figure>`、`<p><a><img></a></p>` → true
/// - `<p>说明文字 <img></p>`、`<div><p>正文</p><img></div>` → false
/// - `<figure><img><figcaption>图注</figcaption></figure>` → false（图注会跟着居中，暂不接管）
///
/// 依据是实测：少数派 21 个 `figure` 里 20 个是纯图，coolshell 用的是
/// `<p><img></p>`，真实源基本都是这个形状。
bool isImageOnlyContainer(dom.Element element) {
  if (!_blockContainerTags.contains(element.localName)) return false;
  if (_hasDirectText(element)) return false;

  final children = element.children;
  if (children.isEmpty) return false;
  return children.every(_isImageOrWrapper);
}

bool _isImageOrWrapper(dom.Element element) {
  if (element.localName == 'img') return true;
  if (!_imageWrapperTags.contains(element.localName)) return false;
  if (_hasDirectText(element)) return false;

  // <picture> 里的 <source> 不算内容
  final children =
      element.children.where((child) => child.localName != 'source');
  return children.length == 1 && children.first.localName == 'img';
}

/// 自己这一层有没有「看得见的文字」。空白与 `&nbsp;` 不算。
bool _hasDirectText(dom.Element element) => element.nodes.any(
    (node) => node is dom.Text && node.data.trim().isNotEmpty);
