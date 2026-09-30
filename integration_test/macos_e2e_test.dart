/// macOS 端完整链路 e2e（集成测试：真 app、真网络、真文件系统）。
///
/// 为什么要有它
/// ------------
/// macOS 端的构建与「抓真实 RSS」早就通了，但「添加源 → 列表 → 详情 →
/// 全文抓取 → 收藏 → 已读 → 删除 → 备份/恢复」这条链路一次都没跑过，
/// 所以文档里一直不敢写「macOS 已支持」。这个文件把这条链路变成可重复执行的，
/// 每个 `testWidgets` 就是 TODO.md 里的一项，失败时能直接看出是哪一项。
///
/// 为什么用 fixture 而不是真实站点
/// ------------------------------
/// 真实站点内容会变、日期不可控、也造不出「摘要刚好不足 200 字符」这种边界。
/// `tool/e2e_fixture/` 里每个文件都对应一个已修过的缺陷（见其 README）。
/// macOS 没有 CORS 限制，用 fixture 只是为了**可断言**。
///
/// 为什么 mock SharedPreferences
/// ----------------------------
/// 集成测试跑的是真 app、真 bundle id（org.ross.rssReader），直接用
/// SharedPreferences 会读写**用户真实数据**（`~/Library/Containers/...plist`）。
/// 这里用 `setMockInitialValues` 换成内存实现，测试完全 hermetic，
/// 跑完不会碰容器里的 plist。
///
/// 哪些没被覆盖（需要原生对话框，自动化一碰就会卡住，列为手动项）
/// ------------------------------------------------------------
/// 备份选择目录、导入选择文件、图片保存到磁盘、系统分享、在浏览器中打开原文。
/// 备份/恢复与 OPML 导出导入改用 **服务层直接调用**覆盖同一段读写的代码，
/// 只是绕过了 file_picker；其余四项必须人工点。
///
/// 跑法
/// ----
///   python3 tool/e2e_fixture/serve.py 8100 &          # 先起 fixture
///   flutter test integration_test/macos_e2e_test.dart -d macos
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rss_reader/main.dart';
import 'package:rss_reader/models/feed.dart';
import 'package:rss_reader/services/backup_service.dart';
import 'package:rss_reader/services/cache_service.dart';
import 'package:rss_reader/services/storage_service.dart';
import 'package:rss_reader/services/theme_service.dart';
import 'package:rss_reader/ui/components/feed_list_tile.dart';
import 'package:rss_reader/ui/components/html_content_view.dart';
import 'package:rss_reader/utils/date_format.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String fixtureBase = 'http://127.0.0.1:8100';
const String rssFeedUrl = '$fixtureBase/feed.xml';
const String atomFeedUrl = '$fixtureBase/atom.xml';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late CacheService cache;
  late ThemeService theme;

  /// 取订阅源，取不到时给出人能看懂的失败信息（而不是 `Bad state: No element`）。
  Feed feedByUrl(String url) {
    final matches = storage.feeds.where((f) => f.url == url);
    if (matches.isEmpty) {
      fail('订阅源不存在：$url\n'
          '用例之间共享数据且按顺序执行；前一个用例失败会连带这里失败，'
          '请先修最前面的失败。');
    }
    return matches.first;
  }

  setUpAll(() async {
    await _assertFixtureServerIsUp(fixtureBase);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    storage = StorageService();
    await storage.init();
    cache = CacheService();
    await cache.init();
    theme = ThemeService(storage);
    await theme.init();
  });

  /// 每个用例都从「重新挂载同一个 app」开始。
  ///
  /// 服务是共享的：用例之间**故意**保留数据（1 添加源 → 2 读文章 → 3 加 Atom →
  /// 4 删 Atom → 5 备份恢复），所以按顺序执行，别单独挑一个跑。
  Future<void> bootApp(WidgetTester tester) async {
    // macOS 默认窗口 1200×800（MainFlutterWindow.swift）→ 宽屏分栏，侧栏常驻。
    // 若这条失败，说明窗口尺寸变了，后面「侧栏一直可见」的假设不成立。
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(width, greaterThanOrEqualTo(900), reason: '需要宽屏布局（侧栏常驻）');

    await tester.pumpWidget(MyApp(
      storageService: storage,
      themeService: theme,
      cacheService: cache,
    ));
    await waitFor(tester, find.text('订阅源'), label: '侧栏表头');
  }

  testWidgets('1. 添加 RSS 源 → 侧栏 → 文章列表（dc:date 只读条目）', (tester) async {
    await bootApp(tester);
    expect(find.text('暂无订阅源'), findsOneWidget);

    await addFeedViaDialog(
        tester, rssFeedUrl, find.widgetWithText(FilledButton, '添加订阅源'));
    await waitFor(tester, feedTile('本地测试源'), label: '侧栏出现 RSS 源');
    expect(feedTile('本地测试源'), findsOneWidget);
    expect(find.text('暂无订阅源'), findsNothing);

    // 选中源 → 列表页自动刷新（真实网络请求打到 fixture）
    await tester.tap(feedTile('本地测试源'));
    await waitFor(tester, find.text('富文本文章'), label: '文章列表渲染');

    expect(find.text('普通文章'), findsOneWidget);
    expect(find.text('短摘要文章'), findsOneWidget);
    expect(find.text('只有 dc:date 的文章'), findsOneWidget);

    // dc:date-only 条目：早期实现写成 pubDate ?? DateTime.now()，会显示「刚刚」。
    // 期望值按本地时区算，避免机器时区不同导致的假失败。
    final expected = formatDate(DateTime.parse('2020-01-02T03:04:05+08:00'));
    expect(find.text(expected), findsOneWidget,
        reason: '只有 dc:date 的文章应显示 2020-01-02 而不是当前时间');
  });

  testWidgets('2. 详情页：全文抓取 / 收藏 / 已读 / 未读数', (tester) async {
    await bootApp(tester);
    final feed = feedByUrl(rssFeedUrl);
    expect(storage.unreadCountOf(feed.id), 4);

    await tester.tap(feedTile('本地测试源'));
    await waitFor(tester, find.text('短摘要文章'), label: '文章列表');
    await tester.tap(find.text('短摘要文章'));

    // 摘要不足 200 字符 → 详情页应抓 article3.html 的全文
    await waitFor(tester, find.byType(HtmlContentView), label: '详情页内容渲染');
    final view = tester.widget<HtmlContentView>(find.byType(HtmlContentView));
    expect(view.html, contains('短摘要文章的完整正文'), reason: '全文抓取应成功');
    expect(view.html, contains('Uint8List'),
        reason: 'fetchFullContent 的 Uint8List 解码回归点');
    expect(view.html, isNot(contains('导航应当被移除')), reason: 'nav 应被剥离');

    // 收藏
    await tester.tap(find.byIcon(Icons.favorite_border));
    await waitFor(tester, find.byIcon(Icons.favorite), label: '收藏状态切换');
    final article = storage.allArticles.firstWhere((a) => a.title == '短摘要文章');
    expect(article.isFavorite, isTrue);
    expect(article.isRead, isTrue, reason: '打开文章即标记已读');
    expect(storage.unreadCountOf(feed.id), 3);

    // 回到列表：未读徽标应变成 3（详情页操作栏也有源名，所以限定在侧栏 tile 里找）
    await tester.tap(feedTile('本地测试源'));
    await waitFor(tester, find.text('富文本文章'), label: '回到文章列表');
    expect(
      find.descendant(of: find.byType(FeedListTile), matching: find.text('3')),
      findsOneWidget,
      reason: '侧栏未读徽标应为 3（4 篇里已读 1 篇）',
    );
  });

  testWidgets('3. 添加 Atom 源（entry 只有 <updated>，曾整源解析崩溃）', (tester) async {
    await bootApp(tester);

    // 用 FloatingActionButton 限定：空状态里的「添加订阅源」按钮也用 Icons.add
    await addFeedViaDialog(tester, atomFeedUrl,
        find.widgetWithIcon(FloatingActionButton, Icons.add));
    await waitFor(tester, feedTile('本地测试源 (Atom)'), label: '侧栏出现 Atom 源');

    await tester.tap(feedTile('本地测试源 (Atom)'));
    await waitFor(tester, find.text('Atom 条目一（只有 updated）'),
        label: 'Atom 条目解析');
    expect(find.text('Atom 条目二（只有 updated）'), findsOneWidget);
  });

  testWidgets('4. 菜单删除订阅源（二次确认 + 级联删文章）', (tester) async {
    await bootApp(tester);
    final atomFeed = feedByUrl(atomFeedUrl);
    expect(storage.allArticles.where((a) => a.feedId == atomFeed.id).length, 2);

    final atomTile = find.ancestor(
      of: find.text('本地测试源 (Atom)'),
      matching: find.byType(FeedListTile),
    );
    await tester.tap(
      find.descendant(of: atomTile, matching: find.byTooltip('更多操作')),
    );
    await tester.pumpAndSettle();

    // 只点右键菜单里的「删除」：tile 内部还藏着同名的滑出按钮（透明度 0）
    final deleteInMenu = find.ancestor(
      of: find.text('删除'),
      matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
    );
    await tester.tap(deleteInMenu);
    await tester.pumpAndSettle();

    expect(find.text('删除订阅源'), findsOneWidget, reason: '删除必须二次确认');
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await waitForGone(tester, feedTile('本地测试源 (Atom)'), label: '侧栏移除');

    expect(storage.feeds.where((f) => f.url == atomFeedUrl), isEmpty);
    expect(storage.allArticles.where((a) => a.feedId == atomFeed.id), isEmpty,
        reason: '删除订阅源应级联删除文章');
  });

  testWidgets('5. 备份/恢复 + OPML 导出导入（服务层，绕过原生文件对话框）', (tester) async {
    await bootApp(tester);
    final backup = BackupService(storage);
    final tempDir = await Directory.systemTemp.createTemp('rss_reader_e2e_');
    addTearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    // 备份：zip 真的写到磁盘
    final zipPath = await backup.backupToFile(outputDirectory: tempDir.path);
    expect(File(zipPath).existsSync(), isTrue);
    expect(File(zipPath).lengthSync(), greaterThan(100));

    // 删除 → 从 zip 恢复 → UI 自动重建
    final feed = feedByUrl(rssFeedUrl);
    final articlesBefore = storage.allArticles.length;
    await storage.deleteFeed(feed.id);
    await waitForGone(tester, feedTile('本地测试源'), label: '删除后侧栏清空');
    expect(storage.feeds, isEmpty);

    expect(await backup.restoreFromJson(zipPath), 1);
    await waitFor(tester, feedTile('本地测试源'), label: '恢复后侧栏自动重建');
    expect(storage.allArticles.length, articlesBefore);

    // OPML：原样导入应被去重；改掉地址后应新增 1 个
    final opmlPath = '${tempDir.path}/subscriptions.opml';
    await File(opmlPath).writeAsString(backup.exportToOpml());
    expect(await backup.importFromOpml(opmlPath), 0, reason: '重复地址不应再新增');

    await File(opmlPath).writeAsString(
      backup
          .exportToOpml()
          .replaceAll(rssFeedUrl, '$fixtureBase/feed-copy.xml'),
    );
    expect(await backup.importFromOpml(opmlPath), 1);
    expect(storage.feeds.length, 2);

    // 收尾：这个副本只是为了验证导入，留着会让同名 tile 出现两个，
    // 干扰后面的用例（tile 标题相同、只有 URL 不同）。
    await storage.deleteFeed(feedByUrl('$fixtureBase/feed-copy.xml').id);
    await tester.pump();
    expect(storage.feeds.length, 1);
  });

  testWidgets('6. 详情页图片：相对路径补全 / 懒加载 / 画廊开关', (tester) async {
    await bootApp(tester);
    await tester.tap(feedTile('本地测试源'));
    await waitFor(tester, find.text('富文本文章'), label: '文章列表');
    await tester.tap(find.text('富文本文章'));

    // 看大图入口出现 = 图片抓取与解析完成
    await waitFor(tester, find.text('看大图'), label: '图片入口');
    final view = tester.widget<HtmlContentView>(find.byType(HtmlContentView));
    expect(view.html, contains('$fixtureBase/img.png'), reason: '相对路径应补全');
    expect(view.html, contains('$fixtureBase/img2.png'),
        reason: 'data-src 应写回 src');
    // 注意 HTML 注释里也提到了 placeholder.png，那不是请求；只看 src 属性
    expect(
      RegExp(r'''src\s*=\s*["'][^"']*placeholder\.png''').hasMatch(view.html),
      isFalse,
      reason: '占位图不应留在 src 里（是否被真请求过看 fixture 服务器日志）',
    );

    // 图片默认居中：fixture 里两张图各自在一个只有图片的 <p> 里
    final contentRect = tester.getRect(find.byType(HtmlContentView));
    final images = find.descendant(
      of: find.byType(HtmlContentView),
      matching: find.byType(Image),
    );
    expect(images, findsNWidgets(2), reason: '正文里应渲染出两张图');
    for (var i = 0; i < 2; i++) {
      final rect = tester.getRect(images.at(i));
      expect(
        (rect.center.dx - contentRect.center.dx).abs(),
        lessThan(2),
        reason: '第 ${i + 1} 张图应水平居中',
      );
    }

    await tester.tap(find.text('看大图'));
    await waitFor(tester, find.byIcon(Icons.close), label: '画廊打开');
    await tester.tap(find.byIcon(Icons.close));
    await waitForGone(tester, find.byIcon(Icons.close), label: '画廊关闭');
  });

  testWidgets('7. 顶栏按钮仍然可用（macOS 拖拽层不吞点击）', (tester) async {
    await bootApp(tester);

    // 顶栏空白处挂了一层 MacWindowDragArea（把拖动交给原生窗口），
    // 它不能把按钮的点击也吃掉。
    final before = theme.themeMode;
    await tester.tap(find.byTooltip('切换主题'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(theme.themeMode, isNot(before), reason: '主题按钮应生效');

    await tester.tap(find.byIcon(Icons.settings));
    await waitFor(tester, find.text('Settings'), label: '设置页');

    // 返回首页，给下一个用例（如果有）留个干净状态
    await tester.pageBack();
    await waitFor(tester, find.text('订阅源'), label: '回到首页');
  });
}

/// 侧栏里的订阅源条目。详情页操作栏也会显示源名，不限定范围会撞车。
Finder feedTile(String title) =>
    find.descendant(of: find.byType(FeedListTile), matching: find.text(title));

/// 走「添加订阅源」对话框加一个源：[openButton] 是入口（空状态的按钮或侧栏 FAB）。
Future<void> addFeedViaDialog(
  WidgetTester tester,
  String url,
  Finder openButton,
) async {
  await tester.tap(openButton);
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(AlertDialog), findsOneWidget);

  // 第 0 个是「自定义名称」，第 1 个才是地址
  final fields = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );
  expect(fields, findsNWidgets(2));
  await tester.enterText(fields.at(1), url);

  await tester.tap(find.widgetWithText(FilledButton, '添加'));
}

/// 轮询等待 [finder] 命中（真实网络请求不能用 pumpAndSettle 等 —— 进度条动画永不停止）。
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  String? label,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('等待超时（${timeout.inSeconds}s）：${label ?? finder.description}');
}

/// 轮询等待 [finder] 消失。
Future<void> waitForGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
  String? label,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  fail('等待超时（${timeout.inSeconds}s），仍存在：${label ?? finder.description}');
}

/// fixture 服务器预检：没起就给一句人话，而不是等 UI 报「添加订阅源失败」。
Future<void> _assertFixtureServerIsUp(String base) async {
  final client = HttpClient();
  String? problem;
  try {
    final request = await client.getUrl(Uri.parse('$base/feed.xml'));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      problem = 'HTTP ${response.statusCode}';
    } else if (!body.contains('本地测试源')) {
      problem = '响应内容不像 fixture';
    }
  } on SocketException catch (e) {
    problem = '连不上 $base（$e）';
  } finally {
    client.close(force: true);
  }
  if (problem != null) {
    fail('fixture 服务器不可用：$problem\n'
        '先运行：python3 tool/e2e_fixture/serve.py 8100');
  }
}
