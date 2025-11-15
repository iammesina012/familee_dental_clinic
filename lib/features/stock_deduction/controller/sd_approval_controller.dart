import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familee_dental/shared/storage/hive_storage.dart';
import 'package:flutter/foundation.dart';

class ApprovalController {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _table = 'stock_deduction_approvals';
  static const String _cacheKey = 'sd_pending_approvals_cache_v1';

  List<Map<String, dynamic>>? _cachedPendingApprovals;

  List<Map<String, dynamic>> get cachedPendingApprovals =>
      _cachedPendingApprovals != null
          ? List<Map<String, dynamic>>.from(_cachedPendingApprovals!)
          : const [];

  /// Load pending approvals from Hive
  Future<List<Map<String, dynamic>>?> _loadApprovalsFromHive() async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.sdPendingApprovalsBox);
      final jsonStr = box.get('pending_approvals') as String?;
      if (jsonStr != null) {
        final jsonList = jsonDecode(jsonStr) as List<dynamic>;
        return jsonList
            .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading approvals from Hive: $e');
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> preloadPendingApprovals() async {
    try {
      // Try Hive first (new persistent cache)
      final hiveData = await _loadApprovalsFromHive();
      if (hiveData != null && hiveData.isNotEmpty) {
        _cachedPendingApprovals = hiveData;
        return List<Map<String, dynamic>>.from(hiveData);
      }

      // Fallback to SharedPreferences (backward compatibility)
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        final restored = decoded
            .map((entry) =>
                Map<String, dynamic>.from(entry as Map<String, dynamic>))
            .toList(growable: false);
        _cachedPendingApprovals = restored;
        // Migrate to Hive for future use
        if (restored.isNotEmpty) {
          final box =
              await HiveStorage.openBox(HiveStorage.sdPendingApprovalsBox);
          unawaited(box.put('pending_approvals', jsonEncode(restored)));
        }
        return List<Map<String, dynamic>>.from(restored);
      }
      _cachedPendingApprovals = null;
      return const [];
    } catch (e) {
      debugPrint('Error preloading approvals: $e');
      _cachedPendingApprovals = null;
      return const [];
    }
  }

  Map<String, dynamic> _mapRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'presetName': row['preset_name'] ?? row['presetName'],
      'name': row['preset_name'] ?? row['name'],
      'supplies': row['supplies'],
      'purpose': row['purpose'],
      'remarks': row['remarks'],
      'status': row['status'] ?? 'pending',
      'created_at': row['created_at']?.toString(),
    };
  }

  bool _isPendingRow(Map<String, dynamic> row) {
    final rawStatus = row['status'] as String?;
    if (rawStatus == 'rejected' || rawStatus == 'approved') {
      return false;
    }
    return rawStatus == 'pending' || rawStatus == null;
  }

  Stream<List<Map<String, dynamic>>> getApprovalsStream() {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    StreamSubscription<List<Map<String, dynamic>>>? subscription;

    void safeAdd(List<Map<String, dynamic>> approvals) {
      if (!controller.isClosed) {
        controller
            .add(List<Map<String, dynamic>>.from(approvals, growable: false));
      }
    }

    Future<void> persist(List<Map<String, dynamic>> approvals) async {
      try {
        // Save to Hive for persistent caching
        final box =
            await HiveStorage.openBox(HiveStorage.sdPendingApprovalsBox);
        await box.put('pending_approvals', jsonEncode(approvals));

        // Also save to SharedPreferences for backward compatibility
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _cacheKey,
          jsonEncode(approvals),
        );
      } catch (e) {
        debugPrint('Error persisting approvals: $e');
        // Ignore cache persistence issues
      }
    }

    void emitCached({bool forceEmpty = false}) {
      if (_cachedPendingApprovals != null) {
        safeAdd(_cachedPendingApprovals!);
      } else if (forceEmpty) {
        safeAdd(const []);
      }
    }

    List<Map<String, dynamic>> filterAndMap(List<Map<String, dynamic>> data) {
      return data
          .where(_isPendingRow)
          .map((row) => _mapRow(row))
          .toList(growable: false);
    }

    void startSubscription() {
      subscription ??= _supabase
          .from(_table)
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .listen(
            (data) {
              try {
                final mapped = filterAndMap(data);
                _cachedPendingApprovals = mapped;
                safeAdd(mapped);
                unawaited(persist(mapped));
              } catch (_) {
                emitCached(forceEmpty: true);
              }
            },
            onError: (error) {
              emitCached(forceEmpty: true);
            },
          );
    }

    controller
      ..onListen = () async {
        // 1. Check in-memory cache first
        emitCached();

        // 2. If in-memory cache is null, auto-load from Hive
        if (_cachedPendingApprovals == null) {
          final hiveData = await _loadApprovalsFromHive();
          if (hiveData != null && hiveData.isNotEmpty) {
            _cachedPendingApprovals = hiveData; // Populate in-memory cache
            safeAdd(hiveData); // Emit immediately
          }
        }

        // 3. Subscribe to Supabase for updates
        startSubscription();
      }
      ..onCancel = () async {
        await subscription?.cancel();
        subscription = null;
      };

    return controller.stream;
  }

  // Save a new approval to Supabase
  Future<void> saveApproval(Map<String, dynamic> approvalData) async {
    try {
      // Convert camelCase keys to snake_case to match database schema
      DateTime createdAt;
      if (approvalData['created_at'] is String) {
        try {
          createdAt =
              DateTime.parse(approvalData['created_at'] as String).toUtc();
        } catch (_) {
          createdAt = DateTime.now().toUtc();
        }
      } else if (approvalData['created_at'] is DateTime) {
        createdAt = (approvalData['created_at'] as DateTime).toUtc();
      } else {
        createdAt = DateTime.now().toUtc();
      }

      final dataToSave = <String, dynamic>{
        'preset_name': approvalData['presetName'] ??
            approvalData['preset_name'] ??
            approvalData[
                'purpose'] ?? // Use purpose if preset_name not provided
            'Unknown Preset',
        'supplies': approvalData['supplies'] ?? [],
        'purpose': approvalData['purpose'] ?? '',
        'remarks': approvalData['remarks'] ?? '',
        'created_at': createdAt.toIso8601String(),
      };

      await _supabase.from(_table).insert(dataToSave);
    } catch (e) {
      throw Exception('Failed to save approval: $e');
    }
  }

  // Delete an approval
  Future<void> deleteApproval(String approvalId) async {
    try {
      await _supabase.from(_table).delete().eq('id', approvalId);
    } catch (e) {
      throw Exception('Failed to delete approval: $e');
    }
  }

  // Get a specific approval by ID
  Future<Map<String, dynamic>?> getApprovalById(String approvalId) async {
    try {
      final response = await _supabase
          .from(_table)
          .select('*')
          .eq('id', approvalId)
          .single();

      // Convert snake_case to camelCase for application use
      return {
        'id': response['id'],
        'presetName': response['preset_name'] ?? response['presetName'],
        'name':
            response['preset_name'] ?? response['name'], // For compatibility
        'supplies': response['supplies'],
        'purpose': response['purpose'],
        'remarks': response['remarks'],
        'status': response['status'] ?? 'pending',
        'created_at': response['created_at'],
      };
    } catch (e) {
      return null;
    }
  }

  // Update approval status to approved
  Future<void> approveApproval(String approvalId) async {
    try {
      await _supabase
          .from(_table)
          .update({'status': 'approved'}).eq('id', approvalId);
    } catch (e) {
      throw Exception('Failed to approve: $e');
    }
  }

  // Update approval status to rejected
  Future<void> rejectApproval(String approvalId) async {
    try {
      await _supabase
          .from(_table)
          .update({'status': 'rejected'}).eq('id', approvalId);
    } catch (e) {
      throw Exception('Failed to reject: $e');
    }
  }
}
