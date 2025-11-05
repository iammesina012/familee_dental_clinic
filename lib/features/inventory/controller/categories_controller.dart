import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/activity_log/controller/inventory_activity_controller.dart';

class CategoriesController {
  // Singleton pattern to ensure cache persists across widget rebuilds
  static final CategoriesController _instance =
      CategoriesController._internal();
  factory CategoriesController() => _instance;
  CategoriesController._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache for last known data (persists across widget rebuilds)
  List<String>? _cachedCategories;

  // Get all categories as stream
  Stream<List<String>> getCategoriesStream() {
    final controller = StreamController<List<String>>.broadcast();

    // Emit cached data immediately if available (no delay - instant feedback)
    if (_cachedCategories != null) {
      controller.add(_cachedCategories!);
    }

    try {
      _supabase.from('categories').stream(primaryKey: ['id']).listen(
        (data) {
          try {
            final categories = data.map((row) => row['name'] as String).toList()
              ..sort();

            // Cache the result
            _cachedCategories = categories;
            controller.add(categories);
          } catch (e) {
            // On error, emit cached data if available
            if (_cachedCategories != null) {
              controller.add(_cachedCategories!);
            } else {
              controller.add([]);
            }
          }
        },
        onError: (error) {
          // On stream error, emit cached data if available
          if (_cachedCategories != null) {
            controller.add(_cachedCategories!);
          } else {
            controller.add([]);
          }
        },
      );
    } catch (e) {
      // If stream creation fails, emit cached data if available
      if (_cachedCategories != null) {
        controller.add(_cachedCategories!);
      } else {
        controller.add([]);
      }
    }

    return controller.stream;
  }

  // Add new category
  Future<void> addCategory(String categoryName) async {
    if (categoryName.trim().isEmpty) return;

    // Check if category already exists
    final existingCategories = await _supabase
        .from('categories')
        .select('id')
        .eq('name', categoryName.trim())
        .limit(1);

    if (existingCategories.isEmpty) {
      // Add new category
      await _supabase.from('categories').insert({
        'name': categoryName.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // Log the category creation activity
      await InventoryActivityController().logCategoryAdded(
        categoryName: categoryName.trim(),
      );
    }
  }

  // Update category name
  Future<void> updateCategory(String oldName, String newName) async {
    if (oldName.trim().isEmpty || newName.trim().isEmpty) return;

    // Update category in categories collection
    final categoryResponse = await _supabase
        .from('categories')
        .select('id')
        .eq('name', oldName.trim())
        .limit(1);

    if (categoryResponse.isNotEmpty) {
      await _supabase.from('categories').update({'name': newName.trim()}).eq(
          'id', categoryResponse.first['id']);
    }

    // Update all supplies with this category
    await _supabase
        .from('supplies')
        .update({'category': newName.trim()}).eq('category', oldName.trim());

    // Log the category update activity
    await InventoryActivityController().logCategoryUpdated(
      oldCategoryName: oldName.trim(),
      newCategoryName: newName.trim(),
    );
  }

  // Delete category
  Future<void> deleteCategory(String categoryName) async {
    if (categoryName.trim().isEmpty) return;

    // Check if category is used by any supplies
    final suppliesResponse = await _supabase
        .from('supplies')
        .select('id')
        .eq('category', categoryName.trim())
        .limit(1);

    if (suppliesResponse.isNotEmpty) {
      throw Exception(
          'Cannot delete category: It is used by existing supplies');
    }

    // Delete category from categories collection
    final categoryResponse = await _supabase
        .from('categories')
        .select('id')
        .eq('name', categoryName.trim())
        .limit(1);

    if (categoryResponse.isNotEmpty) {
      await _supabase
          .from('categories')
          .delete()
          .eq('id', categoryResponse.first['id']);

      // Log the category deletion activity
      await InventoryActivityController().logCategoryDeleted(
        categoryName: categoryName.trim(),
      );
    }
  }

  // Initialize default categories if none exist
  Future<void> initializeDefaultCategories() async {
    // Check if user is authenticated
    final user = _supabase.auth.currentUser;
    if (user == null) {
      print('User not authenticated, skipping category initialization');
      return;
    }

    try {
      final categoriesResponse =
          await _supabase.from('categories').select('id');

      if (categoriesResponse.isEmpty) {
        // Add default categories
        final defaultCategories = [
          "PPE Disposable",
          "Dental Materials",
          "Medicaments",
          "Miscellaneous",
        ];

        for (final categoryName in defaultCategories) {
          await _supabase.from('categories').insert({
            'name': categoryName,
            'created_at': DateTime.now().toIso8601String(),
          });
        }

        // Log the default categories initialization
        for (final categoryName in defaultCategories) {
          await InventoryActivityController().logCategoryAdded(
            categoryName: categoryName,
          );
        }
      }
    } catch (e) {
      print('Error initializing categories: $e');
      // Don't throw the error, just log it
    }
  }
}
