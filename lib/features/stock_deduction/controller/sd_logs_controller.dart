import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familee_dental/shared/storage/hive_storage.dart';
import 'package:flutter/foundation.dart';

class StockDeductionLogsController {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _table = 'stock_deduction_logs';
  static const String _cacheKey = 'stock_deduction_logs_cache_v1';

  // Per-date caching (same as activity logs)
  final Map<String, List<Map<String, dynamic>>> _cachedLogsByDate = {};
  static const int _maxCachedDates = 7;

  // Legacy cache for backward compatibility (deprecated)
  List<Map<String, dynamic>>? _cachedLogs;

  List<Map<String, dynamic>> get cachedLogs => _cachedLogs != null
      ? List<Map<String, dynamic>>.from(_cachedLogs!)
      : const [];

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Map<String, DateTime> _buildUtcRangeForDate(DateTime date) {
    final localStart = DateTime(date.year, date.month, date.day);
    final startUtc = localStart.toUtc();
    final endUtc = localStart.add(const Duration(days: 1)).toUtc();
    return {'start': startUtc, 'end': endUtc};
  }

  List<Map<String, dynamic>>? _getCachedLogsForDate(DateTime date) {
    final cached = _cachedLogsByDate[_dateKey(date)];
    if (cached == null) return null;
    return cached
        .map((log) => Map<String, dynamic>.from(log))
        .toList(growable: false);
  }

  bool hasCachedDataFor(DateTime date) {
    final cached = _cachedLogsByDate[_dateKey(date)];
    return cached != null && cached.isNotEmpty;
  }

  List<Map<String, dynamic>>? getCachedLogsForDate(DateTime date) {
    return _getCachedLogsForDate(date);
  }

  void _cacheLogsForDate(DateTime date, List<Map<String, dynamic>> logs) {
    final key = _dateKey(date);
    final cachedList = logs
        .map((log) => Map<String, dynamic>.from(log))
        .toList(growable: false);
    _cachedLogsByDate[key] = cachedList;

    // Save to Hive for persistence
    unawaited(_saveLogsToHive(key, cachedList));

    // Limit cache size to _maxCachedDates
    if (_cachedLogsByDate.length > _maxCachedDates) {
      final keys = _cachedLogsByDate.keys.toList()..sort(); // oldest first
      while (keys.length > _maxCachedDates) {
        final removeKey = keys.removeAt(0);
        _cachedLogsByDate.remove(removeKey);
        // Also remove from Hive
        unawaited(_removeLogsFromHive(removeKey));
      }
    }
  }

