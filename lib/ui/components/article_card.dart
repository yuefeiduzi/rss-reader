import 'package:flutter/material.dart';

import '../../models/article.dart';
import '../../utils/date_format.dart';

/// 文章列表里的单张卡片。
///
/// 从 `article_list_screen.dart` 拆出来：它只依赖 [Article] 与两个回调，
/// 与页面级的刷新/选中逻辑无关，可单独复用与测试。
class ArticleCard extends StatefulWidget {
  final Article article;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const ArticleCard({
    super.key,
    required this.article,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  State<ArticleCard> createState() => _ArticleCardState();
}

class _ArticleCardState extends State<ArticleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
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

  // 提取纯文本摘要（120字）
  String _getSummaryText(String? html) {
    if (html == null) return '';
    final text = html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.length > 120 ? '${text.substring(0, 120)}...' : text;
  }

  // 统一走 utils/date_format.dart，避免和 article_detail_screen 各维护一份
  String _formatRelativeDate(DateTime date) => formatRelativeDate(date);

  String _formatDateTime(DateTime date) => formatDateTime(date);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : Colors.grey[200]!)
                      .withValues(alpha: isDark ? 0.3 : 0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头图
                if (widget.article.imageUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        Image.network(
                          widget.article.imageUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox.shrink();
                          },
                        ),
                        // 未读标记
                        if (!widget.article.isRead)
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    theme.colorScheme.secondary,
                                    theme.colorScheme.secondary
                                        .withValues(alpha: 0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                '未读',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                // 无头图时的内容区域
                if (widget.article.imageUrl == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        if (!widget.article.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.secondary,
                                  theme.colorScheme.secondary
                                      .withValues(alpha: 0.7),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (!widget.article.isRead)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.secondary,
                                  theme.colorScheme.secondary
                                      .withValues(alpha: 0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '未读',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                // 内容区域
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.article.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: widget.article.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                                height: 1.4,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: widget.onFavorite,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                widget.article.isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                key: ValueKey(widget.article.isFavorite),
                                color: widget.article.isFavorite
                                    ? const Color(0xFFE57373)
                                    : theme.colorScheme.outline,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // 摘要
                      if (widget.article.summary != null &&
                          widget.article.summary!.isNotEmpty)
                        Text(
                          _getSummaryText(widget.article.summary),
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                          maxLines: widget.article.imageUrl != null ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 12),
                      // 作者、发布时间、拉取时间
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 第一行：作者
                          Row(
                            children: [
                              if (widget.article.author != null)
                                Text(
                                  widget.article.author!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.tertiary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // 第二行：发布时间 + 拉取时间
                          Row(
                            children: [
                              Icon(
                                Icons.rss_feed,
                                size: 12,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatRelativeDate(widget.article.pubDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.outline,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Icon(
                                Icons.edit,
                                size: 11,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDateTime(widget.article.cachedAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
