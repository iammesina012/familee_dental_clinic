import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class InventoryStorageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Upload inventory image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String?> uploadImageToSupabase(XFile imageFile) async {
    try {
      final supabase = Supabase.instance.client;
      final isPng = imageFile.path.toLowerCase().endsWith('.png');
      final fileExtension = isPng ? 'png' : 'jpg';
      final contentType = isPng ? 'image/png' : 'image/jpeg';
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      Uint8List bytes = await imageFile.readAsBytes();

      // Use uploadBinary for Uint8List data
      await supabase.storage
          .from('inventory-images')
          .uploadBinary('uploads/$fileName', bytes);

      final publicUrl = supabase.storage
          .from('inventory-images')
          .getPublicUrl('uploads/$fileName');
      return publicUrl;
    } catch (e) {
      debugPrint("Inventory image upload failed: $e");
      return null;
    }
  }

  /// Delete inventory image from Supabase Storage
  Future<bool> deleteInventoryImage(String imageUrl) async {
    try {
      // Extract file path from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      if (pathSegments.length < 3) {
        return false;
      }

      // Path should be: /storage/v1/object/public/inventory-images/uploads/filename
      final fileName = pathSegments.last;
      final filePath = 'uploads/$fileName';

      await _supabase.storage.from('inventory-images').remove([filePath]);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if inventory-images bucket exists and is accessible
  Future<bool> checkInventoryBucketAccess() async {
    try {
      await _supabase.storage.from('inventory-images').list();
      return true;
    } catch (e) {
      return false;
    }
  }
}
