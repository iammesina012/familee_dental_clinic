import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/purchase_order.dart';

class POFirebaseController {
  static const String _storageKey = 'purchase_orders_v1';
  static const String _sequenceKey = 'purchase_order_sequence_v1';

  final FirebaseFirestore _firestore;

  POFirebaseController({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

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

    // Save ALL POs to Firebase (not just closed ones)
    try {
      await savePOToFirebase(po);
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

      // Update Firebase immediately for real-time updates
      try {
        await updatePOInFirebase(updatedPO);
      } catch (e) {
        // Error handling
      }
    }
  }

  // Update PO status in Firebase only (for real-time updates)
  Future<void> updatePOStatusInFirebase(String poId, String newStatus) async {
    try {
      await _firestore
          .collection('purchase_orders')
          .doc(poId)
          .update({'status': newStatus});
    } catch (e) {
      rethrow;
    }
  }

  Future<String> getNextCodeAndIncrement() async {
    try {
      // Prefer Firebase as the source of truth to respect deletions
      final snapshot = await _firestore.collection('purchase_orders').get();

      final Set<int> existingNumbers = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final code = (data['code'] ?? '').toString();
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
      // Fallback to local storage if Firebase read fails
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

      // Clear Firebase data
      final snapshot = await _firestore.collection('purchase_orders').get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      rethrow;
    }
  }

  // ===== FIREBASE OPERATIONS =====

  Future<void> savePOToFirebase(PurchaseOrder po) async {
    try {
      await _firestore.collection('purchase_orders').doc(po.id).set(po.toMap());
    } catch (e) {
      rethrow;
    }
  }

  // Keep the old method for backward compatibility
  Future<void> saveClosedPOToFirebase(PurchaseOrder po) async {
    return savePOToFirebase(po);
  }

  Stream<List<PurchaseOrder>> getClosedPOsStream() {
    return _firestore
        .collection('purchase_orders')
        .where('status', isEqualTo: 'Closed')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        return PurchaseOrder.fromMap(data);
      }).toList();
      list.sort((a, b) =>
          _extractPoNumber(a.code).compareTo(_extractPoNumber(b.code)));
      return list;
    });
  }

  Stream<List<PurchaseOrder>> getApprovalPOsStream() {
    return _firestore
        .collection('purchase_orders')
        .where('status', isEqualTo: 'Approval')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        return PurchaseOrder.fromMap(data);
      }).toList();
      list.sort((a, b) =>
          _extractPoNumber(a.code).compareTo(_extractPoNumber(b.code)));
      return list;
    });
  }

  Stream<List<PurchaseOrder>> getOpenPOsStream() {
    return _firestore
        .collection('purchase_orders')
        .where('status', isEqualTo: 'Open')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        return PurchaseOrder.fromMap(data);
      }).toList();
      list.sort((a, b) =>
          _extractPoNumber(a.code).compareTo(_extractPoNumber(b.code)));
      return list;
    });
  }

  Stream<List<PurchaseOrder>> getAllPOsStream() {
    return _firestore
        .collection('purchase_orders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return PurchaseOrder.fromMap(data);
      }).toList();
    });
  }

  Future<PurchaseOrder?> getPOByIdFromFirebase(String id) async {
    try {
      final doc = await _firestore.collection('purchase_orders').doc(id).get();
      if (doc.exists) {
        return PurchaseOrder.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> updatePOInFirebase(PurchaseOrder po) async {
    try {
      await _firestore
          .collection('purchase_orders')
          .doc(po.id)
          .set(po.toMap(), SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePOFromFirebase(String id) async {
    try {
      await _firestore.collection('purchase_orders').doc(id).delete();
    } catch (e) {
      rethrow;
    }
  }

  // ===== ANALYTICS OPERATIONS =====

  Future<int> getClosedPOCount() async {
    try {
      final snapshot = await _firestore
          .collection('purchase_orders')
          .where('status', isEqualTo: 'Closed')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<double> getClosedPOTotalValue() async {
    try {
      final snapshot = await _firestore
          .collection('purchase_orders')
          .where('status', isEqualTo: 'Closed')
          .get();

      double totalValue = 0.0;
      for (final doc in snapshot.docs) {
        final po = PurchaseOrder.fromMap(doc.data());
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

  Future<void> migrateClosedPOsToFirebase() async {
    try {
      final allPOs = await getAll();
      final closedPOs = allPOs.where((po) => po.status == 'Closed').toList();

      for (final po in closedPOs) {
        try {
          await saveClosedPOToFirebase(po);
        } catch (e) {
          // Error handling
        }
      }
    } catch (e) {
      // Error handling
    }
  }

  Future<void> syncAllLocalPOsToFirebase() async {
    try {
      final allPOs = await getAll();

      for (final po in allPOs) {
        try {
          await savePOToFirebase(po);
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
