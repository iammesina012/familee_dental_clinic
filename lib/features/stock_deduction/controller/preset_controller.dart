import 'package:cloud_firestore/cloud_firestore.dart';

class PresetController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'stock_deduction_presets';

  // Get all presets as a stream
  Stream<List<Map<String, dynamic>>> getPresetsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Ensure ID is included
        return data;
      }).toList();
    });
  }

  // Save a new preset to Firebase
  Future<void> savePreset(Map<String, dynamic> presetData) async {
    try {
      // Remove the temporary ID if it exists
      final dataToSave = Map<String, dynamic>.from(presetData);
      if (dataToSave.containsKey('id')) {
        dataToSave.remove('id');
      }

      // Add timestamp for ordering
      dataToSave['createdAt'] = FieldValue.serverTimestamp();

      await _firestore.collection(_collection).add(dataToSave);
    } catch (e) {
      throw Exception('Failed to save preset: $e');
    }
  }

  // Delete a preset
  Future<void> deletePreset(String presetId) async {
    try {
      await _firestore.collection(_collection).doc(presetId).delete();
    } catch (e) {
      throw Exception('Failed to delete preset: $e');
    }
  }

  // Get a specific preset by ID
  Future<Map<String, dynamic>?> getPresetById(String presetId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(presetId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get preset: $e');
    }
  }

  // Update a preset
  Future<void> updatePreset(
      String presetId, Map<String, dynamic> presetData) async {
    try {
      // Remove the ID from the data to avoid conflicts
      final dataToUpdate = Map<String, dynamic>.from(presetData);
      if (dataToUpdate.containsKey('id')) {
        dataToUpdate.remove('id');
      }

      dataToUpdate['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(_collection)
          .doc(presetId)
          .update(dataToUpdate);
    } catch (e) {
      throw Exception('Failed to update preset: $e');
    }
  }

  // Check if a preset name already exists (case-insensitive)
  Future<bool> isPresetNameExists(String presetName) async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();

      final normalizedInputName = presetName.trim().toLowerCase();

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final existingName = data['name']?.toString() ?? '';
        if (existingName.toLowerCase() == normalizedInputName) {
          return true; // Case-insensitive match found
        }
      }

      return false; // No match found
    } catch (e) {
      throw Exception('Failed to check preset name: $e');
    }
  }

  // Check if the exact set of supplies already exists in any preset
  Future<bool> isExactSupplySetExists(List<Map<String, dynamic>> newSupplies,
      {String? excludePresetId}) async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();

      // Create a set of supply names from the new preset
      final Set<String> newSupplyNames = {};
      for (final supply in newSupplies) {
        final name = supply['name']?.toString() ?? '';
        if (name.isNotEmpty) {
          newSupplyNames.add(name);
        }
      }

      // Check each existing preset
      for (final doc in querySnapshot.docs) {
        // Skip the preset being edited if excludePresetId is provided
        if (excludePresetId != null && doc.id == excludePresetId) {
          continue;
        }

        final data = doc.data();
        final existingSupplies = data['supplies'] as List<dynamic>? ?? [];

        // Create a set of supply names from the existing preset
        final Set<String> existingSupplyNames = {};
        for (final supply in existingSupplies) {
          if (supply is Map<String, dynamic>) {
            final name = supply['name']?.toString() ?? '';
            if (name.isNotEmpty) {
              existingSupplyNames.add(name);
            }
          }
        }

        // Check if the sets are exactly the same
        if (newSupplyNames.length == existingSupplyNames.length &&
            newSupplyNames.containsAll(existingSupplyNames)) {
          return true; // Exact duplicate found
        }
      }

      return false; // No exact duplicate found
    } catch (e) {
      throw Exception('Failed to check existing supply sets: $e');
    }
  }
}
