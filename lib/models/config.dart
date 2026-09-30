/// 应用配置。
///
/// 只保留**真的有代码读写**的字段。2026-09-29 删掉了五个纯持久化、无人使用的字段：
/// `refreshInterval` / `autoRefreshOnStart` / `lastSyncTime` /
/// `maxCachedArticles` / `enableNotifications`。
///
/// 它们当时会写进 SharedPreferences，但全项目没有任何地方读或写，
/// 于是「启动时自动刷新」「定时刷新」「缓存上限」「通知」全部是不存在的功能
/// —— 尽管配置文件里写着 `autoRefreshOnStart: true`。详见
/// `docs/known-issues.md` 2.4。
///
/// 旧数据里残留的这些 key 会被 [fromJson] 直接忽略，无需迁移。
class AppConfig {
  final bool isDarkMode;
  final bool followSystemTheme;

  const AppConfig({
    this.isDarkMode = false,
    this.followSystemTheme = true,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      isDarkMode: json['isDarkMode'] ?? false,
      followSystemTheme: json['followSystemTheme'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isDarkMode': isDarkMode,
      'followSystemTheme': followSystemTheme,
    };
  }

  AppConfig copyWith({
    bool? isDarkMode,
    bool? followSystemTheme,
  }) {
    return AppConfig(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      followSystemTheme: followSystemTheme ?? this.followSystemTheme,
    );
  }
}