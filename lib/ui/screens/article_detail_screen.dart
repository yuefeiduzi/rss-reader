import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../models/article.dart';
import '../../services/storage_service.dart';
import '../../services/theme_service.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;
  final StorageService storageService;
  final ThemeService themeService;

  const ArticleDetailScreen({
    super.key,
    required this.article,
    required this.storageService,
    required this.themeService,
  });

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool _isLoading = true;
  String _fullContent = '';

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);

    // 使用缓存的内容或摘要
    _fullContent = widget.article.content ?? widget.article.summary ?? '';

    if (_fullContent.isEmpty || _fullContent.length < 200) {
      // TODO: 实现全文抓取
      // final rssService = RssService();
      // _fullContent = await rssService.fetchFullContent(widget.article.link);
    }

    setState(() => _isLoading = false);
  }

  void _toggleFavorite() async {
    await widget.storageService.toggleFavorite(widget.article.id);
    // Note: UI will refresh when returning to list
  }

  void _openInBrowser() async {
    // TODO: 使用 url_launcher 打开链接
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Article'),
        actions: [
          IconButton(
            icon: Icon(
              widget.article.isFavorite ? Icons.favorite : Icons.favorite_border,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: 实现分享
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.article.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (widget.article.author != null)
                          Text(
                            widget.article.author!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        const Spacer(),
                        Text(
                          _formatDate(widget.article.pubDate),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Html(
                      data: _fullContent,
                      style: {
                        'body': Style(
                          fontSize: FontSize(16),
                          lineHeight: LineHeight(1.6),
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        'img': Style(
                          width: Width(MediaQuery.of(context).size.width - 32),
                        ),
                        'a': Style(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
