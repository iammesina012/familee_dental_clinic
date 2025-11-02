import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/inventory/controller/catalog_controller.dart';

class SdAddSupplyPresetController {
  final CatalogController _catalogController = CatalogController();

  // Parse existing document IDs from route arguments
  Set<String> parseExistingDocIds(dynamic args) {
    if (args is Map && args['existingDocIds'] is List) {
      return List.from(args['existingDocIds']).map((e) => e.toString()).toSet();
    }
    return <String>{};
  }

  // Check if item is duplicate
  bool isDuplicate(String itemId, Set<String> existingDocIds) {
    return existingDocIds.contains(itemId);
  }

  // Check if any selected items are duplicates
  bool hasDuplicateItems(
      Map<String, InventoryItem> selectedItems, Set<String> existingDocIds) {
    for (final item in selectedItems.values) {
      if (existingDocIds.contains(item.id)) {
        return true;
      }
    }
    return false;
  }

  // Get first duplicate item name for dialog
  String? getFirstDuplicateItemName(
      Map<String, InventoryItem> selectedItems, Set<String> existingDocIds) {
    for (final item in selectedItems.values) {
      if (existingDocIds.contains(item.id)) {
        return item.name;
      }
    }
    return null;
  }

  // Transform single item to return format
  Map<String, dynamic> toReturnMap(InventoryItem item) {
    return {
      'docId': item.id,
      'name': item.name,
      'type': item.type,
      'brand': item.brand,
      'supplier': item.supplier,
      'imageUrl': item.imageUrl,
      'expiry': item.expiry,
      'noExpiry': item.noExpiry,
      'stock': item.stock,
      'cost': item.cost,
      'packagingUnit': item.packagingUnit,
      'packagingContent': item.packagingContent,
      'packagingContentQuantity': item.packagingContentQuantity,
      'packagingQuantity': item.packagingQuantity,
    };
  }

  // Format expiry date for display
  String formatExpiry(String? expiry, bool noExpiry) {
    if (noExpiry) return 'No Expiry';
    if (expiry == null || expiry.isEmpty) return 'No Expiry';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(expiry)) {
      return expiry.replaceAll('-', '/');
    }
    return expiry;
  }

  // Transform multiple items to return format
  List<Map<String, dynamic>> toReturnMapList(
      Map<String, InventoryItem> selectedItems) {
    return selectedItems.values.map(toReturnMap).toList();
  }

  // Get inventory stream
  Stream<List<GroupedInventoryItem>> getGroupedSuppliesStream(
      {bool archived = false, bool? expired}) {
    // Use catalog stream so products remain visible even if only expired batches exist
    return _catalogController.getAllProductsStream(
        archived: archived, expired: expired);
  }

  // Search filtering logic with multi-word support
  List<GroupedInventoryItem> filterSupplies(
      List<GroupedInventoryItem> items, String searchText) {
    if (searchText.isEmpty) return items;

    return items.where((item) {
      final itemName = item.mainItem.name.toLowerCase();
      final searchTextLower = searchText.toLowerCase();

      // Check if the name starts with the search text
      if (itemName.startsWith(searchTextLower)) {
        return true;
      }

      // Check if any word in the name starts with the search text
      final words = itemName.split(' ');
      for (final word in words) {
        if (word.startsWith(searchTextLower)) {
          return true;
        }
      }

      return false;
    }).toList();
  }
}
