import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/storage_service.dart';
import '../../services/theme_service.dart';
import '../../services/backup_service.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storageService;
  final ThemeService themeService;

  const SettingsScreen({
    super.key,
    required this.storageService,
    required this.themeService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BackupService _backupService;
  bool _isLoading = false;

  _SettingsScreenState() : _backupService = BackupService(StorageService());

  void _showBackupResult(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _performBackup() async {
    setState(() => _isLoading = true);
    try {
      final path = await _backupService.backupToFile();
      _showBackupResult('Backup saved to: $path');
    } catch (e) {
      _showBackupResult('Backup failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _performRestore() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowedExtensions: ['json'],
        type: FileType.custom,
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);
        await _backupService.restoreFromJson(result.files.single.path!);
        _showBackupResult('Restore successful! Please restart the app.');
      }
    } catch (e) {
      _showBackupResult('Restore failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
              context,
              'System',
              Icons.brightness_auto,
              ThemeMode.system,
            ),
            _buildThemeOption(
              context,
              'Light',
              Icons.light_mode,
              ThemeMode.light,
            ),
            _buildThemeOption(
              context,
              'Dark',
              Icons.dark_mode,
              ThemeMode.dark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String title,
    IconData icon,
    ThemeMode mode,
  ) {
    final isSelected = widget.themeService.themeMode == mode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.themeService.setThemeMode(mode);
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isSelected
                        ? [
                            Theme.of(context).colorScheme.secondary,
                            Theme.of(context)
                                .colorScheme
                                .secondary
                                .withValues(alpha: 0.8),
                          ]
                        : [
                            Theme.of(context).colorScheme.surfaceVariant,
                            Theme.of(context).colorScheme.surfaceVariant,
                          ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // 外观 Section
            _buildSectionHeader(theme, 'Appearance'),
            _buildSectionCard(theme, [
              _buildSettingItem(
                theme,
                icon: Icons.brightness_6,
                iconColor: const Color(0xFF8B7355),
                title: 'Theme',
                subtitle: widget.themeService.themeMode == ThemeMode.dark
                    ? 'Dark'
                    : widget.themeService.themeMode == ThemeMode.light
                        ? 'Light'
                        : 'System',
                onTap: _showThemeDialog,
              ),
            ]),
            const SizedBox(height: 24),

            // 同步与备份 Section
            _buildSectionHeader(theme, 'Sync & Backup'),
            _buildSectionCard(theme, [
              _buildSettingItem(
                theme,
                icon: Icons.backup,
                iconColor: const Color(0xFF6B7A6B),
                title: 'Backup Now',
                subtitle: 'Export feeds and articles to local file',
                onTap: _isLoading ? null : _performBackup,
                isLoading: _isLoading,
              ),
              const Divider(height: 1, indent: 60),
              _buildSettingItem(
                theme,
                icon: Icons.restore,
                iconColor: const Color(0xFF7A6B8B),
                title: 'Restore',
                subtitle: 'Import from backup file',
                onTap: _performRestore,
              ),
            ]),
            const SizedBox(height: 24),

            // 关于 Section
            _buildSectionHeader(theme, 'About'),
            _buildSectionCard(theme, [
              _buildSettingItem(
                theme,
                icon: Icons.info_outline,
                iconColor: const Color(0xFF8C8C8C),
                title: 'Version',
                subtitle: '1.0.0',
                onTap: null,
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.secondary,
          letterSpacing: 0.5,
          textBaseline: TextBaseline.alphabetic,
        ),
      ),
    );
  }

  Widget _buildSectionCard(ThemeData theme, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingItem(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      iconColor.withValues(alpha: 0.8),
                      iconColor.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.secondary,
                  ),
                )
              else if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.outline,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
