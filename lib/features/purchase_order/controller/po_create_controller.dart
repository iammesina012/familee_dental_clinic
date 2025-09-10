import '../data/purchase_order.dart';
import 'po_firebase_controller.dart';
import 'po_calculations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:projects/features/activity_log/controller/po_activity_controller.dart';

class CreatePOController {
  final POFirebaseController _poController = POFirebaseController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _suggestionsCollection = 'po_suggestions';

  // Get next PO code and increment sequence
  Future<String> getNextCodeAndIncrement() async {
    return await _poController.getNextCodeAndIncrement();
  }

  // Save new PO
  Future<void> savePO(PurchaseOrder po) async {
    await _poController.save(po);

    // Log the purchase order creation activity
    await PoActivityController().logPurchaseOrderCreated(
      poCode: po.code,
      poName: po.name,
      supplies: po.supplies,
    );
  }

  // Update existing PO
  Future<void> updatePO(PurchaseOrder po, {PurchaseOrder? previousPO}) async {
    // Build field changes by comparing with the existing PO BEFORE updating
    Map<String, Map<String, dynamic>> fieldChanges = {};
    // Prefer the previousPO passed in from the edit page; fall back to fetch
    PurchaseOrder? baseline = previousPO;
    baseline ??= await _poController.getPOByIdFromFirebase(po.id);

    if (baseline != null) {
      // Compare PO Name
      if ((baseline.name).toString().trim() != (po.name).toString().trim()) {
        fieldChanges['Name'] = {
          'previous': baseline.name,
          'new': po.name,
        };
      }

      // Compare supplies count
      if ((baseline.supplies.length) != (po.supplies.length)) {
        fieldChanges['Supplies Count'] = {
          'previous': baseline.supplies.length,
          'new': po.supplies.length,
        };
      }

      // Per-item quantity differences: match by name and record specific changes
      String? nameOf(Map<String, dynamic> s) =>
          (s['supplyName'] ?? s['name'])?.toString();
      int qtyOf(Map<String, dynamic> s) {
        final q = s['quantity'];
        if (q is int) return q;
        if (q is num) return q.toInt();
        return 0;
      }

      final Map<String, Map<String, dynamic>> baselineByName = {
        for (final s in baseline.supplies)
          if (nameOf(s) != null) nameOf(s)!: s,
      };
      final Map<String, Map<String, dynamic>> updatedByName = {
        for (final s in po.supplies)
          if (nameOf(s) != null) nameOf(s)!: s,
      };

      for (final entry in baselineByName.entries) {
        final oldName = entry.key;
        final oldSupply = entry.value;
        final newSupply = updatedByName[oldName];
        if (newSupply != null) {
          // Quantity change
          final oldQty = qtyOf(oldSupply);
          final newQty = qtyOf(newSupply);
          if (oldQty != newQty) {
            fieldChanges['Quantity::$oldName'] = {
              'previous': oldQty,
              'new': newQty,
            };
          }

          // Supplier name change
          final oldSupplier =
              (oldSupply['supplierName'] ?? oldSupply['supplier'])
                      ?.toString() ??
                  'N/A';
          final newSupplier =
              (newSupply['supplierName'] ?? newSupply['supplier'])
                      ?.toString() ??
                  'N/A';
          if (oldSupplier != newSupplier) {
            fieldChanges['Supplier Name::$oldName'] = {
              'previous': oldSupplier,
              'new': newSupplier,
            };
          }

          // Brand name change (optional, for completeness)
          final oldBrand =
              (oldSupply['brandName'] ?? oldSupply['brand'])?.toString() ??
                  'N/A';
          final newBrand =
              (newSupply['brandName'] ?? newSupply['brand'])?.toString() ??
                  'N/A';
          if (oldBrand != newBrand) {
            fieldChanges['Brand Name::$oldName'] = {
              'previous': oldBrand,
              'new': newBrand,
            };
          }

          // Cost change
          final oldCostNum = (oldSupply['cost'] ?? 0) as num;
          final newCostNum = (newSupply['cost'] ?? 0) as num;
          if (oldCostNum.toDouble() != newCostNum.toDouble()) {
            fieldChanges['Subtotal::$oldName'] = {
              'previous': oldCostNum,
              'new': newCostNum,
            };
          }

          // Expiry date change
          final oldExpiry =
              (oldSupply['expiryDate'] ?? 'No expiry date').toString();
          final newExpiry =
              (newSupply['expiryDate'] ?? 'No expiry date').toString();
          if (oldExpiry != newExpiry) {
            fieldChanges['Expiry Date::$oldName'] = {
              'previous': oldExpiry,
              'new': newExpiry,
            };
          }
        }
      }

      // Compare first supply name if available (best-effort signal)
      final oldFirst = baseline.supplies.isNotEmpty
          ? (baseline.supplies.first['supplyName'] ??
              baseline.supplies.first['name'])
          : null;
      final newFirst = po.supplies.isNotEmpty
          ? (po.supplies.first['supplyName'] ?? po.supplies.first['name'])
          : null;
      if (oldFirst != null &&
          newFirst != null &&
          oldFirst.toString() != newFirst.toString()) {
        fieldChanges['First Supply'] = {
          'previous': oldFirst,
          'new': newFirst,
        };
      }
    }

    // Persist the update
    await _poController.updatePOInFirebase(po);

    // Log the purchase order edited activity
    await PoActivityController().logPurchaseOrderEdited(
      poCode: po.code,
      poName: po.name,
      supplies: po.supplies,
      fieldChanges: fieldChanges.isEmpty ? null : fieldChanges,
    );
  }

