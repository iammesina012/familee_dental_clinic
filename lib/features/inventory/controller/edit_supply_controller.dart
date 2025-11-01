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

  int stock = 0;
  String? selectedCategory;
  String? selectedUnit;
  String? selectedPackagingUnit;
  String? selectedPackagingContent;
  int packagingQuantity = 1;
  int packagingContent = 1;
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
    packagingQuantityController.text = packagingQuantity.toString();
    packagingContentController.text = packagingContent.toString();
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
      final existingQuery = await _supabase
          .from('supplies')
          .select('*')
          .eq('name', name)
          .eq('brand', brand)
          .eq('type', type);

      // Find a matching document (excluding current) with the same expiry (null == null allowed)
      Map<String, dynamic>? mergeTarget;
      for (final row in existingQuery) {
        if (row['id'] == docId) continue;
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
        if (expiryMatches) {
          mergeTarget = row;
          break;
        }
      }

      if (mergeTarget != null) {
        // Merge stock into the target and delete the current document
        final int targetStock = (mergeTarget['stock'] ?? 0) as int;
        final int thisStock = (updatedData['stock'] ?? 0) as int;
        final int mergedStock = targetStock + thisStock;

        final Map<String, dynamic> updates = {'stock': mergedStock};
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

      // Log the edit activity with detailed field changes
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
        fieldChanges: fieldChanges,
      );

      // Check for notifications
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
        );
      }

      return null; // Success
    } catch (e) {
      return 'Failed to update supply: $e';
    }
  }
}
