/// 日期时间的统一格式化。
///
/// 抽出来的原因：`article_list_screen` 和 `article_detail_screen` 原本各有一份
/// 逐字相同的 `_formatDateTime`，并且**都漏了 `toLocal()`** —— 于是带时区的
/// 源（例如 `+0800`）会把 UTC 时间直接当本地时间显示，整体偏移 8 小时。
library;

/// 只取年月日，例如 `2026-09-16`。
String formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

/// 年月日 + 时分，例如 `2026-09-16 08:30`。始终按本地时区显示。
String formatDateTime(DateTime date) {
  final local = date.toLocal();
  return '${formatDate(local)} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// 相对时间，例如 `3分钟前`、`2天前`；超过一周回退到 [formatDate]。
///
/// [DateTime.difference] 比较的是绝对时刻，不受 isUtc 影响，
/// 所以这里不需要额外转换。
String formatRelativeDate(DateTime date) {
  final diff = DateTime.now().difference(date);

  // 源的时间戳不准时可能是未来时间，差值会是负数
  if (diff.isNegative) return formatDateTime(date);
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (diff.inDays < 7) return '${diff.inDays}天前';
  return formatDate(date);
}