/// HTML 正文里的图片地址处理。
///
/// 两个问题会一起出现，所以放在一起解决：
/// 1. 博客站的正文常写 `<img src="/images/a.jpg">`。相对地址如果不补全，
///    `flutter_html` 会相对**应用自身**的域名去取图，必然 404。
/// 2. 懒加载站点把真实地址放在 `data-src`/`data-original`，`src` 只是占位图；
///    而 `flutter_html` 只认 `src`，于是永远只显示占位图。
library;

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
    // 完全没有 src 时补一个，否则 flutter_html 不会渲染这张图
    return '<img src="$absolute"${raw.substring('<img'.length)}';
  });
}