import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../data/inventory_item.dart';
import 'filter_controller.dart';
import 'package:projects/features/activity_log/controller/inventory_activity_controller.dart';
import 'package:projects/features/notifications/controller/notifications_controller.dart';

class EditSupplyController {
  final nameController = TextEditingController();
  final costController = TextEditingController();
  final stockController = TextEditingController();
  final supplierController = TextEditingController();
  final brandController = TextEditingController();
  final expiryController = TextEditingController();

  int stock = 0;
  String? selectedCategory;
  String? selectedUnit;
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
  String? originalCategory;
  int? originalStock;
  String? originalUnit;
  double? originalCost;
  String? originalExpiry;
  bool? originalNoExpiry;
  String? originalBrand;
  String? originalSupplier;

  void initFromItem(InventoryItem item) {
    nameController.text = item.name;
    costController.text = item.cost.toString();
    stockController.text = item.stock.toString();
    supplierController.text = item.supplier == "N/A" ? "" : item.supplier;
    brandController.text = item.brand == "N/A" ? "" : item.brand;
    expiryController.text = item.expiry ?? '';
    stock = item.stock;
    selectedCategory = item.category;
    selectedUnit = _normalizeUnit(item.unit);
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
    originalCategory = item.category;
    originalStock = item.stock;
    originalUnit = item.unit;
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
    // Map common variants to our canonical set used in dropdown: Box, Piece, Pack
    if (s == 'box' || s == 'boxes' || s == 'bx') return 'Box';
    if (s == 'pack' || s == 'packs' || s == 'pk') return 'Pack';
    if (s == 'piece' ||
        s == 'pieces' ||
        s == 'pc' ||
        s == 'pcs' ||
        s == 'unit' ||
        s == 'units') {
      return 'Piece';
    }
    // If it already matches one of the allowed labels ignoring case
    final allowed = ['Box', 'Piece', 'Pack'];
    for (final a in allowed) {
      if (a.toLowerCase() == s) return a;
    }
    // Fallback to Piece to avoid dropdown mismatch
    return 'Piece';
  }

  void dispose() {
    nameController.dispose();
    costController.dispose();
    stockController.dispose();
    supplierController.dispose();
    brandController.dispose();
    expiryController.dispose();
  }

  Future<String?> uploadImageToSupabase(XFile imageFile) async {
    try {
      final supabase = Supabase.instance.client;
      final isPng = imageFile.path.toLowerCase().endsWith('.png');
      final fileExtension = isPng ? 'png' : 'jpg';
      final contentType = isPng ? 'image/png' : 'image/jpeg';
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      Uint8List bytes = await imageFile.readAsBytes();
      final response =
          await supabase.storage.from('inventory-images').uploadBinary(
                'uploads/$fileName',
                bytes,
                fileOptions: FileOptions(contentType: contentType),
              );
      if (response.isEmpty) {
        debugPrint("Upload failed: empty response");
        return null;
      }
      final publicUrl = supabase.storage
          .from('inventory-images')
          .getPublicUrl('uploads/$fileName');
      return publicUrl;
    } catch (e) {
      debugPrint("Upload error: $e");
      return null;
    }
  }

  // Helper function to validate alphanumeric input
  bool _isValidAlphanumeric(String text) {
    if (text.trim().isEmpty) return true; // Allow empty for optional fields
    // Check if the text contains only numbers
    if (RegExp(r'^[0-9]+$').hasMatch(text.trim())) {
      return false;
    }
    // Check if the text contains at least one letter and allows common characters
    return RegExp(r'^[a-zA-Z0-9\s\-_\.]+$').hasMatch(text.trim()) &&
        RegExp(r'[a-zA-Z]').hasMatch(text.trim());
  }

