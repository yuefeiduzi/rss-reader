import 'package:flutter/material.dart';
import '../components/add_feed_dialog.dart';
import '../components/feed_list_tile.dart';
import '../../models/feed.dart';
import '../../services/rss_service.dart';
import '../../services/storage_service.dart';
import '../../services/theme_service.dart';
import 'article_list_screen.dart';
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
    await widget.storageService.deleteFeed(feed.id);
    await _loadFeeds();
  }

  void _navigateToArticles(Feed feed) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleListScreen(
          feed: feed,
          storageService: widget.storageService,
          themeService: widget.themeService,
        ),
      ),
    ).then((_) => _loadFeeds());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RSS Reader'),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => widget.themeService.toggleDarkMode(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    storageService: widget.storageService,
                    themeService: widget.themeService,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _feeds.isEmpty
              ? Center(
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
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _feeds.length,
                  itemBuilder: (context, index) {
                    final feed = _feeds[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: FeedListTile(
                        feed: feed,
                        onTap: () => _navigateToArticles(feed),
                        onDelete: () => _deleteFeed(feed),
                      ),
                    );
                  },
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
}
