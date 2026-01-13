import 'package:flutter/material.dart';
import '../components/add_feed_dialog.dart';
import '../components/feed_list_tile.dart';
import '../components/responsive_layout.dart';
import '../../models/feed.dart';
import '../../models/article.dart';
import '../../services/rss_service.dart';
import '../../services/storage_service.dart';
import '../../services/theme_service.dart';
import 'article_list_screen.dart';
import 'article_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;
  final ThemeService themeService;

  const HomeScreen({
    super.key,
    required this.storageService,
    required this.themeService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Feed> _feeds = [];
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
    setState(() {
      _feeds = feeds;
      _isLoading = false;
    });
  }

  Future<void> _addFeed(String url) async {
    try {
      final rssService = RssService();
      final feed = await rssService.fetchFeed(url);
      await widget.storageService.addFeed(feed);
      await _loadFeeds();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add feed: $e')),
        );
      }
    }
  }

  void _deleteFeed(Feed feed) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subscription'),
        content: Text('Are you sure you want to delete "${feed.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.storageService.deleteFeed(feed.id);
      await _loadFeeds();
      if (_selectedFeed?.id == feed.id) {
        setState(() {
          _selectedFeed = null;
          _selectedArticle = null;
        });
      }
    }
  }

  void _onFeedSelected(Feed feed) {
    setState(() {
      _selectedFeed = feed;
      _selectedArticle = null;
    });
  }

  void _onArticleSelected(Article article) {
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
        title: Text(_selectedFeed?.title ?? 'RSS Reader'),
        leading: _selectedFeed != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _clearSelection,
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(
              widget.themeService.themeMode == ThemeMode.dark
                  ? Icons.dark_mode
                  : widget.themeService.themeMode == ThemeMode.light
                      ? Icons.light_mode
                      : Icons.brightness_6,
            ),
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
        label: const Text('Add Feed'),
      ),
    );
  }

  Widget _buildMobileBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 如果选中了文章，显示文章详情
    if (_selectedArticle != null) {
      return ArticleDetailScreen(
        article: _selectedArticle!,
        storageService: widget.storageService,
        themeService: widget.themeService,
      );
    }

    // 如果选中了订阅源，显示文章列表
    if (_selectedFeed != null) {
      return ArticleListScreen(
        feed: _selectedFeed!,
        storageService: widget.storageService,
        themeService: widget.themeService,
        onArticleSelected: _onArticleSelected,
      );
    }

    // 否则显示订阅源列表
    if (_feeds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rss_feed, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No subscriptions yet'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AddFeedDialog(onAdd: _addFeed),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Feed'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _feeds.length,
      itemBuilder: (context, index) {
        final feed = _feeds[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: FeedListTile(
            feed: feed,
            onTap: () => _onFeedSelected(feed),
            onDelete: () => _deleteFeed(feed),
          ),
        );
      },
    );
  }

  /// 宽屏分栏布局（macOS/Windows/Web）
  Widget _buildWideScreenLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RSS Reader'),
        actions: [
          IconButton(
            icon: Icon(
              widget.themeService.themeMode == ThemeMode.dark
                  ? Icons.dark_mode
                  : widget.themeService.themeMode == ThemeMode.light
                      ? Icons.light_mode
                      : Icons.brightness_6,
            ),
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
          // 左侧：订阅源列表 (1/3)
          SizedBox(
            width: 300,
            child: _buildFeedListPanel(),
          ),
          const VerticalDivider(width: 1),
          // 右侧：文章列表或文章内容 (2/3)
          Expanded(
            child: _selectedArticle != null
                ? ArticleDetailScreen(
                    article: _selectedArticle!,
                    storageService: widget.storageService,
                    themeService: widget.themeService,
                  )
                : _selectedFeed != null
                    ? ArticleListScreen(
                        feed: _selectedFeed!,
                        storageService: widget.storageService,
                        themeService: widget.themeService,
                        onArticleSelected: _onArticleSelected,
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.article,
                              size: 64,
                              color: Colors.grey.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Select a subscription to view articles',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildFeedListPanel() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_feeds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rss_feed, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No subscriptions yet'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (ctx) => AddFeedDialog(onAdd: _addFeed),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Feed'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          ),
          child: Row(
            children: [
              Text(
                'Subscriptions',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Text(
                '${_feeds.length}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _feeds.length,
            itemBuilder: (context, index) {
              final feed = _feeds[index];
              final isSelected = _selectedFeed?.id == feed.id;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: FeedListTile(
                  feed: feed,
                  onTap: () => _onFeedSelected(feed),
                  onDelete: () => _deleteFeed(feed),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
