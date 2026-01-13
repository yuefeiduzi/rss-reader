import 'package:flutter/material.dart';

/// 响应式布局断点
enum ResponsiveBreakpoint {
  mobile(600),
  tablet(900),
  desktop(1200);

  final double width;
  const ResponsiveBreakpoint(this.width);
}

/// 判断当前是否为宽屏设备
bool isWideScreen(BuildContext context) {
  return MediaQuery.of(context).size.width >= ResponsiveBreakpoint.tablet.width;
}

/// 响应式布局组件
/// 宽屏时显示分栏布局，窄屏时显示单页导航
class ResponsiveLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget wideScreenLayout;

  const ResponsiveLayout({
    super.key,
    required this.mobileLayout,
    required this.wideScreenLayout,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveBreakpoint.tablet.width) {
          return wideScreenLayout;
        } else {
          return mobileLayout;
        }
      },
    );
  }
}
