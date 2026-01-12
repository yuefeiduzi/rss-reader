import 'package:flutter/material.dart';
import '../../models/feed.dart';
import '../../models/article.dart';
import '../../services/storage_service.dart';
import '../../services/theme_service.dart';
import 'article_detail_screen.dart';

class ArticleListScreen extends StatefulWidget {
  final Feed feed;
  final StorageService storageService;
  final ThemeService themeService;

  const ArticleListScreen({
    super.key,
    required this.feed,
    required this.storageService,
    required this.themeService,
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
      // 先加载本地缓存
      final local = await widget.storageService.getArticlesByFeed(widget.feed.id);
      if (local.isNotEmpty) {
        setState(() {
          _articles = local;
          _isLoading = false;
        });
      }
      // 然后刷新获取新文章
      await _refreshArticles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshArticles() async {
    setState(() => _isRefreshing = true);
    try {
      // TODO: 实现 RSS 抓取
      // final rssService = RssService();
      // final newArticles = await rssService.fetchArticles(widget.feed);
      // await widget.storageService.addArticles(newArticles);
      // await _loadArticles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _navigateToDetail(Article article) async {
    await widget.storageService.markAsRead(article.id);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleDetailScreen(
          article: article,
          storageService: widget.storageService,
          themeService: widget.themeService,
        ),
      ),
    ).then((_) {
      _loadArticles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.feed.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshArticles,
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
              : RefreshIndicator(
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
                          await widget.storageService.toggleFavorite(article.id);
                          _loadArticles();
                        },
                      );
                    },
                  ),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      article.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: article.isRead
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      article.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: article.isFavorite
                          ? Theme.of(context).colorScheme.primary
                          : null,
                      size: 20,
                    ),
                    onPressed: onFavorite,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              if (article.author != null || article.pubDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      if (article.author != null)
                        Text(
                          article.author!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      const Spacer(),
                      Text(
                        _formatDate(article.pubDate),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              if (article.summary != null && article.summary!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    article.summary!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}
