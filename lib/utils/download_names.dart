/// 批量下载图片时的文件名推导。
///
/// 抽成纯函数的原因：要处理 URL 的 query、空 basename、百分号编码、跨平台
/// 非法字符，以及「不同地址同名」的去重 —— 埋在 widget 里没法测，
/// 而这几件事每一件都能让「下载全部」出错（覆盖、失败、找不到文件）。
library;

final RegExp _illegalChars = RegExp(r'[\\/:*?"<>|\x00-\x1f]');

/// 从图片地址推导出安全的文件名。取不到就用 `image`。
String fileNameFromUrl(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  final segments = path.split('/').where((s) => s.isNotEmpty);
  var name = segments.isEmpty ? '' : segments.last;

  // %20 之类要还原，否则存下来的是乱码文件名
  try {
    name = Uri.decodeComponent(name);
  } on FormatException {
    // 编码非法时保留原样，别为了文件名把下载整件事搞挂
  }

  name = name.replaceAll(_illegalChars, '_').trim();
  return name.isEmpty ? 'image' : name;
}

/// 给一组图片地址生成互不冲突的文件名（顺序与入参一致）。
///
/// 同名时在扩展名前加序号：`img.png`、`img-2.png`、`img-3.png`。
List<String> uniqueFileNamesFor(List<String> urls) {
  final used = <String>{};
  final names = <String>[];

  for (final url in urls) {
    final base = fileNameFromUrl(url);
    var candidate = base;
    var index = 2;
    while (used.contains(candidate)) {
      final dot = base.lastIndexOf('.');
      candidate = dot > 0
          ? '${base.substring(0, dot)}-$index${base.substring(dot)}'
          : '$base-$index';
      index++;
    }
    used.add(candidate);
    names.add(candidate);
  }

  return names;
}
