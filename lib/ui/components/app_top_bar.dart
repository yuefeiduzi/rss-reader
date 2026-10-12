import 'package:flutter/material.dart';

import '../../utils/macos_window.dart';
import 'window_drag_area.dart';

/// 全应用统一的顶栏（AppBar）。
///
/// macOS 上窗口内容铺满整窗、标题栏透明、红绿灯浮在左上角
/// （见 `macos/Runner/MainFlutterWindow.swift`），于是顶栏排版有四件容易写漏的事，
/// 集中在这里处理：
///
/// 1. 用 [macOSTopBarHeight] 把工具栏压矮，让标题与按钮跟红绿灯处在同一条视觉带子上；
/// 2. 标题往右让开 [macOSTrafficLightInset]，不跟红绿灯重叠；
/// 3. 返回键画在标题前面 —— AppBar 自带的 `leading` 会被居中在红绿灯底下，点不到；
/// 4. 顶栏空白处交给 [MacWindowDragArea] 拖动窗口。
///
/// 各页面只管给出标题、返回动作与右侧按钮。
PreferredSizeWidget appTopBar({
  required Widget title,
  List<Widget>? actions,
  VoidCallback? onBack,
  bool showDivider = false,
}) {
  final isMac = isMacOSDesktop;

  return AppBar(
    toolbarHeight: macOSTopBarHeight,
    // macOS 上返回键自己画（见下），其余平台交给 AppBar 按路由推断
    automaticallyImplyLeading: !isMac,
    titleSpacing: isMac ? macOSTrafficLightInset : null,
    leading: isMac
        ? null
        : (onBack == null ? null : BackButton(onPressed: onBack)),
    title: isMac && onBack != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 用 BackButton 而不是裸 IconButton：它在 macOS 上会画成 iOS 风格的
              // 尖括号，tooltip 也跟着 MaterialLocalizations 走
              BackButton(onPressed: onBack),
              Flexible(child: title),
            ],
          )
        : title,
    centerTitle: false,
    flexibleSpace: const MacWindowDragArea(),
    actions: actions,
    bottom: showDivider
        ? PreferredSize(
            preferredSize: const Size(double.infinity, 1),
            child: Builder(
              builder: (context) => Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              ),
            ),
          )
        : null,
  );
}
