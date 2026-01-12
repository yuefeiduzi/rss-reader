import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'services/theme_service.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化存储
  final storageService = StorageService();
  await storageService.init();

  // 初始化主题
  final themeService = ThemeService(storageService);
  await themeService.init();

  runApp(MyApp(storageService: storageService, themeService: themeService));
}

class MyApp extends StatelessWidget {
  final StorageService storageService;
  final ThemeService themeService;

  const MyApp({
    super.key,
    required this.storageService,
    required this.themeService,
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
          ),
        );
      },
    );
  }
}
