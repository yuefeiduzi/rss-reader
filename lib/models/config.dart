class AppConfig {
  final bool isDarkMode;
  final bool followSystemTheme;
  final int refreshInterval;
  final int maxCachedArticles;
  final bool autoRefreshOnStart;
  final bool enableNotifications;
  final String? lastSyncTime;

  AppConfig({
    this.isDarkMode = false,
    this.followSystemTheme = true,
    this.refreshInterval = 60,
    this.maxCachedArticles = 500,
    this.autoRefreshOnStart = true,
    this.enableNotifications = false,
    this.lastSyncTime,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      isDarkMode: json['isDarkMode'] ?? false,
      followSystemTheme: json['followSystemTheme'] ?? true,
      refreshInterval: json['refreshInterval'] ?? 60,
      maxCachedArticles: json['maxCachedArticles'] ?? 500,
      autoRefreshOnStart: json['autoRefreshOnStart'] ?? true,
      enableNotifications: json['enableNotifications'] ?? false,
      lastSyncTime: json['lastSyncTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isDarkMode': isDarkMode,
      'followSystemTheme': followSystemTheme,
      'refreshInterval': refreshInterval,
      'maxCachedArticles': maxCachedArticles,
      'autoRefreshOnStart': autoRefreshOnStart,
      'enableNotifications': enableNotifications,
      'lastSyncTime': lastSyncTime,
    };
  }

  AppConfig copyWith({
    bool? isDarkMode,
    bool? followSystemTheme,
    int? refreshInterval,
    int? maxCachedArticles,
    bool? autoRefreshOnStart,
    bool? enableNotifications,
    String? lastSyncTime,
  }) {
    return AppConfig(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      followSystemTheme: followSystemTheme ?? this.followSystemTheme,
      refreshInterval: refreshInterval ?? this.refreshInterval,
      maxCachedArticles: maxCachedArticles ?? this.maxCachedArticles,
      autoRefreshOnStart: autoRefreshOnStart ?? this.autoRefreshOnStart,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}
