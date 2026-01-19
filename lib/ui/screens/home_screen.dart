import 'package:flutter/material.dart';
import '../components/add_feed_dialog.dart';
import '../components/feed_list_tile.dart';
import '../components/responsive_layout.dart';
import '../../models/feed.dart';
import '../../models/article.dart';
import '../../services/cache_service.dart';
import '../../services/rss_service.dart';
import '../../services/storage_service.dart';
import '../../services/theme_service.dart';
import 'article_list_screen.dart';
import 'article_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;
  final ThemeService themeService;
  final CacheService cacheService;

  const HomeScreen({
    super.key,
    required this.storageService,
    required this.themeService,
    required this.cacheService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Feed> _feeds = [];
  Map<String, int> _unreadCounts = {};
  bool _isLoading = true;
  Feed? _selectedFeed;
  Article? _selectedArticle;

  @override
  void initState() {
    super.initState();
    _loadFeeds();
  }

  Future<void> _loadFeeds() async {
    final feeds = await widget.storageService.getAllFeeds();
    // 置顶的订阅源排在前面
    feeds.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.addedAt.compareTo(a.addedAt);
    });
    // 计算每个订阅源的未读文章数量
    final unreadCounts = <String, int>{};
    for (final feed in feeds) {
      final articles = await widget.storageService.getArticlesByFeed(feed.id);
      unreadCounts[feed.id] = articles.where((a) => !a.isRead).length;
    }
    if (mounted) {
      setState(() {
        _feeds = feeds;
        _unreadCounts = unreadCounts;
        _isLoading = false;
      });
    }
    debugPrint('[动作] 加载订阅源列表: ${feeds.length} 个订阅源');
  }

  Future<void> _addFeed(String url) async {
    debugPrint('[动作] 添加订阅源: $url');
    try {
      final rssService = RssService();
      final feed = await rssService.fetchFeed(url);
      await widget.storageService.addFeed(feed);
      await _loadFeeds();
      debugPrint('[成功] 添加订阅源成功: ${feed.title}');
    } catch (e) {
      debugPrint('[错误] 添加订阅源失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add feed: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _deleteFeed(Feed feed) async {
    debugPrint('[动作] 删除订阅源: ${feed.title}');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除订阅源'),
        content: Text('确定要删除 "${feed.title}" 吗？'),
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
    );
    if (confirm == true) {
      await widget.storageService.deleteFeed(feed.id);
      await _loadFeeds();
      debugPrint('[成功] 删除订阅源成功: ${feed.title}');
      if (_selectedFeed?.id == feed.id) {
        setState(() {
          _selectedFeed = null;
          _selectedArticle = null;
        });
      }
    }
  }

  void _togglePinFeed(Feed feed) async {
    debugPrint('[动作] ${feed.isPinned ? '取消置顶' : '置顶'}: ${feed.title}');
    final updatedFeed = feed.copyWith(isPinned: !feed.isPinned);
    await widget.storageService.updateFeed(updatedFeed);
    await _loadFeeds();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(feed.isPinned ? '已取消置顶 "${feed.title}"' : '已置顶 "${feed.title}"'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _onFeedSelected(Feed feed) {
    debugPrint('[动作] 点击订阅源: ${feed.title}');
    setState(() {
      _selectedFeed = feed;
      _selectedArticle = null;
    });
  }

  void _onArticleSelected(Article article) {
    debugPrint('[动作] 点击文章: ${article.title}');
    setState(() {
      _selectedArticle = article;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFeed = null;
      _selectedArticle = null;
    });
  }

  /// 刷新未读文章计数
  Future<void> _refreshUnreadCounts() async {
    final unreadCounts = <String, int>{};
    for (final feed in _feeds) {
      final articles = await widget.storageService.getArticlesByFeed(feed.id);
      unreadCounts[feed.id] = articles.where((a) => !a.isRead).length;
    }
    if (mounted) {
      setState(() {
        _unreadCounts = unreadCounts;
      });
    }
    debugPrint('[动作] 刷新未读计数完成');
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          storageService: widget.storageService,
          themeService: widget.themeService,
        ),
      ),
    );
  }

  Widget _buildThemeIcon() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    IconData icon;
    if (isDark) {
      icon = Icons.dark_mode;
    } else if (widget.themeService.themeMode == ThemeMode.light) {
      icon = Icons.light_mode;
    } else {
      icon = Icons.brightness_6;
    }
    return Icon(icon);
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobileLayout: _buildMobileLayout(),
      wideScreenLayout: _buildWideScreenLayout(),
    );
  }

  /// 窄屏单页布局（移动端）
  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedFeed?.title ?? 'RSS Reader',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        leading: _selectedFeed != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _clearSelection,
              )
            : null,
        actions: [
          IconButton(
            icon: _buildThemeIcon(),
            onPressed: () => widget.themeService.toggleDarkMode(),
            tooltip: 'Toggle theme',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      body: _buildMobileBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
          context: context,
          builder: (ctx) => AddFeedDialog(onAdd: _addFeed),
        ),
        icon: const Icon(Icons.add),
        label: const Text('添加订阅源'),
      ),
    );
  }

  Widget _buildMobileBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '加载中...',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // 如果选中了文章，显示文章详情
    if (_selectedArticle != null) {
      return ArticleDetailScreen(
        article: _selectedArticle!,
        storageService: widget.storageService,
        themeService: widget.themeService,
        cacheService: widget.cacheService,
      );
    }

    // 如果选中了订阅源，显示文章列表
    if (_selectedFeed != null) {
      return ArticleListScreen(
        key: ValueKey(_selectedFeed!.id),
        feed: _selectedFeed!,
        storageService: widget.storageService,
        themeService: widget.themeService,
        cacheService: widget.cacheService,
        onArticleSelected: _onArticleSelected,
        onArticleRead: _refreshUnreadCounts,
      );
    }

    // 否则显示订阅源列表
    if (_feeds.isEmpty) {
      return _buildEmptyState();
    }

    return _buildFeedList();
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.secondary.withValues(alpha: 0.8),
                    theme.colorScheme.secondary.withValues(alpha: 0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.rss_feed,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '暂无订阅源',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '添加你的第一个 RSS 订阅源，开始阅读',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AddFeedDialog(onAdd: _addFeed),
              ),
              icon: const Icon(Icons.add),
              label: const Text('添加订阅源'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 88),
      itemCount: _feeds.length,
      itemBuilder: (context, index) {
        final feed = _feeds[index];
        return FeedListTile(
          feed: feed,
          unreadCount: _unreadCounts[feed.id] ?? 0,
          onTap: () => _onFeedSelected(feed),
          onDelete: () => _deleteFeed(feed),
          onTogglePin: () => _togglePinFeed(feed),
        );
      },
    );
  }

  /// 宽屏分栏布局（macOS/Windows/Web）
  Widget _buildWideScreenLayout() {
    final screenWidth = MediaQuery.of(context).size.width;
    // 左侧面板宽度：根据屏幕宽度动态调整
    final leftPanelWidth = screenWidth > 1400 ? 320 : (screenWidth > 1200 ? 280 : 260);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RSS Reader',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: _buildThemeIcon(),
            onPressed: () => widget.themeService.toggleDarkMode(),
            tooltip: 'Toggle theme',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      body: Row(
        children: [
          // 左侧：订阅源列表
          SizedBox(
            width: leftPanelWidth.toDouble(),
            child: _buildFeedListPanel(),
          ),
          Container(
            width: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
          // 右侧：文章列表或文章内容
          Expanded(
            child: _selectedArticle != null
                ? ArticleDetailScreen(
                    article: _selectedArticle!,
                    storageService: widget.storageService,
                    themeService: widget.themeService,
                    cacheService: widget.cacheService,
                  )
                : _selectedFeed != null
                    ? ArticleListScreen(
                        key: ValueKey(_selectedFeed!.id),
                        feed: _selectedFeed!,
                        storageService: widget.storageService,
                        themeService: widget.themeService,
                        cacheService: widget.cacheService,
                        onArticleSelected: _onArticleSelected,
                        onArticleRead: _refreshUnreadCounts,
                      )
                    : _buildWideScreenEmptyState(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showDialog(
          context: context,
          builder: (ctx) => AddFeedDialog(onAdd: _addFeed),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Feed'),
      ),
    );
  }

  Widget _buildWideScreenEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.secondary.withValues(alpha: 0.6),
                  theme.colorScheme.secondary.withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.article,
              size: 40,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Select a subscription to view articles',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedListPanel() {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_feeds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.secondary.withValues(alpha: 0.6),
                    theme.colorScheme.secondary.withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.rss_feed,
                size: 32,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无订阅源',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AddFeedDialog(onAdd: _addFeed),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加订阅源'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
              Text(
                '订阅源',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.secondary,
                      theme.colorScheme.secondary.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_feeds.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            itemCount: _feeds.length,
            itemBuilder: (context, index) {
              final feed = _feeds[index];
              return FeedListTile(
                feed: feed,
                unreadCount: _unreadCounts[feed.id] ?? 0,
                onTap: () => _onFeedSelected(feed),
                onDelete: () => _deleteFeed(feed),
                onTogglePin: () => _togglePinFeed(feed),
              );
            },
          ),
        ),
      ],
    );
  }
}
