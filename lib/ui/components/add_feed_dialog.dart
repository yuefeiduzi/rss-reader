import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/rss_service.dart';

class AddFeedDialog extends StatefulWidget {
  final Function(String url, String? customName) onAdd;
  final List<String> existingUrls;

  const AddFeedDialog({
    super.key,
    required this.onAdd,
    this.existingUrls = const [],
  });

  @override
  State<AddFeedDialog> createState() => _AddFeedDialogState();
}

class _AddFeedDialogState extends State<AddFeedDialog> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _fetchedTitle;

  bool get _isDuplicate {
    final url = _urlController.text.trim();
    if (url.isEmpty) return false;
    final normalizedUrl = url.toLowerCase();
    return widget.existingUrls.any(
      (existing) => existing.toLowerCase() == normalizedUrl,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _validateAndAdd() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = '请输入订阅源地址');
      return;
    }

    // 验证 URL 格式
    try {
      final uri = Uri.parse(url);
      if (!uri.isAbsolute) {
        setState(() => _error = '请输入有效的 URL 地址');
        return;
      }
      // 自动补全 http:// 前缀
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        _urlController.text = 'https://$url';
      }
    } catch (e) {
      setState(() => _error = 'URL 格式无效');
      return;
    }

    // 检查是否已存在
    if (_isDuplicate) {
      setState(() => _error = '该订阅源已添加');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 先获取 feed 信息以获取标题
      final rssService = RssService();
      final feed = await rssService.fetchFeed(_urlController.text.trim());

      // 设置默认名称为 feed 标题
      if (_nameController.text.isEmpty) {
        _nameController.text = feed.title;
      }

      final finalUrl = _urlController.text.trim();
      final customName = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : null;

      await widget.onAdd(finalUrl, customName);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = '添加订阅源失败: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _previewFeed() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final rssService = RssService();
      final feed = await rssService.fetchFeed(url);
      setState(() {
        _fetchedTitle = feed.title;
        _nameController.text = feed.title;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = '无法获取订阅源信息';
        _fetchedTitle = null;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData != null && clipboardData.text != null) {
        _urlController.text = clipboardData.text!;
        setState(() => _error = null);
        // 自动预览
        await _previewFeed();
      }
    } catch (e) {
      debugPrint('Clipboard access failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.rss_feed,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          const Text('添加订阅源'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 名称输入框（可留空，默认使用源标题）
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '自定义名称（可选）',
                hintText: _fetchedTitle ?? '留空则使用订阅源标题',
                prefixIcon: const Icon(Icons.edit),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              enabled: !_isLoading,
              onSubmitted: (_) => _validateAndAdd(),
            ),
            const SizedBox(height: 16),
            // URL 输入框
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: '订阅源地址',
                hintText: 'https://example.com/feed.xml',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_urlController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _urlController.clear();
                          _nameController.clear();
                          _fetchedTitle = null;
                          setState(() => _error = null);
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.paste),
                      tooltip: '从剪贴板粘贴',
                      onPressed: _isLoading ? null : _pasteFromClipboard,
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: '预览订阅源',
                      onPressed: _isLoading ? null : _previewFeed,
                    ),
                  ],
                ),
                filled: _error != null,
                fillColor: _error != null
                    ? Theme.of(context)
                        .colorScheme
                        .errorContainer
                        .withValues(alpha: 0.3)
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
              autofocus: true,
              enabled: !_isLoading,
              onSubmitted: (_) => _validateAndAdd(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
                // URL 变化时清除已获取的标题
                if (_fetchedTitle != null) {
                  setState(() {
                    _fetchedTitle = null;
                  });
                }
              },
            ),
            // 错误提示
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _isLoading ? null : _validateAndAdd,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add),
          label: const Text('添加'),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
