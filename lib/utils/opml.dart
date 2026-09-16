/// OPML 订阅列表的解析与生成。
///
/// 单独成文件是为了可单测：原实现把正则内联在 `BackupService` 的两个方法里，
/// 且要求 `xmlUrl` 紧跟 `text` 出现，而导出（以及绝大多数阅读器）
/// 都把 `xmlUrl` 放在最后 —— 所以自己导出的 OPML 自己都导不回来。
library;

/// OPML 中的一个订阅源条目。
class OpmlSubscription {
  final String url;
  final String title;

  const OpmlSubscription({required this.url, required this.title});

  @override
  String toString() => 'OpmlSubscription($title, $url)';
}

/// 匹配 `<outline ...>` 开标签（自闭合或成对皆可），捕获属性区。
final RegExp _outlineTag = RegExp(r'<outline\b([^>]*)>', caseSensitive: false);

/// 匹配单个 `name="value"` 属性，属性名大小写不敏感（OPML 里 xmlUrl/xmlurl 都常见）。
final RegExp _attribute = RegExp(r'([A-Za-z_][\w.:\-]*)\s*=\s*"([^"]*)"');

/// 解析 OPML 文本中的订阅源。
///
/// 只依据 outline 标签是否带 `xmlUrl` 属性来判定，**不假设属性顺序**；
/// 重复 url 只保留首次出现的那条。
List<OpmlSubscription> parseOpmlSubscriptions(String content) {
  final result = <OpmlSubscription>[];
  final seenUrls = <String>{};

  for (final tag in _outlineTag.allMatches(content)) {
    final attributes = _parseAttributes(tag.group(1)!);
    final url = unescapeXml(attributes['xmlurl'] ?? '');
    if (url.isEmpty) continue;
    if (!seenUrls.add(url)) continue;

    final title = unescapeXml(attributes['title'] ?? attributes['text'] ?? '');
    result.add(OpmlSubscription(
      url: url,
      title: title.isEmpty ? url : title,
    ));
  }

  return result;
}

Map<String, String> _parseAttributes(String raw) {
  final attributes = <String, String>{};
  for (final match in _attribute.allMatches(raw)) {
    attributes[match.group(1)!.toLowerCase()] = match.group(2)!;
  }
  return attributes;
}

const Map<String, String> _xmlEntities = {
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&apos;': "'",
};

/// 还原 XML 属性值中的实体转义，是 [escapeXml] 的逆操作。
String unescapeXml(String value) {
  var result = value;
  _xmlEntities.forEach((entity, character) {
    result = result.replaceAll(entity, character);
  });
  // 数字实体（&#38; / &#x26;）也常出现在第三方导出的 OPML 里
  result = result.replaceAllMapped(
    RegExp(r'&#(x?)([0-9A-Fa-f]+);'),
    (match) {
      final radix = match.group(1)!.isEmpty ? 10 : 16;
      final codePoint = int.tryParse(match.group(2)!, radix: radix);
      if (codePoint == null || codePoint > 0x10FFFF) return match.group(0)!;
      return String.fromCharCode(codePoint);
    },
  );
  return result;
}

/// 转义 XML 属性值中的特殊字符。
String escapeXml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}