# CLAUDE.md

This file provides guidance for Claude Code when working with this project.

## Project Overview

rss_reader - A cross-platform RSS/Atom reader built with Flutter, supporting iOS, Android, macOS, Windows, Linux, and Web.

## Build Commands

```bash
# Install dependencies
flutter pub get

# Run development build
flutter run

# Build releases
flutter build apk --release          # Android
flutter build ios --release          # iOS
flutter build macos --release        # macOS
flutter build windows --release      # Windows
flutter build linux --release        # Linux
flutter build web --release          # Web
```

## Architecture Pattern

This project follows a **MVVM-like** architecture with clear separation:

```
lib/
├── main.dart              # App entry point, theme setup
├── models/                # Data models (Article, Feed, Config)
├── services/              # Business logic services
│   ├── rss_service.dart       # RSS/Atom parsing (pubDate, dc:date support)
│   ├── storage_service.dart   # Local storage (SharedPreferences)
│   ├── cache_service.dart     # Cache management
│   ├── theme_service.dart     # Theme management
│   └── backup_service.dart    # Backup/restore
└── ui/                    # Presentation layer
    ├── screens/           # Page components
    └── components/        # Reusable widgets
        ├── add_feed_dialog.dart   # Add feed dialog
        ├── edit_feed_dialog.dart  # Edit feed name dialog
        ├── feed_list_tile.dart    # Feed list tile with swipe/long-press/menu
        └── responsive_layout.dart # Adaptive layout
```

## Code Conventions

### Dart/Flutter
- Use `const` constructors where possible
- Prefer `const` declarations for static values
- Avoid `print()` statements in production code (use debugPrint)
- Follow Material 3 design guidelines
- Use Provider for state management

### Lint Rules (analysis_options.yaml)
- `prefer_const_constructors`
- `prefer_const_declarations`
- `avoid_print`

### Key Conventions
- Models: Simple data classes with JSON serialization
- Services: Singleton pattern for persistent services
- UI: Stateful widgets for screen components, stateless for reusable widgets
- Responsive: Use `ResponsiveLayout` widget for adaptive layouts

## Key Dependencies

- `webfeed` - RSS/Atom feed parsing
- `dio` - HTTP client
- `html` - HTML parsing for full-text extraction
- `shared_preferences` - Local persistence
- `provider` - State management
- `flutter_html` - HTML rendering
- `cached_network_image` - Image caching

## Platform-Specific Notes

- **Web**: Share functionality uses Web Share API
- **Desktop**: Supports file picker for backup import/export, right-click context menus
- **Mobile**: Optimized for touch interactions

## Recent Changes

### Feed List Interactions
- Added `more_vert` button for all platforms
- Added long-press context menu (500ms)
- Added right-click menu (macOS/Windows)
- Swipe actions preserved for touch devices

### RSS Parsing
- Supports both `pubDate` and `dc:date` formats
- Articles sorted by pubDate in descending order
