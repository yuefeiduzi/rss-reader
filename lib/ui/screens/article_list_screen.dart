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

  Future<void> _clearCacheAndRefresh() async {
    debugPrint('[动作] 清除缓存并刷新: ${widget.feed.title}');
    await widget.cacheService.clearAllCache();
    await _refreshArticles();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared and refreshing...')),
      );
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
        title: Text(widget.feed.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshArticles,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear_cache') {
                _clearCacheAndRefresh();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear_cache',
                child: Row(
                  children: const [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 8),
                    Text('Clear Cache & Refresh'),
                  ],
                ),
              ),
            ],
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
                      Positioned(
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

class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const ArticleCard({
    super.key,
    required this.article,
    required this.onTap,
    required this.onFavorite,
  });

  // 提取纯文本摘要（100字）
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
    return text.length > 100 ? text.substring(0, 100) + '...' : text;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  // 未读标记
                  if (!article.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  // 标签
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: article.isRead
                          ? Colors.grey.withValues(alpha: 0.3)
                          : Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      article.isRead ? '已读' : '未读',
                      style: TextStyle(
                        color: article.isRead
                            ? Colors.grey[700]
                            : Colors.blue[700],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 有头图时只显示头图
              if (article.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    article.imageUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              // 没有头图时显示文字简介
              else if (article.summary != null && article.summary!.isNotEmpty)
                Text(
                  _getSummaryText(article.summary),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '暂无预览',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ),
              // 有头图时在标题下显示简短摘要
              if (article.imageUrl != null &&
                  article.summary != null &&
                  article.summary!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _getSummaryText(article.summary),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      article.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: article.isFavorite
                          ? Colors.red
                          : Colors.grey[400],
                      size: 20,
                    ),
                    onPressed: onFavorite,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              if (article.author != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Text(
                        article.author!,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(article.pubDate),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.year}-${date.month}-${date.day}';
    }
  }
}
