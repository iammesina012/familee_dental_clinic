import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/purchase_order/data/purchase_order.dart';
import 'package:familee_dental/shared/storage/hive_storage.dart';
import 'package:flutter/foundation.dart';

class POSupabaseController {
  POSupabaseController._internal();

  static final POSupabaseController _instance =
      POSupabaseController._internal();

  factory POSupabaseController() => _instance;

  static const String _storageKey = 'purchase_orders_v1';
  static const String _sequenceKey = 'purchase_order_sequence_v1';

  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache for last known data (persists across widget rebuilds)
  List<PurchaseOrder>? _cachedOpenPOs;
  List<PurchaseOrder>? _cachedPartialPOs;
  List<PurchaseOrder>? _cachedApprovalPOs;
  List<PurchaseOrder>? _cachedClosedPOs;
  List<PurchaseOrder>? _cachedAllPOs;

  PurchaseOrder? _findInCache(String id) {
    final List<List<PurchaseOrder>?> caches = [
      _cachedAllPOs,
      _cachedOpenPOs,
      _cachedPartialPOs,
      _cachedApprovalPOs,
      _cachedClosedPOs,
    ];

    for (final list in caches) {
      if (list == null || list.isEmpty) continue;
      for (final po in list) {
        if (po.id == id) {
          return po;
        }
      }
    }
    return null;
  }

  /// Return a cached purchase order if it already exists in memory.
  PurchaseOrder? getCachedPOById(String id) {
    return _findInCache(id);
  }

  /// Try to resolve a purchase order from cache or local storage without
  /// requiring a network request. Falls back to Supabase on failure when
  /// [fallbackToSupabase] is true.
  Future<PurchaseOrder?> getPOByIdFromCache(String id,
      {bool fallbackToSupabase = false}) async {
    final cached = _findInCache(id);
    if (cached != null) return cached;

    try {
      final localPOs = await getAll();
      for (final po in localPOs) {
        if (po.id == id) {
          // Update in-memory cache for faster access next time.
          _cachedAllPOs = localPOs;
          return po;
        }
      }
    } catch (_) {
      // Ignore and fallback if requested
    }

    if (!fallbackToSupabase) {
      return null;
    }

    return getPOByIdFromSupabase(id);
  }

  Future<void> _persistAllPurchaseOrders(List<PurchaseOrder> orders) async {
    try {
      // Save to Hive for persistent caching
      final box = await HiveStorage.openBox(HiveStorage.poAllPOsBox);
      final jsonList = orders.map((po) => po.toJson()).toList(growable: false);
      await box.put('all_pos', jsonEncode(jsonList));

      // Also save to SharedPreferences for backward compatibility (can be removed later)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_storageKey, jsonList);
    } catch (_) {
      // Ignore persistence errors; cache is just a best-effort fallback.
    }
  }

