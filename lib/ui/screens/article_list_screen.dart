import 'package:flutter/material.dart';
import '../../models/feed.dart';
import '../../models/article.dart';
import '../../services/cache_service.dart';
import '../../services/rss_service.dart';
import '../../services/storage_service.dart';
import '../../services/theme_service.dart';
import 'article_detail_screen.dart';

class ArticleListScreen extends StatefulWidget {
  final Feed feed;
  final StorageService storageService;
  final ThemeService themeService;
  final CacheService cacheService;
  final void Function(Article article)? onArticleSelected;
  final VoidCallback? onArticleRead; // 阅读文章后刷新未读计数

  const ArticleListScreen({
    super.key,
    required this.feed,
    required this.storageService,
    required this.themeService,
    required this.cacheService,
    this.onArticleSelected,
    this.onArticleRead,
  });

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  List<Article> _articles = [];
  bool _isLoading = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('[加载缓存] 加载订阅源文章: ${widget.feed.title}');
      final local =
          await widget.storageService.getArticlesByFeed(widget.feed.id);
      // 按发布时间倒序排序
      local.sort((a, b) => b.pubDate.compareTo(a.pubDate));
      if (mounted) {
        setState(() {
          _articles = local;
          _isLoading = false;
        });
      }
      // 加载完缓存后自动刷新
      await _refreshArticles();
    } catch (e) {
      debugPrint('[错误] 加载文章失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshArticles() async {
    setState(() => _isRefreshing = true);
    try {
      debugPrint('[动作] 刷新订阅源: ${widget.feed.title}');
      final rssService = RssService();
      final newArticles = await rssService.fetchArticles(widget.feed);
      debugPrint('[成功] 获取到 ${newArticles.length} 篇文章');
      await widget.storageService.addArticles(newArticles);
      // 重新加载本地数据
      final local =
          await widget.storageService.getArticlesByFeed(widget.feed.id);
      // 按发布时间倒序排序
      local.sort((a, b) => b.pubDate.compareTo(a.pubDate));
      if (mounted) {
        setState(() {
          _articles = local;
        });
      }
    } catch (e) {
      debugPrint('[错误] 刷新文章失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _forceRefresh() async {
    setState(() => _isRefreshing = true);
    try {
      debugPrint('[动作] 强制刷新订阅源: ${widget.feed.title}');
      // 清除该订阅源的缓存文章
      await widget.storageService.clearArticlesByFeed(widget.feed.id);
      // 重新拉取
      final rssService = RssService();
      final newArticles = await rssService.fetchArticles(widget.feed);
      debugPrint('[成功] 获取到 ${newArticles.length} 篇文章');
      await widget.storageService.addArticles(newArticles);
      // 重新加载本地数据
      final local =
          await widget.storageService.getArticlesByFeed(widget.feed.id);
      // 按发布时间倒序排序
      local.sort((a, b) => b.pubDate.compareTo(a.pubDate));
      if (mounted) {
        setState(() {
          _articles = local;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('强制刷新完成')),
        );
      }
    } catch (e) {
      debugPrint('[错误] 强制刷新失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('强制刷新失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _navigateToDetail(Article article) async {
    debugPrint('[动作] 打开文章: ${article.title}');
    await widget.storageService.markAsRead(article.id);
    // 通知首页刷新未读计数
    widget.onArticleRead?.call();
    if (!mounted) return;

    // 如果有回调函数（宽屏模式），调用回调而不是导航
    if (widget.onArticleSelected != null) {
      widget.onArticleSelected!(article);
      _loadArticles();
      return;
    }

    // 否则导航到详情页（窄屏模式）
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleDetailScreen(
          article: article,
          storageService: widget.storageService,
          themeService: widget.themeService,
          cacheService: widget.cacheService,
        ),
      ),
    ).then((_) {
      _loadArticles();
      // 返回后也刷新未读计数
      widget.onArticleRead?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.feed.displayTitle,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (widget.feed.description != null &&
                widget.feed.description!.isNotEmpty)
              Text(
                widget.feed.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
          ],
        ),
        actions: [
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshArticles,
            tooltip: '刷新',
          ),
          // 强制刷新按钮
          IconButton(
            icon: const Icon(Icons.restart_alt),
            onPressed: _isRefreshing ? null : _forceRefresh,
            tooltip: '强制刷新',
          ),
        ],
      ),
      body: _isLoading && _articles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _articles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.article, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No articles yet'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _refreshArticles,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: _refreshArticles,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _articles.length,
                        itemBuilder: (context, index) {
                          final article = _articles[index];
                          return ArticleCard(
                            article: article,
                            onTap: () => _navigateToDetail(article),
                            onFavorite: () async {
                              await widget.storageService
                                  .toggleFavorite(article.id);
                              _loadArticles();
                            },
                          );
                        },
                      ),
                    ),
                    // 刷新时的顶部进度指示
                    if (_isRefreshing)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          minHeight: 2,
                        ),
                      ),
                  ],
                ),
    );
  }
}

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

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

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
