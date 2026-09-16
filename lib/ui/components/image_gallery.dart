import 'package:flutter/material.dart';

/// 全屏图片画廊：左右切换、缩放平移、下载/复制/分享。
///
/// 从 `article_detail_screen.dart` 拆出来（原本约 200 行）：它只依赖一个
/// 图片 URL 列表和几个回调，与文章页的加载逻辑无关。
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
