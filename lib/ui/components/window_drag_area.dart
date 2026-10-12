import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/macos_window.dart';
/// macOS 上把一块区域变成「拖动窗口」的把手。
///
/// 窗口加了 `.fullSizeContentView`（见 `macos/Runner/MainFlutterWindow.swift`），
/// Flutter 的内容铺满整窗、盖住了标题栏那条带，鼠标事件先被 Flutter 视图吃掉，
/// 所以顶栏的空白处得自己把拖动意图通过 method channel 交给原生窗口的
/// `performDrag(with:)`。（红绿灯本身仍是原生的，点它们不受影响；
/// 双击顶栏的系统缩放行为也还在。）
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

/// 把顶栏高度告知原生窗口：红绿灯要据此对齐到顶栏中线
/// （见 `macos/Runner/MainFlutterWindow.swift` 的 `alignTrafficLights`）。
///
/// 高度的唯一来源是 Dart 侧的 [macOSTopBarHeight]，原生侧只存 Dart 发来的值 ——
/// 两边各写一个常量迟早会写歪（历史上 macOS 标题栏是 32pt，Dart 里写的是 28）。
///
/// macOS 之外是空操作；测试环境没有原生侧（会抛 `MissingPluginException`），也当空操作。
Future<void> syncMacOSTopBarHeight() async {
  if (!isMacOSDesktop) return;
  try {
    await MacWindowDragArea._channel
        .invokeMethod<void>('setTopBarHeight', macOSTopBarHeight);
  } on MissingPluginException {
    // 没有原生实现（单元测试）—— 顶栏样式本来就不参与断言，忽略
  }
}
