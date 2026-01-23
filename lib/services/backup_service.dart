import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/article.dart';
import '../models/feed.dart';
import '../models/config.dart';
import 'storage_service.dart';

class BackupService {
  final StorageService _storage;

  BackupService(this._storage);

  /// 导出所有数据为 JSON
  Future<Map<String, dynamic>> exportToJson() async {
    final feeds = await _storage.getAllFeeds();
    final articles = await _storage.getAllArticles(limit: 10000);
    final config = await _storage.getConfig();

    debugPrint('[导出] 订阅源数量: ${feeds.length}');
    debugPrint('[导出] 文章数量: ${articles.length}');

    return {
      'version': '1.0',
      'exportTime': DateTime.now().toIso8601String(),
      'feeds': feeds.map((f) => f.toJson()).toList(),
      'articles': articles.map((a) => a.toJson()).toList(),
      'config': config.toJson(),
    };
  }

  /// 导出订阅源为 OPML（用于其他阅读器兼容）
  Future<String> exportToOpml({String title = 'RSS Reader Subscriptions'}) async {
    final feeds = await _storage.getAllFeeds();
    final buffer = StringBuffer();

    buffer.write('<?xml version="1.0" encoding="UTF-8"?>\n');
    buffer.write('<opml version="2.0">\n');
    buffer.write('  <head>\n');
    buffer.write('    <title>$title</title>\n');
    buffer.write('  </head>\n');
    buffer.write('  <body>\n');

    // 按分组组织
    final groups = <String, List<Feed>>{};
    for (var feed in feeds) {
      final group = feed.group ?? 'Ungrouped';
      groups.putIfAbsent(group, () => []).add(feed);
    }

    for (var entry in groups.entries) {
      if (entry.key != 'Ungrouped') {
        buffer.write('    <outline text="${_escapeXml(entry.key)}" title="${_escapeXml(entry.key)}">\n');
      }

      for (var feed in entry.value) {
        buffer.write('      <outline ');
        buffer.write('type="rss" ');
        buffer.write('text="${_escapeXml(feed.title)}" ');
        buffer.write('title="${_escapeXml(feed.title)}" ');
        buffer.write('xmlUrl="${_escapeXml(feed.url)}" ');
        if (feed.description != null) {
          buffer.write('description="${_escapeXml(feed.description!)}" ');
        }
        buffer.write('/>\n');
      }

      if (entry.key != 'Ungrouped') {
        buffer.write('    </outline>\n');
      }
    }

    buffer.write('  </body>\n');
    buffer.write('</opml>');

    return buffer.toString();
  }

  /// 备份到 zip 文件，可选指定目录
  Future<String> backupToFile({String? outputDirectory}) async {
    final dir = outputDirectory != null
        ? Directory(outputDirectory)
        : await getApplicationDocumentsDirectory();

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final zipPath = '${dir.path}/backup_$timestamp.zip';

    // 生成 JSON 和 OPML 数据
    final jsonData = await exportToJson();
    final opmlData = await exportToOpml();

    // 创建 zip 文件
    final archive = Archive();
    archive.addFile(ArchiveFile(
      'backup.json',
      utf8.encode(jsonEncode(jsonData)).length,
      utf8.encode(jsonEncode(jsonData)),
    ));
    archive.addFile(ArchiveFile(
      'subscriptions.opml',
      utf8.encode(opmlData).length,
      utf8.encode(opmlData),
    ));

    // 写入 zip 文件
    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(ZipEncoder().encode(archive)!);

    return zipPath;
  }

  /// 从备份文件恢复（支持 JSON 和 zip），返回新导入的订阅源数量
  Future<int> restoreFromJson(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Backup file not found');
    }

    Map<String, dynamic> data;

    // 如果是 zip 文件，解压后读取
    if (path.endsWith('.zip')) {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final jsonFile = archive.findFile('backup.json');
      if (jsonFile == null) {
        throw Exception('Invalid backup file: backup.json not found');
      }
      final jsonStr = utf8.decode(jsonFile.content);
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
    } else {
      // JSON 文件直接读取
      final jsonStr = await file.readAsString();
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
    }

    final feeds = (data['feeds'] as List).map((f) => Feed.fromJson(f)).toList();
    final articles = (data['articles'] as List).map((a) => Article.fromJson(a)).toList();
    final config = AppConfig.fromJson(data['config']);

    // 恢复数据（带去重）
    int feedCount = 0;
    for (var feed in feeds) {
      await _storage.addFeedWithDuplicateCheck(feed);
      feedCount++;
    }
    await _storage.addArticles(articles);
    await _storage.updateConfig(config);

    return feedCount;
  }

  /// 从 zip 文件中的 OPML 导入订阅源（用于去重导入）
  Future<int> importOpmlFromZip(String zipPath) async {
    final file = File(zipPath);
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final opmlFile = archive.findFile('subscriptions.opml');
    if (opmlFile == null) return 0;

    final content = utf8.decode(opmlFile.content);
    int count = 0;

    // 简单解析 OPML
    final regex = RegExp(r'xmlUrl="([^"]+)"\s+text="([^"]+)"');
    final matches = regex.allMatches(content);

    for (var match in matches) {
      final url = match.group(1)!;
      final title = match.group(2)!;

      // 检查是否已存在
      final feeds = await _storage.getAllFeeds();
      if (!feeds.any((f) => f.url == url)) {
        final feed = Feed(
          id: Uri.parse(url).host + '_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          url: url,
          description: null,
          lastUpdated: DateTime.now(),
          group: null,
          addedAt: DateTime.now(),
        );
        await _storage.addFeed(feed);
        count++;
      }
    }

    return count;
  }

  /// 从 OPML 文件导入订阅源
  Future<int> importFromOpml(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('OPML file not found');
    }

    final content = await file.readAsString();
    int count = 0;

    // 简单解析 OPML
    final regex = RegExp(r'xmlUrl="([^"]+)"\s+text="([^"]+)"');
    final matches = regex.allMatches(content);

    for (var match in matches) {
      final url = match.group(1)!;
      final title = match.group(2)!;

      // 检查是否已存在
      final feeds = await _storage.getAllFeeds();
      if (!feeds.any((f) => f.url == url)) {
        final feed = Feed(
          id: Uri.parse(url).host + '_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          url: url,
          description: null,
          lastUpdated: DateTime.now(),
          group: null,
          addedAt: DateTime.now(),
        );
        await _storage.addFeed(feed);
        count++;
      }
    }

    return count;
  }

  /// 获取备份文件列表
  Future<List<File>> getBackupFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/backup');
    if (!await backupDir.exists()) return [];

    return backupDir.listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
  }

  String _escapeXml(String str) {
    return str
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
