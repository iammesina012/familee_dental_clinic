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

  // Stream controller for broadcasting updates
  StreamController<List<String>>? _streamController;

  List<String>? get cachedCategories =>
      _cachedCategories != null ? List<String>.from(_cachedCategories!) : null;

  // Get all categories as stream
  Stream<List<String>> getCategoriesStream() {
    // If stream controller exists and is still open, reuse it
    // Otherwise create a new one
    if (_streamController != null && !_streamController!.isClosed) {
      // Return existing stream, but ensure we emit current cache
      if (_cachedCategories != null) {
        _streamController!.add(_cachedCategories!);
      }
      return _streamController!.stream;
    }

    _streamController = StreamController<List<String>>.broadcast();

    void emitCachedOrEmpty({bool forceEmpty = false}) {
      if (_streamController == null || _streamController!.isClosed) return;
      if (_cachedCategories != null) {
        _streamController!.add(List<String>.from(_cachedCategories!));
      } else if (forceEmpty) {
        _streamController!.add(<String>[]);
      }
    }

    // Immediately emit cache (if any), otherwise emit empty once
    emitCachedOrEmpty(forceEmpty: true);

    // Use a one-time query with timeout to avoid blocking when offline
    // This prevents the app from freezing when trying to establish a stream connection
    Future<void> fetchCategories() async {
      try {
        // Use timeout to prevent hanging when offline
        try {
          final data = await _supabase
              .from('categories')
              .select('name')
              .timeout(const Duration(seconds: 2));

          try {
            final categories = data.map((row) => row['name'] as String).toList()
              ..sort();

            // Cache the result
            _cachedCategories = categories;
            emitCachedOrEmpty(forceEmpty: true);
          } catch (e) {
            emitCachedOrEmpty(forceEmpty: true);
          }
        } catch (error) {
          // On query error (network/timeout), emit cached data if available
          emitCachedOrEmpty(forceEmpty: true);
        }

        // After initial query, set up stream for real-time updates (non-blocking)
        try {
          _supabase.from('categories').stream(primaryKey: ['id']).listen(
            (data) {
              try {
                final categories =
                    data.map((row) => row['name'] as String).toList()..sort();

                // Cache the result
                _cachedCategories = categories;
                emitCachedOrEmpty(forceEmpty: true);
              } catch (e) {
                emitCachedOrEmpty(forceEmpty: true);
              }
            },
            onError: (error) {
              // On stream error, emit cached data if available (don't block)
              emitCachedOrEmpty();
              // Don't emit empty list on stream errors to avoid overwriting good data
            },
            cancelOnError: false, // Continue listening even on errors
          );
        } catch (e) {
          // Stream creation failed, but we already have data from the query
          // Don't do anything - cached data is already emitted
        }
      } catch (e) {
        // If query fails (timeout/network error), emit cached data if available
        emitCachedOrEmpty(forceEmpty: true);
      }
    }

    // Start fetching (non-blocking)
    fetchCategories();

    return _streamController!.stream;
  }

  // Refresh categories cache and notify listeners
  Future<void> refreshCategories() async {
    try {
      final data = await _supabase
          .from('categories')
          .select('name')
          .timeout(const Duration(seconds: 2));

      final categories = data.map((row) => row['name'] as String).toList()
        ..sort();

      // Update cache
      _cachedCategories = categories;

      // Notify all listeners immediately
      if (_streamController != null && !_streamController!.isClosed) {
        _streamController!.add(categories);
      }
    } catch (e) {
      // If refresh fails, keep existing cache
      // The Supabase stream will eventually update
    }
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

      // Refresh cache immediately for real-time update
      await refreshCategories();
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

    // Refresh cache immediately for real-time update
    await refreshCategories();
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

      // Refresh cache immediately for real-time update
      await refreshCategories();
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
