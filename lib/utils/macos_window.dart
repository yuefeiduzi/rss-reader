/// macOS 窗口的顶部安全区。
///
/// `macos/Runner/MainFlutterWindow.swift` 把标题栏设成透明、隐藏标题，并让内容
/// 顶到窗口最顶部，于是红绿灯会浮在 Flutter 画的顶栏之上。这里给出需要让出的
/// 高度；`main.dart` 把它注入 `MediaQuery.padding.top`，Material 的 AppBar
/// （`primary: true` 时）会自动据此加高自己并把标题、按钮下移，
/// 因此不用在各个页面里手写 padding。
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// NSWindow 标题栏的高度，也就是红绿灯所在那条带子。
const double macOSTitleBarHeight = 28;

/// 是否运行在 macOS 桌面端。
///
/// Web 上 `Platform` 不可用（读了会抛 `UnsupportedError`），所以先用 `kIsWeb`
/// 挡一道 —— 和 `backup_service` 处理 `dart:io` 的方式一致。
bool get isMacOSDesktop => !kIsWeb && Platform.isMacOS;
