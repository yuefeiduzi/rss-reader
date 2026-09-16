import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rss_reader/models/feed.dart';
import 'package:rss_reader/services/cache_service.dart';
import 'package:rss_reader/services/rss_service.dart';
import 'package:rss_reader/services/storage_service.dart';
import 'package:rss_reader/services/theme_service.dart';
import 'package:rss_reader/ui/components/feed_list_panel.dart';
import 'package:rss_reader/ui/screens/home_screen.dart';

/// 建一棵带好依赖的树，替代手工透传服务。
Future<void> pumpHome(WidgetTester tester, StorageService storage) async {
  final cache = CacheService();
  final theme = ThemeService(storage);
  await theme.init();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<StorageService>.value(value: storage),
        ChangeNotifierProvider<ThemeService>.value(value: theme),
        Provider<CacheService>.value(value: cache),
        Provider<RssService>(create: (_) => RssService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, theme, _) => MaterialApp(
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          themeMode: theme.themeMode,
          home: const HomeScreen(),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    // 让 SharedPreferences 走内存实现，测试不碰真实磁盘
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('没有订阅源时显示空状态', (tester) async {
    final storage = StorageService();
    await storage.init();

    await pumpHome(tester, storage);
    await tester.pumpAndSettle();

    expect(find.text('暂无订阅源'), findsOneWidget);
  });

  testWidgets('订阅源列表来自 StorageService，写入后自动出现', (tester) async {
    final storage = StorageService();
    await storage.init();

    await pumpHome(tester, storage);
    await tester.pumpAndSettle();

    // 模拟一次外部写入：界面应当自行更新，不需要调用方刷新
    await storage.addFeed(Feed(
      id: 'f1',
      title: '示例订阅源',
      url: 'https://example.com/feed.xml',
      lastUpdated: DateTime(2026),
      addedAt: DateTime(2026),
    ));
    await tester.pumpAndSettle();

    expect(find.text('示例订阅源'), findsOneWidget);

    // 列表面板直接使用 unreadCountOf，未读数为 0
    expect(find.byType(FeedListPanel), findsOneWidget);
  });

  testWidgets('未读数由服务端增量维护', (tester) async {
    final storage = StorageService();
    await storage.init();

    await storage.addFeed(Feed(
      id: 'f1',
      title: '源',
      url: 'https://example.com/feed.xml',
      lastUpdated: DateTime(2026),
      addedAt: DateTime(2026),
    ));

    expect(storage.unreadCountOf('f1'), 0);
  });
}