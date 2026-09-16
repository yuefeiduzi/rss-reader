import 'package:flutter/material.dart';
import '../../models/feed.dart';
import 'feed_context_menu.dart';

class FeedListTile extends StatefulWidget {
  final Feed feed;
  final int unreadCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onTogglePin;
  final VoidCallback? onEdit;

  const FeedListTile({
    super.key,
    required this.feed,
    required this.unreadCount,
    required this.onTap,
    required this.onDelete,
    this.onTogglePin,
    this.onEdit,
  });

  @override
  State<FeedListTile> createState() => _FeedListTileState();
}

class _FeedListTileState extends State<FeedListTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  double _dragExtent = 0;
  bool _showActions = false;

  /// 弹出右键/长按菜单。删除的二次确认由 [FeedListPanel] 负责，
  /// 这里只把意图转达出去。
  void _openMenu([Offset? position]) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    FeedContextMenu.show(
      context,
      feed: widget.feed,
      renderBox: renderBox,
      onDelete: widget.onDelete,
      onTogglePin: widget.onTogglePin,
      onEdit: widget.onEdit,
      position: position,
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetPosition() {
    _controller.reverse().whenComplete(() {
      if (mounted) {
        setState(() {
          _showActions = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const maxDrag = 80.0;
    final effectiveOffset = _dragExtent.clamp(0.0, maxDrag);

    // 统一的菜单样式
    final menuTheme = PopupMenuTheme.of(context).copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: isDark
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.95)
          : theme.colorScheme.surface,
    );

    return PopupMenuTheme(
      data: menuTheme,
      child: Stack(
      children: [
        // 背景操作按钮区域
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final progress = _slideAnimation.value;
              return Row(
                children: [
                  const SizedBox(width: 60),
                  Expanded(
                    child: Transform.translate(
                      offset: Offset(60 * (1 - progress), 0),
                      child: Opacity(
                        opacity: progress,
                        child: Row(
                          children: [
                            _buildActionButton(
                              theme: theme,
                              icon: Icons.edit_outlined,
                              label: '重命名',
                              gradientColors: [
                                theme.colorScheme.tertiary
                                    .withValues(alpha: 0.7),
                                theme.colorScheme.tertiary
                                    .withValues(alpha: 0.9),
                              ],
                              onTap: () {
                                widget.onEdit?.call();
                                _resetPosition();
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildActionButton(
                              theme: theme,
                              icon: widget.feed.isPinned
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                              label: widget.feed.isPinned ? '取消置顶' : '置顶',
                              gradientColors: [
                                theme.colorScheme.secondary
                                    .withValues(alpha: 0.7),
                                theme.colorScheme.secondary
                                    .withValues(alpha: 0.9),
                              ],
                              onTap: () {
                                widget.onTogglePin?.call();
                                _resetPosition();
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildActionButton(
                              theme: theme,
                              icon: Icons.delete_outline,
                              label: '删除',
                              gradientColors: [
                                Colors.red[400]!.withValues(alpha: 0.7),
                                Colors.red[400]!.withValues(alpha: 0.9),
                              ],
                              onTap: widget.onDelete,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        // 主内容层
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragExtent += details.delta.dx;
              if (_dragExtent > maxDrag) _dragExtent = maxDrag;
              if (_dragExtent < 0) _dragExtent = 0;
            });
          },
          onHorizontalDragEnd: (details) {
            if (_dragExtent > maxDrag * 0.5) {
              _controller.forward().whenComplete(() {
                if (mounted) {
                  setState(() {
                    _showActions = true;
                  });
                }
              });
            } else {
              _resetPosition();
            }
            setState(() {
              _dragExtent = 0;
            });
          },
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse(),
          onTapCancel: () => _controller.reverse(),
          onTap: () {
            if (_showActions) {
              _resetPosition();
            } else {
              widget.onTap();
            }
          },
          onLongPress: () => _openMenu(),
          onSecondaryTapDown: (details) => _openMenu(details.globalPosition),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(effectiveOffset, 0),
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                    .withValues(alpha: isDark ? 1.0 : 0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isDark
                          ? theme.colorScheme.outline.withValues(alpha: 0.3)
                          : const Color(0xFFE8E4DE))
                      .withValues(alpha: isDark ? 0.5 : 1.0),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildAvatar(theme, isDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.feed.displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: widget.unreadCount > 0
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: theme.colorScheme.onSurface,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              if (widget.feed.isPinned)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.push_pin,
                                    size: 12,
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              if (widget.feed.customName != null &&
                                  widget.feed.customName!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.edit,
                                    size: 12,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.feed.description ?? widget.feed.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.unreadCount > 0) _buildUnreadBadge(theme),
                    // 菜单按钮
                    IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      tooltip: '更多操作',
                      onPressed: () => _openMenu(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildActionButton({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme, bool isDark) {
    final colors = [
      const Color(0xFF8B7355),
      const Color(0xFF6B7A6B),
      const Color(0xFF7A6B8B),
      const Color(0xFF6B8B8B),
      const Color(0xFF8B7A6B),
    ];

    final colorIndex = widget.feed.title.isNotEmpty
        ? widget.feed.title.codeUnitAt(0) % colors.length
        : 0;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors[colorIndex].withValues(alpha: isDark ? 0.8 : 1.0),
            colors[colorIndex].withValues(alpha: isDark ? 0.6 : 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors[colorIndex].withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          widget.feed.title.isNotEmpty
              ? widget.feed.title[0].toUpperCase()
              : '?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildUnreadBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.secondary,
            theme.colorScheme.secondary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.secondary.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        widget.unreadCount > 99 ? '99+' : widget.unreadCount.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
