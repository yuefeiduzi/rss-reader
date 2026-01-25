import 'package:flutter/material.dart';
import 'storage_service.dart';

class ThemeService extends ChangeNotifier {
  final StorageService _storage;
  ThemeMode _themeMode = ThemeMode.system;
  bool _followSystem = true;

  ThemeService(this._storage);

  ThemeMode get themeMode => _themeMode;
  bool get followSystem => _followSystem;

  /// 初始化主题设置
  Future<void> init() async {
    final config = await _storage.getConfig();
    _followSystem = config.followSystemTheme;
    _themeMode = config.isDarkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _followSystem = mode == ThemeMode.system;
    notifyListeners();

    final config = await _storage.getConfig();
    await _storage.updateConfig(config.copyWith(
      isDarkMode: mode == ThemeMode.dark,
      followSystemTheme: _followSystem,
    ));
  }

  /// 切换暗色模式
  Future<void> toggleDarkMode() async {
    await setThemeMode(
      _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  /// 获取当前主题数据 - Zen Monochrome 主题
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      // 使用系统默认字体，保持优雅排版
      fontFamily: null,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF8B7355), // Warm amber/coral 强调色
        brightness: Brightness.light,
        primary: const Color(0xFF2D2D2D),
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFE8E0D5),
        onPrimaryContainer: const Color(0xFF1A1A1A),
        secondary: const Color(0xFF8B7355),
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFF5EDE4),
        onSecondaryContainer: const Color(0xFF5C4A3A),
        tertiary: const Color(0xFF6B7A6B),
        onTertiary: Colors.white,
        background: const Color(0xFFFAFAFA),
        onBackground: const Color(0xFF1A1A1A),
        surface: Colors.white,
        onSurface: const Color(0xFF2D2D2D),
        surfaceVariant: const Color(0xFFF0EBE3),
        onSurfaceVariant: const Color(0xFF5C5C5C),
        outline: const Color(0xFFE0DED8),
        outlineVariant: const Color(0xFFF5F5F0),
        error: const Color(0xFFBA1A1A),
        onError: Colors.white,
      ),
      // 精致的卡片样式 - 无阴影，使用细边框
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE8E4DE), width: 1),
        ),
        color: Colors.white,
      ),
      // 优雅的 AppBar
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2D2D2D),
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: Color(0xFF5C5C5C)),
      ),
      // 导航栏主题
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFE8E0D5),
        labelTextStyle: MaterialStateTextStyle.resolveWith((states) {
          return TextStyle(
            fontSize: 11,
            fontWeight: states.contains(MaterialState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(MaterialState.selected)
                ? const Color(0xFF2D2D2D)
                : const Color(0xFF8C8C8C),
          );
        }),
      ),
      // 悬浮按钮样式
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF2D2D2D),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      // 凸起按钮
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF2D2D2D),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      // 填充按钮
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF8B7355),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      // 文本按钮
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
      ),
      // 输入框样式
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8F7F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8E4DE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8E4DE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B7355), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      // 对话框样式
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2D2D2D),
        ),
      ),
      // 底部弹窗样式
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: 0,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      // 分隔线样式
      dividerTheme: const DividerThemeData(
        color: Color(0xFFF0EBE3),
        thickness: 1,
      ),
      // 图标主题
      iconTheme: const IconThemeData(
        color: Color(0xFF5C5C5C),
        size: 22,
      ),
      // 列表磁贴样式
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2D2D2D),
        ),
        subtitleTextStyle: const TextStyle(
          fontSize: 13,
          color: Color(0xFF8C8C8C),
        ),
      ),
      // 页面过渡动画
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      // 支架背景色
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
    );
  }

  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: null,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFD4A574), // 暖琥珀色用于暗色模式
        brightness: Brightness.dark,
        primary: const Color(0xFFE8E0D5),
        onPrimary: const Color(0xFF1A1A1A),
        primaryContainer: const Color(0xFF3D3D3D),
        onPrimaryContainer: const Color(0xFFE8E0D5),
        secondary: const Color(0xFFD4A574),
        onSecondary: const Color(0xFF1A1A1A),
        secondaryContainer: const Color(0xFF4A3F35),
        onSecondaryContainer: const Color(0xFFF5EDE4),
        tertiary: const Color(0xFF9DB89E),
        onTertiary: const Color(0xFF1A1A1A),
        background: const Color(0xFF121212),
        onBackground: const Color(0xFFE8E0D5),
        surface: const Color(0xFF1E1E1E),
        onSurface: const Color(0xFFE8E0D5),
        surfaceVariant: const Color(0xFF2A2A2A),
        onSurfaceVariant: const Color(0xFFB0B0B0),
        outline: const Color(0xFF3A3A3A),
        outlineVariant: const Color(0xFF2A2A2A),
        error: const Color(0xFFFFB4AB),
        onError: const Color(0xFF690005),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF3A3A3A), width: 1),
        ),
        color: const Color(0xFF1E1E1E),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE8E0D5),
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: Color(0xFFB0B0B0)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF3D3D3D),
        labelTextStyle: MaterialStateTextStyle.resolveWith((states) {
          return TextStyle(
            fontSize: 11,
            fontWeight: states.contains(MaterialState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(MaterialState.selected)
                ? const Color(0xFFE8E0D5)
                : const Color(0xFF707070),
          );
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFE8E0D5),
        foregroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFFE8E0D5),
          foregroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFFD4A574),
          foregroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4A574), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE8E0D5),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: 0,
        backgroundColor: Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A2A),
        thickness: 1,
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFFB0B0B0),
        size: 22,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        tileColor: const Color(0xFF1E1E1E),
        titleTextStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFFE8E0D5),
        ),
        subtitleTextStyle: const TextStyle(
          fontSize: 13,
          color: Color(0xFF8C8C8C),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
    );
  }
}
