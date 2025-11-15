import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'filter_controller.dart';
import 'package:familee_dental/features/activity_log/controller/inventory_activity_controller.dart';
import 'package:familee_dental/features/notifications/controller/notifications_controller.dart';
import 'package:familee_dental/features/inventory/services/inventory_storage_service.dart';

class EditSupplyController {
  final SupabaseClient _supabase = Supabase.instance.client;
  final InventoryStorageService _storageService = InventoryStorageService();
  final nameController = TextEditingController();
  final typeController = TextEditingController();
  final costController = TextEditingController();
  final stockController = TextEditingController();
  final supplierController = TextEditingController();
  final brandController = TextEditingController();
  final expiryController = TextEditingController();
  final packagingQuantityController = TextEditingController(text: "1");
  final packagingContentController = TextEditingController(text: "1");
  final lowStockThresholdController = TextEditingController(text: "1");

  int stock = 0;
  String? selectedCategory;
  String? selectedUnit;
  String? selectedPackagingUnit;
  String? selectedPackagingContent;
  int packagingQuantity = 1;
  int packagingContent = 1;
  int lowStockThreshold = 1;
  DateTime? expiryDate;
  bool noExpiry = false;

  XFile? pickedImage;
  String? imageUrl;
  bool uploading = false;
  bool isPickingImage = false; // Flag to prevent multiple picker calls
  final ImagePicker _picker = ImagePicker();
  ImagePicker get picker => _picker;

  final FilterController filterController = FilterController();

  // Store original values for comparison
  String? originalName;
  String? originalType;
  String? originalCategory;
  int? originalStock;
  String? originalUnit;
  String? originalPackagingUnit;
  String? originalPackagingContent;
  int? originalPackagingQuantity;
  int? originalPackagingContentQuantity;
  int? originalLowStockThreshold;
  double? originalCost;
  String? originalExpiry;
  bool? originalNoExpiry;
  String? originalBrand;
  String? originalSupplier;

  void initFromItem(InventoryItem item) {
    nameController.text = item.name;
    typeController.text = item.type ?? '';
    costController.text = item.cost.toString();
    stockController.text = item.stock.toString();
    supplierController.text = item.supplier == "N/A" ? "" : item.supplier;
    brandController.text = item.brand == "N/A" ? "" : item.brand;
    expiryController.text = item.expiry ?? '';
    stock = item.stock;
    selectedCategory = item.category;
    selectedUnit = _normalizeUnit(item.unit);
    selectedPackagingUnit = item.packagingUnit ?? 'Box';
    selectedPackagingContent = item.packagingContent ?? 'Pieces';
    packagingQuantity = item.packagingQuantity ?? 1;
    packagingContent = item.packagingContentQuantity ?? 1;
    lowStockThreshold = item.lowStockBaseline ?? 1;
    packagingQuantityController.text = packagingQuantity.toString();
    packagingContentController.text = packagingContent.toString();
    lowStockThresholdController.text = lowStockThreshold.toString();
    noExpiry = item.noExpiry;
    imageUrl = item.imageUrl;
    if (item.expiry != null && item.expiry!.isNotEmpty) {
      // Support both YYYY-MM-DD and YYYY/MM/DD formats
      expiryDate = DateTime.tryParse(item.expiry!) ??
          DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
    } else {
      expiryDate = null;
    }

    // Store original values for comparison
    originalName = item.name;
    originalType = item.type ?? '';
    originalCategory = item.category;
    originalStock = item.stock;
    originalUnit = item.unit;
    originalPackagingUnit = item.packagingUnit ?? 'Box';
    originalPackagingContent = item.packagingContent ?? 'Pieces';
    originalPackagingQuantity = item.packagingQuantity ?? 1;
    originalPackagingContentQuantity = item.packagingContentQuantity ?? 1;
    originalLowStockThreshold = item.lowStockBaseline ?? 1;
    originalCost = item.cost;
    originalExpiry = item.expiry;
    originalNoExpiry = item.noExpiry;
    originalBrand = item.brand == "N/A" ? "" : item.brand;
    originalSupplier = item.supplier == "N/A" ? "" : item.supplier;
  }

