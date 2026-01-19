import 'package:flutter/material.dart';
import '../../models/feed.dart';

class FeedListTile extends StatefulWidget {
  final Feed feed;
  final int unreadCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onTogglePin;

  const FeedListTile({
    super.key,
    required this.feed,
    required this.unreadCount,
    required this.onTap,
    required this.onDelete,
    this.onTogglePin,
  });

  @override
  State<FeedListTile> createState() => _FeedListTileState();
}

class _FeedListTileState extends State<FeedListTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  double _dragExtent = 0;
  bool _showDeleteConfirm = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
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

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Icon(
                  widget.feed.isPinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                title: Text(widget.feed.isPinned ? '取消置顶' : '置顶'),
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onTogglePin?.call();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red[400]),
                title: Text('删除', style: TextStyle(color: Colors.red[400])),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmDelete();
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除订阅源'),
        content: Text('确定要删除 "${widget.feed.title}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red[400],
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    ).then((confirm) {
      if (confirm == true) {
        widget.onDelete();
      }
    });
  }

  void _resetPosition() {
    _controller.reverse().whenComplete(() {
      if (mounted) {
        setState(() {
          _showDeleteConfirm = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 计算主内容偏移量
    final maxDrag = 80.0;
    final effectiveOffset = _dragExtent.clamp(-maxDrag, maxDrag);
    final contentOffset = effectiveOffset;

    return Stack(
      children: [
        // 背景按钮层
        Positioned.fill(
          child: Row(
            children: [
              // 右滑 - 置顶按钮
              Expanded(
                child: GestureDetector(
                  onTap: _showDeleteConfirm ? null : _handlePin,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          theme.colorScheme.secondary.withValues(alpha: 0.9),
                          theme.colorScheme.secondary.withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      widget.feed.isPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // 左滑 - 删除按钮
              Expanded(
                child: GestureDetector(
                  onTap: _showDeleteConfirm ? _confirmDelete : null,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.red[400]!.withValues(alpha: 0.7),
                          Colors.red[400]!.withValues(alpha: 0.9),
                        ],
                      ),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(16),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 主内容层
        GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _dragExtent += details.delta.dx;
              if (_dragExtent > maxDrag) _dragExtent = maxDrag;
              if (_dragExtent < -maxDrag) _dragExtent = -maxDrag;
            });
          },
          onHorizontalDragEnd: (details) {
            if (_dragExtent > maxDrag * 0.5) {
              // 右滑超过阈值，置顶
              _controller.forward().whenComplete(() {
                _handlePin();
              });
            } else if (_dragExtent < -maxDrag * 0.5) {
              // 左滑超过阈值，显示删除按钮
              _controller.forward().whenComplete(() {
                if (mounted) {
                  setState(() {
                    _showDeleteConfirm = true;
                  });
                }
              });
            } else {
              // 没有超过阈值，复位
              _resetPosition();
            }
            setState(() {
              _dragExtent = 0;
            });
          },
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse(),
          onTapCancel: () => _controller.reverse(),
          onLongPress: () => _showActions(context),
          onTap: () {
            if (_showDeleteConfirm) {
              _resetPosition();
            } else {
              widget.onTap();
            }
          },
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(contentOffset, 0),
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
                                  widget.feed.title,
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
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Icon(
                                    Icons.push_pin,
                                    size: 14,
                                    color: theme.colorScheme.secondary,
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
                    const SizedBox(width: 12),
                    if (widget.unreadCount > 0) _buildUnreadBadge(theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handlePin() {
    widget.onTogglePin?.call();
    _resetPosition();
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
          style: TextStyle(
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
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
