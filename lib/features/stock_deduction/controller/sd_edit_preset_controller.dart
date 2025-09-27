import 'package:familee_dental/features/stock_deduction/controller/sd_preset_management_controller.dart';

class SdEditPresetController {
  final PresetController _presetController = PresetController();

  // Extract existing document IDs from preset supplies
  List<String> extractExistingDocIds(
      List<Map<String, dynamic>> presetSupplies) {
    return presetSupplies
        .map((e) => (e['docId']?.toString() ?? ''))
        .where((id) => id.isNotEmpty)
        .toList();
  }

  // Check if a supply is already in the current preset
  bool isSupplyInPreset(
      Map<String, dynamic> supply, List<Map<String, dynamic>> presetSupplies) {
    final docId = supply['docId']?.toString();
    return presetSupplies.any((e) => e['docId'] == docId);
  }

  // Check if any supplies in a list are already in the current preset
  bool hasDuplicateSupplies(
      List<dynamic> supplies, List<Map<String, dynamic>> presetSupplies) {
    for (final dynamic supply in supplies) {
      if (supply is Map<String, dynamic>) {
        if (isSupplyInPreset(supply, presetSupplies)) {
          return true;
        }
      }
    }
    return false;
  }

  // Get the name of the first duplicate supply
  String? getFirstDuplicateSupplyName(
      List<dynamic> supplies, List<Map<String, dynamic>> presetSupplies) {
    for (final dynamic supply in supplies) {
      if (supply is Map<String, dynamic>) {
        if (isSupplyInPreset(supply, presetSupplies)) {
          return supply['name']?.toString() ?? 'This supply';
        }
      }
    }
    return null;
  }

  // Validate preset name is not empty
  bool isPresetNameEmpty(String presetName) {
    return presetName.trim().isEmpty;
  }

  // Validate preset has supplies
  bool isPresetEmpty(List<Map<String, dynamic>> presetSupplies) {
    return presetSupplies.isEmpty;
  }

  // Check if preset name has changed
  bool hasNameChanged(String newName, String originalName) {
    return newName.toLowerCase() != originalName.toLowerCase();
  }

  // Check if preset name already exists
  Future<bool> isPresetNameExists(String presetName) async {
    return await _presetController.isPresetNameExists(presetName.trim());
  }

  // Check if exact supply set already exists (excluding current preset)
  Future<bool> isExactSupplySetExists(List<Map<String, dynamic>> presetSupplies,
      {String? excludePresetId}) async {
    return await _presetController.isExactSupplySetExists(presetSupplies,
        excludePresetId: excludePresetId);
  }

  // Create updated preset data structure
  Map<String, dynamic> createUpdatedPresetData(
      Map<String, dynamic> originalPreset,
      String presetName,
      List<Map<String, dynamic>> presetSupplies) {
    return {
      ...originalPreset,
      'name': presetName,
      'supplies': presetSupplies,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // Check if there are unsaved changes
  bool hasUnsavedChanges(String newName, List<Map<String, dynamic>> newSupplies,
      String originalName, List<Map<String, dynamic>> originalSupplies) {
    return newName.trim() != originalName ||
        newSupplies.length != originalSupplies.length;
  }

  // Extract supply name from result
  String extractSupplyName(Map<String, dynamic> result) {
    return result['name']?.toString() ?? 'This supply';
  }

  // Process supplies result and return valid supplies
  List<Map<String, dynamic>> processSuppliesResult(List<dynamic> result) {
    final List<Map<String, dynamic>> validSupplies = [];
    for (final dynamic r in result) {
      if (r is Map<String, dynamic>) {
        validSupplies.add(r);
      }
    }
    return validSupplies;
  }

  // Update preset in Supabase
  Future<void> updatePreset(
      String presetId, Map<String, dynamic> updatedPreset) async {
    await _presetController.updatePreset(presetId, updatedPreset);
  }

  // Process add supply result and handle duplicates
  Map<String, dynamic>? processAddSupplyResult(
      dynamic result, List<Map<String, dynamic>> presetSupplies) {
    if (result is Map<String, dynamic>) {
      if (isSupplyInPreset(result, presetSupplies)) {
        return {'isDuplicate': true, 'supplyName': extractSupplyName(result)};
      }
      return {'isDuplicate': false, 'supply': result};
    } else if (result is List) {
      if (hasDuplicateSupplies(result, presetSupplies)) {
        final duplicateName =
            getFirstDuplicateSupplyName(result, presetSupplies);
        return {
          'isDuplicate': true,
          'supplyName': duplicateName ?? 'This supply'
        };
      }
      final validSupplies = processSuppliesResult(result);
      return {'isDuplicate': false, 'supplies': validSupplies};
    }
    return null;
  }

  // Validate preset data before saving
  Map<String, dynamic> validatePresetData(
      String presetName, List<Map<String, dynamic>> presetSupplies) {
    if (isPresetNameEmpty(presetName)) {
      return {'isValid': false, 'error': 'Please enter a preset name'};
    }
    if (isPresetEmpty(presetSupplies)) {
      return {
        'isValid': false,
        'error': 'Please add at least one supply to the preset'
      };
    }
    return {'isValid': true};
  }

  // Remove supply from preset
  List<Map<String, dynamic>> removeSupplyFromPreset(
      List<Map<String, dynamic>> presetSupplies, int index) {
    final updatedSupplies = List<Map<String, dynamic>>.from(presetSupplies);
    updatedSupplies.removeAt(index);
    return updatedSupplies;
  }

  // Add single supply to preset
  List<Map<String, dynamic>> addSupplyToPreset(
      List<Map<String, dynamic>> presetSupplies, Map<String, dynamic> supply) {
    final updatedSupplies = List<Map<String, dynamic>>.from(presetSupplies);
    updatedSupplies.add(supply);
    return updatedSupplies;
  }

  // Add multiple supplies to preset
  List<Map<String, dynamic>> addSuppliesToPreset(
      List<Map<String, dynamic>> presetSupplies,
      List<Map<String, dynamic>> supplies) {
    final updatedSupplies = List<Map<String, dynamic>>.from(presetSupplies);
    updatedSupplies.addAll(supplies);
    return updatedSupplies;
  }

  // Get original supplies as Map list
  List<Map<String, dynamic>> getOriginalSupplies(
      Map<String, dynamic> originalPreset) {
    final originalSupplies =
        (originalPreset['supplies'] as List<dynamic>?) ?? [];
    return originalSupplies
        .map((supply) =>
            supply is Map<String, dynamic> ? supply : <String, dynamic>{})
        .toList();
  }

  // Detect field changes between original and updated preset
  Map<String, dynamic> detectFieldChanges(
    Map<String, dynamic> originalPreset,
    String newPresetName,
    List<Map<String, dynamic>> newSupplies,
  ) {
    final Map<String, dynamic> fieldChanges = {};

    // Check if preset name changed
    final originalName = originalPreset['name']?.toString() ?? '';
    if (originalName != newPresetName) {
      fieldChanges['Name'] = {
        'previous': originalName,
        'new': newPresetName,
      };
    }

    // Check if supplies changed (simplified - just count for now)
    final originalSupplies =
        (originalPreset['supplies'] as List<dynamic>?) ?? [];
    if (originalSupplies.length != newSupplies.length) {
      fieldChanges['Supplies Count'] = {
        'previous': originalSupplies.length.toString(),
        'new': newSupplies.length.toString(),
      };
    }

    return fieldChanges;
  }
}
