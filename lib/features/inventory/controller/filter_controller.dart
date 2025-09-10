import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/inventory_item.dart';
import 'package:projects/features/activity_log/controller/inventory_activity_controller.dart';

class FilterController {
  final FirebaseFirestore firestore;

  FilterController({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  // Get all brands for filter
  Stream<List<Brand>> getBrandsStream() {
    return firestore.collection('brands').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Brand.fromMap(doc.id, doc.data())).toList()
          ..sort((a, b) => a.name.compareTo(b.name)));
  }

  // Get all suppliers for filter
  Stream<List<Supplier>> getSuppliersStream() {
    return firestore.collection('suppliers').snapshots().map((snapshot) =>
        snapshot.docs
            .map((doc) => Supplier.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)));
  }

  // Check if brand name already exists
  Future<bool> brandExists(String brandName) async {
    if (brandName.trim().isEmpty) return false;

    final existingBrands = await firestore
        .collection('brands')
        .where('name', isEqualTo: brandName.trim())
        .get();

    return existingBrands.docs.isNotEmpty;
  }

  // Add new brand if it doesn't exist
  Future<bool> addBrandIfNotExists(String brandName) async {
    if (brandName.trim().isEmpty) return false;

    // Check if brand already exists (case-insensitive)
    final existingBrands = await firestore.collection('brands').get();

    final normalizedInput = brandName.trim().toLowerCase();
    final exists = existingBrands.docs.any((doc) =>
        doc.data()['name']?.toString().trim().toLowerCase() == normalizedInput);

    if (!exists) {
      // Add new brand
      await firestore.collection('brands').add({
        'name': brandName.trim(),
        'createdAt': FieldValue.serverTimestamp(),
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

    final suppliesDocs = await firestore
        .collection('supplies')
        .where('brand', isEqualTo: 'N/A')
        .get();

    // Count supplies that have this brand as their original brand
    int count = 0;
    for (final doc in suppliesDocs.docs) {
      final originalBrand = doc.data()['originalBrand']?.toString() ?? '';
      if (originalBrand.toLowerCase() == brandName.trim().toLowerCase()) {
        count++;
      }
    }

    return count;
  }

  // Restore supplies with "N/A" brand to the specified brand
  Future<void> restoreSuppliesToBrand(String brandName) async {
    if (brandName.trim().isEmpty) return;

    final suppliesDocs = await firestore
        .collection('supplies')
        .where('brand', isEqualTo: 'N/A')
        .get();

    final batch = firestore.batch();
    for (final doc in suppliesDocs.docs) {
      final originalBrand = doc.data()['originalBrand']?.toString() ?? '';
      if (originalBrand.toLowerCase() == brandName.trim().toLowerCase()) {
        batch.update(doc.reference, {
          'brand': brandName.trim(),
          'originalBrand':
              FieldValue.delete(), // Remove the original brand field
        });
      }
    }
    await batch.commit();
  }

  // Check if supplier name already exists
  Future<bool> supplierExists(String supplierName) async {
    if (supplierName.trim().isEmpty) return false;

    final existingSuppliers = await firestore
        .collection('suppliers')
        .where('name', isEqualTo: supplierName.trim())
        .get();

    return existingSuppliers.docs.isNotEmpty;
  }

  // Add new supplier if it doesn't exist
  Future<bool> addSupplierIfNotExists(String supplierName) async {
    if (supplierName.trim().isEmpty) return false;

    // Check if supplier already exists (case-insensitive)
    final existingSuppliers = await firestore.collection('suppliers').get();

    final normalizedInput = supplierName.trim().toLowerCase();
    final exists = existingSuppliers.docs.any((doc) =>
        doc.data()['name']?.toString().trim().toLowerCase() == normalizedInput);

    if (!exists) {
      // Add new supplier
      await firestore.collection('suppliers').add({
        'name': supplierName.trim(),
        'createdAt': FieldValue.serverTimestamp(),
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

    final suppliesDocs = await firestore
        .collection('supplies')
        .where('supplier', isEqualTo: 'N/A')
        .get();

    // Count supplies that have this supplier as their original supplier
    int count = 0;
    for (final doc in suppliesDocs.docs) {
      final originalSupplier = doc.data()['originalSupplier']?.toString() ?? '';
      if (originalSupplier.toLowerCase() == supplierName.trim().toLowerCase()) {
        count++;
      }
    }

    return count;
  }

  // Restore supplies with "N/A" supplier to the specified supplier
  Future<void> restoreSuppliesToSupplier(String supplierName) async {
    if (supplierName.trim().isEmpty) return;

    final suppliesDocs = await firestore
        .collection('supplies')
        .where('supplier', isEqualTo: 'N/A')
        .get();

    final batch = firestore.batch();
    for (final doc in suppliesDocs.docs) {
      final originalSupplier = doc.data()['originalSupplier']?.toString() ?? '';
      if (originalSupplier.toLowerCase() == supplierName.trim().toLowerCase()) {
        batch.update(doc.reference, {
          'supplier': supplierName.trim(),
          'originalSupplier':
              FieldValue.delete(), // Remove the original supplier field
        });
      }
    }
    await batch.commit();
  }

  // Update brand name across all supplies
  Future<void> updateBrandName(String oldName, String newName) async {
    if (oldName.trim().isEmpty || newName.trim().isEmpty) return;

    // Update brand in brands collection
    final brandDocs = await firestore
        .collection('brands')
        .where('name', isEqualTo: oldName.trim())
        .get();

    if (brandDocs.docs.isNotEmpty) {
      await brandDocs.docs.first.reference.update({
        'name': newName.trim(),
      });
    } else {
      // If old brand doesn't exist in brands collection, add the new one
      await addBrandIfNotExists(newName.trim());
    }

    // Update all supplies with this brand
    final suppliesDocs = await firestore
        .collection('supplies')
        .where('brand', isEqualTo: oldName.trim())
        .get();

    final batch = firestore.batch();
    for (final doc in suppliesDocs.docs) {
      batch.update(doc.reference, {'brand': newName.trim()});
    }
    await batch.commit();

    // Log the brand update activity
    await InventoryActivityController().logBrandUpdated(
      oldBrandName: oldName.trim(),
      newBrandName: newName.trim(),
    );
  }

  // Update supplier name across all supplies
  Future<void> updateSupplierName(String oldName, String newName) async {
    if (oldName.trim().isEmpty || newName.trim().isEmpty) return;

    // Update supplier in suppliers collection
    final supplierDocs = await firestore
        .collection('suppliers')
        .where('name', isEqualTo: oldName.trim())
        .get();

    if (supplierDocs.docs.isNotEmpty) {
      await supplierDocs.docs.first.reference.update({
        'name': newName.trim(),
      });
    } else {
      // If old supplier doesn't exist in suppliers collection, add the new one
      await addSupplierIfNotExists(newName.trim());
    }

    // Update all supplies with this supplier
    final suppliesDocs = await firestore
        .collection('supplies')
        .where('supplier', isEqualTo: oldName.trim())
        .get();

    final batch = firestore.batch();
    for (final doc in suppliesDocs.docs) {
      batch.update(doc.reference, {'supplier': newName.trim()});
    }
    await batch.commit();

    // Log the supplier update activity
    await InventoryActivityController().logSupplierUpdated(
      oldSupplierName: oldName.trim(),
      newSupplierName: newName.trim(),
    );
  }

  // Get brand names as list of strings
  Stream<List<String>> getBrandNamesStream() {
    return getBrandsStream().map((brands) =>
        brands.map((b) => b.name).where((name) => name != "N/A").toList());
  }

  // Get supplier names as list of strings
  Stream<List<String>> getSupplierNamesStream() {
    return getSuppliersStream().map((suppliers) =>
        suppliers.map((s) => s.name).where((name) => name != "N/A").toList());
  }

  // Migration function to extract existing brands and suppliers from supplies
  Future<void> migrateExistingBrandsAndSuppliers() async {
    try {
      // Get all supplies
      final suppliesSnapshot = await firestore.collection('supplies').get();

      final Set<String> existingBrands = {};
      final Set<String> existingSuppliers = {};

      // Extract unique brands and suppliers from existing supplies
      for (final doc in suppliesSnapshot.docs) {
        final data = doc.data();
        final brand = data['brand']?.toString().trim();
        final supplier = data['supplier']?.toString().trim();

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
      final brandsSnapshot = await firestore.collection('brands').get();
      final Map<String, List<String>> brandGroups = {};

      for (final doc in brandsSnapshot.docs) {
        final brandName = doc.data()['name']?.toString().trim() ?? '';
        if (brandName.isNotEmpty) {
          brandGroups.putIfAbsent(brandName, () => []).add(doc.id);
        }
      }

      // Delete duplicate brand documents (keep the first one)
      for (final entry in brandGroups.entries) {
        if (entry.value.length > 1) {
          // Keep the first document, delete the rest
          for (int i = 1; i < entry.value.length; i++) {
            await firestore.collection('brands').doc(entry.value[i]).delete();
          }
        }
      }

      // Remove duplicate suppliers
      final suppliersSnapshot = await firestore.collection('suppliers').get();
      final Map<String, List<String>> supplierGroups = {};

      for (final doc in suppliersSnapshot.docs) {
        final supplierName = doc.data()['name']?.toString().trim() ?? '';
        if (supplierName.isNotEmpty) {
          supplierGroups.putIfAbsent(supplierName, () => []).add(doc.id);
        }
      }

      // Delete duplicate supplier documents (keep the first one)
      for (final entry in supplierGroups.entries) {
        if (entry.value.length > 1) {
          // Keep the first document, delete the rest
          for (int i = 1; i < entry.value.length; i++) {
            await firestore
                .collection('suppliers')
                .doc(entry.value[i])
                .delete();
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

    // Delete brand from brands collection
    final brandDocs = await firestore
        .collection('brands')
        .where('name', isEqualTo: brandName.trim())
        .get();

    for (final doc in brandDocs.docs) {
      await doc.reference.delete();
    }

    // Log the brand deletion activity
    await InventoryActivityController().logBrandDeleted(
      brandName: brandName.trim(),
    );

    // Update all supplies with this brand to use "N/A" and store original brand
    final suppliesDocs = await firestore
        .collection('supplies')
        .where('brand', isEqualTo: brandName.trim())
        .get();

    final batch = firestore.batch();
    for (final doc in suppliesDocs.docs) {
      batch.update(doc.reference, {
        'brand': 'N/A',
        'originalBrand':
            brandName.trim(), // Store original brand for restoration
      });
    }
    await batch.commit();
  }

  // Delete supplier and update all supplies to use "N/A"
  Future<void> deleteSupplier(String supplierName) async {
    if (supplierName.trim().isEmpty) return;

    // Delete supplier from suppliers collection
    final supplierDocs = await firestore
        .collection('suppliers')
        .where('name', isEqualTo: supplierName.trim())
        .get();

    for (final doc in supplierDocs.docs) {
      await doc.reference.delete();
    }

    // Log the supplier deletion activity
    await InventoryActivityController().logSupplierDeleted(
      supplierName: supplierName.trim(),
    );

    // Update all supplies with this supplier to use "N/A" and store original supplier
    final suppliesDocs = await firestore
        .collection('supplies')
        .where('supplier', isEqualTo: supplierName.trim())
        .get();

    final batch = firestore.batch();
    for (final doc in suppliesDocs.docs) {
      batch.update(doc.reference, {
        'supplier': 'N/A',
        'originalSupplier':
            supplierName.trim(), // Store original supplier for restoration
      });
    }
    await batch.commit();
  }
}
