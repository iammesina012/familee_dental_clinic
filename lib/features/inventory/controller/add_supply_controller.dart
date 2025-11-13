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

      // Check if an exact duplicate supply exists (all fields match)
      final supplierValue = supplierController.text.trim().isEmpty
          ? "N/A"
          : supplierController.text.trim();
      final brandValue = brandController.text.trim().isEmpty
          ? "N/A"
          : brandController.text.trim();
      final costValue = double.tryParse(costController.text.trim()) ?? 0.0;
      final categoryValue = selectedCategory ?? "";
      final packagingUnitValue = selectedPackagingUnit ?? "";
      final packagingContentValue = isPackagingContentDisabled()
          ? null
          : (selectedPackagingContent ?? "");
      final expiryValue = noExpiry || expiryController.text.isEmpty
          ? null
          : expiryController.text;

      // Query for potential duplicates - query by key fields first, then check all fields
      // Note: We query by non-nullable fields, then check nullable fields in code
      var duplicateQuery = _supabase
          .from('supplies')
          .select(
              'id, cost, packaging_content, expiry, no_expiry, supplier, brand, category, packaging_unit, low_stock_baseline')
          .eq('name', nameController.text.trim())
          .eq('archived', false);

      // Get all potential matches and check all fields
      final existingSupplies = await duplicateQuery;
      bool foundDuplicate = false;

      for (final row in existingSupplies) {
        // Check supplier
        final existingSupplier = (row['supplier'] ?? 'N/A').toString();
        final supplierMatches = supplierValue == 'N/A'
            ? (existingSupplier == 'N/A' || existingSupplier.isEmpty)
            : supplierValue == existingSupplier;

        // Check brand
        final existingBrand = (row['brand'] ?? 'N/A').toString();
        final brandMatches = brandValue == 'N/A'
            ? (existingBrand == 'N/A' || existingBrand.isEmpty)
            : brandValue == existingBrand;

        // Check category
        final existingCategory = (row['category'] ?? '').toString();
        final categoryMatches = categoryValue == existingCategory;

        // Check packaging unit
        final existingPackagingUnit = (row['packaging_unit'] ?? '').toString();
        final packagingUnitMatches =
            packagingUnitValue == existingPackagingUnit;

        // Check low stock baseline
        final existingLowStockBaseline = row['low_stock_baseline'] != null
            ? (row['low_stock_baseline'] as num).toInt()
            : null;
        final lowStockBaselineMatches =
            lowStockThreshold == (existingLowStockBaseline ?? 0);

        // Check cost (with tolerance for floating point)
        final existingCost = (row['cost'] ?? 0.0).toDouble();
        final costMatches = (costValue - existingCost).abs() < 0.01;

        // Check packaging content match
        final existingPackagingContent = row['packaging_content'];
        final packagingContentMatches = (packagingContentValue == null &&
                (existingPackagingContent == null ||
                    existingPackagingContent.toString().isEmpty)) ||
            (packagingContentValue != null &&
                existingPackagingContent != null &&
                packagingContentValue == existingPackagingContent.toString());

        // Check expiry match
        final existingExpiry = row['expiry'];
        final existingNoExpiry = row['no_expiry'] ?? false;
        final expiryMatches = (expiryValue == null &&
                (existingExpiry == null ||
                    existingExpiry.toString().isEmpty ||
                    existingNoExpiry == true)) ||
            (expiryValue != null &&
                existingExpiry != null &&
                expiryValue == existingExpiry.toString());

        // All fields must match for it to be a duplicate
        if (supplierMatches &&
            brandMatches &&
            categoryMatches &&
            packagingUnitMatches &&
            lowStockBaselineMatches &&
            costMatches &&
            packagingContentMatches &&
            expiryMatches) {
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
      );

      return null; // Success
    } catch (e) {
      return 'Failed to add supply: $e';
    }
  }

  // Smart autofill methods
  Future<void> autoFillFromExistingSupply(String supplyName) async {
    if (supplyName.trim().isEmpty) return;

    try {
      // Find existing supplies with the same name
      final response = await _supabase
          .from('supplies')
          .select('supplier, brand, type')
          .eq('name', supplyName.trim())
          .eq('archived', false)
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isNotEmpty) {
        final row = response.first;
        final supplier = row['supplier'] as String?;
        final brand = row['brand'] as String?;

        // Auto-fill supplier and brand if they exist and are not "N/A"
        if (supplier != null && supplier.isNotEmpty && supplier != 'N/A') {
          supplierController.text = supplier;
        }
        if (brand != null && brand.isNotEmpty && brand != 'N/A') {
          brandController.text = brand;
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
