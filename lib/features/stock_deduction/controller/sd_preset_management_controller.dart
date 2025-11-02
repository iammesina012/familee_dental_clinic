import 'package:supabase_flutter/supabase_flutter.dart';

class PresetController {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _table = 'stock_deduction_presets';

  // Get all presets as a stream
  Stream<List<Map<String, dynamic>>> getPresetsStream() {
    return _supabase
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          return data.map((row) {
            return row;
          }).toList();
        });
  }

  // Save a new preset to Supabase
  Future<void> savePreset(Map<String, dynamic> presetData) async {
    try {
      // Remove the temporary ID if it exists
      final dataToSave = Map<String, dynamic>.from(presetData);
      if (dataToSave.containsKey('id')) {
        dataToSave.remove('id');
      }

      // Add timestamp for ordering
      dataToSave['created_at'] = DateTime.now().toIso8601String();

      await _supabase.from(_table).insert(dataToSave);
    } catch (e) {
      throw Exception('Failed to save preset: $e');
    }
  }

  // Delete a preset
  Future<void> deletePreset(String presetId) async {
    try {
      await _supabase.from(_table).delete().eq('id', presetId);
    } catch (e) {
      throw Exception('Failed to delete preset: $e');
    }
  }

  // Get a specific preset by ID
  Future<Map<String, dynamic>?> getPresetById(String presetId) async {
    try {
      final response =
          await _supabase.from(_table).select('*').eq('id', presetId).single();
      return response;
    } catch (e) {
      return null;
    }
  }

  // Get a specific preset by name (case-insensitive)
  Future<Map<String, dynamic>?> getPresetByName(String presetName) async {
    try {
      final response = await _supabase
          .from(_table)
          .select('*')
          .ilike('name', presetName.trim())
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
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

      dataToUpdate['updated_at'] = DateTime.now().toIso8601String();

      await _supabase.from(_table).update(dataToUpdate).eq('id', presetId);
    } catch (e) {
      throw Exception('Failed to update preset: $e');
    }
  }

  // Check if a preset name already exists (case-insensitive)
  Future<bool> isPresetNameExists(String presetName) async {
    try {
      final response = await _supabase
          .from(_table)
          .select('name')
          .ilike('name', presetName.trim());

      return response.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check preset name: $e');
    }
  }

  // Check if the exact set of supplies already exists in any preset
  Future<bool> isExactSupplySetExists(List<Map<String, dynamic>> newSupplies,
      {String? excludePresetId}) async {
    try {
      final response = await _supabase.from(_table).select('id, supplies');

      // Create a set of supply names from the new preset
      final Set<String> newSupplyNames = {};
      for (final supply in newSupplies) {
        final name = supply['name']?.toString() ?? '';
        if (name.isNotEmpty) {
          newSupplyNames.add(name);
        }
      }

      // Check each existing preset
      for (final row in response) {
        // Skip the preset being edited if excludePresetId is provided
        if (excludePresetId != null && row['id'] == excludePresetId) {
          continue;
        }

        final existingSupplies = row['supplies'] as List<dynamic>? ?? [];

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
