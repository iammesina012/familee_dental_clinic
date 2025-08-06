import 'package:cloud_firestore/cloud_firestore.dart';

class CategoriesController {
  final FirebaseFirestore firestore;

  CategoriesController({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  // Get all categories as stream
  Stream<List<String>> getCategoriesStream() {
    return firestore.collection('categories').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => doc.data()['name'] as String).toList()
          ..sort());
  }

  // Add new category
  Future<void> addCategory(String categoryName) async {
    if (categoryName.trim().isEmpty) return;

    // Check if category already exists
    final existingCategories = await firestore
        .collection('categories')
        .where('name', isEqualTo: categoryName.trim())
        .get();

    if (existingCategories.docs.isEmpty) {
      // Add new category
      await firestore.collection('categories').add({
        'name': categoryName.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Update category name
  Future<void> updateCategory(String oldName, String newName) async {
    if (oldName.trim().isEmpty || newName.trim().isEmpty) return;

    // Update category in categories collection
    final categoryDocs = await firestore
        .collection('categories')
        .where('name', isEqualTo: oldName.trim())
        .get();

    if (categoryDocs.docs.isNotEmpty) {
      await categoryDocs.docs.first.reference.update({
        'name': newName.trim(),
      });
    }

    // Update all supplies with this category
    final suppliesDocs = await firestore
        .collection('supplies')
        .where('category', isEqualTo: oldName.trim())
        .get();

    final batch = firestore.batch();
    for (final doc in suppliesDocs.docs) {
      batch.update(doc.reference, {'category': newName.trim()});
    }
    await batch.commit();
  }

  // Delete category
  Future<void> deleteCategory(String categoryName) async {
    if (categoryName.trim().isEmpty) return;

    // Check if category is used by any supplies
    final suppliesDocs = await firestore
        .collection('supplies')
        .where('category', isEqualTo: categoryName.trim())
        .get();

    if (suppliesDocs.docs.isNotEmpty) {
      throw Exception(
          'Cannot delete category: It is used by existing supplies');
    }

    // Delete category from categories collection
    final categoryDocs = await firestore
        .collection('categories')
        .where('name', isEqualTo: categoryName.trim())
        .get();

    if (categoryDocs.docs.isNotEmpty) {
      await categoryDocs.docs.first.reference.delete();
    }
  }

  // Initialize default categories if none exist
  Future<void> initializeDefaultCategories() async {
    final categoriesSnapshot = await firestore.collection('categories').get();

    if (categoriesSnapshot.docs.isEmpty) {
      // Add default categories
      final defaultCategories = [
        "PPE Disposable",
        "Dental Materials",
        "Medicaments",
        "Miscellaneous",
      ];

      final batch = firestore.batch();
      for (final categoryName in defaultCategories) {
        final docRef = firestore.collection('categories').doc();
        batch.set(docRef, {
          'name': categoryName,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }
}
