import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'filter_controller.dart';

class AddSupplyController {
  final nameController = TextEditingController();
  final costController = TextEditingController();
  final stockController = TextEditingController(text: "0");
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
    if (!noExpiry &&
        (expiryController.text.trim().isEmpty || expiryDate == null)) {
      return 'Please enter the expiry date or check "No expiry date" if there\'s none.';
    }

    return null;
  }

  Map<String, dynamic> buildSupplyData() {
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
      "createdAt": FieldValue.serverTimestamp(),
    };
  }

  Future<String?> addSupply() async {
    final error = validateFields();
    if (error != null) return error;
    final supplyData = buildSupplyData();
    try {
      // Add supply to Firestore
      await FirebaseFirestore.instance.collection('supplies').add(supplyData);

      // Auto-manage brands and suppliers
      await filterController.addBrandIfNotExists(brandController.text.trim());
      await filterController
          .addSupplierIfNotExists(supplierController.text.trim());

      return null; // Success
    } catch (e) {
      return 'Failed to add supply: $e';
    }
  }
}
