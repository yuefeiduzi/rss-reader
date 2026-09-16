import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/feed.dart';

/// 订阅源的右键 / 长按菜单。
///
/// 从 `feed_list_tile.dart` 拆出来（原本约 180 行）：菜单项构造、样式、
/// 选中后的分发与「复制链接」，都与 tile 的手势/动画无关，放在一起
/// 只会让 tile 变成什么都管的巨石。
///
/// **删除的二次确认不在这里**：那是 [FeedListPanel] 的职责，菜单只负责
/// 把「用户要删除」这件事喊出去。早先 tile 自己也弹一次确认框，
/// 和面板的确认框重复。
class FeedContextMenu {
  const FeedContextMenu._();

  /// 在 [renderBox] 附近弹出菜单。
  ///
  /// [position] 为长按/右键位置；为空时贴着 tile 居中显示。
  static Future<void> show(
    BuildContext context, {
    required Feed feed,
    required RenderBox renderBox,
    required VoidCallback onDelete,
    VoidCallback? onTogglePin,
    VoidCallback? onEdit,
    Offset? position,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final origin = position ?? renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final selected = await showMenu<_MenuItem>(
      context: context,
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy + size.height / 2,
        origin.dx + size.width,
        origin.dy + size.height / 2,
      ),
      items: _buildItems(context, feed),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.95)
          : theme.colorScheme.surface,
    );

    switch (selected) {
      case _MenuItem.togglePin:
        onTogglePin?.call();
      case _MenuItem.rename:
        onEdit?.call();
      case _MenuItem.copyLink:
        await _copyLink(context, feed.url);
      case _MenuItem.delete:
        onDelete();
      case null:
        break;
    }
  }

  static List<PopupMenuEntry<_MenuItem>> _buildItems(
      BuildContext context, Feed feed) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    PopupMenuItem<_MenuItem> item({
      required _MenuItem value,
      required IconData icon,
      required Color iconColor,
      required String label,
      bool isDestructive = false,
    }) {
      return PopupMenuItem<_MenuItem>(
        value: value,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isDestructive
                ? theme.colorScheme.errorContainer
                    .withValues(alpha: isDark ? 0.15 : 0.1)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? theme.colorScheme.error
                          .withValues(alpha: isDark ? 0.2 : 0.1)
                      : iconColor.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isDestructive ? theme.colorScheme.error : iconColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isDestructive ? FontWeight.w500 : FontWeight.w400,
                    color: isDestructive
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return [
      item(
        value: _MenuItem.togglePin,
        icon: feed.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        iconColor: theme.colorScheme.primary,
        label: feed.isPinned ? '取消置顶' : '置顶',
      ),
      item(
        value: _MenuItem.rename,
        icon: Icons.edit_outlined,
        iconColor: theme.colorScheme.onSurfaceVariant,
        label: '重命名',
      ),
      item(
        value: _MenuItem.copyLink,
        icon: Icons.link,
        iconColor: theme.colorScheme.onSurfaceVariant,
        label: '复制链接',
      ),
      const PopupMenuDivider(height: 1, indent: 16, endIndent: 16),
      item(
        value: _MenuItem.delete,
        icon: Icons.delete_outline,
        iconColor: theme.colorScheme.error,
        label: '删除',
        isDestructive: true,
      ),
    ];
  }

  /// 复制订阅源地址。
  ///
  /// 首次可能拿不到剪贴板（某些平台在菜单刚关闭时不可用），故重试一次。
  static Future<void> _copyLink(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await Future.delayed(Duration(milliseconds: attempt == 0 ? 50 : 100));
        await Clipboard.setData(ClipboardData(text: url));
        messenger.showSnackBar(
          const SnackBar(
            content: Text('已复制链接到剪贴板'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      } catch (e) {
        debugPrint('复制链接失败（第 ${attempt + 1} 次）: $e');
      }
    }
  }
}

enum _MenuItem { togglePin, rename, copyLink, delete }