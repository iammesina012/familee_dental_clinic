import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:projects/shared/themes/font.dart';
import 'package:projects/features/backup_restore/services/backup_restore_service.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  final BackupRestoreService _service = BackupRestoreService();

  bool _isBackingUp = false;
  bool _isRestoring = false;
  int _progressCount = 0;
  int _totalCount = 0;
  List<BackupFileMeta> _backups = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() {
      _error = null;
    });
    try {
      final files = await _service.listBackups();
      setState(() {
        _backups = files;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _backupNow() async {
    setState(() {
      _isBackingUp = true;
      _progressCount = 0;
      _totalCount = 0; // unknown until done
      _error = null;
    });
    try {
      final res = await _service.createBackup(onProgress: (processed) {
        setState(() {
          _progressCount = processed;
        });
      });
      if (!mounted) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  Future<void> _restoreFrom(BackupFileMeta meta) async {
    setState(() {
      _isRestoring = true;
      _progressCount = 0;
      _totalCount = 0;
      _error = null;
    });
    try {
      final result = await _service.restoreFromBackup(
        storagePath: meta.fullPath,
        onProgress: (processed, total) {
          setState(() {
            _progressCount = processed;
            _totalCount = total;
          });
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore complete: ${result.totalItems} items')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
      setState(() {
        _error = e.toString();
      });
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
        title: const Text('Backup & Restore'),
        centerTitle: true,
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
                    onPressed: isBusy ? null : _backupNow,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Backup Now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (!_isRestoring && _backups.isNotEmpty)
                        ? () => _restoreFrom(_backups.first)
                        : null,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Restore Latest'),
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
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
            ],
            const Text('Available Backups'),
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
                              child: ListTile(
                                title: Tooltip(
                                  message: meta.name,
                                  child: Text(
                                    meta.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                subtitle: Text(ts),
                                trailing: TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: const Size(0, 36),
                                  ),
                                  onPressed: _isRestoring
                                      ? null
                                      : () => _restoreFrom(meta),
                                  child: const Text('Restore'),
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
}
