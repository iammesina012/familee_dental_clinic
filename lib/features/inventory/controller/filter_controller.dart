import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/activity_log/controller/inventory_activity_controller.dart';

class FilterController {
  // Singleton pattern to ensure cache persists across widget rebuilds
  static final FilterController _instance = FilterController._internal();
  factory FilterController() => _instance;
  FilterController._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache for last known data (persists across widget rebuilds)
  List<Brand>? _cachedBrands;
  List<Supplier>? _cachedSuppliers;

  // Get all brands for filter
  Stream<List<Brand>> getBrandsStream() {
    final controller = StreamController<List<Brand>>.broadcast();

    // Emit cached data immediately if available (no delay - instant feedback)
    if (_cachedBrands != null) {
      controller.add(_cachedBrands!);
    }

    try {
      _supabase.from('brands').stream(primaryKey: ['id']).listen(
        (data) {
          try {
            final brands = data
                .map((row) => Brand.fromMap(row['id'] as String, row))
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

            // Cache the result
            _cachedBrands = brands;
            controller.add(brands);
          } catch (e) {
            // On error, emit cached data if available
            if (_cachedBrands != null) {
              controller.add(_cachedBrands!);
            } else {
              controller.add([]);
            }
          }
        },
        onError: (error) {
          // On stream error, emit cached data if available
          if (_cachedBrands != null) {
            controller.add(_cachedBrands!);
          } else {
            controller.add([]);
          }
        },
      );
    } catch (e) {
      // If stream creation fails, emit cached data if available
      if (_cachedBrands != null) {
        controller.add(_cachedBrands!);
      } else {
        controller.add([]);
      }
    }

    return controller.stream;
  }

  // Get all suppliers for filter
  Stream<List<Supplier>> getSuppliersStream() {
    final controller = StreamController<List<Supplier>>.broadcast();

    // Emit cached data immediately if available (no delay - instant feedback)
    if (_cachedSuppliers != null) {
      controller.add(_cachedSuppliers!);
    }

    try {
      _supabase.from('suppliers').stream(primaryKey: ['id']).listen(
        (data) {
          try {
            final suppliers = data
                .map((row) => Supplier.fromMap(row['id'] as String, row))
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

            // Cache the result
            _cachedSuppliers = suppliers;
            controller.add(suppliers);
          } catch (e) {
            // On error, emit cached data if available
            if (_cachedSuppliers != null) {
              controller.add(_cachedSuppliers!);
            } else {
              controller.add([]);
            }
          }
        },
        onError: (error) {
          // On stream error, emit cached data if available
          if (_cachedSuppliers != null) {
            controller.add(_cachedSuppliers!);
          } else {
            controller.add([]);
          }
        },
      );
    } catch (e) {
      // If stream creation fails, emit cached data if available
      if (_cachedSuppliers != null) {
        controller.add(_cachedSuppliers!);
      } else {
        controller.add([]);
      }
    }

    return controller.stream;
  }

  // Check if brand name already exists
  Future<bool> brandExists(String brandName) async {
    if (brandName.trim().isEmpty) return false;

    final response = await _supabase
        .from('brands')
        .select('id')
        .eq('name', brandName.trim())
        .limit(1);

    return response.isNotEmpty;
  }

