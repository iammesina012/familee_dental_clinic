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
  bool hasDuplicateItems(Map<String, GroupedInventoryItem> selectedItems,
      Set<String> existingDocIds) {
    for (final item in selectedItems.values) {
      if (existingDocIds.contains(item.mainItem.id)) {
        return true;
      }
    }
    return false;
  }

  // Get first duplicate item name for dialog
  String? getFirstDuplicateItemName(
      Map<String, GroupedInventoryItem> selectedItems,
      Set<String> existingDocIds) {
    for (final item in selectedItems.values) {
      if (existingDocIds.contains(item.mainItem.id)) {
        return item.mainItem.name;
      }
    }
    return null;
  }

  // Transform single item to return format
  Map<String, dynamic> toReturnMap(GroupedInventoryItem item) {
    return {
      'docId': item.mainItem.id,
      'name': item.mainItem.name,
      'brand': item.mainItem.brand,
      'supplier': item.mainItem.supplier,
      'imageUrl': item.mainItem.imageUrl,
      'expiry': item.mainItem.expiry,
      'noExpiry': item.mainItem.noExpiry,
      'stock': item.mainItem.stock, // Use individual batch stock, not total
    };
  }

  // Transform multiple items to return format
  List<Map<String, dynamic>> toReturnMapList(
      Map<String, GroupedInventoryItem> selectedItems) {
    return selectedItems.values.map(toReturnMap).toList();
  }

  // Get inventory stream
  Stream<List<GroupedInventoryItem>> getGroupedSuppliesStream(
      {bool archived = false}) {
    // Use catalog stream so products remain visible even if only expired batches exist
    return _catalogController.getAllProductsStream(archived: archived);
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
