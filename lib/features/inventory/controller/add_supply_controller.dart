import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'filter_controller.dart';
import 'package:familee_dental/features/activity_log/controller/inventory_activity_controller.dart';
import 'package:familee_dental/features/notifications/controller/notifications_controller.dart';

class AddSupplyController {
  final SupabaseClient _supabase = Supabase.instance.client;
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
      "image_url": imageUrl ?? "", // Make image optional
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
      "no_expiry": noExpiry,
      "archived": false,
      "created_at": DateTime.now().toIso8601String(),
    };
  }

  Future<String?> addSupply() async {
    final error = validateFields();
    if (error != null) return error;
    final supplyData = buildSupplyData();
    try {
      // Add supply to Supabase
      await _supabase.from('supplies').insert(supplyData);

      // Auto-manage brands and suppliers
      await filterController.addBrandIfNotExists(brandController.text.trim());
      await filterController
          .addSupplierIfNotExists(supplierController.text.trim());

      // Log the activity
      await InventoryActivityController().logInventorySupplyAdded(
        itemName: nameController.text.trim(),
        category: selectedCategory!,
        stock: int.tryParse(stockController.text.trim()) ?? 0,
        unit: selectedUnit!,
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
      final newStock = int.tryParse(stockController.text.trim()) ?? 0;

      // Check stock level notifications (new item, so previous stock is 0)
      await notificationsController.checkStockLevelNotification(
        nameController.text.trim(),
        newStock,
        0, // previous stock is 0 for new items
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
}
