import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

/// Service handling Firestore <-> JSON <-> Storage backup/restore
class BackupRestoreService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final supa.SupabaseClient _supabase;

  static const String collectionName = 'supplies';
  static const String _bucket = 'backups';
  static const List<String> _allCollections = <String>[
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
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    supa.SupabaseClient? supabase,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _supabase = supabase ?? supa.Supabase.instance.client;

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

  /// Create a backup JSON for all collections and upload to Storage.
  /// onProgress returns processed document count.
  Future<BackupResult> createBackup(
      {void Function(int processed)? onProgress}) async {
    _requireUser();

    const int pageSize = 500;
    final Map<String, List<Map<String, dynamic>>> collections =
        <String, List<Map<String, dynamic>>>{};
    int processed = 0;

    for (final String coll in _allCollections) {
      final List<Map<String, dynamic>> items = <Map<String, dynamic>>[];
      Query<Map<String, dynamic>> baseQuery = _firestore
          .collection(coll)
          .orderBy(FieldPath.documentId)
          .limit(pageSize);

      QueryDocumentSnapshot<Map<String, dynamic>>? lastDoc;
      while (true) {
        Query<Map<String, dynamic>> q = baseQuery;
        if (lastDoc != null) {
          q = q.startAfterDocument(lastDoc);
        }
        final snap = await q.get();
        if (snap.docs.isEmpty) break;
        for (final doc in snap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          items.add(<String, dynamic>{
            'id': doc.id,
            'data': _serializeForJson(data),
          });
        }
        processed += snap.docs.length;
        if (onProgress != null) onProgress(processed);
        lastDoc = snap.docs.last;
        if (snap.docs.length < pageSize) break;
      }
      collections[coll] = items;
    }

    final Map<String, dynamic> payload = <String, dynamic>{
      'version': 1,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'collections': collections,
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

    int totalItems = 0;
    for (final entry in collections.entries) {
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
    final Map<String, dynamic> collectionsMap = hasCollections
        ? Map<String, dynamic>.from(decoded['collections'] as Map)
        : <String, dynamic>{
            collectionName: decoded['items'] ?? <dynamic>[],
          };

    int total = 0;
    collectionsMap.forEach((key, value) {
      if (value is List) total += value.length;
    });
    int processed = 0;

    WriteBatch batch = _firestore.batch();
    int batchCount = 0;

    collectionsMap.forEach((String coll, dynamic listDyn) {
      if (listDyn is! List) return;
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

        final Map<String, dynamic> restored =
            _deserializeFromJson(Map<String, dynamic>.from(dataDyn));
        final DocumentReference<Map<String, dynamic>> docRef =
            _firestore.collection(coll).doc(id);
        batch.set(docRef, restored, SetOptions(merge: false));
        batchCount++;

        if (batchCount >= 500) {
          // commit and throttle
          // simple throttling to avoid rate limits
          // (keep code minimal, UX handles progress)
          batch.commit();
          Future<void>.delayed(const Duration(milliseconds: 200));
          batch = _firestore.batch();
          batchCount = 0;
        }

        processed++;
        if (onProgress != null) onProgress(processed, total);
      }
    });

    if (batchCount > 0) {
      await batch.commit();
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

  User _requireUser() {
    final user = _auth.currentUser;
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

  Map<String, dynamic> _serializeForJson(Map<String, dynamic> original) {
    Map<String, dynamic> out = <String, dynamic>{};
    original.forEach((key, value) {
      out[key] = _toJsonSafe(value);
    });
    return out;
  }

  dynamic _toJsonSafe(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is GeoPoint) {
      return {
        '__type__': 'geopoint',
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }
    if (value is DocumentReference) {
      return {
        '__type__': 'docref',
        'path': value.path,
      };
    }
    if (value is List) {
      return value.map(_toJsonSafe).toList();
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _toJsonSafe(v)));
    }
    return value;
  }

  Map<String, dynamic> _deserializeFromJson(Map<String, dynamic> jsonMap) {
    Map<String, dynamic> out = <String, dynamic>{};
    jsonMap.forEach((key, value) {
      out[key] = _fromJsonSafe(key, value);
    });
    return out;
  }

  dynamic _fromJsonSafe(String key, dynamic value) {
    if (value == null) return null;
    if (value is Map && value['__type__'] == 'geopoint') {
      final lat = (value['latitude'] as num).toDouble();
      final lon = (value['longitude'] as num).toDouble();
      return GeoPoint(lat, lon);
    }
    if (value is Map && value['__type__'] == 'docref') {
      final path = value['path'] as String;
      return _firestore.doc(path);
    }
    if (value is String &&
        _looksLikeIso8601(value) &&
        _likelyTimestampField(key)) {
      try {
        final dt = DateTime.parse(value);
        return Timestamp.fromDate(dt);
      } catch (_) {}
    }
    if (value is List) {
      return value.map((v) => _fromJsonSafe(key, v)).toList();
    }
    if (value is Map) {
      return value.map(
          (k, v) => MapEntry(k.toString(), _fromJsonSafe(k.toString(), v)));
    }
    return value;
  }

  bool _looksLikeIso8601(String s) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(s);
  }

  bool _likelyTimestampField(String key) {
    final lower = key.toLowerCase();
    return lower.endsWith('at') || lower.contains('date');
  }
}

/*
Security rules guidance (add to your Firebase rules, adjust as needed):

// Firestore rules (pseudo):
// match /databases/{database}/documents {
//   match /inventory_items/{docId} {
//     allow read, write: if request.auth != null && request.resource.data.uid == request.auth.uid;
//   }
// }

// Storage rules (pseudo):
// rules_version = '2';
// service firebase.storage {
//   match /b/{bucket}/o {
//     match /backups/{uid}/{fileName} {
//       allow read, write: if request.auth != null && request.auth.uid == uid;
//     }
//   }
// }
*/