  // Add new brand if it doesn't exist
  Future<bool> addBrandIfNotExists(String brandName) async {
    if (brandName.trim().isEmpty) return false;

    // Check if brand already exists (case-insensitive)
    final existingBrands = await _supabase.from('brands').select('name');

    final normalizedInput = brandName.trim().toLowerCase();
    final exists = existingBrands.any(
        (row) => (row['name'] as String?)?.toLowerCase() == normalizedInput);

    if (!exists) {
      // Add new brand
      await _supabase.from('brands').insert({
        'name': brandName.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Log the brand creation activity
      await InventoryActivityController().logBrandAdded(
        brandName: brandName.trim(),
      );
      return true;
    }
    return false;
  }

  // Check if there are supplies with "N/A" brand that can be restored to this brand
  Future<int> getSuppliesWithNABrand(String brandName) async {
    if (brandName.trim().isEmpty) return 0;

    final supplies = await _supabase
        .from('supplies')
        .select('original_brand')
        .eq('brand', 'N/A');

    // Count supplies that have this brand as their original brand
    int count = 0;
    for (final supply in supplies) {
      final originalBrand = (supply['original_brand'] as String?) ?? '';
      if (originalBrand.toLowerCase() == brandName.trim().toLowerCase()) {
        count++;
      }
    }

    return count;
  }

  // Restore supplies with "N/A" brand to the specified brand
  Future<void> restoreSuppliesToBrand(String brandName) async {
    if (brandName.trim().isEmpty) return;

    final supplies = await _supabase
        .from('supplies')
        .select('id, original_brand')
        .eq('brand', 'N/A');

    for (final supply in supplies) {
      final originalBrand = (supply['original_brand'] as String?) ?? '';
      if (originalBrand.toLowerCase() == brandName.trim().toLowerCase()) {
        await _supabase.from('supplies').update({
          'brand': brandName.trim(),
          'original_brand': null, // Remove the original brand field
        }).eq('id', supply['id']);
      }
    }
  }

  // Check if supplier name already exists
  Future<bool> supplierExists(String supplierName) async {
    if (supplierName.trim().isEmpty) return false;

    final response = await _supabase
        .from('suppliers')
        .select('id')
        .eq('name', supplierName.trim())
        .limit(1);

    return response.isNotEmpty;
  }

  // Add new supplier if it doesn't exist
  Future<bool> addSupplierIfNotExists(String supplierName) async {
    if (supplierName.trim().isEmpty) return false;

    // Check if supplier already exists (case-insensitive)
    final existingSuppliers = await _supabase.from('suppliers').select('name');

    final normalizedInput = supplierName.trim().toLowerCase();
    final exists = existingSuppliers.any(
        (row) => (row['name'] as String?)?.toLowerCase() == normalizedInput);

    if (!exists) {
      // Add new supplier
      await _supabase.from('suppliers').insert({
        'name': supplierName.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Log the supplier creation activity
      await InventoryActivityController().logSupplierAdded(
        supplierName: supplierName.trim(),
      );
      return true;
    }
    return false;
  }

  // Check if there are supplies with "N/A" supplier that can be restored to this supplier
  Future<int> getSuppliesWithNASupplier(String supplierName) async {
    if (supplierName.trim().isEmpty) return 0;

    final supplies = await _supabase
        .from('supplies')
        .select('original_supplier')
        .eq('supplier', 'N/A');

    // Count supplies that have this supplier as their original supplier
    int count = 0;
    for (final supply in supplies) {
      final originalSupplier = (supply['original_supplier'] as String?) ?? '';
      if (originalSupplier.toLowerCase() == supplierName.trim().toLowerCase()) {
        count++;
      }
    }

    return count;
  }

  // Restore supplies with "N/A" supplier to the specified supplier
  Future<void> restoreSuppliesToSupplier(String supplierName) async {
    if (supplierName.trim().isEmpty) return;

    final supplies = await _supabase
        .from('supplies')
        .select('id, original_supplier')
        .eq('supplier', 'N/A');

    for (final supply in supplies) {
      final originalSupplier = (supply['original_supplier'] as String?) ?? '';
      if (originalSupplier.toLowerCase() == supplierName.trim().toLowerCase()) {
        await _supabase.from('supplies').update({
          'supplier': supplierName.trim(),
          'original_supplier': null, // Remove the original supplier field
        }).eq('id', supply['id']);
      }
    }
  }

  // Update brand name across all supplies
  Future<void> updateBrandName(String oldName, String newName) async {
    if (oldName.trim().isEmpty || newName.trim().isEmpty) return;

    // Check if the new brand name already exists
    final newBrandExists = await brandExists(newName.trim());

    if (newBrandExists) {
      // If new brand already exists, just update all supplies to use the existing brand
      await _supabase
          .from('supplies')
          .update({'brand': newName.trim()}).eq('brand', oldName.trim());
    } else {
      // If new brand doesn't exist, update the old brand name
      final brandResponse = await _supabase
          .from('brands')
          .select('id')
          .eq('name', oldName.trim())
          .limit(1);

      if (brandResponse.isNotEmpty) {
        await _supabase.from('brands').update({'name': newName.trim()}).eq(
            'id', brandResponse.first['id']);
      } else {
        // If old brand doesn't exist in brands collection, add the new one
        await addBrandIfNotExists(newName.trim());
      }

      // Update all supplies with this brand
      await _supabase
          .from('supplies')
          .update({'brand': newName.trim()}).eq('brand', oldName.trim());
    }

    // Log the brand update activity
    await InventoryActivityController().logBrandUpdated(
      oldBrandName: oldName.trim(),
      newBrandName: newName.trim(),
    );
  }

  // Update supplier name across all supplies
  Future<void> updateSupplierName(String oldName, String newName) async {
    if (oldName.trim().isEmpty || newName.trim().isEmpty) return;

    // Check if the new supplier name already exists
    final newSupplierExists = await supplierExists(newName.trim());

    if (newSupplierExists) {
      // If new supplier already exists, just update all supplies to use the existing supplier
      await _supabase
          .from('supplies')
          .update({'supplier': newName.trim()}).eq('supplier', oldName.trim());
    } else {
      // If new supplier doesn't exist, update the old supplier name
      final supplierResponse = await _supabase
          .from('suppliers')
          .select('id')
          .eq('name', oldName.trim())
          .limit(1);

      if (supplierResponse.isNotEmpty) {
        await _supabase.from('suppliers').update({'name': newName.trim()}).eq(
            'id', supplierResponse.first['id']);
      } else {
        // If old supplier doesn't exist in suppliers collection, add the new one
        await addSupplierIfNotExists(newName.trim());
      }

      // Update all supplies with this supplier
      await _supabase
          .from('supplies')
          .update({'supplier': newName.trim()}).eq('supplier', oldName.trim());
    }

    // Log the supplier update activity
    await InventoryActivityController().logSupplierUpdated(
      oldSupplierName: oldName.trim(),
      newSupplierName: newName.trim(),
    );
  }

  // Cache for brand names and supplier names (derived from cached brands/suppliers)
  List<String>? _cachedBrandNames;
  List<String>? _cachedSupplierNames;

  // Get brand names as list of strings
  Stream<List<String>> getBrandNamesStream() {
    final controller = StreamController<List<String>>.broadcast();

    // Emit cached names immediately if available
    if (_cachedBrandNames != null) {
      controller.add(_cachedBrandNames!);
    }

    getBrandsStream().listen(
      (brands) {
        try {
          final brandNames =
              brands.map((b) => b.name).where((name) => name != "N/A").toList();
          _cachedBrandNames = brandNames;
          controller.add(brandNames);
        } catch (e) {
          if (_cachedBrandNames != null) {
            controller.add(_cachedBrandNames!);
          } else {
            controller.add([]);
          }
        }
      },
      onError: (error) {
        if (_cachedBrandNames != null) {
          controller.add(_cachedBrandNames!);
        } else {
          controller.add([]);
        }
      },
    );

    return controller.stream;
  }

  // Get supplier names as list of strings
  Stream<List<String>> getSupplierNamesStream() {
    final controller = StreamController<List<String>>.broadcast();

    // Emit cached names immediately if available
    if (_cachedSupplierNames != null) {
      controller.add(_cachedSupplierNames!);
    }

    getSuppliersStream().listen(
      (suppliers) {
        try {
          final supplierNames = suppliers
              .map((s) => s.name)
              .where((name) => name != "N/A")
              .toList();
          _cachedSupplierNames = supplierNames;
          controller.add(supplierNames);
        } catch (e) {
          if (_cachedSupplierNames != null) {
            controller.add(_cachedSupplierNames!);
          } else {
            controller.add([]);
          }
        }
      },
      onError: (error) {
        if (_cachedSupplierNames != null) {
          controller.add(_cachedSupplierNames!);
        } else {
          controller.add([]);
        }
      },
    );

    return controller.stream;
  }

  // Migration function to extract existing brands and suppliers from supplies
  Future<void> migrateExistingBrandsAndSuppliers() async {
    try {
      // Get all supplies
      final supplies =
          await _supabase.from('supplies').select('brand, supplier');

      final Set<String> existingBrands = {};
      final Set<String> existingSuppliers = {};

      // Extract unique brands and suppliers from existing supplies
      for (final supply in supplies) {
        final brand = (supply['brand'] as String?)?.trim();
        final supplier = (supply['supplier'] as String?)?.trim();

        if (brand != null && brand.isNotEmpty) {
          existingBrands.add(brand);
        }
        if (supplier != null && supplier.isNotEmpty) {
          existingSuppliers.add(supplier);
        }
      }

      // Add existing brands to brands collection
      for (final brandName in existingBrands) {
        await addBrandIfNotExists(brandName);
      }

      // Add existing suppliers to suppliers collection
      for (final supplierName in existingSuppliers) {
        await addSupplierIfNotExists(supplierName);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // Remove duplicate brands and suppliers
  Future<void> removeDuplicates() async {
    try {
      // Remove duplicate brands
      final brands = await _supabase.from('brands').select('id, name');
      final Map<String, List<String>> brandGroups = {};

      for (final brand in brands) {
        final brandName = (brand['name'] as String?)?.trim() ?? '';
        if (brandName.isNotEmpty) {
          brandGroups
              .putIfAbsent(brandName, () => [])
              .add(brand['id'] as String);
        }
      }

      // Delete duplicate brand documents (keep the first one)
      for (final entry in brandGroups.entries) {
        if (entry.value.length > 1) {
          // Keep the first document, delete the rest
          for (int i = 1; i < entry.value.length; i++) {
            await _supabase.from('brands').delete().eq('id', entry.value[i]);
          }
        }
      }

      // Remove duplicate suppliers
      final suppliers = await _supabase.from('suppliers').select('id, name');
      final Map<String, List<String>> supplierGroups = {};

      for (final supplier in suppliers) {
        final supplierName = (supplier['name'] as String?)?.trim() ?? '';
        if (supplierName.isNotEmpty) {
          supplierGroups
              .putIfAbsent(supplierName, () => [])
              .add(supplier['id'] as String);
        }
      }

      // Delete duplicate supplier documents (keep the first one)
      for (final entry in supplierGroups.entries) {
        if (entry.value.length > 1) {
          // Keep the first document, delete the rest
          for (int i = 1; i < entry.value.length; i++) {
            await _supabase.from('suppliers').delete().eq('id', entry.value[i]);
          }
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // Delete brand and update all supplies to use "N/A"
  Future<void> deleteBrand(String brandName) async {
    if (brandName.trim().isEmpty) return;

    try {
      // Update all supplies with this brand to use "N/A" and store original brand
      await _supabase.from('supplies').update({
        'brand': 'N/A',
        'original_brand':
            brandName.trim(), // Store original brand for restoration
      }).eq('brand', brandName.trim());

      // Delete brand from brands collection
      await _supabase.from('brands').delete().eq('name', brandName.trim());

      // Log the brand deletion activity
      await InventoryActivityController().logBrandDeleted(
        brandName: brandName.trim(),
      );
    } catch (e) {
      print('Error deleting brand: $e');
      rethrow;
    }
  }

  // Delete supplier and update all supplies to use "N/A"
  Future<void> deleteSupplier(String supplierName) async {
    if (supplierName.trim().isEmpty) return;

    try {
      // Update all supplies with this supplier to use "N/A" and store original supplier
      await _supabase.from('supplies').update({
        'supplier': 'N/A',
        'original_supplier':
            supplierName.trim(), // Store original supplier for restoration
      }).eq('supplier', supplierName.trim());

      // Delete supplier from suppliers collection
      await _supabase
          .from('suppliers')
          .delete()
          .eq('name', supplierName.trim());

      // Log the supplier deletion activity
      await InventoryActivityController().logSupplierDeleted(
        supplierName: supplierName.trim(),
      );
    } catch (e) {
      print('Error deleting supplier: $e');
      rethrow;
    }
  }
}
