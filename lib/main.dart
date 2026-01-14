import 'package:flutter/material.dart';
import 'services/cache_service.dart';
import 'services/storage_service.dart';
import 'services/theme_service.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化存储
  final storageService = StorageService();
  await storageService.init();

  // 初始化缓存服务
  final cacheService = CacheService();
  await cacheService.init();

  // 初始化主题
  final themeService = ThemeService(storageService);
  await themeService.init();

  runApp(MyApp(
    storageService: storageService,
    themeService: themeService,
    cacheService: cacheService,
  ));
}

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
    return AnimatedBuilder(
      animation: themeService,
      builder: (context, child) {
        return MaterialApp(
          title: 'RSS Reader',
          debugShowCheckedModeBanner: false,
          theme: themeService.lightTheme,
          darkTheme: themeService.darkTheme,
          themeMode: themeService.themeMode,
          home: HomeScreen(
            storageService: storageService,
            themeService: themeService,
            cacheService: cacheService,
          ),
        );
      },
    );
  }
}
