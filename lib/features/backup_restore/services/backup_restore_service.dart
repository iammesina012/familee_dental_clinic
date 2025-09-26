import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// Simple models for backup metadata and results
class BackupFileMeta {
  final String name; // file name only
  final String fullPath; // storage path
  final DateTime? timestampUtc; // parsed from file name
  const BackupFileMeta({
    required this.name,
    required this.fullPath,
    required this.timestampUtc,
  });
}

class BackupResult {
  final String storagePath;
  final int totalItems;
  const BackupResult({required this.storagePath, required this.totalItems});
}

class RestoreResult {
  final String storagePath;
  final int totalItems;
  const RestoreResult({required this.storagePath, required this.totalItems});
}

/// Service handling Supabase <-> JSON <-> Storage backup/restore
class BackupRestoreService {
  final supa.SupabaseClient _supabase;

  static const String _bucket = 'backups';
  static const int _maxBackups = 10;
  static const List<String> _allTables = <String>[
    'supplies',
    'brands',
    'suppliers',
    'categories',
    'purchase_orders',
    'notifications',
    'activity_logs',
    'user_roles',
    'po_suggestions',
    'stock_deduction_presets',
  ];

  BackupRestoreService({
    supa.SupabaseClient? supabase,
  }) : _supabase = supabase ?? supa.Supabase.instance.client;

  /// List available backup files under backups/{uid}/
  Future<List<BackupFileMeta>> listBackups() async {
    _requireUser();
    final entries =
        await _supabase.storage.from(_bucket).list(path: 'familee-backups');

    final List<BackupFileMeta> files = entries
        .where((f) => f.name.toLowerCase().endsWith('.json'))
        .map((f) => BackupFileMeta(
              name: f.name,
              fullPath: 'familee-backups/${f.name}',
              timestampUtc: _parseTimestampFromFilename(f.name),
            ))
        .toList();

    files.sort((a, b) {
      final at = a.timestampUtc?.millisecondsSinceEpoch ?? 0;
      final bt = b.timestampUtc?.millisecondsSinceEpoch ?? 0;
      return bt.compareTo(at); // newest first
    });

    return files;
  }

  /// Create a backup JSON for all tables and upload to Storage.
  /// onProgress returns processed document count.
  Future<BackupResult> createBackup(
      {void Function(int processed)? onProgress, bool force = false}) async {
    _requireUser();

    const int pageSize = 500;
    final Map<String, List<Map<String, dynamic>>> tables =
        <String, List<Map<String, dynamic>>>{};
    int processed = 0;

    for (final String table in _allTables) {
      final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];

      try {
        final response =
            await _supabase.from(table).select('*').order('id').limit(pageSize);

        for (final item in response) {
          items.add({
            'id': item['id']?.toString() ?? '',
            'data': item,
          });
        }

        processed += items.length;
        if (onProgress != null) onProgress(processed);
      } catch (e) {
        print('Error backing up table $table: $e');
        // Continue with other tables even if one fails
      }

      tables[table] = items;
    }

    // Compute a simple checksum of the tables content to detect no-op backups
    final String tablesJsonForHash = jsonEncode(tables);
    final String checksum = _simpleChecksum(tablesJsonForHash);

    // Compare with latest backup checksum (if available)
    try {
      final existing = await listBackups();
      if (!force && existing.isNotEmpty) {
        final latest = existing.first; // newest first
        final bytes =
            await _supabase.storage.from(_bucket).download(latest.fullPath);
        final lastPayload =
            jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final String? lastChecksum = lastPayload['checksum'] as String?;
        if (lastChecksum != null && lastChecksum == checksum) {
          throw StateError('no_changes');
        }
      }
    } on StateError catch (e) {
      if (e.message == 'no_changes') rethrow;
    } catch (_) {
      // ignore other errors; proceed with backup
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'version': 1,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'checksum': checksum,
      'collections': tables,
    };

    final String jsonStr = jsonEncode(payload);
    final String filename = _buildBackupFilename();
    final String path = 'familee-backups/$filename';
    final data = Uint8List.fromList(utf8.encode(jsonStr));
    await _supabase.storage.from(_bucket).uploadBinary(
          path,
          data,
          fileOptions: supa.FileOptions(
            contentType: 'application/json',
            upsert: true,
          ),
        );

    // Retain only the latest _maxBackups files
    try {
      final existing = await listBackups();
      if (existing.length > _maxBackups) {
        final toDelete = existing.sublist(_maxBackups);
        final paths = toDelete.map((f) => f.fullPath).toList();
        if (paths.isNotEmpty) {
          await _supabase.storage.from(_bucket).remove(paths);
        }
      }
    } catch (_) {
      // ignore retention failures
    }