  /// Save logs for a specific date to Hive
  Future<void> _saveLogsToHive(
      String dateKey, List<Map<String, dynamic>> logs) async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.sdLogsBox);
      await box.put(dateKey, jsonEncode(logs));
    } catch (e) {
      debugPrint('Error saving logs to Hive ($dateKey): $e');
    }
  }

  /// Load logs for a specific date from Hive
  Future<List<Map<String, dynamic>>?> _loadLogsFromHive(String dateKey) async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.sdLogsBox);
      final jsonStr = box.get(dateKey) as String?;
      if (jsonStr != null) {
        final jsonList = jsonDecode(jsonStr) as List<dynamic>;
        return jsonList
            .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading logs from Hive ($dateKey): $e');
    }
    return null;
  }

  /// Remove logs for a specific date from Hive
  Future<void> _removeLogsFromHive(String dateKey) async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.sdLogsBox);
      await box.delete(dateKey);
    } catch (e) {
      debugPrint('Error removing logs from Hive ($dateKey): $e');
    }
  }

  Future<List<Map<String, dynamic>>> preloadLogs() async {
    // Legacy method - now loads from Hive (backward compatible)
    try {
      // Try to load today's logs from Hive
      final today = DateTime.now();
      final dateKey = _dateKey(today);
      final hiveData = await _loadLogsFromHive(dateKey);
      if (hiveData != null && hiveData.isNotEmpty) {
        _cachedLogsByDate[dateKey] = hiveData;
        _cachedLogs = hiveData; // Keep legacy cache for backward compatibility
        return List<Map<String, dynamic>>.from(hiveData);
      }

      // Fallback to SharedPreferences (backward compatibility)
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        final restored = decoded
            .map(
              (entry) => Map<String, dynamic>.from(
                entry as Map<String, dynamic>,
              ),
            )
            .toList(growable: false);
        _cachedLogs = restored;
        // Also save to Hive for future use
        if (restored.isNotEmpty) {
          unawaited(_saveLogsToHive(dateKey, restored));
        }
        return List<Map<String, dynamic>>.from(restored);
      }
      _cachedLogs = null;
    } catch (_) {
      _cachedLogs = null;
    }

    return getCachedLogsForDate(DateTime.now()) ?? const [];
  }

  Stream<List<Map<String, dynamic>>> getLogsStream({DateTime? selectedDate}) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    StreamSubscription<List<Map<String, dynamic>>>? subscription;
    RealtimeChannel? realtimeChannel;

    // Use today's date if not provided
    final targetDate = selectedDate ?? DateTime.now();
    final dateKey = _dateKey(targetDate);

    void safeAdd(List<Map<String, dynamic>> logs) {
      if (!controller.isClosed) {
        controller.add(List<Map<String, dynamic>>.from(logs, growable: false));
      }
    }

    void emitCachedForDate() {
      final cached = _getCachedLogsForDate(targetDate);
      if (cached != null) {
        safeAdd(cached);
      }
    }

    Future<void> _fetchLogsForDate() async {
      try {
        final range = _buildUtcRangeForDate(targetDate);
        final response = await _supabase
            .from(_table)
            .select('*')
            .gte('created_at', range['start']!.toIso8601String())
            .lt('created_at', range['end']!.toIso8601String())
            .order('created_at', ascending: false);

        final List<dynamic> rows = response as List<dynamic>;
        final mapped = rows
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false);

        _cacheLogsForDate(targetDate, mapped);
        safeAdd(mapped);

        // Attach realtime channel for this date range
        if (realtimeChannel != null) {
          await realtimeChannel!.unsubscribe();
        }

        realtimeChannel = _supabase
            .channel('stock_deduction_logs_$dateKey')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: _table,
              callback: (payload) => _handleRealtimePayload(
                  payload, range, PostgresChangeEvent.insert, targetDate),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: _table,
              callback: (payload) => _handleRealtimePayload(
                  payload, range, PostgresChangeEvent.update, targetDate),
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.delete,
              schema: 'public',
              table: _table,
              callback: (payload) => _handleRealtimePayload(
                  payload, range, PostgresChangeEvent.delete, targetDate),
            )
            .subscribe();
      } catch (_) {
        // On error (e.g., offline), emit cached data if available
        emitCachedForDate();
      }
    }

    controller
      ..onListen = () async {
        // 1. Check in-memory cache first
        emitCachedForDate();

        // 2. If in-memory cache is null, auto-load from Hive
        if (!_cachedLogsByDate.containsKey(dateKey)) {
          final hiveData = await _loadLogsFromHive(dateKey);
          if (hiveData != null && hiveData.isNotEmpty) {
            _cachedLogsByDate[dateKey] = hiveData; // Populate in-memory cache
            safeAdd(hiveData); // Emit immediately
          }
        }

        // 3. Fetch from Supabase and subscribe to realtime updates
        unawaited(_fetchLogsForDate());
      }
      ..onCancel = () async {
        await subscription?.cancel();
        await realtimeChannel?.unsubscribe();
        subscription = null;
        realtimeChannel = null;
      };

    return controller.stream;
  }

  void _handleRealtimePayload(
    PostgresChangePayload payload,
    Map<String, DateTime> range,
    PostgresChangeEvent eventType,
    DateTime targetDate,
  ) {
    try {
      final Map<String, dynamic>? record =
          eventType == PostgresChangeEvent.delete
              ? payload.oldRecord as Map<String, dynamic>?
              : payload.newRecord as Map<String, dynamic>?;
      if (record == null) return;

      final createdAtRaw = record['created_at']?.toString();
      if (createdAtRaw == null) return;
      final createdAt = DateTime.tryParse(createdAtRaw);
      if (createdAt == null) return;

      final start = range['start']!;
      final end = range['end']!;
      final createdAtUtc = createdAt.toUtc();
      if (createdAtUtc.isBefore(start) || !createdAtUtc.isBefore(end)) {
        return;
      }

      // Refetch logs for the date to get updated list
      final cached = _getCachedLogsForDate(targetDate);
      if (cached != null) {
        if (eventType == PostgresChangeEvent.delete) {
          final id = record['id'];
          if (id != null) {
            cached.removeWhere((log) => log['id'] == id);
            _cacheLogsForDate(targetDate, cached);
          }
        } else {
          // For insert/update, refetch the entire list
          // This will be handled by the stream listener
        }
      }
    } catch (_) {
      // Ignore errors
    }
  }

  Future<void> saveLog(Map<String, dynamic> logData) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    final dataToSave = Map<String, dynamic>.from(logData);
    if (dataToSave.containsKey('id')) {
      dataToSave.remove('id');
    }
    dataToSave['created_at'] = DateTime.now().toUtc().toIso8601String();
    dataToSave['created_by'] = currentUser.id;
    dataToSave['created_by_email'] = currentUser.email;
    dataToSave['created_by_role'] =
        await _getUserRole(currentUser.id) ?? 'Unknown';
    await _supabase.from(_table).insert(dataToSave);
  }

  Future<void> deleteLog(String logId) async {
    await _supabase.from(_table).delete().eq('id', logId);
  }

  Future<String?> _getUserRole(String userId) async {
    try {
      final response = await _supabase
          .from('user_roles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      final role = response?['role']?.toString();
      if (role != null && role.isNotEmpty) {
        return role;
      }
    } catch (_) {
      // ignore lookup failures
    }
    return null;
  }
}