  String? _normalizeUnit(String? raw) {
    if (raw == null) return null;
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return null;
    // Map common variants to our canonical set used in dropdown: Box, Pieces, Pack
    if (s == 'box' || s == 'boxes' || s == 'bx') return 'Box';
    if (s == 'pack' || s == 'packs' || s == 'pk') return 'Pack';
    if (s == 'piece' ||
        s == 'pieces' ||
        s == 'pc' ||
        s == 'pcs' ||
        s == 'unit' ||
        s == 'units') {
      return 'Pieces';
    }
    // If it already matches one of the allowed labels ignoring case
    final allowed = ['Box', 'Pieces', 'Pack'];
    for (final a in allowed) {
      if (a.toLowerCase() == s) return a;
    }
    // Fallback to Pieces to avoid dropdown mismatch
    return 'Pieces';
  }

  bool isPackagingContentDisabled() {
    return selectedPackagingUnit == 'Pieces' ||
        selectedPackagingUnit == 'Spool' ||
        selectedPackagingUnit == 'Tub';
  }

  void dispose() {
    nameController.dispose();
    typeController.dispose();
    costController.dispose();
    stockController.dispose();
    packagingQuantityController.dispose();
    packagingContentController.dispose();
    lowStockThresholdController.dispose();
    supplierController.dispose();
    brandController.dispose();
    expiryController.dispose();
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

    if (selectedCategory == null || selectedCategory!.isEmpty) {
      errors['category'] = 'Please choose a category.';
    }

    if (selectedUnit == null || selectedUnit!.isEmpty) {
      errors['unit'] = 'Please choose a unit.';
    }

    if (costController.text.trim().isEmpty) {
      errors['cost'] = 'Please enter the cost.';
    } else if (double.tryParse(costController.text.trim()) == null) {
      errors['cost'] = 'Cost must be a valid number.';
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
    if (!noExpiry && expiryController.text.trim().isEmpty) {
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

  Map<String, dynamic> buildUpdatedData() {
    return {
      "name": nameController.text.trim(),
      "type": typeController.text.trim(),
      "image_url": imageUrl ?? "", // Make image optional
      "category": selectedCategory ?? "",
      "cost": double.tryParse(costController.text.trim()) ?? 0.0,
      "stock": int.tryParse(stockController.text.trim()) ?? 0,
      "unit": selectedUnit ?? "", // Legacy column
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
      // Persist expiry in canonical yyyy-MM-dd format
      "expiry": noExpiry || expiryController.text.isEmpty
          ? null
          : expiryController.text.replaceAll('/', '-'),
      "no_expiry": noExpiry,
      "low_stock_baseline": lowStockThreshold,
    };
  }

  Future<String?> updateSupply(String docId) async {
    final error = validateFieldsForBackend();
    if (error != null) return error;
    final updatedData = buildUpdatedData();
    try {
      // Try to merge with an existing batch if name + brand + expiry match
      final String name = (updatedData['name'] ?? '').toString();
      final String brand = (updatedData['brand'] ?? '').toString();
      final String? newExpiry = updatedData['expiry'] == null ||
              updatedData['expiry'].toString().isEmpty
          ? null
          : updatedData['expiry'].toString();
      // Normalize and parse expiry for reliable comparisons
      DateTime? parseExpiry(String? value) {
        if (value == null || value.isEmpty) return null;
        return DateTime.tryParse(value) ??
            DateTime.tryParse(value.replaceAll('/', '-'));
      }

      final DateTime? newExpiryDate = parseExpiry(newExpiry);

      final String type = (updatedData['type'] ?? '').toString();
      final String supplier = (updatedData['supplier'] ?? '').toString();
      final double cost = (updatedData['cost'] ?? 0.0) as double;
      final String? packagingUnit = updatedData['packaging_unit'];
      final String? updatedPackagingContent = updatedData['packaging_content'];
      final int? updatedPackagingContentQuantity =
          updatedData['packaging_content_quantity'] as int?;

      // Check if only stock is being changed (no other fields changed)
      final DateTime? originalExpiryDate =
          (originalExpiry != null && originalExpiry!.isNotEmpty)
              ? parseExpiry(originalExpiry)
              : null;
      final bool expiryMatches = (newExpiryDate == null &&
              (originalNoExpiry == true || originalExpiryDate == null)) ||
          (newExpiryDate != null &&
              originalExpiryDate != null &&
              newExpiryDate.year == originalExpiryDate.year &&
              newExpiryDate.month == originalExpiryDate.month &&
              newExpiryDate.day == originalExpiryDate.day);

      final bool onlyStockChanged = name == (originalName ?? '') &&
          brand == (originalBrand ?? '') &&
          type == (originalType ?? '') &&
          supplier == (originalSupplier ?? '') &&
          (cost - (originalCost ?? 0.0)).abs() < 0.01 &&
          packagingUnit == (originalPackagingUnit ?? '') &&
          updatedPackagingContent == (originalPackagingContent ?? '') &&
          updatedPackagingContentQuantity ==
              (originalPackagingContentQuantity ?? 1) &&
          expiryMatches;

      // Only attempt merge if fields other than stock were changed
      // This prevents accidental merging when user just wants to update stock quantity
      if (!onlyStockChanged) {
        final existingQuery = await _supabase
            .from('supplies')
            .select('*')
            .eq('name', name)
            .eq('brand', brand)
            .eq('type', type);

        // Find an EXACT matching batch (excluding current) - must match ALL distinguishing fields
        Map<String, dynamic>? mergeTarget;
        for (final row in existingQuery) {
          if (row['id'] == docId) continue;

          // Check expiry match
          final dynamic otherExpiryRaw = row['expiry'];
          final String? otherExpiry =
              (otherExpiryRaw == null || otherExpiryRaw.toString().isEmpty)
                  ? null
                  : otherExpiryRaw.toString();
          final DateTime? otherExpiryDate = parseExpiry(otherExpiry);
          final bool expiryMatches =
              (newExpiryDate == null && otherExpiryDate == null) ||
                  (newExpiryDate != null &&
                      otherExpiryDate != null &&
                      newExpiryDate.year == otherExpiryDate.year &&
                      newExpiryDate.month == otherExpiryDate.month &&
                      newExpiryDate.day == otherExpiryDate.day);

          // Check supplier match
          final String otherSupplier = (row['supplier'] ?? 'N/A').toString();
          final bool supplierMatches = supplier == 'N/A'
              ? (otherSupplier == 'N/A' || otherSupplier.isEmpty)
              : supplier == otherSupplier;

          // Check cost match (within 0.01 tolerance)
          final double otherCost = (row['cost'] ?? 0.0).toDouble();
          final bool costMatches = (cost - otherCost).abs() < 0.01;

          // Check packaging unit match
          final String? otherPackagingUnit = row['packaging_unit'];
          final bool packagingUnitMatches =
              (packagingUnit == null || packagingUnit.isEmpty)
                  ? (otherPackagingUnit == null ||
                      otherPackagingUnit.toString().isEmpty)
                  : packagingUnit == (otherPackagingUnit?.toString() ?? '');

          // Check packaging content match
          final String? otherPackagingContent = row['packaging_content'];
          final bool packagingContentMatches =
              (updatedPackagingContent == null ||
                      updatedPackagingContent.isEmpty)
                  ? (otherPackagingContent == null ||
                      otherPackagingContent.toString().isEmpty)
                  : updatedPackagingContent ==
                      (otherPackagingContent?.toString() ?? '');

          // Check packaging content quantity match (handle String/int conversion)
          final dynamic otherPackagingContentQtyRaw =
              row['packaging_content_quantity'];
          final int? otherPackagingContentQty =
              otherPackagingContentQtyRaw == null
                  ? null
                  : (otherPackagingContentQtyRaw is int
                      ? otherPackagingContentQtyRaw
                      : int.tryParse(otherPackagingContentQtyRaw.toString()));
          final bool packagingContentQtyMatches =
              (updatedPackagingContentQuantity ?? 1) ==
                  (otherPackagingContentQty ?? 1);

          // Only merge if ALL distinguishing fields match exactly
          if (expiryMatches &&
              supplierMatches &&
              costMatches &&
              packagingUnitMatches &&
              packagingContentMatches &&
              packagingContentQtyMatches) {
            mergeTarget = row;
            break;
          }
        }

        if (mergeTarget != null) {
          // Merge stock into the target and delete the current document
          final int targetStock = (mergeTarget['stock'] ?? 0) as int;
          final int thisStock = (updatedData['stock'] ?? 0) as int;
          final int mergedStock = targetStock + thisStock;

          final Map<String, dynamic> updates = {
            'stock': mergedStock,
          };
          // Fill missing fields on target if needed
          if ((mergeTarget['image_url'] ?? '').toString().isEmpty &&
              (updatedData['image_url'] ?? '').toString().isNotEmpty) {
            updates['image_url'] = updatedData['image_url'];
          }
          if (mergeTarget['archived'] == null) {
            updates['archived'] = false;
          }

          await _supabase
              .from('supplies')
              .update(updates)
              .eq('id', mergeTarget['id']);
          await _supabase.from('supplies').delete().eq('id', docId);
        } else {
          // No merge target; just update this document normally
          await _supabase.from('supplies').update(updatedData).eq('id', docId);
        }
      } else {
        // Only stock changed - just update this document normally (no merging)
        await _supabase.from('supplies').update(updatedData).eq('id', docId);
      }

      // Update low stock threshold for ALL batches of the same supply (name + category)
      // This ensures the threshold applies to the overall stock, not just individual batches
      if (lowStockThreshold != originalLowStockThreshold) {
        final String category = (updatedData['category'] ?? '').toString();
        await _supabase
            .from('supplies')
            .update({'low_stock_baseline': lowStockThreshold})
            .eq('name', name)
            .eq('category', category);
      }

      // Auto-manage brands and suppliers
      final newBrand = brandController.text.trim();
      final newSupplier = supplierController.text.trim();

      // Update brand name across all supplies if changed
      if (originalBrand != null && originalBrand != newBrand) {
        await filterController.updateBrandName(originalBrand!, newBrand);
      } else {
        // Add new brand if it doesn't exist
        await filterController.addBrandIfNotExists(newBrand);
      }

      // Update supplier name across all supplies if changed
      if (originalSupplier != null && originalSupplier != newSupplier) {
        await filterController.updateSupplierName(
            originalSupplier!, newSupplier);
      } else {
        // Add new supplier if it doesn't exist
        await filterController.addSupplierIfNotExists(newSupplier);
      }

      // Track what fields were actually changed with before/after values
      final Map<String, Map<String, dynamic>> fieldChanges = {};

      // Compare current values with original values and track changes
      if (nameController.text.trim() != (originalName ?? '')) {
        fieldChanges['Name'] = {
          'previous': originalName ?? 'N/A',
          'new': nameController.text.trim(),
        };
      }
      if (typeController.text.trim() != (originalType ?? '')) {
        fieldChanges['Type'] = {
          'previous': originalType ?? 'N/A',
          'new': typeController.text.trim(),
        };
      }
      if (selectedCategory != (originalCategory ?? '')) {
        fieldChanges['Category'] = {
          'previous': originalCategory ?? 'N/A',
          'new': selectedCategory ?? 'Unknown Category',
        };
      }
      if (selectedUnit != (originalUnit ?? '')) {
        fieldChanges['Unit'] = {
          'previous': originalUnit ?? 'N/A',
          'new': selectedUnit ?? 'Unknown Unit',
        };
      }
      if (costController.text.trim().isNotEmpty &&
          double.tryParse(costController.text.trim()) !=
              (originalCost ?? 0.0)) {
        fieldChanges['Cost'] = {
          'previous': originalCost ?? 0.0,
          'new': double.tryParse(costController.text.trim()) ?? 0.0,
        };
      }
      if (brandController.text.trim() != (originalBrand ?? '')) {
        fieldChanges['Brand'] = {
          'previous': originalBrand ?? 'N/A',
          'new': brandController.text.trim(),
        };
      }
      if (supplierController.text.trim() != (originalSupplier ?? '')) {
        fieldChanges['Supplier'] = {
          'previous': originalSupplier ?? 'N/A',
          'new': supplierController.text.trim(),
        };
      }
      if (expiryController.text.trim() != (originalExpiry ?? '')) {
        fieldChanges['Expiry Date'] = {
          'previous': originalExpiry ?? 'N/A',
          'new': expiryController.text.trim().isNotEmpty
              ? expiryController.text.trim()
              : 'N/A',
        };
      }
      if (noExpiry != (originalNoExpiry ?? false)) {
        fieldChanges['No Expiry'] = {
          'previous': originalNoExpiry ?? false,
          'new': noExpiry,
        };
      }

      // Track threshold changes
      if (lowStockThreshold != (originalLowStockThreshold ?? 1)) {
        fieldChanges['Threshold'] = {
          'previous': originalLowStockThreshold ?? 1,
          'new': lowStockThreshold,
        };
      }

      // Track packaging unit changes
      if (selectedPackagingUnit != (originalPackagingUnit ?? 'Box')) {
        fieldChanges['Packaging Unit'] = {
          'previous': originalPackagingUnit ?? 'Box',
          'new': selectedPackagingUnit ?? 'Box',
        };
      }

      // Track packaging content/unit changes (combine quantity and content)
      // Check if original packaging content was disabled (Pieces, Spool, Tub units)
      final bool originalPackagingContentDisabled =
          originalPackagingUnit == 'Pieces' ||
              originalPackagingUnit == 'Spool' ||
              originalPackagingUnit == 'Tub';

      final bool packagingContentChanged =
          (isPackagingContentDisabled() ? null : selectedPackagingContent) !=
                  (originalPackagingContentDisabled
                      ? null
                      : (originalPackagingContent ?? 'Pieces')) ||
              (!isPackagingContentDisabled() &&
                  !originalPackagingContentDisabled &&
                  packagingContent != (originalPackagingContentQuantity ?? 1));

      if (packagingContentChanged) {
        // Build previous value
        String previousValue;
        if (originalPackagingContentDisabled ||
            (originalPackagingContent == null ||
                originalPackagingContent!.isEmpty)) {
          previousValue = originalPackagingUnit ?? 'Box';
        } else {
          previousValue =
              '${originalPackagingContentQuantity ?? 1} ${originalPackagingContent ?? 'Pieces'}';
        }

        // Build new value
        String newValue;
        if (isPackagingContentDisabled() ||
            (selectedPackagingContent == null ||
                selectedPackagingContent!.isEmpty)) {
          newValue = selectedPackagingUnit ?? 'Box';
        } else {
          newValue =
              '$packagingContent ${selectedPackagingContent ?? 'Pieces'}';
        }

        fieldChanges['Packaging Content/Unit'] = {
          'previous': previousValue,
          'new': newValue,
        };
      }

      // Log the edit activity with detailed field changes (wrap in try-catch to prevent breaking save)
      try {
        await InventoryActivityController().logInventorySupplyEdited(
          itemName: nameController.text.trim(),
          type: typeController.text.trim(),
          category: selectedCategory ?? 'Unknown Category',
          stock: int.tryParse(stockController.text.trim()) ?? 0,
          unit: selectedUnit ?? 'Unknown Unit',
          packagingUnit: selectedPackagingUnit ?? 'Unknown Unit',
          packagingQuantity: packagingQuantity,
          packagingContent: isPackagingContentDisabled()
              ? ""
              : (selectedPackagingContent ?? ""),
          packagingContentQuantity:
              isPackagingContentDisabled() ? 1 : packagingContent,
          cost: double.tryParse(costController.text.trim()),
          brand: brandController.text.trim(),
          supplier: supplierController.text.trim(),
          expiryDate: expiryController.text.trim().isNotEmpty
              ? expiryController.text.trim()
              : null,
          noExpiry: noExpiry,
          lowStockBaseline: lowStockThreshold,
          fieldChanges: fieldChanges,
        );
      } catch (logError) {
        // Log error but don't fail the save operation
        print('Failed to log activity: $logError');
      }

      // Check for notifications (wrap in try-catch to prevent breaking save)
      try {
        final notificationsController = NotificationsController();

        // Check expiry notifications if expiry changed
        if ((expiryController.text.trim() != (originalExpiry ?? '')) ||
            (noExpiry != (originalNoExpiry ?? false))) {
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
        }

        // Check stock level notifications if stock changed
        final newStock = int.tryParse(stockController.text.trim()) ?? 0;
        final prevStock = originalStock ?? 0;
        if (newStock != prevStock) {
          // Pass batchId so we can calculate status before/after accurately
          await notificationsController.checkStockLevelNotification(
            nameController.text.trim(),
            newStock,
            prevStock,
            batchId: docId,
          );
        }
      } catch (notificationError) {
        // Log error but don't fail the save operation
        print('Failed to check notifications: $notificationError');
      }

      return null; // Success
    } catch (e) {
      return 'Failed to update supply: $e';
    }
  }
}