  // Validate PO data
  bool validatePOData(String name, List<Map<String, dynamic>> supplies) {
    if (name.trim().isEmpty) {
      return false;
    }
    if (supplies.isEmpty) {
      return false;
    }

    // Validate each supply
    for (final supply in supplies) {
      final supplyName = supply['supplyName'] ?? supply['name'] ?? '';
      final quantity = supply['quantity'] ?? 0;
      if (supplyName.toString().trim().isEmpty || quantity is! int) {
        return false;
      }
    }

    return true;
  }

  // Create PO object from form data
  PurchaseOrder createPOFromData(
    String code,
    String name,
    List<Map<String, dynamic>> supplies,
  ) {
    return PurchaseOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      code: code,
      name: name,
      createdAt: DateTime.now(),
      status: 'Open',
      supplies: supplies,
      receivedCount: 0,
    );
  }

  // Calculate total cost of supplies
  double calculateTotalCost(List<Map<String, dynamic>> supplies) {
    // Create a temporary PO object to use the centralized method
    final tempPO = PurchaseOrder(
      id: '',
      code: '',
      name: '',
      status: '',
      supplies: supplies,
      receivedCount: 0,
      createdAt: DateTime.now(),
    );
    return POBusinessService.calculateTotalCost(tempPO);
  }

  // Validate supply data
  bool validateSupplyData(Map<String, dynamic> supply) {
    final supplyName = supply['supplyName'] ?? supply['name'] ?? '';
    final brandName = supply['brandName'] ?? supply['brand'] ?? '';
    final supplierName = supply['supplierName'] ?? supply['supplier'] ?? '';
    final quantity = supply['quantity'] ?? 0;
    final cost = supply['cost'] ?? 0.0;

    return supplyName.trim().isNotEmpty &&
        brandName.trim().isNotEmpty &&
        supplierName.trim().isNotEmpty &&
        quantity > 0 &&
        cost > 0;
  }

  // Format currency
  String formatCurrency(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }

  // ===== SUGGESTIONS METHODS =====

  // Get suggestions based on input text
  Future<List<String>> getSuggestions(String input) async {
    if (input.trim().isEmpty) return [];

    final suggestions = await _getAllSuggestions();
    final query = input.toLowerCase().trim();

    // Filter suggestions that contain the input text
    final filtered = suggestions
        .where((suggestion) => suggestion.toLowerCase().contains(query))
        .toList();

    // Return top 5 suggestions (already sorted by frequency from Firebase)
    return filtered.take(5).toList();
  }

  // Add a new PO name to suggestions (called when PO is saved)
  Future<void> addSuggestion(String poName) async {
    if (poName.trim().isEmpty) return;

    final normalizedName = poName.trim();

    // Increment frequency (this will create or update the suggestion)
    await _incrementFrequency(normalizedName);
  }

  // Get all suggestions from Firebase
  Future<List<String>> _getAllSuggestions() async {
    try {
      final querySnapshot = await _firestore
          .collection(_suggestionsCollection)
          .orderBy('frequency', descending: true)
          .limit(20)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data()['name'] as String)
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Save suggestion to Firebase
  Future<void> _saveSuggestion(String name, int frequency) async {
    try {
      await _firestore
          .collection(_suggestionsCollection)
          .doc(name.toLowerCase().replaceAll(' ', '_'))
          .set({
        'name': name,
        'frequency': frequency,
        'lastUsed': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Handle error silently
    }
  }

  // Get frequency of a suggestion from Firebase
  Future<int> _getFrequency(String name) async {
    try {
      final doc = await _firestore
          .collection(_suggestionsCollection)
          .doc(name.toLowerCase().replaceAll(' ', '_'))
          .get();

      if (doc.exists) {
        return doc.data()?['frequency'] ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Increment frequency for a suggestion in Firebase
  Future<void> _incrementFrequency(String name) async {
    try {
      final docRef = _firestore
          .collection(_suggestionsCollection)
          .doc(name.toLowerCase().replaceAll(' ', '_'));

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        if (doc.exists) {
          // Increment existing frequency
          final currentFreq = doc.data()?['frequency'] ?? 0;
          transaction.update(docRef, {
            'frequency': currentFreq + 1,
            'lastUsed': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new suggestion with frequency 1
          transaction.set(docRef, {
            'name': name,
            'frequency': 1,
            'lastUsed': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      // Handle error silently
    }
  }

  // Initialize suggestions (no defaults, only from previous PO names)
  Future<void> initializeDefaultSuggestions() async {
    // This method now does nothing - suggestions will be populated
    // only when users create POs and the names are added via addSuggestion()
    // Suggestions are now stored in Firebase for multi-user sync
  }
}
