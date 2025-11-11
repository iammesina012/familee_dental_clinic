import 'package:flutter/material.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/inventory/controller/catalog_controller.dart';

class SdAddSupplyController {
  final CatalogController _catalogController = CatalogController();

  // Data transformation logic
  Map<String, dynamic> toReturnMap(InventoryItem item) {
    return {
      'docId': item.id,
      'name': item.name,
      'type': item.type,
      'brand': item.brand,
      'imageUrl': item.imageUrl,
      'expiry': item.expiry,
      'noExpiry': item.noExpiry,
      'stock': item.stock,
      'packagingUnit': item.packagingUnit,
      'packagingContent': item.packagingContent,
      'packagingContentQuantity': item.packagingContentQuantity,
    };
  }

  // Business logic for selection handling
  void toggleSelect(
    InventoryItem item,
    Set<String> selectedIds,
    Map<String, InventoryItem> selectedItems,
    VoidCallback onStateChanged,
  ) {
    if (item.stock <= 0) {
      return; // Let UI handle the dialog
    }

    if (selectedIds.contains(item.id)) {
      selectedIds.remove(item.id);
      selectedItems.remove(item.id);
    } else {
      selectedIds.add(item.id);
      selectedItems[item.id] = item;
    }

    onStateChanged();
  }

  // Parse existing document IDs from route arguments
  Set<String> parseExistingDocIds(dynamic args) {
    if (args is Map && args['existingDocIds'] is List) {
      return List.from(args['existingDocIds']).map((e) => e.toString()).toSet();
    }
    return <String>{};
  }

  // Validation logic
  bool isOutOfStock(InventoryItem item) {
    return item.stock <= 0;
  }

  bool isDuplicate(String itemId, Set<String> existingDocIds) {
    return existingDocIds.contains(itemId);
  }

  // Selection submission logic
  List<Map<String, dynamic>> submitSelection(
      Map<String, InventoryItem> selectedItems) {
    if (selectedItems.isEmpty) return [];
    return selectedItems.values.map(toReturnMap).toList();
  }

  // Get inventory stream
  Stream<List<GroupedInventoryItem>> getGroupedSuppliesStream(
      {bool archived = false, bool? expired}) {
    // Use catalog stream so products remain visible even if only expired batches exist
    return _catalogController.getAllProductsStream(
        archived: archived, expired: expired);
  }

  // Search filtering logic
  List<GroupedInventoryItem> filterSupplies(
    List<GroupedInventoryItem> groups,
    String searchText,
  ) {
    if (searchText.isEmpty) return groups;

    return groups
        .where((g) =>
            g.mainItem.name.toLowerCase().contains(searchText.toLowerCase()))
        .toList();
  }

  // Format expiry date for display
  String formatExpiry(String? expiry, bool noExpiry) {
    if (noExpiry) return 'No Expiry';
    if (expiry == null || expiry.isEmpty) return 'No Expiry';

    final normalized = expiry.replaceAll('/', '-');
    try {
      final parsed = DateTime.parse(normalized);
      final month = parsed.month.toString().padLeft(2, '0');
      final day = parsed.day.toString().padLeft(2, '0');
      return '$month/$day/${parsed.year}';
    } catch (_) {
      final match = RegExp(r'^(\d{4})/(\d{2})/(\d{2})$').firstMatch(expiry);
      if (match != null) {
        final month = match.group(2);
        final day = match.group(3);
        final year = match.group(1);
        return '$month/$day/$year';
      }
      return expiry;
    }
  }
}
