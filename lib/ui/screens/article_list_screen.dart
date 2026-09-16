import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/article.dart';
import '../../models/feed.dart';
import '../../services/rss_service.dart';
import '../../services/storage_service.dart';
import '../components/article_card.dart';

/// 某个订阅源的文章列表。
///
/// 不自带 Scaffold / AppBar：标题栏由 [HomeScreen] 统一提供，否则窄屏下
/// 会出现上下两条标题栏。
///
/// 文章数据直接取自 [StorageService]，写入后由它通知重建，所以这里没有
/// 「标记已读 / 收藏之后再手工重新加载列表」的代码。
class ArticleListScreen extends StatefulWidget {
  final Feed feed;

  /// 选中某篇文章（由父级决定是替换右侧面板还是整页跳转）
  final ValueChanged<Article> onArticleSelected;

  const ArticleListScreen({
    super.key,
    required this.feed,
    required this.onArticleSelected,
  });

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  /// 是否有一次网络刷新正在进行。用于禁用按钮与显示进度条，
  /// 同时避免自动刷新与下拉刷新叠加成两次请求。
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // 打开某个订阅源时拉一次新内容。只在订阅源切换时触发一次
    // （父级用 feed.id 作 key），不会因为标记已读、收藏而重跑。
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    final store = context.read<StorageService>();
    final rss = context.read<RssService>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final articles = await rss.fetchArticles(widget.feed);
      await store.addArticles(articles);
      debugPrint('[成功] ${widget.feed.title}: 获取到 ${articles.length} 篇文章');
    } catch (e) {
      debugPrint('[错误] 刷新失败: $e');
      messenger.showSnackBar(SnackBar(content: Text('刷新失败: $e')));
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  /// 清掉本地缓存后重新拉取
  Future<void> _forceRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    final store = context.read<StorageService>();
    final rss = context.read<RssService>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await store.clearArticlesByFeed(widget.feed.id);
      final articles = await rss.fetchArticles(widget.feed);
      await store.addArticles(articles);
      messenger.showSnackBar(const SnackBar(content: Text('强制刷新完成')));
    } catch (e) {
      debugPrint('[错误] 强制刷新失败: $e');
      messenger.showSnackBar(SnackBar(content: Text('强制刷新失败: $e')));
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _open(Article article) {
    // 不必 await 落盘：状态已在内存生效，列表与未读数会自动更新
    context.read<StorageService>().markAsRead(article.id);
    widget.onArticleSelected(article);
  }

  @override
  Widget build(BuildContext context) {
    final articles = context.watch<StorageService>().articlesOf(widget.feed.id);

    return Column(
      children: [
        _ArticleListHeader(
          feed: widget.feed,
          isRefreshing: _isRefreshing,
          onRefresh: _refresh,
          onForceRefresh: _forceRefresh,
        ),
        if (_isRefreshing) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: articles.isEmpty
                ? const _NoArticles()
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: articles.length,
                    itemBuilder: (context, index) {
                      final article = articles[index];
                      return ArticleCard(
                        article: article,
                        onTap: () => _open(article),
                        onFavorite: () => context
                            .read<StorageService>()
                            .toggleFavorite(article.id),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _ArticleListHeader extends StatelessWidget {
  final Feed feed;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onForceRefresh;

  const _ArticleListHeader({
    required this.feed,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onForceRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = feed.description;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          if (description != null && description.isNotEmpty)
            Expanded(
              child: Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: isRefreshing ? null : onRefresh,
            tooltip: '刷新',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt, size: 20),
            onPressed: isRefreshing ? null : onForceRefresh,
            tooltip: '强制刷新（清空本地缓存后重新抓取）',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _NoArticles extends StatelessWidget {
  const _NoArticles();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 用 ListView 包裹，否则内容为空时 RefreshIndicator 无法下拉
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 96),
        Icon(
          Icons.article_outlined,
          size: 56,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(
          '还没有文章',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          '下拉或点右上角刷新',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}