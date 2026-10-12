/// macOS 窗口顶栏的尺寸约定。
///
/// `macos/Runner/MainFlutterWindow.swift` 给窗口加了 `.fullSizeContentView`：
/// 内容铺满整窗（含标题栏那条带），标题栏透明、标题隐藏，于是红绿灯直接浮在
/// Flutter 画的顶栏左上角 —— 整个头部是一条带子，不是「系统标题栏 + 应用顶栏」两层。
/// 这里给出这条带子要用的两个数，`HomeScreen` / `SettingsScreen` 据此排版。
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// 顶栏高度。
///
/// 比 Material 默认的 56 略矮。红绿灯在原生侧被下移到这条带子的中线上
/// （`MainFlutterWindow.alignTrafficLights`，高度由 `syncMacOSTopBarHeight` 告知），
/// 所以标题/按钮与红绿灯是同一条中心线。
///
/// 改这个值别忘了一起改 `app_top_bar.dart` 里的排版预期；原生侧不用改，它会收到新值。
double get macOSTopBarHeight => isMacOSDesktop ? 52 : kDefaultToolbarHeight;

/// 非 macOS 上就是 Material 的默认工具栏高度。
const double kDefaultToolbarHeight = 56;

/// 红绿灯占掉的横向空间。
///
/// 三个 12pt 的圆点从 x=13 开始、间距 8pt，加上一点余量约 80pt ——
/// 顶栏最左侧的内容要往右让开这么多，否则会被红绿灯压住且点不到。
double get macOSTrafficLightInset => isMacOSDesktop ? 80 : 0;

/// 是否运行在 macOS 桌面端。
///
/// Web 上 `Platform` 不可用（读了会抛 `UnsupportedError`），所以先用 `kIsWeb`
/// 挡一道 —— 和 `backup_service` 处理 `dart:io` 的方式一致。
bool get isMacOSDesktop => !kIsWeb && Platform.isMacOS;
