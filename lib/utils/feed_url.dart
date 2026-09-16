/// 订阅源地址的规范化与校验。
///
/// 单独成文件是为了让这段逻辑可以脱离 widget 直接单测 —— 它原本埋在
/// `AddFeedDialog._validateAndAdd` 里，且顺序有误（先判 `isAbsolute`，
/// 导致 "example.com/feed" 这类最常见的手输形式被直接拒绝）。
library;

/// 匹配带 scheme 的绝对地址前缀，例如 `https://`、`feed://`。
final RegExp _schemePrefix = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://');

/// 把用户输入整理成可用的订阅源地址。
///
/// 接受 `example.com/feed.xml`、`https://example.com/feed.xml` 等形式，
/// 缺省补 `https://`。返回 `null` 表示无法整理成 http/https 地址。
///
/// 注意：不能用 `Uri.parse(...).isAbsolute` 来判断，因为 `localhost:8080/feed`
/// 会被 Dart 解析成 scheme 为 `localhost` 的绝对 URI。
String? normalizeFeedUrl(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  final candidate =
      _schemePrefix.hasMatch(trimmed) ? trimmed : 'https://$trimmed';

  final uri = Uri.tryParse(candidate);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;

  return uri.toString();
}