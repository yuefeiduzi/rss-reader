// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rss_reader/services/cache_service.dart';
import 'package:rss_reader/services/storage_service.dart';
import 'package:rss_reader/services/theme_service.dart';
import 'package:rss_reader/ui/screens/home_screen.dart';

void main() {
  testWidgets('Home screen loads feeds list', (WidgetTester tester) async {
    // Create mock services
    final storageService = StorageService();
    final cacheService = CacheService();
    final themeService = ThemeService(storageService);

    // Build our app and trigger a frame
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeService),
        ],
        child: MaterialApp(
          home: HomeScreen(
            storageService: storageService,
            themeService: themeService,
            cacheService: cacheService,
          ),
        ),
      ),
    );

    // Verify that the app title is shown
    expect(find.text('RSS Reader'), findsOneWidget);
  });
}
