import '../data/purchase_order.dart';
import 'po_firebase_controller.dart';
import 'po_calculations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  }

  // Update existing PO
  Future<void> updatePO(PurchaseOrder po) async {
    await _poController.updatePOInFirebase(po);
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
      final cost = supply['cost'] ?? 0.0;

      if (supplyName.trim().isEmpty || quantity <= 0 || cost <= 0) {
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
