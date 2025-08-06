import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../data/inventory_item.dart';
import 'filter_controller.dart';

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
    selectedUnit = item.unit;
    noExpiry = item.noExpiry;
    imageUrl = item.imageUrl;
    expiryDate = (item.expiry != null && item.expiry!.isNotEmpty)
        ? DateTime.tryParse(item.expiry!)
        : null;

    // Store original values for comparison
    originalBrand = item.brand == "N/A" ? "" : item.brand;
    originalSupplier = item.supplier == "N/A" ? "" : item.supplier;
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
    // Check if the text contains at least one letter and is alphanumeric
    return RegExp(r'^[a-zA-Z0-9\s]+$').hasMatch(text.trim()) &&
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
    if (!noExpiry &&
        (expiryController.text.trim().isEmpty || expiryDate == null)) {
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
      "expiry": noExpiry || expiryController.text.isEmpty
          ? null
          : expiryController.text,
      "noExpiry": noExpiry,
    };
  }

  Future<String?> updateSupply(String docId) async {
    final error = validateFields();
    if (error != null) return error;
    final updatedData = buildUpdatedData();
    try {
      // Update supply in Firestore
      await FirebaseFirestore.instance
          .collection('supplies')
          .doc(docId)
          .update(updatedData);

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

      return null; // Success
    } catch (e) {
      return 'Failed to update supply: $e';
    }
  }
}