    int totalItems = 0;
    for (final entry in tables.entries) {
      totalItems += entry.value.length;
    }
    return BackupResult(storagePath: '$_bucket/$path', totalItems: totalItems);
  }

  /// Restore from a selected backup file path. Overwrites documents with incoming data.
  /// Performs batched writes of up to 500 per commit.
  Future<RestoreResult> restoreFromBackup({
    required String storagePath,
    void Function(int processed, int total)? onProgress,
  }) async {
    _requireUser();
    // Expect storagePath like "familee-backups/filename.json" or "backups/familee-backups/filename.json"
    final normalizedPath = storagePath.startsWith('$_bucket/')
        ? storagePath.substring(_bucket.length + 1)
        : storagePath;
    if (!normalizedPath.startsWith('familee-backups/')) {
      throw StateError('Invalid backup path');
    }
    final bytes =
        await _supabase.storage.from(_bucket).download(normalizedPath);
    final String jsonStr = utf8.decode(bytes);

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid JSON in backup file');
    }

    if (!decoded.containsKey('version')) {
      throw FormatException('Backup file missing required fields');
    }

    final bool hasCollections = decoded['collections'] is Map<String, dynamic>;
    final Map<String, dynamic> tablesMap = hasCollections
        ? Map<String, dynamic>.from(decoded['collections'] as Map)
        : <String, dynamic>{
            'supplies': decoded['items'] ?? <dynamic>[],
          };

    int total = 0;
    tablesMap.forEach((key, value) {
      if (value is List) total += value.length;
    });
    int processed = 0;

    // Process each table
    for (final entry in tablesMap.entries) {
      final String table = entry.key;
      final dynamic listDyn = entry.value;

      if (listDyn is! List) continue;

      for (final item in listDyn) {
        if (item is! Map<String, dynamic>) {
          processed++;
          if (onProgress != null) onProgress(processed, total);
          continue;
        }

        final String? id = item['id'] as String?;
        final dynamic dataDyn = item['data'];
        if (id == null || id.isEmpty || dataDyn is! Map<String, dynamic>) {
          processed++;
          if (onProgress != null) onProgress(processed, total);
          continue;
        }

        try {
          // Use upsert to handle both insert and update
          await _supabase.from(table).upsert(
                Map<String, dynamic>.from(dataDyn),
                onConflict: 'id',
              );
        } catch (e) {
          print('Error restoring item $id to table $table: $e');
          // Continue with other items even if one fails
        }

        processed++;
        if (onProgress != null) onProgress(processed, total);

        // Simple throttling to avoid rate limits
        if (processed % 100 == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
    }

    return RestoreResult(storagePath: storagePath, totalItems: total);
  }

  /// Delete a backup file from the shared folder.
  Future<void> deleteBackup({required String storagePath}) async {
    _requireUser();
    final String normalizedPath = storagePath.startsWith('$_bucket/')
        ? storagePath.substring(_bucket.length + 1)
        : storagePath;
    if (!normalizedPath.startsWith('familee-backups/')) {
      throw StateError('Invalid backup path');
    }
    await _supabase.storage.from(_bucket).remove(<String>[normalizedPath]);
  }

  // --- Helpers ---

  supa.User _requireUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }
    return user;
  }

  String _buildBackupFilename() {
    // 2025-09-23T08-45-12Z (no colons)
    final now = DateTime.now().toUtc();
    final iso = now.toIso8601String().replaceAll(':', '-');
    return 'inventory_backup_${iso}.json';
  }

  DateTime? _parseTimestampFromFilename(String name) {
    // inventory_backup_2025-09-23T08-45-12Z.json
    try {
      final start = name.indexOf('inventory_backup_');
      if (start == -1) return null;
      final ts = name.substring('inventory_backup_'.length, name.length - 5);
      // Replace only the time colons back; date dashes must stay.
      // Approach: convert last two '-' back to ':' in the time portion.
      // Find the 'T'
      final tIndex = ts.indexOf('T');
      if (tIndex == -1) return null;
      String datePart = ts.substring(0, tIndex); // yyyy-mm-dd
      String timePart = ts.substring(tIndex + 1); // HH-mm-ssZ or HH-mm-ss.mmmZ
      timePart = timePart.replaceFirst('-', ':').replaceFirst('-', ':');
      final iso = '${datePart}T$timePart';
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  // Lightweight deterministic checksum (FNV-1a 32-bit) to avoid extra deps
  String _simpleChecksum(String input) {
    const int fnvPrime = 0x01000193;
    int hash = 0x811c9dc5;
    for (int i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    // convert to 8-char hex
    return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
  }
}

/*
Security guidance for Supabase:

1. Enable Row Level Security (RLS) on all tables
2. Create policies for user_roles table to allow users to manage their own data
3. Set up storage policies for the backups bucket to allow authenticated users
4. Consider using service role key for admin operations like backup/restore
*/
