import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/backup_restore/services/backup_restore_service.dart';
import 'package:familee_dental/features/backup_restore/services/automatic_backup_service.dart';
import 'package:familee_dental/features/activity_log/controller/settings_activity_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/storage/hive_storage.dart';
import 'package:familee_dental/shared/services/connectivity_service.dart';
import 'package:familee_dental/shared/widgets/connection_error_dialog.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shimmer/shimmer.dart';

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
  bool _isFirstLoad = true;
  bool _isLoadingAutoBackupSettings = true;
  bool _hasBackupsLoaded = false;

  // In-memory cache for backup list and settings
  List<BackupFileMeta>? _cachedBackups;
  bool? _cachedAutoBackupEnabled;
  DateTime? _cachedLastBackupDate;

  @override
  void initState() {
    super.initState();
    _loadBackups();
    _loadAutoBackupSettings();
  }

  Future<void> _loadAutoBackupSettings() async {
    try {
      // 1. First, try to load from Hive cache (for offline support)
      if (_cachedAutoBackupEnabled == null) {
        await _loadAutoBackupSettingsFromHive();
      }

      // 2. If cached data found, use it immediately
      if (_cachedAutoBackupEnabled != null) {
        if (mounted) {
          setState(() {
            _isAutoBackupEnabled = _cachedAutoBackupEnabled!;
            _lastBackupDate = _cachedLastBackupDate;
            _isLoadingAutoBackupSettings = false;
            // Only show content when both backups AND settings are loaded
            if (_hasBackupsLoaded) {
              _isFirstLoad = false;
            }
          });
        }
      }

      // 3. Try to fetch fresh data from Supabase (if online)
      try {
        // Check if backup is needed first
        await AutomaticBackupService.checkAndCreateBackupIfNeeded();

        final isEnabled = await AutomaticBackupService.isAutoBackupEnabled();
        final lastDate = await AutomaticBackupService.getLastBackupDate();

        // Save to cache
        await _saveAutoBackupSettingsToHive(isEnabled, lastDate);
        _cachedAutoBackupEnabled = isEnabled;
        _cachedLastBackupDate = lastDate;

        if (mounted) {
          setState(() {
            _isAutoBackupEnabled = isEnabled;
            _lastBackupDate = lastDate;
            _isLoadingAutoBackupSettings = false;
            // Only show content when both backups AND settings are loaded
            if (_hasBackupsLoaded) {
              _isFirstLoad = false;
            }
          });
        }
      } catch (e) {
        // If Supabase fetch fails (e.g., offline), use cached data
        debugPrint('Error fetching auto-backup settings from Supabase: $e');
        // Cached data is already loaded above, so we're good
        if (_cachedAutoBackupEnabled == null && mounted) {
          // No cache available, set defaults
          setState(() {
            _isAutoBackupEnabled = false;
            _lastBackupDate = null;
            _isLoadingAutoBackupSettings = false;
            if (_hasBackupsLoaded) {
              _isFirstLoad = false;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading auto-backup settings: $e');
      if (mounted) {
        setState(() {
          _isLoadingAutoBackupSettings = false;
          if (_hasBackupsLoaded) {
            _isFirstLoad = false;
          }
        });
      }
    }
  }

  Future<void> _loadBackups() async {
    if (mounted) {
      setState(() {
        _error = null;
      });
    }
    try {
      // 1. First, try to load from Hive cache (for offline support)
      if (_cachedBackups == null) {
        await _loadBackupsFromHive();
      }

      // 2. If cached data found, use it immediately
      if (_cachedBackups != null) {
        if (mounted) {
          setState(() {
            _backups = _cachedBackups!;
            _hasBackupsLoaded = true;
            // Only mark as loaded when both backups AND settings are loaded
            if (!_isLoadingAutoBackupSettings) {
              _isFirstLoad = false;
            }
          });
        }
      }

      // 3. Try to fetch fresh data from Supabase (if online)
      try {
        final files = await _service.listBackups();

        // Save to cache
        await _saveBackupsToHive(files);
        _cachedBackups = files;

        if (mounted) {
          setState(() {
            _backups = files;
            _hasBackupsLoaded = true;
            // Only mark as loaded when both backups AND settings are loaded
            if (!_isLoadingAutoBackupSettings) {
              _isFirstLoad = false;
            }
          });
        }
      } catch (e) {
        // If Supabase fetch fails (e.g., offline), use cached data
        debugPrint('Error fetching backups from Supabase: $e');
        // Hide raw error for no_changes; only show snackbar above
        if (!(e is StateError && e.message == 'no_changes')) {
          if (mounted) {
            setState(() {
              if (_cachedBackups == null) {
                _error = e.toString();
              }
              _hasBackupsLoaded = true;
              // Only mark as loaded when both backups AND settings are loaded
              if (!_isLoadingAutoBackupSettings) {
                _isFirstLoad = false;
              }
            });
          }
        } else {
          // Handle no_changes case
          if (mounted) {
            setState(() {
              _hasBackupsLoaded = true;
              if (!_isLoadingAutoBackupSettings) {
                _isFirstLoad = false;
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading backups: $e');
      if (mounted) {
        setState(() {
          _hasBackupsLoaded = true;
          if (!_isLoadingAutoBackupSettings) {
            _isFirstLoad = false;
          }
        });
      }
    }
  }

  /// Load backup list from Hive cache
  Future<void> _loadBackupsFromHive() async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.backupRestoreBox);
      final backupsStr = box.get('backups') as String?;

      if (backupsStr != null) {
        final jsonList = jsonDecode(backupsStr) as List<dynamic>;
        _cachedBackups = jsonList.map((e) {
          final map = e as Map<String, dynamic>;
          return BackupFileMeta(
            name: map['name'] ?? '',
            fullPath: map['fullPath'] ?? '',
            timestampUtc: map['timestampUtc'] != null
                ? DateTime.tryParse(map['timestampUtc'] as String)
                : null,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Error loading backups from Hive: $e');
    }
  }

  /// Save backup list to Hive cache
  Future<void> _saveBackupsToHive(List<BackupFileMeta> backups) async {
    try {
      _cachedBackups = backups;
      final box = await HiveStorage.openBox(HiveStorage.backupRestoreBox);
      final jsonList = backups
          .map((backup) => {
                'name': backup.name,
                'fullPath': backup.fullPath,
                'timestampUtc': backup.timestampUtc?.toIso8601String(),
              })
          .toList();
      await box.put('backups', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving backups to Hive: $e');
    }
  }

  /// Load auto-backup settings from Hive cache
  Future<void> _loadAutoBackupSettingsFromHive() async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.backupRestoreBox);
      final settingsStr = box.get('autoBackupSettings') as String?;

      if (settingsStr != null) {
        final settings = jsonDecode(settingsStr) as Map<String, dynamic>;
        _cachedAutoBackupEnabled = settings['enabled'] as bool? ?? false;
        _cachedLastBackupDate = settings['lastBackupDate'] != null
            ? DateTime.tryParse(settings['lastBackupDate'] as String)
            : null;
      }
    } catch (e) {
      debugPrint('Error loading auto-backup settings from Hive: $e');
    }
  }

  /// Save auto-backup settings to Hive cache
  Future<void> _saveAutoBackupSettingsToHive(
      bool enabled, DateTime? lastBackupDate) async {
    try {
      _cachedAutoBackupEnabled = enabled;
      _cachedLastBackupDate = lastBackupDate;
      final box = await HiveStorage.openBox(HiveStorage.backupRestoreBox);
      final settings = {
        'enabled': enabled,
        'lastBackupDate': lastBackupDate?.toIso8601String(),
      };
      await box.put('autoBackupSettings', jsonEncode(settings));
    } catch (e) {
      debugPrint('Error saving auto-backup settings to Hive: $e');
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
        // Check if it's a network error
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('socketexception') ||
            errorString.contains('failed host lookup') ||
            errorString.contains('no address associated') ||
            errorString.contains('network is unreachable') ||
            errorString.contains('connection refused') ||
            errorString.contains('connection timed out') ||
            errorString.contains('clientexception') ||
            errorString.contains('connection abort') ||
            errorString.contains('software caused connection abort')) {
          if (mounted) {
            await showConnectionErrorDialog(context);
          }
        } else {
          // Other error - show generic error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Backup failed: $e')),
          );
          if (mounted) {
            setState(() {
              _error = e.toString();
            });
          }
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

      // Check if it's a network error
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('socketexception') ||
          errorString.contains('failed host lookup') ||
          errorString.contains('no address associated') ||
          errorString.contains('network is unreachable') ||
          errorString.contains('connection refused') ||
          errorString.contains('connection timed out') ||
          errorString.contains('clientexception') ||
          errorString.contains('connection abort') ||
          errorString.contains('software caused connection abort')) {
        if (mounted) {
          await showConnectionErrorDialog(context);
        }
      } else {
        // Other error - show generic error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
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
          _isRestoring = false;
        });
      }
    }
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            height: 80,
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isBackingUp || _isRestoring;
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
      body: ResponsiveContainer(
        maxWidth: 1000,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
            vertical: 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isFirstLoad) ...[
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
              ],
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
              if (!_isFirstLoad) ...[
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
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
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
              ],
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
                  child: _isFirstLoad
                      ? _buildSkeletonLoader(context)
                      : _backups.isEmpty
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
                                final ts =
                                    meta.timestampUtc?.toLocal().toString() ??
                                        'Unknown time';
                                return Card(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
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
                                          onPressed: (_) =>
                                              _confirmDelete(meta),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
      ),
    );
  }

  Future<void> _confirmDelete(BackupFileMeta meta) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 400,
              minWidth: 350,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Delete backup',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to delete ${meta.name}?',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.bodyMedium?.color,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
    final isDark = theme.brightness == Brightness.dark;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 400,
              minWidth: 350,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.backup_outlined,
                    color: Colors.blue,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Create backup',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to create a new backup now?',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Backup',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.bodyMedium?.color,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      // Check network connection AFTER confirmation
      final hasConnection = await ConnectivityService().hasInternetConnection();
      if (!hasConnection) {
        if (mounted) {
          await showConnectionErrorDialog(context);
        }
        return;
      }

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
    final isDark = theme.brightness == Brightness.dark;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 400,
              minWidth: 350,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.restore_outlined,
                    color: Colors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Restore backup',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to restore ${meta.name}? This will overwrite existing data.',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Restore',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.bodyMedium?.color,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      // Check network connection AFTER confirmation
      final hasConnection = await ConnectivityService().hasInternetConnection();
      if (!hasConnection) {
        if (mounted) {
          await showConnectionErrorDialog(context);
        }
        return;
      }

      await _restoreFrom(meta);
    }
  }

  Future<void> _toggleAutoBackup(bool enabled) async {
    // Check network connection before toggling
    final hasConnection = await ConnectivityService().hasInternetConnection();
    if (!hasConnection) {
      if (mounted) {
        await showConnectionErrorDialog(context);
      }
      return;
    }

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
    // Convert UTC time to local time
    final localDate = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(localDate.year, localDate.month, localDate.day);

    if (dateOnly == today) {
      return 'Today at ${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
    } else if (dateOnly == yesterday) {
      return 'Yesterday at ${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
    } else {
      return '${localDate.month}/${localDate.day}/${localDate.year} at ${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
    }
  }
}
