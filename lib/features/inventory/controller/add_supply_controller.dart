import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'filter_controller.dart';
import 'package:familee_dental/features/activity_log/controller/inventory_activity_controller.dart';
import 'package:familee_dental/features/notifications/controller/notifications_controller.dart';
import 'package:familee_dental/features/inventory/services/inventory_storage_service.dart';

class AddSupplyController {
  final SupabaseClient _supabase = Supabase.instance.client;
  final InventoryStorageService _storageService = InventoryStorageService();
  final nameController = TextEditingController();
  final typeController = TextEditingController();
  final costController = TextEditingController();
  final stockController = TextEditingController(text: "0");
  final supplierController = TextEditingController();
  final brandController = TextEditingController();
  final expiryController = TextEditingController();
  final packagingQuantityController = TextEditingController(text: "1");
  final packagingContentController = TextEditingController(text: "1");
  final lowStockThresholdController = TextEditingController(text: "1");

  int stock = 0;
  int packagingQuantity = 1; // Default packaging quantity
  int packagingContent = 1; // Default packaging content
  int lowStockThreshold = 1; // Default low stock threshold
  String? selectedCategory;
  String? selectedPackagingUnit = 'Box';
  String? selectedPackagingContent = 'Pieces';
  DateTime? expiryDate;
  bool noExpiry = false;

  XFile? pickedImage;
  String? imageUrl;
  bool uploading = false;
  bool isPickingImage = false; // Flag to prevent multiple picker calls
  final ImagePicker _picker = ImagePicker();
  ImagePicker get picker => _picker;

  final FilterController filterController = FilterController();

  void dispose() {
    nameController.dispose();
    typeController.dispose();
    costController.dispose();
    stockController.dispose();
    supplierController.dispose();
    brandController.dispose();
    expiryController.dispose();
    packagingQuantityController.dispose();
    packagingContentController.dispose();
    lowStockThresholdController.dispose();
  }

  Future<String?> uploadImageToSupabase(XFile imageFile) async {
    return await _storageService.uploadImageToSupabase(imageFile);
  }

  // Helper function to validate alphanumeric input
  bool _isValidAlphanumeric(String text) {
    if (text.trim().isEmpty)
      return false; // Empty is not valid for required fields
    // Check if the text contains only numbers
    if (RegExp(r'^[0-9]+$').hasMatch(text.trim())) {
      return false;
    }
    // Check if the text contains at least one letter and allows common characters
    return RegExp(r'^[a-zA-Z0-9\s\-_\.]+$').hasMatch(text.trim()) &&
        RegExp(r'[a-zA-Z]').hasMatch(text.trim());
  }

