import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rss_reader/models/config.dart';

void main() {
  group('AppConfig 默认值', () {
    test('新装的应用是浅色 + 跟随系统', () {
      const config = AppConfig();
      expect(config.isDarkMode, isFalse);
      expect(config.followSystemTheme, isTrue);
    });

    test('空 JSON 走默认值', () {
      final config = AppConfig.fromJson(const {});
      expect(config.isDarkMode, isFalse);
      expect(config.followSystemTheme, isTrue);
    });
  });

  group('AppConfig JSON 往返', () {
    test('两个字段都能往返', () {
      const original = AppConfig(isDarkMode: true, followSystemTheme: false);
      final restored = AppConfig.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(restored.isDarkMode, isTrue);
      expect(restored.followSystemTheme, isFalse);
    });

    test('toJson 只输出两个 key', () {
      expect(const AppConfig().toJson().keys,
          unorderedEquals(['isDarkMode', 'followSystemTheme']));
    });
  });

  group('AppConfig 向后兼容', () {
    // 2026-09-29 删掉了五个纯持久化、无人读写的字段：
    // refreshInterval / autoRefreshOnStart / lastSyncTime /
    // maxCachedArticles / enableNotifications。
    // 老用户的 SharedPreferences 和旧备份文件里仍然带着这些 key，
    // 加载时必须被忽略，而不是抛异常或把数据带进来。
    test('旧数据里的已删字段被忽略，不影响新字段', () {
      final legacy = jsonDecode('''
      {
        "isDarkMode": true,
        "followSystemTheme": false,
        "refreshInterval": 60,
        "autoRefreshOnStart": true,
        "maxCachedArticles": 500,
        "enableNotifications": false,
        "lastSyncTime": "2026-09-29T16:24:28.337891"
      }
      ''') as Map<String, dynamic>;

      final config = AppConfig.fromJson(legacy);

      expect(config.isDarkMode, isTrue);
      expect(config.followSystemTheme, isFalse);
    });

    test('旧数据只有被删字段时退回默认值', () {
      final config = AppConfig.fromJson(const {
        'refreshInterval': 60,
        'autoRefreshOnStart': true,
        'lastSyncTime': null,
      });

      expect(config.isDarkMode, isFalse);
      expect(config.followSystemTheme, isTrue);
    });

    test('再序列化后已删字段不会回来', () {
      final config = AppConfig.fromJson(const {
        'isDarkMode': true,
        'refreshInterval': 60,
        'autoRefreshOnStart': true,
        'maxCachedArticles': 500,
        'enableNotifications': false,
        'lastSyncTime': '2026-09-29T16:24:28.337891',
      });

      final keys = config.toJson().keys;
      expect(keys, isNot(contains('refreshInterval')));
      expect(keys, isNot(contains('autoRefreshOnStart')));
      expect(keys, isNot(contains('maxCachedArticles')));
      expect(keys, isNot(contains('enableNotifications')));
      expect(keys, isNot(contains('lastSyncTime')));
    });
  });

  group('AppConfig.copyWith', () {
    test('只改传进来的字段', () {
      const original = AppConfig(isDarkMode: false, followSystemTheme: true);
      final updated = original.copyWith(isDarkMode: true);

      expect(updated.isDarkMode, isTrue);
      expect(updated.followSystemTheme, isTrue, reason: '没传的字段应保持原值');
    });

    test('不传任何参数时等于原值', () {
      const original = AppConfig(isDarkMode: true, followSystemTheme: false);
      final same = original.copyWith();

      expect(same.isDarkMode, isTrue);
      expect(same.followSystemTheme, isFalse);
    });
  });
}