  /// Load all POs from Hive
  Future<List<PurchaseOrder>?> _loadAllPOsFromHive() async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.poAllPOsBox);
      final jsonStr = box.get('all_pos') as String?;
      if (jsonStr != null) {
        final jsonList = jsonDecode(jsonStr) as List<dynamic>;
        return jsonList
            .map((e) => PurchaseOrder.fromJson(e as String))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading all POs from Hive: $e');
    }
    return null;
  }

  /// Save specific PO list to Hive
  Future<void> _savePOsToHive(
      String boxName, String key, List<PurchaseOrder> pos) async {
    try {
      final box = await HiveStorage.openBox(boxName);
      final jsonList = pos.map((po) => po.toJson()).toList(growable: false);
      await box.put(key, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving POs to Hive ($boxName/$key): $e');
    }
  }

  /// Load specific PO list from Hive
  Future<List<PurchaseOrder>?> _loadPOsFromHive(
      String boxName, String key) async {
    try {
      final box = await HiveStorage.openBox(boxName);
      final jsonStr = box.get(key) as String?;
      if (jsonStr != null) {
        final jsonList = jsonDecode(jsonStr) as List<dynamic>;
        return jsonList
            .map((e) => PurchaseOrder.fromJson(e as String))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading POs from Hive ($boxName/$key): $e');
    }
    return null;
  }

  int _extractPoNumber(String code) {
    final String trimmed = code.trim();
    final RegExp re = RegExp(r'^#?PO(\d+)');
    final match = re.firstMatch(trimmed);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    // Fallback: try to parse trailing digits
    final digits = RegExp(r'(\d+)').allMatches(trimmed).lastOrNull?.group(1);
    return int.tryParse(digits ?? '') ?? 0;
  }

  // ===== LOCAL STORAGE OPERATIONS =====

  Future<List<PurchaseOrder>> getAll() async {
    // Try Hive first (new persistent cache)
    final hivePOs = await _loadAllPOsFromHive();
    if (hivePOs != null && hivePOs.isNotEmpty) {
      return hivePOs;
    }

    // Fallback to SharedPreferences (backward compatibility)
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey) ?? <String>[];
      if (jsonList.isNotEmpty) {
        final pos = jsonList.map((e) => PurchaseOrder.fromJson(e)).toList();
        // Migrate to Hive for future use
        unawaited(_persistAllPurchaseOrders(pos));
        return pos;
      }
    } catch (e) {
      debugPrint('Error loading from SharedPreferences: $e');
    }

    return [];
  }

  Future<void> save(PurchaseOrder po) async {
    final all = await getAll();
    // replace if same id
    final idx = all.indexWhere((p) => p.id == po.id);
    if (idx >= 0) {
      all[idx] = po;
    } else {
      all.add(po);
    }

    // Save to Hive (new persistent cache)
    await _persistAllPurchaseOrders(all);

    // Also save to SharedPreferences for backward compatibility
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = all.map((e) => e.toJson()).toList();
      await prefs.setStringList(_storageKey, jsonList);
    } catch (e) {
      debugPrint('Error saving to SharedPreferences: $e');
    }

    // Save ALL POs to Supabase (not just closed ones)
    try {
      await savePOToSupabase(po);
    } catch (e) {
      // Don't rethrow - local save was successful
    }
  }

  Future<void> updatePOStatus(String poId, String newStatus) async {
    final all = await getAll();
    final idx = all.indexWhere((p) => p.id == poId);

    if (idx >= 0) {
      final updatedPO = PurchaseOrder(
        id: all[idx].id,
        code: all[idx].code,
        name: all[idx].name,
        createdAt: all[idx].createdAt,
        status: newStatus,
        supplies: all[idx].supplies,
        receivedCount: all[idx].receivedCount,
      );

      all[idx] = updatedPO;

      // Save to Hive (new persistent cache)
      await _persistAllPurchaseOrders(all);

      // Also save to SharedPreferences for backward compatibility
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonList = all.map((e) => e.toJson()).toList();
        await prefs.setStringList(_storageKey, jsonList);
      } catch (e) {
        debugPrint('Error saving to SharedPreferences: $e');
      }

      // Update Supabase immediately for real-time updates
      try {
        await updatePOInSupabase(updatedPO);
      } catch (e) {
        // Error handling
      }
    }
  }

  // Update PO status in Supabase only (for real-time updates)
  Future<void> updatePOStatusInSupabase(String poId, String newStatus) async {
    try {
      await _supabase
          .from('purchase_orders')
          .update({'status': newStatus}).eq('id', poId);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> getNextCodeAndIncrement() async {
    try {
      // Prefer Supabase as the source of truth to respect deletions
      final response = await _supabase.from('purchase_orders').select('code');

      final Set<int> existingNumbers = {};
      for (final row in response) {
        final code = (row['code'] ?? '').toString();
        if (code.startsWith('#PO')) {
          final numberStr = code.substring(3);
          final number = int.tryParse(numberStr);
          if (number != null) {
            existingNumbers.add(number);
          }
        }
      }

      int nextNumber = 1;
      while (existingNumbers.contains(nextNumber)) {
        nextNumber++;
      }
      return '#PO$nextNumber';
    } catch (e) {
      // Fallback to local storage if Supabase read fails
      final existingPOs = await getAll();
      final Set<int> existingNumbers = {};
      for (final po in existingPOs) {
        final code = po.code;
        if (code.startsWith('#PO')) {
          final numberStr = code.substring(3);
          final number = int.tryParse(numberStr);
          if (number != null) {
            existingNumbers.add(number);
          }
        }
      }
      int nextNumber = 1;
      while (existingNumbers.contains(nextNumber)) {
        nextNumber++;
      }
      return '#PO$nextNumber';
    }
  }

  Future<void> clearAllPOs() async {
    try {
      // Clear Hive boxes
      await HiveStorage.clearBox(HiveStorage.poAllPOsBox);
      await HiveStorage.clearBox(HiveStorage.poOpenPOsBox);
      await HiveStorage.clearBox(HiveStorage.poPartialPOsBox);
      await HiveStorage.clearBox(HiveStorage.poApprovalPOsBox);
      await HiveStorage.clearBox(HiveStorage.poClosedPOsBox);

      // Clear in-memory caches
      _cachedAllPOs = null;
      _cachedOpenPOs = null;
      _cachedPartialPOs = null;
      _cachedApprovalPOs = null;
      _cachedClosedPOs = null;

      // Clear SharedPreferences (backward compatibility)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      await prefs.remove(_sequenceKey);

      // Clear Supabase data
      await _supabase.from('purchase_orders').delete().neq('id', '');
    } catch (e) {
      rethrow;
    }
  }

  // ===== SUPABASE OPERATIONS =====

  Future<void> savePOToSupabase(PurchaseOrder po) async {
    try {
      await _supabase.from('purchase_orders').upsert(po.toMap());
    } catch (e) {
      rethrow;
    }
  }

  // Keep the old method for backward compatibility
  Future<void> saveClosedPOToSupabase(PurchaseOrder po) async {
    return savePOToSupabase(po);
  }

  Stream<List<PurchaseOrder>> getClosedPOsStream() {
    final controller = StreamController<List<PurchaseOrder>>.broadcast();

    void emitCachedOrEmpty({bool forceEmpty = false}) {
      if (_cachedClosedPOs != null) {
        controller.add(_cachedClosedPOs!);
      } else if (forceEmpty) {
        controller.add([]);
      }
    }

    void startSubscription() {
      try {
        _supabase.from('purchase_orders').stream(primaryKey: ['id']).inFilter(
            'status', ['Closed', 'Cancelled']).listen(
          (data) {
            try {
              final list = data.map((row) {
                return PurchaseOrder.fromMap(row);
              }).toList();
              list.sort((a, b) =>
                  _extractPoNumber(a.code).compareTo(_extractPoNumber(b.code)));

              // Cache the result
              _cachedClosedPOs = list;
              unawaited(_savePOsToHive(
                  HiveStorage.poClosedPOsBox, 'closed_pos', list));
              controller.add(list);
            } catch (e) {
              emitCachedOrEmpty(forceEmpty: true);
            }
          },
          onError: (error) {
            emitCachedOrEmpty(forceEmpty: true);
          },
        );
      } catch (e) {
        emitCachedOrEmpty(forceEmpty: true);
      }
    }

    controller
      ..onListen = () async {
        // 1. Check in-memory cache first
        emitCachedOrEmpty();

        // 2. If in-memory cache is null, auto-load from Hive
        if (_cachedClosedPOs == null) {
          final hiveData =
              await _loadPOsFromHive(HiveStorage.poClosedPOsBox, 'closed_pos');
          if (hiveData != null) {
            _cachedClosedPOs = hiveData; // Populate in-memory cache
            controller.add(hiveData); // Emit immediately
          }
        }

        // 3. Subscribe to Supabase for updates
        startSubscription();
      }
      ..onCancel = () {
        // Cleanup handled automatically
      };

    return controller.stream;
  }

  Stream<List<PurchaseOrder>> getApprovalPOsStream() {
    final controller = StreamController<List<PurchaseOrder>>.broadcast();

    void emitCachedOrEmpty({bool forceEmpty = false}) {
      if (_cachedApprovalPOs != null) {
        controller.add(_cachedApprovalPOs!);
      } else if (forceEmpty) {
        controller.add([]);
      }
    }

    void startSubscription() {
      try {
        _supabase
            .from('purchase_orders')
            .stream(primaryKey: ['id'])
            .eq('status', 'Approval')
            .listen(
              (data) {
                try {
                  final list = data.map((row) {
                    return PurchaseOrder.fromMap(row);
                  }).toList();
                  list.sort((a, b) => _extractPoNumber(a.code)
                      .compareTo(_extractPoNumber(b.code)));

                  // Cache the result
                  _cachedApprovalPOs = list;
                  unawaited(_savePOsToHive(
                      HiveStorage.poApprovalPOsBox, 'approval_pos', list));
                  controller.add(list);
                } catch (e) {
                  emitCachedOrEmpty(forceEmpty: true);
                }
              },
              onError: (error) {
                emitCachedOrEmpty(forceEmpty: true);
              },
            );
      } catch (e) {
        emitCachedOrEmpty(forceEmpty: true);
      }
    }

    controller
      ..onListen = () async {
        // 1. Check in-memory cache first
        emitCachedOrEmpty();

        // 2. If in-memory cache is null, auto-load from Hive
        if (_cachedApprovalPOs == null) {
          final hiveData = await _loadPOsFromHive(
              HiveStorage.poApprovalPOsBox, 'approval_pos');
          if (hiveData != null) {
            _cachedApprovalPOs = hiveData; // Populate in-memory cache
            controller.add(hiveData); // Emit immediately
          }
        }

        // 3. Subscribe to Supabase for updates
        startSubscription();
      }
      ..onCancel = () {
        // Cleanup handled automatically
      };

    return controller.stream;
  }

  Stream<List<PurchaseOrder>> getOpenPOsStream() {
    final controller = StreamController<List<PurchaseOrder>>.broadcast();

    void emitCachedOrEmpty({bool forceEmpty = false}) {
      if (_cachedOpenPOs != null) {
        controller.add(_cachedOpenPOs!);
      } else if (forceEmpty) {
        controller.add([]);
      }
    }

    void startSubscription() {
      try {
        _supabase
            .from('purchase_orders')
            .stream(primaryKey: ['id'])
            .eq('status', 'Open')
            .listen(
              (data) {
                try {
                  final list = data.map((row) {
                    return PurchaseOrder.fromMap(row);
                  }).toList();
                  // Filter to only include POs with pending supplies (no partial receives)
                  final filteredList = list.where((po) {
                    return po.supplies
                        .every((supply) => supply['status'] == 'Pending');
                  }).toList();
                  filteredList.sort((a, b) => _extractPoNumber(a.code)
                      .compareTo(_extractPoNumber(b.code)));

                  // Cache the result
                  _cachedOpenPOs = filteredList;
                  unawaited(_savePOsToHive(
                      HiveStorage.poOpenPOsBox, 'open_pos', filteredList));
                  controller.add(filteredList);
                } catch (e) {
                  emitCachedOrEmpty(forceEmpty: true);
                }
              },
              onError: (error) {
                emitCachedOrEmpty(forceEmpty: true);
              },
            );
      } catch (e) {
        emitCachedOrEmpty(forceEmpty: true);
      }
    }

    controller
      ..onListen = () async {
        // 1. Check in-memory cache first
        emitCachedOrEmpty();

        // 2. If in-memory cache is null, auto-load from Hive
        if (_cachedOpenPOs == null) {
          final hiveData =
              await _loadPOsFromHive(HiveStorage.poOpenPOsBox, 'open_pos');
          if (hiveData != null) {
            _cachedOpenPOs = hiveData; // Populate in-memory cache
            controller.add(hiveData); // Emit immediately
          }
        }

        // 3. Subscribe to Supabase for updates
        startSubscription();
      }
      ..onCancel = () {
        // Cleanup handled automatically
      };

    return controller.stream;
  }

  Stream<List<PurchaseOrder>> getPartialPOsStream() {
    final controller = StreamController<List<PurchaseOrder>>.broadcast();

    void emitCachedOrEmpty({bool forceEmpty = false}) {
      if (_cachedPartialPOs != null) {
        controller.add(_cachedPartialPOs!);
      } else if (forceEmpty) {
        controller.add([]);
      }
    }

    void startSubscription() {
      try {
        _supabase.from('purchase_orders').stream(primaryKey: ['id']).listen(
          (data) {
            try {
              final list = data.map((row) {
                return PurchaseOrder.fromMap(row);
              }).toList();
              // Filter to include POs with status "Partially Received" OR POs with status "Open" that have partially received supplies
              final filteredList = list.where((po) {
                // Include POs with "Partially Received" status
                if (po.status == 'Partially Received') {
                  return true;
                }
                // Include POs with "Open" status that have partially received or received supplies
                if (po.status == 'Open') {
                  return po.supplies.any((supply) =>
                      supply['status'] == 'Partially Received' ||
                      supply['status'] == 'Received');
                }
                return false;
              }).toList();
              filteredList.sort((a, b) =>
                  _extractPoNumber(a.code).compareTo(_extractPoNumber(b.code)));

              // Cache the result
              _cachedPartialPOs = filteredList;
              unawaited(_savePOsToHive(
                  HiveStorage.poPartialPOsBox, 'partial_pos', filteredList));
              controller.add(filteredList);
            } catch (e) {
              emitCachedOrEmpty(forceEmpty: true);
            }
          },
          onError: (error) {
            emitCachedOrEmpty(forceEmpty: true);
          },
        );
      } catch (e) {
        emitCachedOrEmpty(forceEmpty: true);
      }
    }

    controller
      ..onListen = () async {
        // 1. Check in-memory cache first
        emitCachedOrEmpty();

        // 2. If in-memory cache is null, auto-load from Hive
        if (_cachedPartialPOs == null) {
          final hiveData = await _loadPOsFromHive(
              HiveStorage.poPartialPOsBox, 'partial_pos');
          if (hiveData != null) {
            _cachedPartialPOs = hiveData; // Populate in-memory cache
            controller.add(hiveData); // Emit immediately
          }
        }

        // 3. Subscribe to Supabase for updates
        startSubscription();
      }
      ..onCancel = () {
        // Cleanup handled automatically
      };

    return controller.stream;
  }

  Stream<List<PurchaseOrder>> getAllPOsStream() {
    final controller = StreamController<List<PurchaseOrder>>.broadcast();

    void emitCachedOrEmpty({bool forceEmpty = false}) {
      if (_cachedAllPOs != null) {
        controller.add(_cachedAllPOs!);
      } else if (forceEmpty) {
        controller.add([]);
      }
    }

    void startSubscription() {
      try {
        _supabase
            .from('purchase_orders')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false)
            .listen(
              (data) {
                try {
                  final list = data.map((row) {
                    return PurchaseOrder.fromMap(row);
                  }).toList();

                  // Cache the result
                  _cachedAllPOs = list;
                  // Keep other cache buckets in sync so offline hydration matches
                  _cachedOpenPOs = list
                      .where((po) => po.status == 'Open')
                      .toList(growable: false);
                  _cachedApprovalPOs = list
                      .where((po) =>
                          po.status == 'Approval' ||
                          po.status == 'For Approval')
                      .toList(growable: false);
                  _cachedClosedPOs = list
                      .where((po) => po.status == 'Closed')
                      .toList(growable: false);
                  _cachedPartialPOs = list
                      .where((po) =>
                          po.status == 'Partially Received' ||
                          (po.status == 'Open' &&
                              po.supplies.any((supply) =>
                                  supply['status'] == 'Partially Received' ||
                                  supply['status'] == 'Received')))
                      .toList(growable: false);

                  // Save all caches to Hive
                  unawaited(_persistAllPurchaseOrders(list));
                  unawaited(_savePOsToHive(
                      HiveStorage.poOpenPOsBox, 'open_pos', _cachedOpenPOs!));
                  unawaited(_savePOsToHive(HiveStorage.poApprovalPOsBox,
                      'approval_pos', _cachedApprovalPOs!));
                  unawaited(_savePOsToHive(HiveStorage.poClosedPOsBox,
                      'closed_pos', _cachedClosedPOs!));
                  unawaited(_savePOsToHive(HiveStorage.poPartialPOsBox,
                      'partial_pos', _cachedPartialPOs!));

                  controller.add(list);
                } catch (e) {
                  emitCachedOrEmpty(forceEmpty: true);
                }
              },
              onError: (error) {
                emitCachedOrEmpty(forceEmpty: true);
              },
            );
      } catch (e) {
        emitCachedOrEmpty(forceEmpty: true);
      }
    }

    controller
      ..onListen = () async {
        // 1. Check in-memory cache first
        emitCachedOrEmpty();

        // 2. If in-memory cache is null, auto-load from Hive
        if (_cachedAllPOs == null) {
          final hiveData = await _loadAllPOsFromHive();
          if (hiveData != null && hiveData.isNotEmpty) {
            _cachedAllPOs = hiveData; // Populate in-memory cache
            // Keep other cache buckets in sync
            _cachedOpenPOs = hiveData
                .where((po) => po.status == 'Open')
                .toList(growable: false);
            _cachedApprovalPOs = hiveData
                .where((po) =>
                    po.status == 'Approval' || po.status == 'For Approval')
                .toList(growable: false);
            _cachedClosedPOs = hiveData
                .where((po) => po.status == 'Closed')
                .toList(growable: false);
            _cachedPartialPOs = hiveData
                .where((po) =>
                    po.status == 'Partially Received' ||
                    (po.status == 'Open' &&
                        po.supplies.any((supply) =>
                            supply['status'] == 'Partially Received' ||
                            supply['status'] == 'Received')))
                .toList(growable: false);
            controller.add(hiveData); // Emit immediately
          }
        }

        // 3. Subscribe to Supabase for updates
        startSubscription();
      }
      ..onCancel = () {
        // Cleanup handled automatically
      };

    return controller.stream;
  }

  Future<List<PurchaseOrder>> preloadFromLocalCache() async {
    try {
      // Load from Hive (new persistent cache)
      final localPOs = await getAll();
      if (localPOs.isNotEmpty) {
        _cachedAllPOs = localPOs;
        _cachedOpenPOs =
            localPOs.where((po) => po.status == 'Open').toList(growable: false);
        _cachedPartialPOs = localPOs
            .where((po) =>
                po.status == 'Partially Received' ||
                (po.status == 'Open' &&
                    po.supplies.any((supply) =>
                        supply['status'] == 'Partially Received' ||
                        supply['status'] == 'Received')))
            .toList(growable: false);
        _cachedApprovalPOs = localPOs
            .where(
                (po) => po.status == 'Approval' || po.status == 'For Approval')
            .toList(growable: false);
        _cachedClosedPOs = localPOs
            .where((po) => po.status == 'Closed')
            .toList(growable: false);

        // Save individual caches to Hive for faster access
        unawaited(_savePOsToHive(
            HiveStorage.poOpenPOsBox, 'open_pos', _cachedOpenPOs!));
        unawaited(_savePOsToHive(
            HiveStorage.poPartialPOsBox, 'partial_pos', _cachedPartialPOs!));
        unawaited(_savePOsToHive(
            HiveStorage.poApprovalPOsBox, 'approval_pos', _cachedApprovalPOs!));
        unawaited(_savePOsToHive(
            HiveStorage.poClosedPOsBox, 'closed_pos', _cachedClosedPOs!));
      }
      return localPOs;
    } catch (e) {
      return _cachedAllPOs ?? <PurchaseOrder>[];
    }
  }

  Future<PurchaseOrder?> getPOByIdFromSupabase(String id) async {
    try {
      final response = await _supabase
          .from('purchase_orders')
          .select('*')
          .eq('id', id)
          .single();
      return PurchaseOrder.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  Future<void> updatePOInSupabase(PurchaseOrder po) async {
    try {
      await _supabase
          .from('purchase_orders')
          .update(po.toMap())
          .eq('id', po.id);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePOFromSupabase(String id) async {
    try {
      await _supabase.from('purchase_orders').delete().eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  // ===== ANALYTICS OPERATIONS =====

  Future<int> getClosedPOCount() async {
    try {
      final response = await _supabase
          .from('purchase_orders')
          .select('id')
          .eq('status', 'Closed');
      return response.length;
    } catch (e) {
      return 0;
    }
  }

  Future<double> getClosedPOTotalValue() async {
    try {
      final response = await _supabase
          .from('purchase_orders')
          .select('*')
          .eq('status', 'Closed');

      double totalValue = 0.0;
      for (final row in response) {
        final po = PurchaseOrder.fromMap(row);
        for (final supply in po.supplies) {
          final cost = (supply['cost'] ?? 0.0).toDouble();
          final quantity = (supply['quantity'] ?? 0).toInt();
          totalValue += cost * quantity;
        }
      }
      return totalValue;
    } catch (e) {
      return 0.0;
    }
  }

  Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final closedCount = await getClosedPOCount();
      final totalValue = await getClosedPOTotalValue();

      return {
        'closedCount': closedCount,
        'totalValue': totalValue,
      };
    } catch (e) {
      return {
        'closedCount': 0,
        'totalValue': 0.0,
      };
    }
  }

  // ===== MIGRATION OPERATIONS =====

  Future<void> migrateClosedPOsToSupabase() async {
    try {
      final allPOs = await getAll();
      final closedPOs = allPOs.where((po) => po.status == 'Closed').toList();

      for (final po in closedPOs) {
        try {
          await saveClosedPOToSupabase(po);
        } catch (e) {
          // Error handling
        }
      }
    } catch (e) {
      // Error handling
    }
  }

  Future<void> syncAllLocalPOsToSupabase() async {
    try {
      final allPOs = await getAll();

      for (final po in allPOs) {
        try {
          await savePOToSupabase(po);
        } catch (e) {
          // Error handling
        }
      }
    } catch (e) {
      // Error handling
    }
  }

  // ===== UTILITY OPERATIONS =====

  Future<void> resetSequence() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sequenceKey);
  }

  Future<int> getCurrentSequence() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_sequenceKey) ?? 0;
    return current;
  }
}
