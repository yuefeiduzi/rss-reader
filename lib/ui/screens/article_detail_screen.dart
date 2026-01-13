import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/article.dart';
import '../../models/feed.dart';
import '../../services/rss_service.dart';
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
  Feed? _feed;

  @override
  void initState() {
    super.initState();
    _loadContent();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    final feed = await widget.storageService.getFeed(widget.article.feedId);
    if (mounted) {
      setState(() => _feed = feed);
    }
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);

    // 使用缓存的内容或摘要
    _fullContent = widget.article.content ?? widget.article.summary ?? '';

    if (_fullContent.isEmpty || _fullContent.length < 200) {
      try {
        final rssService = RssService();
        _fullContent = await rssService.fetchFullContent(widget.article.link);
      } catch (e) {
        debugPrint('Failed to fetch full content: $e');
      }
    }

    setState(() => _isLoading = false);
  }

  void _toggleFavorite() async {
    await widget.storageService.toggleFavorite(widget.article.id);
    // Note: UI will refresh when returning to list
  }

  void _openInBrowser() async {
    final uri = Uri.parse(widget.article.link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  void _shareArticle() async {
    await Share.share(
      '${widget.article.title}\n\n${widget.article.link}',
      subject: widget.article.title,
    );
  }

  void _showImagePreview(BuildContext context, String url) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (BuildContext dialogContext, Animation animation,
          Animation secondaryAnimation) {
        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // 点击关闭
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(dialogContext).pop(),
                ),
              ),
              // 关闭按钮
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
              // 图片预览
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(32),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          child,
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              valueColor:
                                  const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                        ],
                      );
                    },
                    errorBuilder: (context, error, stack) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image,
                              color: Colors.white, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.white70,
                                    ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              // 操作提示
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Pinch to zoom • Drag to pan',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 处理 HTML 内容，为图片添加点击事件
  String _processHtmlWithImageClick(String html) {
    // 只添加点击链接，不修改 img 标签
    return html.replaceAllMapped(RegExp(r'<img([^>]*?)src="([^"]+)"([^>]*?)>'),
        (match) {
      final url = match.group(2) ?? '';
      final attrs = '${match.group(1) ?? ''}${match.group(3) ?? ''}';
      return '<a href="$url" class="image-link"><img$attrs></a>';
    }).replaceAllMapped(RegExp(r"<img([^>]*?)src='([^']+)'([^>]*?)>"), (match) {
      final url = match.group(2) ?? '';
      final attrs = '${match.group(1) ?? ''}${match.group(3) ?? ''}';
      return "<a href=\"$url\" class=\"image-link\"><img$attrs></a>";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_feed?.title ?? 'Article',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(
              widget.article.isFavorite
                  ? Icons.favorite
                  : Icons.favorite_border,
            ),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: _openInBrowser,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareArticle,
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
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (widget.article.author != null)
                          Text(
                            widget.article.author!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        const Spacer(),
                        Text(
                          _formatDate(widget.article.pubDate),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: Html(
                        data: _processHtmlWithImageClick(_fullContent),
                        style: {
                          'body': Style(
                            fontSize: FontSize(16),
                            lineHeight: LineHeight(1.6),
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          'p': Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                          ),
                          'a': Style(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          'img': Style(
                            width: null,
                            height: null,
                          ),
                        },
                        onAnchorTap: (url, _, __) {
                          if (url != null) {
                            _showImagePreview(context, url);
                          }
                        },
                      ),
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
