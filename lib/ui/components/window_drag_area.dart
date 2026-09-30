import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/macos_window.dart';

/// macOS 上把一块区域变成「拖动窗口」的把手。
///
/// 窗口标题栏是透明的（见 `macos/Runner/MainFlutterWindow.swift`），于是 AppKit
/// 只认窗口顶部那条**真正的**标题栏（28px）能拖 —— Flutter 画出来的顶栏它不认，
/// 因为鼠标事件先被 Flutter 视图吃掉了。`isMovableByWindowBackground` 实测也
/// 不管用（Flutter 视图会拦截）。所以这里把拖动意图通过 method channel 交给
/// 原生窗口的 `performDrag(with:)`，整条顶栏就都能拖了。
///
/// 用法：放在 AppBar 的 `flexibleSpace` 里 —— 它在标题与按钮**下面**一层，
/// 所以点按钮不会拖窗口，只有拖空白处才会。
class MacWindowDragArea extends StatelessWidget {
  const MacWindowDragArea({super.key});

  static const MethodChannel _channel =
      MethodChannel('org.ross.rssReader/window');

  @override
  Widget build(BuildContext context) {
    if (!isMacOSDesktop) return const SizedBox.shrink();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => _channel.invokeMethod<void>('startDrag'),
    );
  }
}