  Map<String, String?> validateFields() {
    Map<String, String?> errors = {};

    // Required fields validation
    if (nameController.text.trim().isEmpty) {
      errors['name'] = 'Please enter the item name.';
    } else if (!_isValidAlphanumeric(nameController.text.trim())) {
      errors['name'] =
          'Item name must contain letters and cannot be only numbers.';
    }

    // Validate type name (optional but if provided, should be valid)
    if (typeController.text.trim().isNotEmpty &&
        !_isValidAlphanumeric(typeController.text.trim())) {
      errors['type'] =
          'Type name must contain letters and cannot be only numbers.';
    }

    if (selectedCategory == null || selectedCategory!.isEmpty) {
      errors['category'] = 'Please choose a category.';
    }

    if (selectedPackagingUnit == null || selectedPackagingUnit!.isEmpty) {
      errors['packagingUnit'] = 'Please choose a packaging unit.';
    }

    if (selectedPackagingContent == null || selectedPackagingContent!.isEmpty) {
      // Only require packaging content if the unit needs it
      if (selectedPackagingUnit != 'Pieces' &&
          selectedPackagingUnit != 'Spool' &&
          selectedPackagingUnit != 'Tub') {
        errors['packagingContent'] = 'Please choose packaging content.';
      }
    }

    if (costController.text.trim().isEmpty) {
      errors['cost'] = 'Please enter the cost.';
    } else if (double.tryParse(costController.text.trim()) == null) {
      errors['cost'] = 'Cost must be a valid number.';
    }

    // Validate packaging quantities
    if (packagingQuantity < 1) {
      errors['packagingQuantity'] = 'Packaging quantity must be at least 1.';
    }

    if (packagingContent < 1) {
      errors['packagingContent'] =
          'Packaging content quantity must be at least 1.';
    }

    // Validate supplier name (now required)
    if (supplierController.text.trim().isEmpty) {
      errors['supplier'] = 'Please enter the supplier name.';
    } else if (!_isValidAlphanumeric(supplierController.text.trim())) {
      errors['supplier'] =
          'Supplier name must contain letters and cannot be only numbers.';
    }

    // Validate brand name (now required)
    if (brandController.text.trim().isEmpty) {
      errors['brand'] = 'Please enter the brand name.';
    } else if (!_isValidAlphanumeric(brandController.text.trim())) {
      errors['brand'] =
          'Brand name must contain letters and cannot be only numbers.';
    }

    // Expiry date validation
    if (!noExpiry &&
        (expiryController.text.trim().isEmpty || expiryDate == null)) {
      errors['expiry'] =
          'Please enter the expiry date or check "No expiry date" if there\'s none.';
    }

    return errors;
  }

  String? validateFieldsForBackend() {
    final errors = validateFields();
    if (errors.isNotEmpty) {
      return errors
          .values.first; // Return first error for backend compatibility
    }
    return null;
  }

  bool isPackagingContentDisabled() {
    return selectedPackagingUnit == 'Pieces' ||
        selectedPackagingUnit == 'Spool' ||
        selectedPackagingUnit == 'Tub';
  }

  Map<String, dynamic> buildSupplyData() {
    return {
      "name": nameController.text.trim(),
      "type": typeController.text.trim(),
      "image_url": imageUrl ?? "", // Make image optional
      "category": selectedCategory ?? "",
      "cost": double.tryParse(costController.text.trim()) ?? 0.0,
      "stock": packagingQuantity, // Stock should be the packaging quantity
      "unit": selectedPackagingUnit ?? "", // Legacy column
      "packaging_unit": selectedPackagingUnit ?? "",
      "packaging_quantity": 1, // Always 1 (e.g., 1 Box)
      "packaging_content": isPackagingContentDisabled()
          ? null
          : (selectedPackagingContent ?? ""),
      "packaging_content_quantity":
          isPackagingContentDisabled() ? 1 : packagingContent,
      "supplier": supplierController.text.trim().isEmpty
          ? "N/A"
          : supplierController.text.trim(),
      "brand": brandController.text.trim().isEmpty
          ? "N/A"
          : brandController.text.trim(),
      "expiry": noExpiry || expiryController.text.isEmpty
          ? null
          : expiryController.text,
      "no_expiry": noExpiry,
      "low_stock_baseline": lowStockThreshold,
      "archived": false,
      "created_at": DateTime.now().toIso8601String(),
    };
  }

