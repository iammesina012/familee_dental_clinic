import 'package:flutter/material.dart';
import 'package:projects/features/stock_deduction/controller/sd_preset_management_controller.dart';

class SdCreatePresetController {
  final PresetController _presetController = PresetController();

  // Extract existing document IDs from preset supplies
  List<String> extractExistingDocIds(
      List<Map<String, dynamic>> presetSupplies) {
    return presetSupplies
        .map((e) => (e['docId'] ?? '').toString())
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

  // Check if preset name already exists
  Future<bool> isPresetNameExists(String presetName) async {
    return await _presetController.isPresetNameExists(presetName.trim());
  }

  // Check if exact supply set already exists
  Future<bool> isExactSupplySetExists(
      List<Map<String, dynamic>> presetSupplies) async {
    return await _presetController.isExactSupplySetExists(presetSupplies);
  }

  // Create preset data structure
  Map<String, dynamic> createPresetData(
      String presetName, List<Map<String, dynamic>> presetSupplies) {
    return {
      'name': presetName.trim(),
      'supplies': presetSupplies,
      'createdAt': DateTime.now().toString().split(' ')[0], // YYYY-MM-DD format
    };
  }

  // Check if there are unsaved changes
  bool hasUnsavedChanges(
      String presetName, List<Map<String, dynamic>> presetSupplies) {
    return presetName.trim().isNotEmpty || presetSupplies.isNotEmpty;
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
}