  String? validateFields() {
    // Required fields validation
    if (nameController.text.trim().isEmpty) {
      return 'Please enter the item name.';
    }

    // Validate item name is alphanumeric and not just numbers
    if (!_isValidAlphanumeric(nameController.text.trim())) {
      return 'Item name must contain letters and cannot be only numbers.';
    }

    if (selectedCategory == null || selectedCategory!.isEmpty) {
      return 'Please choose a category.';
    }
    if (selectedUnit == null || selectedUnit!.isEmpty) {
      return 'Please choose a unit.';
    }
    if (costController.text.trim().isEmpty) {
      return 'Please enter the cost.';
    }
    if (double.tryParse(costController.text.trim()) == null) {
      return 'Cost must be a valid number.';
    }
    if (stockController.text.trim().isEmpty) {
      return 'Please enter the stock quantity.';
    }
    if (int.tryParse(stockController.text.trim()) == null) {
      return 'Stock must be a valid number.';
    }

    // Validate supplier name if provided
    if (supplierController.text.trim().isNotEmpty &&
        !_isValidAlphanumeric(supplierController.text.trim())) {
      return 'Supplier name must contain letters and cannot be only numbers.';
    }

    // Validate brand name if provided
    if (brandController.text.trim().isNotEmpty &&
        !_isValidAlphanumeric(brandController.text.trim())) {
      return 'Brand name must contain letters and cannot be only numbers.';
    }

    // Expiry date validation
    if (!noExpiry && expiryController.text.trim().isEmpty) {
      return 'Please enter the expiry date or check "No expiry date" if there\'s none.';
    }

    return null;
  }

  Map<String, dynamic> buildUpdatedData() {
    return {
      "name": nameController.text.trim(),
      "imageUrl": imageUrl ?? "", // Make image optional
      "category": selectedCategory ?? "",
      "cost": double.tryParse(costController.text.trim()) ?? 0.0,
      "stock": int.tryParse(stockController.text.trim()) ?? 0,
      "unit": selectedUnit ?? "",
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
      "noExpiry": noExpiry,
    };
  }

  Future<String?> updateSupply(String docId) async {
    final error = validateFields();
    if (error != null) return error;
    final updatedData = buildUpdatedData();
    try {
      final suppliesRef = FirebaseFirestore.instance.collection('supplies');

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

      final existingQuery = await suppliesRef
          .where('name', isEqualTo: name)
          .where('brand', isEqualTo: brand)
          .get();

      // Find a matching document (excluding current) with the same expiry (null == null allowed)
      QueryDocumentSnapshot<Map<String, dynamic>>? mergeTarget;
      for (final doc in existingQuery.docs) {
        if (doc.id == docId) continue;
        final data = doc.data();
        final dynamic otherExpiryRaw = data['expiry'];
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
          mergeTarget = doc;
          break;
        }
      }

      if (mergeTarget != null) {
        // Merge stock into the target and delete the current document
        final targetData = mergeTarget.data();
        final int targetStock = (targetData['stock'] ?? 0) as int;
        final int thisStock = (updatedData['stock'] ?? 0) as int;
        final int mergedStock = targetStock + thisStock;

        final Map<String, dynamic> updates = {'stock': mergedStock};
        // Fill missing fields on target if needed
        if ((targetData['imageUrl'] ?? '').toString().isEmpty &&
            (updatedData['imageUrl'] ?? '').toString().isNotEmpty) {
          updates['imageUrl'] = updatedData['imageUrl'];
        }
        if (targetData['archived'] == null) {
          updates['archived'] = false;
        }

        await suppliesRef.doc(mergeTarget.id).update(updates);
        await suppliesRef.doc(docId).delete();
      } else {
        // No merge target; just update this document normally
        await suppliesRef.doc(docId).update(updatedData);
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
      if ((int.tryParse(stockController.text.trim()) ?? 0) !=
          (originalStock ?? 0)) {
        fieldChanges['Stock'] = {
          'previous': originalStock ?? 0,
          'new': int.tryParse(stockController.text.trim()) ?? 0,
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
        category: selectedCategory ?? 'Unknown Category',
        stock: int.tryParse(stockController.text.trim()) ?? 0,
        unit: selectedUnit ?? 'Unknown Unit',
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
      final newStock = int.tryParse(stockController.text.trim()) ?? 0;

      // Check stock level notifications if stock changed
      if (newStock != (originalStock ?? 0)) {
        await notificationsController.checkStockLevelNotification(
          nameController.text.trim(),
          newStock,
          originalStock ?? 0,
        );
      }

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
