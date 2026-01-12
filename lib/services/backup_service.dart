import 'dart:convert';
import 'dart:io';
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

  /// 备份到文件
  Future<String> backupToFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/backup');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final jsonPath = '${backupDir.path}/backup_$timestamp.json';
    final opmlPath = '${backupDir.path}/subscriptions_$timestamp.opml';

    // 保存 JSON 备份
    final jsonData = await exportToJson();
    final jsonFile = File(jsonPath);
    await jsonFile.writeAsString(jsonEncode(jsonData));

    // 保存 OPML
    final opmlData = await exportToOpml();
    final opmlFile = File(opmlPath);
    await opmlFile.writeAsString(opmlData);

    return jsonPath;
  }

  /// 从 JSON 文件恢复
  Future<void> restoreFromJson(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Backup file not found');
    }

    final jsonStr = await file.readAsString();
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    final feeds = (data['feeds'] as List).map((f) => Feed.fromJson(f)).toList();
    final articles = (data['articles'] as List).map((a) => Article.fromJson(a)).toList();
    final config = AppConfig.fromJson(data['config']);

    // 恢复数据
    for (var feed in feeds) {
      await _storage.addFeed(feed);
    }
    await _storage.addArticles(articles);
    await _storage.updateConfig(config);
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
