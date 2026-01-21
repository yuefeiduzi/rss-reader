import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/article.dart';
import '../../models/feed.dart';
import '../../services/cache_service.dart';
import '../../services/rss_service.dart';
import '../../services/storage_service.dart';
import '../../services/theme_service.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;
  final StorageService storageService;
  final ThemeService themeService;
  final CacheService cacheService;

  const ArticleDetailScreen({
    super.key,
    required this.article,
    required this.storageService,
    required this.themeService,
    required this.cacheService,
  });

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool _isLoading = true;
  String _fullContent = '';
  Feed? _feed;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.article.isFavorite;
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

    debugPrint('[加载缓存] 加载文章内容: ${widget.article.title}');

    if (_fullContent.isEmpty || _fullContent.length < 200) {
      try {
        debugPrint('[动作] 抓取文章全文: ${widget.article.link}');
        final rssService = RssService();
        _fullContent = await rssService.fetchFullContent(widget.article.link);
        // 缓存文章内容
        await widget.cacheService.cacheArticleContent(widget.article.id, _fullContent);
        debugPrint('[成功] 全文抓取完成, 内容长度: ${_fullContent.length}');
      } catch (e) {
        debugPrint('[错误] 全文抓取失败: $e');
      }
    }

    setState(() => _isLoading = false);
  }

  void _toggleFavorite() async {
    await widget.storageService.toggleFavorite(widget.article.id);
    setState(() {
      _isFavorite = !_isFavorite;
    });
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

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        leading: isWideScreen ? null : const BackButton(),
        title: Text(_feed?.title ?? 'Article',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite
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
                    // 作者信息
                    if (widget.article.author != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          widget.article.author!,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                    // 发布时间和拉取时间
                    Row(
                      children: [
                        Icon(
                          Icons.rss_feed,
                          size: 14,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(widget.article.pubDate),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Icon(
                          Icons.edit,
                          size: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(widget.article.cachedAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _HtmlContent(
                      html: _fullContent,
                      onImageTap: (url) => _showImagePreview(context, url),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// 自定义 HTML 内容组件，支持图片显示
class _HtmlContent extends StatelessWidget {
  final String html;
  final void Function(String url) onImageTap;

  const _HtmlContent({required this.html, required this.onImageTap});

  @override
  Widget build(BuildContext context) {
    // 解析 HTML 文档
    final document = html_parser.parse(html);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: _buildContent(context, document.body!),
    );
  }

  Widget _buildContent(BuildContext context, dom.Element node) {
    final widgets = <Widget>[];
    for (final child in node.nodes) {
      final widget = _buildNode(context, child);
      if (widget != null) {
        widgets.add(widget);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget? _buildNode(BuildContext context, dom.Node node) {
    final theme = Theme.of(context);
    if (node.nodeType == dom.Node.TEXT_NODE) {
      final text = (node as dom.Text).data.trim();
      if (text.isEmpty) return null;
      return Text(text);
    }

    if (node is! dom.Element) return null;

    final tag = node.localName?.toLowerCase() ?? '';

    switch (tag) {
      case 'p':
        final widgets = <Widget>[];
        for (final child in node.nodes) {
          final widget = _buildNode(context, child);
          if (widget != null) widgets.add(widget);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widgets,
          ),
        );

      case 'img':
        final src = node.attributes['src'] ?? node.attributes['data-src'] ?? '';
        if (src.isEmpty) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => onImageTap(src),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Image.network(
              src,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stack) => const Icon(Icons.broken_image),
            ),
          ),
        );

      case 'a':
        final href = node.attributes['href'] ?? '';
        final text = _extractText(node);

        if (href.startsWith('http') && text.isNotEmpty) {
          return GestureDetector(
            onTap: () => onImageTap(href),
            child: Text(
              text,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          );
        }
        return Text(text);

      case 'br':
        return const SizedBox(height: 8);

      case 'strong':
      case 'b':
        final text = _extractText(node);
        return Text(text, style: const TextStyle(fontWeight: FontWeight.bold));

      case 'em':
      case 'i':
        final text = _extractText(node);
        return Text(text, style: const TextStyle(fontStyle: FontStyle.italic));

      case 'blockquote':
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            _extractText(node),
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );

      case 'h1':
        final text = _extractText(node);
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(text, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        );

      case 'h2':
        final text = _extractText(node);
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        );

      case 'h3':
        final text = _extractText(node);
        return Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        );

      case 'ul':
        final widgets = <Widget>[];
        for (final child in node.nodes) {
          final widget = _buildNode(context, child);
          if (widget != null) widgets.add(widget);
        }
        return Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widgets,
          ),
        );

      case 'li':
        final text = _extractText(node);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• '),
              Expanded(child: Text(text)),
            ],
          ),
        );

      case 'code':
        final text = _extractText(node);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );

      case 'pre':
        final text = _extractText(node);
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        );

      default:
        final widgets = <Widget>[];
        for (final child in node.nodes) {
          final widget = _buildNode(context, child);
          if (widget != null) widgets.add(widget);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: widgets,
        );
    }
  }

  String _extractText(dom.Node node) {
    if (node.nodeType == dom.Node.TEXT_NODE) {
      return (node as dom.Text).data;
    }
    if (node is dom.Element) {
      return node.nodes.map((child) => _extractText(child)).join('');
    }
    return '';
  }
}
