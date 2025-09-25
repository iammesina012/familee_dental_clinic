import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:projects/features/purchase_order/data/purchase_order.dart';

class POSupabaseController {
  static const String _storageKey = 'purchase_orders_v1';
  static const String _sequenceKey = 'purchase_order_sequence_v1';

  final SupabaseClient _supabase = Supabase.instance.client;

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
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey) ?? <String>[];
    return jsonList.map((e) => PurchaseOrder.fromJson(e)).toList();
  }

  Future<void> save(PurchaseOrder po) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await getAll();
    // replace if same id
    final idx = all.indexWhere((p) => p.id == po.id);
    if (idx >= 0) {
      all[idx] = po;
    } else {
      all.add(po);
    }
    final jsonList = all.map((e) => e.toJson()).toList();
    await prefs.setStringList(_storageKey, jsonList);

    // Save ALL POs to Supabase (not just closed ones)
    try {
      await savePOToSupabase(po);
    } catch (e) {
      // Don't rethrow - local save was successful
    }
  }

  Future<void> updatePOStatus(String poId, String newStatus) async {
    final prefs = await SharedPreferences.getInstance();
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
      final jsonList = all.map((e) => e.toJson()).toList();
      await prefs.setStringList(_storageKey, jsonList);

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
      // Clear local storage
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
    return _supabase
        .from('purchase_orders')
        .stream(primaryKey: ['id'])
        .eq('status', 'Closed')
        .map((data) {
          final list = data.map((row) {
            return PurchaseOrder.fromMap(row);
          }).toList();
          list.sort((a, b) =>
              _extractPoNumber(a.code).compareTo(_extractPoNumber(b.code)));
          return list;
        });
  }

  Stream<List<PurchaseOrder>> getApprovalPOsStream() {
    return _supabase
        .from('purchase_orders')
        .stream(primaryKey: ['id'])
        .eq('status', 'Approval')
        .map((data) {
          final list = data.map((row) {
            return PurchaseOrder.fromMap(row);
          }).toList();
          list.sort((a, b) =>
              _extractPoNumber(a.code).compareTo(_extractPoNumber(b.code)));
          return list;
        });
  }

  Stream<List<PurchaseOrder>> getOpenPOsStream() {
    return _supabase
        .from('purchase_orders')
        .stream(primaryKey: ['id'])
        .eq('status', 'Open')
        .map((data) {
          final list = data.map((row) {
            return PurchaseOrder.fromMap(row);
          }).toList();
          list.sort((a, b) =>
              _extractPoNumber(a.code).compareTo(_extractPoNumber(b.code)));
          return list;
        });
  }

  Stream<List<PurchaseOrder>> getAllPOsStream() {
    return _supabase
        .from('purchase_orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          return data.map((row) {
            return PurchaseOrder.fromMap(row);
          }).toList();
        });
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
