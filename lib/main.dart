import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/cache_service.dart';
import 'services/rss_service.dart';
import 'services/storage_service.dart';
import 'services/theme_service.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final cacheService = CacheService();
  await cacheService.init();

  final themeService = ThemeService(storageService);
  await themeService.init();

  runApp(MyApp(
    storageService: storageService,
    themeService: themeService,
    cacheService: cacheService,
  ));
}

/// 应用根。
///
/// 服务在这里一次性创建并通过 Provider 注入，页面从 `context` 自取，
/// 不再逐层透传。`StorageService` / `ThemeService` 都是 [ChangeNotifier]，
/// 页面 watch 它们即可在数据变化时自动重建。
class MyApp extends StatelessWidget {
  final StorageService storageService;
  final ThemeService themeService;
  final CacheService cacheService;

  const MyApp({
    super.key,
    required this.storageService,
    required this.themeService,
    required this.cacheService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<StorageService>.value(value: storageService),
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
        Provider<CacheService>.value(value: cacheService),
        // RssService 无状态，创建一次复用，避免每个页面各自 new 一个
        Provider<RssService>(create: (_) => RssService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, theme, _) => MaterialApp(
          title: 'RSS Reader',
          debugShowCheckedModeBanner: false,
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          themeMode: theme.themeMode,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}