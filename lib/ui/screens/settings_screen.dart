import 'package:flutter/material.dart';
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
      SnackBar(content: Text(message)),
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performRestore() async {
    // TODO: 实现文件选择和恢复
    _showBackupResult('Restore feature coming soon');
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('System'),
              trailing: widget.themeService.themeMode == ThemeMode.system
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                widget.themeService.setThemeMode(ThemeMode.system);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('Light'),
              trailing: widget.themeService.themeMode == ThemeMode.light
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                widget.themeService.setThemeMode(ThemeMode.light);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Dark'),
              trailing: widget.themeService.themeMode == ThemeMode.dark
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                widget.themeService.setThemeMode(ThemeMode.dark);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 外观
          const Text(
            'Appearance',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme'),
            subtitle: Text(
              widget.themeService.themeMode == ThemeMode.dark
                  ? 'Dark'
                  : widget.themeService.themeMode == ThemeMode.light
                      ? 'Light'
                      : 'System',
            ),
            onTap: _showThemeDialog,
          ),
          const Divider(),

          // 同步与备份
          const Text(
            'Sync & Backup',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Backup Now'),
            subtitle: const Text('Export feeds and articles to local file'),
            onTap: _isLoading ? null : _performBackup,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore'),
            subtitle: const Text('Import from backup file'),
            onTap: _performRestore,
          ),
          const Divider(),

          // 关于
          const Text(
            'About',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}