  Future<String?> addSupply() async {
    final error = validateFieldsForBackend();
    if (error != null) return error;
    final supplyData = buildSupplyData();
    try {
      // Check if an archived supply with the same name exists
      final archivedCheck = await _supabase
          .from('supplies')
          .select('id')
          .eq('name', nameController.text.trim())
          .eq('archived', true)
          .limit(1);

      if (archivedCheck.isNotEmpty) {
        return 'ARCHIVED_SUPPLY_EXISTS';
      }

      // Check if an exact duplicate supply exists
      // Duplicate = same product identity (name, type, brand, category, packaging)
      // Different batches (supplier, cost, expiry, threshold) are NOT duplicates
      final brandValue = brandController.text.trim().isEmpty
          ? "N/A"
          : brandController.text.trim();
      final typeValue =
          typeController.text.trim().isEmpty ? "" : typeController.text.trim();
      final categoryValue = selectedCategory ?? "";
      final packagingUnitValue = selectedPackagingUnit ?? "";
      final packagingContentValue = isPackagingContentDisabled()
          ? null
          : (selectedPackagingContent ?? "");

      // Query for potential duplicates - query by name, then check product identity fields
      var duplicateQuery = _supabase
          .from('supplies')
          .select(
              'id, type, brand, category, packaging_unit, packaging_content, packaging_content_quantity')
          .eq('name', nameController.text.trim())
          .eq('archived', false);

      // Get all potential matches and check product identity fields only
      final existingSupplies = await duplicateQuery;
      bool foundDuplicate = false;

      for (final row in existingSupplies) {
        // Check brand
        final existingBrand = (row['brand'] ?? 'N/A').toString();
        final brandMatches = brandValue == 'N/A'
            ? (existingBrand == 'N/A' || existingBrand.isEmpty)
            : brandValue == existingBrand;

        // Check type (treat null and empty as equivalent)
        final existingType = (row['type'] ?? '').toString();
        final typeMatches = typeValue.isEmpty
            ? (existingType.isEmpty)
            : typeValue == existingType;

        // Check category
        final existingCategory = (row['category'] ?? '').toString();
        final categoryMatches = categoryValue == existingCategory;

        // Check packaging unit
        final existingPackagingUnit = (row['packaging_unit'] ?? '').toString();
        final packagingUnitMatches =
            packagingUnitValue == existingPackagingUnit;

        // Check packaging content match
        final existingPackagingContent = row['packaging_content'];
        final packagingContentMatches = (packagingContentValue == null &&
                (existingPackagingContent == null ||
                    existingPackagingContent.toString().isEmpty)) ||
            (packagingContentValue != null &&
                existingPackagingContent != null &&
                packagingContentValue == existingPackagingContent.toString());

        // Check packaging content quantity match
        final existingPackagingContentQuantity =
            row['packaging_content_quantity'] != null
                ? (row['packaging_content_quantity'] as num).toInt()
                : 1;
        final packagingContentQuantityMatches =
            packagingContent == existingPackagingContentQuantity;

        // Product identity fields must match for it to be a duplicate
        // Different batches (supplier, cost, expiry, threshold) are allowed
        if (brandMatches &&
            typeMatches &&
            categoryMatches &&
            packagingUnitMatches &&
            packagingContentMatches &&
            packagingContentQuantityMatches) {
          foundDuplicate = true;
          break;
        }
      }

      if (foundDuplicate) {
        return 'DUPLICATE_SUPPLY_EXISTS';
      }

      // Add supply to Supabase
      await _supabase.from('supplies').insert(supplyData);

      // Auto-manage brands and suppliers
      await filterController.addBrandIfNotExists(brandController.text.trim());
      await filterController
          .addSupplierIfNotExists(supplierController.text.trim());

      // Log the activity
      await InventoryActivityController().logInventorySupplyAdded(
        itemName: nameController.text.trim(),
        type: typeController.text.trim(),
        category: selectedCategory!,
        stock: packagingQuantity, // Use packaging quantity as stock
        packagingUnit: selectedPackagingUnit!,
        packagingQuantity: packagingQuantity,
        packagingContent: isPackagingContentDisabled()
            ? ""
            : (selectedPackagingContent ?? ""),
        packagingContentQuantity:
            isPackagingContentDisabled() ? 1 : packagingContent,
        cost: double.tryParse(costController.text.trim()),
        brand: brandController.text.trim().isEmpty
            ? null
            : brandController.text.trim(),
        supplier: supplierController.text.trim().isEmpty
            ? null
            : supplierController.text.trim(),
        expiryDate: expiryController.text.trim().isEmpty
            ? null
            : expiryController.text.trim(),
        noExpiry: noExpiry,
        lowStockBaseline: lowStockThreshold,
      );

      // Check for notifications
      final notificationsController = NotificationsController();
      final newStock = packagingQuantity; // Use packaging quantity as stock

      // Check stock level notifications (new item, so previous stock is 0)
      await notificationsController.checkStockLevelNotification(
        nameController.text.trim(),
        newStock,
        0, // previous stock is 0 for new items
        type: typeController.text.trim().isNotEmpty
            ? typeController.text.trim()
            : null,
      );

      // Check expiry notifications
      await notificationsController.checkExpiryNotification(
        nameController.text.trim(),
        expiryController.text.trim().isEmpty
            ? null
            : expiryController.text.trim(),
        noExpiry,
        supplyType: typeController.text.trim().isNotEmpty
            ? typeController.text.trim()
            : null,
      );

      return null; // Success
    } catch (e) {
      return 'Failed to add supply: $e';
    }
  }

