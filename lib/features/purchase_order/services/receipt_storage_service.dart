import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ReceiptStorageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Upload receipt image to Supabase Storage
  /// Returns the public URL of the uploaded image
  Future<String?> uploadReceiptImage(XFile imageFile) async {
    try {
      final isPng = imageFile.path.toLowerCase().endsWith('.png');
      final fileExtension = isPng ? 'png' : 'jpg';
      final fileName =
          'receipt_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final Uint8List bytes = await imageFile.readAsBytes();

      debugPrint("Uploading receipt image to receipts bucket...");
      debugPrint("File size: ${bytes.length} bytes");
      debugPrint("File name: $fileName");
      debugPrint("Full path: receipts/$fileName");

      // Upload to receipts bucket
      await _supabase.storage
          .from('receipts')
          .uploadBinary('receipts/$fileName', bytes);

      debugPrint("Receipt upload completed successfully");

      // Get public URL
      final publicUrl =
          _supabase.storage.from('receipts').getPublicUrl('receipts/$fileName');

      debugPrint("Generated receipt URL: $publicUrl");
      return publicUrl;
    } catch (e) {
      debugPrint("Receipt upload error: $e");
      debugPrint("Error type: ${e.runtimeType}");

      // Provide specific error messages
      if (e.toString().contains('bucket')) {
        debugPrint("Receipts bucket not found or not accessible");
      } else if (e.toString().contains('permission')) {
        debugPrint("Permission denied for receipts bucket");
      } else if (e.toString().contains('auth')) {
        debugPrint("Authentication error for receipt upload");
      }

      return null;
    }
  }

  /// Delete receipt image from Supabase Storage
  Future<bool> deleteReceiptImage(String imageUrl) async {
    try {
      // Extract file path from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      if (pathSegments.length < 3) {
        debugPrint("Invalid receipt image URL format");
        return false;
      }

      // Path should be: /storage/v1/object/public/receipts/receipts/filename
      final fileName = pathSegments.last;
      final filePath = 'receipts/$fileName';

      debugPrint("Deleting receipt image: $filePath");

      await _supabase.storage.from('receipts').remove([filePath]);

      debugPrint("Receipt image deleted successfully");
      return true;
    } catch (e) {
      debugPrint("Error deleting receipt image: $e");
      return false;
    }
  }

  /// Check if receipts bucket exists and is accessible
  Future<bool> checkReceiptsBucketAccess() async {
    try {
      await _supabase.storage.from('receipts').list();
      return true;
    } catch (e) {
      debugPrint("Receipts bucket access check failed: $e");
      return false;
    }
  }
}
