import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/backup_restore/services/backup_restore_service.dart';
import 'package:familee_dental/features/backup_restore/services/automatic_backup_service.dart';
import 'package:familee_dental/features/activity_log/controller/settings_activity_controller.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  final BackupRestoreService _service = BackupRestoreService();
  final SettingsActivityController _settingsActivityController =
      SettingsActivityController();

  bool _isBackingUp = false;
  bool _isRestoring = false;
  int _progressCount = 0;
  int _totalCount = 0;
  List<BackupFileMeta> _backups = [];
  String? _error;
  bool _isAutoBackupEnabled = false;
  DateTime? _lastBackupDate;

  @override
  void initState() {
    super.initState();
    _loadBackups();
    _loadAutoBackupSettings();
  }

  Future<void> _loadAutoBackupSettings() async {
    // Check if backup is needed first
    await AutomaticBackupService.checkAndCreateBackupIfNeeded();

    final isEnabled = await AutomaticBackupService.isAutoBackupEnabled();
    final lastDate = await AutomaticBackupService.getLastBackupDate();
    if (mounted) {
      setState(() {
        _isAutoBackupEnabled = isEnabled;
        _lastBackupDate = lastDate;
      });
    }
  }

  Future<void> _loadBackups() async {
    if (mounted) {
      setState(() {
        _error = null;
      });
    }
    try {
      final files = await _service.listBackups();
      if (mounted) {
        setState(() {
          _backups = files;
        });
      }
    } catch (e) {
      // Hide raw error for no_changes; only show snackbar above
      if (!(e is StateError && e.message == 'no_changes')) {
        if (mounted) {
          setState(() {
            _error = e.toString();
          });
        }
      }
    }
  }

  Future<void> _backupNow() async {
    if (mounted) {
      setState(() {
        _isBackingUp = true;
        _progressCount = 0;
        _totalCount = 0; // unknown until done
        _error = null;
      });
    }
    try {
      final res = await _service.createBackup(onProgress: (processed) {
        if (mounted) {
          setState(() {
            _progressCount = processed;
          });
        }
      });
      if (!mounted) return;

      // Log backup created activity
      final backupFileName =
          res.storagePath.split('/').last; // Extract filename
      await _settingsActivityController.logBackupCreated(
        backupFileName: backupFileName,
        backupTime: DateTime.now(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup saved: ${res.storagePath} (${res.totalItems} items)',
          ),
        ),
      );
      await _loadBackups();
    } catch (e) {
      if (!mounted) return;
      if (e is StateError && e.message == 'no_changes') {
        final theme = Theme.of(context);
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Backup not needed',
              style: AppFonts.sfProStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                'No changes since last backup.',
                style: AppFonts.sfProStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
        if (mounted) {
          setState(() {
            _error = e.toString();
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  Future<void> _restoreFrom(BackupFileMeta meta) async {
    if (mounted) {
      setState(() {
        _isRestoring = true;
        _progressCount = 0;
        _totalCount = 0;
        _error = null;
      });
    }
    try {
      final result = await _service.restoreFromBackup(
        storagePath: meta.fullPath,
        onProgress: (processed, total) {
          if (mounted) {
            setState(() {
              _progressCount = processed;
              _totalCount = total;
            });
          }
        },
      );
      if (!mounted) return;

      // Log backup restored activity
      final backupFileName = meta.fullPath.split('/').last; // Extract filename
      await _settingsActivityController.logBackupRestored(
        backupFileName: backupFileName,
        backupTime:
            meta.timestampUtc ?? DateTime.now(), // Use original backup time
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore complete: ${result.totalItems} items')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isBackingUp || _isRestoring;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Backup & Restore',
          style: AppFonts.sfProStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
        elevation: Theme.of(context).appBarTheme.elevation,
        shadowColor: Theme.of(context).appBarTheme.shadowColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isBusy ? null : _confirmBackup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4AA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: const Icon(Icons.cloud_upload),
                    label: Text(
                      'Backup Now',
                      style: AppFonts.sfProStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (!_isRestoring && _backups.isNotEmpty)
                        ? _confirmRestoreLatest
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBusy || _backups.isEmpty
                          ? Colors.grey[400]
                          : const Color(0xFF00D4AA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    icon: const Icon(Icons.cloud_download),
                    label: Text(
                      'Restore Latest',
                      style: AppFonts.sfProStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isBusy) ...[
              LinearProgressIndicator(
                value: _totalCount > 0 ? _progressCount / _totalCount : null,
              ),
              const SizedBox(height: 8),
              Text(
                _totalCount > 0
                    ? '$_progressCount / $_totalCount'
                    : 'Processed: $_progressCount',
              ),
              const SizedBox(height: 16),
            ],
            if (_error != null && !_error!.contains('no_changes')) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],
            // Automatic Backup Settings
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: const Color(0xFF00D4AA),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Automatic Daily Backup',
                        style: AppFonts.sfProStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _isAutoBackupEnabled,
                        onChanged: _toggleAutoBackup,
                        activeColor: const Color(0xFF00D4AA),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Automatically creates a backup at 11:59 PM daily',
                    style: AppFonts.sfProStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  if (_isAutoBackupEnabled && _lastBackupDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Last automatic backup: ${_formatDate(_lastBackupDate!)}',
                      style: AppFonts.sfProStyle(
                        fontSize: 12,
                        color: const Color(0xFF00D4AA),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Available Backups',
              style: AppFonts.sfProStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadBackups,
                child: _backups.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: const [
                          SizedBox(height: 32),
                          Center(child: Text('No backups yet')),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: _backups.length,
                        itemBuilder: (context, index) {
                          final meta = _backups[index];
                          final ts = meta.timestampUtc?.toLocal().toString() ??
                              'Unknown time';
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: Slidable(
                              key: ValueKey(meta.fullPath),
                              endActionPane: ActionPane(
                                motion: const ScrollMotion(),
                                children: [
                                  SlidableAction(
                                    onPressed: (_) => _confirmDelete(meta),
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete_outline,
                                    label: 'Delete',
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            meta.name,
                                            softWrap: true,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(ts,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        minimumSize: const Size(0, 36),
                                      ),
                                      onPressed: _isRestoring
                                          ? null
                                          : () => _confirmRestore(meta),
                                      child: const Text('Restore'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BackupFileMeta meta) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Delete backup',
            style: AppFonts.sfProStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          content: Text(
            'Are you sure you want to delete ${meta.name}?',
            style: AppFonts.sfProStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _service.deleteBackup(storagePath: meta.fullPath);
        if (!mounted) return;

        // Log backup deleted activity
        final backupFileName =
            meta.fullPath.split('/').last; // Extract filename
        await _settingsActivityController.logBackupDeleted(
          backupFileName: backupFileName,
          backupTime:
              meta.timestampUtc ?? DateTime.now(), // Use original backup time
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup deleted')),
        );
        await _loadBackups();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmBackup() async {
    if (!mounted) return;
    final theme = Theme.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Create backup',
            style: AppFonts.sfProStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          content: Text(
            'Are you sure you want to create a new backup now?',
            style: AppFonts.sfProStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Backup'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _backupNow();
    }
  }

  Future<void> _confirmRestoreLatest() async {
    if (!mounted || _backups.isEmpty) return;
    await _confirmRestore(_backups.first);
  }

  Future<void> _confirmRestore(BackupFileMeta meta) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Restore backup',
            style: AppFonts.sfProStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          content: Text(
            'Are you sure you want to restore ${meta.name}? This will overwrite existing data.',
            style: AppFonts.sfProStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _restoreFrom(meta);
    }
  }

  Future<void> _toggleAutoBackup(bool enabled) async {
    try {
      if (enabled) {
        await AutomaticBackupService.enableAutoBackup();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Automatic daily backup enabled'),
              backgroundColor: Color(0xFF00D4AA),
            ),
          );
        }
      } else {
        await AutomaticBackupService.disableAutoBackup();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Automatic daily backup disabled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      await _loadAutoBackupSettings();
    } catch (e) {
      // Only show error for enable operation, not disable
      if (enabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error enabling auto backup: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // For disable operation, just update the UI state
      await _loadAutoBackupSettings();
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (dateOnly == yesterday) {
      return 'Yesterday at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.month}/${date.day}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