  // Smart autofill methods
  Future<void> autoFillFromExistingSupply(String supplyName,
      {String? typeName}) async {
    if (supplyName.trim().isEmpty) return;

    try {
      // Find ALL existing supplies with the same name (case-insensitive)
      // If type is provided, also filter by type for image matching
      // We'll pick the most common values for each field
      var query = _supabase
          .from('supplies')
          .select(
              'supplier, brand, type, category, low_stock_baseline, packaging_unit, packaging_content, packaging_content_quantity, no_expiry, image_url')
          .ilike('name', supplyName.trim())
          .eq('archived', false);

      // If type is provided, filter by type for more accurate autofill
      if (typeName != null && typeName.trim().isNotEmpty) {
        query = query.ilike('type', typeName.trim());
      }

      final response = await query;

      if (response.isNotEmpty) {
        // Count occurrences for each field
        final Map<String, int> supplierCounts = {};
        final Map<String, int> brandCounts = {};
        final Map<String, int> packagingUnitCounts = {};
        final Map<String, int> packagingContentCounts = {};
        final Map<int, int> packagingContentQuantityCounts = {};

        final Map<String, String> supplierExamples = {};
        final Map<String, String> brandExamples = {};
        final Map<String, String> packagingUnitExamples = {};
        final Map<String, String> packagingContentExamples = {};

        String? mostCommonCategory;
        int? mostCommonLowStockBaseline;
        int noExpiryCount = 0;
        int hasExpiryCount = 0;
        String? firstImageUrl;

        for (final row in response) {
          final supplier = row['supplier'] as String?;
          final brand = row['brand'] as String?;
          final category = row['category'] as String?;
          final lowStockBaseline = row['low_stock_baseline'] as int?;
          final packagingUnit = row['packaging_unit'] as String?;
          final packagingContent = row['packaging_content'] as String?;
          final packagingContentQuantity =
              row['packaging_content_quantity'] as int?;
          final noExpiryFlag = row['no_expiry'] as bool?;
          final imgUrl = row['image_url'] as String?;

          // Count suppliers (skip N/A)
          if (supplier != null && supplier.isNotEmpty && supplier != 'N/A') {
            final key = supplier.toLowerCase();
            supplierCounts[key] = (supplierCounts[key] ?? 0) + 1;
            supplierExamples[key] = supplier;
          }

          // Count brands (skip N/A)
          if (brand != null && brand.isNotEmpty && brand != 'N/A') {
            final key = brand.toLowerCase();
            brandCounts[key] = (brandCounts[key] ?? 0) + 1;
            brandExamples[key] = brand;
          }

          // Count packaging units
          if (packagingUnit != null && packagingUnit.isNotEmpty) {
            final key = packagingUnit.toLowerCase();
            packagingUnitCounts[key] = (packagingUnitCounts[key] ?? 0) + 1;
            packagingUnitExamples[key] = packagingUnit;
          }

          // Count packaging content
          if (packagingContent != null && packagingContent.isNotEmpty) {
            final key = packagingContent.toLowerCase();
            packagingContentCounts[key] =
                (packagingContentCounts[key] ?? 0) + 1;
            packagingContentExamples[key] = packagingContent;
          }

          // Count packaging content quantity
          if (packagingContentQuantity != null &&
              packagingContentQuantity > 0) {
            packagingContentQuantityCounts[packagingContentQuantity] =
                (packagingContentQuantityCounts[packagingContentQuantity] ??
                        0) +
                    1;
          }

          // Count no expiry flag
          if (noExpiryFlag != null) {
            if (noExpiryFlag == true) {
              noExpiryCount++;
            } else {
              hasExpiryCount++;
            }
          }

          // Track most common category
          if (category != null && category.isNotEmpty) {
            if (mostCommonCategory == null || category == mostCommonCategory) {
              mostCommonCategory = category;
            }
          }

          // Track most common low stock baseline
          if (lowStockBaseline != null && lowStockBaseline > 0) {
            if (mostCommonLowStockBaseline == null ||
                lowStockBaseline == mostCommonLowStockBaseline) {
              mostCommonLowStockBaseline = lowStockBaseline;
            }
          }

          // Track first non-empty image URL
          if (firstImageUrl == null && imgUrl != null && imgUrl.isNotEmpty) {
            firstImageUrl = imgUrl;
          }
        }

        // Find most common supplier
        if (supplierCounts.isNotEmpty) {
          final mostCommonSupplierKey = supplierCounts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
          supplierController.text = supplierExamples[mostCommonSupplierKey]!;
        }

        // Find most common brand
        if (brandCounts.isNotEmpty) {
          final mostCommonBrandKey = brandCounts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
          brandController.text = brandExamples[mostCommonBrandKey]!;
        }

        // Find most common packaging unit
        if (packagingUnitCounts.isNotEmpty) {
          final mostCommonPackagingUnitKey = packagingUnitCounts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
          selectedPackagingUnit =
              packagingUnitExamples[mostCommonPackagingUnitKey]!;
        }

        // Find most common packaging content
        if (packagingContentCounts.isNotEmpty) {
          final mostCommonPackagingContentKey = packagingContentCounts.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
          selectedPackagingContent =
              packagingContentExamples[mostCommonPackagingContentKey]!;
        }

        // Find most common packaging content quantity
        if (packagingContentQuantityCounts.isNotEmpty) {
          final mostCommonPackagingContentQuantity =
              packagingContentQuantityCounts.entries
                  .reduce((a, b) => a.value > b.value ? a : b)
                  .key;
          packagingContentController.text =
              mostCommonPackagingContentQuantity.toString();
          packagingContent = mostCommonPackagingContentQuantity;
        }

        // Set no expiry flag based on majority
        if (noExpiryCount > hasExpiryCount) {
          noExpiry = true;
        } else if (hasExpiryCount > 0) {
          noExpiry = false;
        }

        // Auto-fill category if it exists
        if (mostCommonCategory != null) {
          selectedCategory = mostCommonCategory;
        }

        // Auto-fill low stock threshold if it exists
        if (mostCommonLowStockBaseline != null) {
          lowStockThresholdController.text =
              mostCommonLowStockBaseline.toString();
          lowStockThreshold = mostCommonLowStockBaseline;
        }

        // Auto-fill image ONLY if type is specified and matches
        // This prevents grabbing wrong type's image (e.g., Pink vs Blue surgical mask)
        if (typeName != null &&
            typeName.trim().isNotEmpty &&
            firstImageUrl != null) {
          imageUrl = firstImageUrl;
        }
      }
    } catch (e) {
      print('Error auto-filling from existing supply: $e');
    }
  }

  Future<List<String>> getExistingTypes(String supplyName) async {
    if (supplyName.trim().isEmpty) return [];

    try {
      final response = await _supabase
          .from('supplies')
          .select('type')
          .eq('name', supplyName.trim())
          .eq('archived', false);

      final types = <String>[];
      for (final row in response) {
        final type = row['type'] as String?;
        if (type != null && type.isNotEmpty && !types.contains(type)) {
          types.add(type);
        }
      }
      return types;
    } catch (e) {
      print('Error getting existing types: $e');
      return [];
    }
  }
}
