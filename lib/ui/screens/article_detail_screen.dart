// ignore_for_file: use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
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
  bool _isRefreshing = false;
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
        await widget.cacheService
            .cacheArticleContent(widget.article.id, _fullContent);
        debugPrint('[成功] 全文抓取完成, 内容长度: ${_fullContent.length}');
      } catch (e) {
        debugPrint('[错误] 全文抓取失败: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _forceRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      debugPrint('[动作] 强制刷新文章全文: ${widget.article.link}');
      final rssService = RssService();
      final newContent = await rssService.fetchFullContent(widget.article.link);

      if (!mounted) return;

      // 刷新成功，更新内容并缓存
      setState(() {
        _fullContent = newContent;
      });
      await widget.cacheService
          .cacheArticleContent(widget.article.id, newContent);
      debugPrint('[成功] 强制刷新成功, 内容长度: ${newContent.length}');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('内容已更新')),
      );
    } catch (e) {
      debugPrint('[错误] 强制刷新失败: $e');
      if (!mounted) return;

      // 刷新失败，显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('内容已失效，无法获取新内容')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
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
      '${widget.article.title}\n\n${widget.article.link}\n\n分享自 RSS Reader',
      subject: widget.article.title,
    );
  }

  void _openLinkInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开链接')),
        );
      }
    }
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
              // 按钮区域
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.download, color: Colors.white),
                          onPressed: () => _downloadImage(context, url),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadImage(BuildContext context, String url) async {
    try {
      final fileName = url.substring(url.lastIndexOf('/') + 1).split('?')[0];
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '保存图片',
        fileName: fileName,
      );

      if (result == null) return;

      await Dio().download(url, result);

      if (!mounted) return;

      _showToast(
        context,
        '图片已保存到: $result',
        actionLabel: '分享',
        onAction: () async {
          await Share.shareXFiles([XFile(result)]);
        },
      );
    } catch (e) {
      if (!mounted) return;
      _showToast(context, '下载失败');
    }
  }

  void _showToast(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).padding.bottom + 80,
        left: 20,
        right: 20,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onAction,
                      child: Text(
                        actionLabel,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      floatingActionButton: _buildImageGalleryButton(context),
      appBar: AppBar(
        title: Text(_feed?.title ?? 'Article',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _forceRefresh,
          ),
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
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
                          theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.article.author != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          widget.article.author!,
                          style: theme
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                        ),
                      ),
                    Row(
                      children: [
                        Icon(
                          Icons.rss_feed,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(widget.article.pubDate),
                          style:
                              theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Icon(
                          Icons.edit,
                          size: 12,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(widget.article.cachedAt),
                          style: theme
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    ErrorBoundary(
                      content: _fullContent,
                      link: widget.article.link,
                      onOpenInBrowser: _openInBrowser,
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

  /// 提取 HTML 中的所有图片 URL
  List<String> _extractImageUrls(String html) {
    final urls = <String>[];
    // 匹配 img 标签的 src 属性
    final regex = RegExp('<img[^>]+src=[\'"]([^\'"]+)[\'"]', caseSensitive: false);
    final matches = regex.allMatches(html);
    for (final match in matches) {
      final url = match.group(1);
      if (url != null && url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  /// 显示图片画廊
  void _showImageGallery(BuildContext context, List<String> images, int initialIndex) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return ImageGallery(
          images: images,
          initialIndex: initialIndex,
          onDownload: (url) => _downloadImage(context, url),
          onOpenInBrowser: (url) => _openLinkInBrowser(url),
          onCopyUrl: (url) => _copyImageUrl(url),
          onShare: (url) => _shareImage(url),
        );
      },
    );
  }

  /// 复制图片链接
  void _copyImageUrl(String url) {
    Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('链接已复制到剪贴板')),
      );
    }
  }

  /// 分享图片链接
  Future<void> _shareImage(String url) async {
    await Share.share(url, subject: '分享图片');
  }

  /// 悬浮图片入口按钮 - 使用蓝色系
  Widget _buildImageGalleryButton(BuildContext context) {
    final images = _extractImageUrls(_fullContent);
    if (images.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 8),
      child: FloatingActionButton.extended(
        onPressed: () => _showImageGallery(context, images, 0),
        icon: const Icon(Icons.image),
        label: const Text('看大图'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
      ),
    );
  }

  /// 从 HTML 内容中提取所有图片 URL
  List<String> _extractImageUrlsFromContent(String html) {
    final urls = <String>[];
    final regex = RegExp('<img[^>]+src=[\']([^\'"]+)[\']', caseSensitive: false);
    final matches = regex.allMatches(html);
    for (final match in matches) {
      final url = match.group(1);
      if (url != null && url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  /// 显示图片上下文菜单
  void _showImageContextMenu(BuildContext context) {
    final images = _extractImageUrlsFromContent(_fullContent);
    if (images.isEmpty) return;

    final theme = Theme.of(context);

    // 显示底部操作菜单
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Text(
                  '图片操作 (${images.length} 张)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: Text('查看图片'),
                subtitle: Text('浏览所有图片'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openImageGalleryFromContext(context, images, 0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: Text('下载第一张图片'),
                subtitle: Text(images.first),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _downloadImage(context, images.first);
                },
              ),
              if (images.length > 1)
                ListTile(
                  leading: const Icon(Icons.download_for_offline),
                  title: Text('下载所有图片'),
                  subtitle: Text('共 ${images.length} 张'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _downloadAllImages(context, images);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.link),
                title: Text('复制第一张图片链接'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Clipboard.setData(ClipboardData(text: images.first));
                  _showToast(context, '链接已复制到剪贴板');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// 从上下文菜单打开图片画廊
  void _openImageGalleryFromContext(BuildContext context, List<String> images, int initialIndex) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return ImageGallery(
          images: images,
          initialIndex: initialIndex,
          onDownload: (url) => _downloadImage(context, url),
          onOpenInBrowser: (url) => _openLinkInBrowser(url),
          onCopyUrl: (url) {
            Clipboard.setData(ClipboardData(text: url));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('链接已复制到剪贴板')),
              );
            }
          },
          onShare: (url) => Share.share(url, subject: '分享图片'),
        );
      },
    );
  }

  /// 下载所有图片
  void _downloadAllImages(BuildContext context, List<String> images) {
    for (final url in images) {
      _downloadImage(context, url);
    }
  }
}

/// 图片画廊组件
class ImageGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final void Function(String url) onDownload;
  final void Function(String url) onOpenInBrowser;
  final void Function(String url) onCopyUrl;
  final void Function(String url) onShare;

  const ImageGallery({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.onDownload,
    required this.onOpenInBrowser,
    required this.onCopyUrl,
    required this.onShare,
  });

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _previousImage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextImage() {
    if (_currentIndex < widget.images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 构建图片项
  Widget _buildImageItem(String url) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Center(child: CircularProgressIndicator(
            value: progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                : null,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ));
        },
        errorBuilder: (c, e, s) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white, size: 64),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // PageView 显示大图（支持右键菜单）
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              final url = widget.images[index];
              return _buildImageItem(url);
            },
          ),
          // 顶部索引指示器
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.images.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 左侧切换按钮
          if (widget.images.length > 1)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                      onPressed: _previousImage,
                    ),
                  ),
                ),
              ),
            ),
          // 右侧切换按钮
          if (widget.images.length > 1)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                      onPressed: _nextImage,
                    ),
                  ),
                ),
              ),
            ),
          // 底部操作栏
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.download, color: Colors.white),
                      onPressed: () => widget.onDownload(widget.images[_currentIndex]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// HTML 转纯文本
String _stripHtml(String html) {
  return html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}

/// 错误边界组件：捕获 flutter_html 渲染错误，降级到纯文本
class ErrorBoundary extends StatefulWidget {
  final String content;
  final String link;
  final VoidCallback onOpenInBrowser;

  const ErrorBoundary({
    super.key,
    required this.content,
    required this.link,
    required this.onOpenInBrowser,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_hasError) {
      // 降级 UI：纯文本 + 提示 + 浏览器打开
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 错误提示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '内容渲染异常，已显示纯文本版本',
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 纯文本内容（支持选择复制）
          SelectionArea(
            child: Text(
              _stripHtml(widget.content),
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 在浏览器中打开按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onOpenInBrowser,
              icon: const Icon(Icons.open_in_browser),
              label: const Text('在浏览器中打开原文'),
            ),
          ),
        ],
      );
    }

    // 正常渲染
    return SelectionArea(
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: GestureDetector(
          // 禁用双击放大，避免与文本选择冲突
          behavior: HitTestBehavior.translucent,
          child: SizedBox(
            width: double.infinity,
            child: Html(
              data: widget.content,
              style: {
                'body': Style(
                  fontSize: FontSize(16.0),
                  lineHeight: LineHeight(1.6),
                  padding: HtmlPaddings.zero,
                  margin: Margins.zero,
                ),
                'p': Style(margin: Margins.only(bottom: 8)),
                'a': Style(
                  color: theme.colorScheme.primary,
                  textDecoration: TextDecoration.underline,
                ),
                'img': Style(),
                'blockquote': Style(
                  margin: Margins.symmetric(horizontal: 16, vertical: 8),
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                'pre': Style(
                  margin: Margins.symmetric(vertical: 8),
                  padding: HtmlPaddings.all(12),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  fontFamily: 'monospace',
                  fontSize: FontSize(13.0),
                  color: theme.colorScheme.onSurfaceVariant,
                  whiteSpace: WhiteSpace.pre,
                ),
                'code': Style(
                  fontFamily: 'monospace',
                  fontSize: FontSize(13.0),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
                ),
                'h1': Style(
                  fontSize: FontSize(24.0),
                  fontWeight: FontWeight.bold,
                  margin: Margins.only(top: 16, bottom: 8),
                ),
                'h2': Style(
                  fontSize: FontSize(20.0),
                  fontWeight: FontWeight.bold,
                  margin: Margins.only(top: 14, bottom: 6),
                ),
                'h3': Style(
                  fontSize: FontSize(18.0),
                  fontWeight: FontWeight.bold,
                  margin: Margins.only(top: 12, bottom: 6),
                ),
                'ul': Style(margin: Margins.only(left: 16, bottom: 8)),
                'ol': Style(margin: Margins.only(left: 16, bottom: 8)),
                'li': Style(margin: Margins.only(bottom: 4)),
              },
              onLinkTap: (url, attributes, element) {
                if (url != null) {
                  final uri = Uri.parse(url);
                  canLaunchUrl(uri).then((can) {
                    if (can) {
                      // ignore: flutter_style_tips
                      Future.value(launchUrl(uri, mode: LaunchMode.externalApplication));
                    }
                  });
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
