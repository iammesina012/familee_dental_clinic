import 'package:flutter/material.dart';
import 'package:familee_dental/features/inventory/controller/categories_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:shimmer/shimmer.dart';

class EditCategoriesPage extends StatefulWidget {
  const EditCategoriesPage({super.key});

  @override
  State<EditCategoriesPage> createState() => _EditCategoriesPageState();
}

class _EditCategoriesPageState extends State<EditCategoriesPage> {
  final CategoriesController categoriesController = CategoriesController();
  final Map<String, TextEditingController> editControllers = {};
  final Map<String, bool> isEditing = {};
  final Map<String, String?> validationErrors = {};

  @override
  void dispose() {
    editControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _startEditing(String categoryName) {
    setState(() {
      isEditing[categoryName] = true;
      editControllers[categoryName] = TextEditingController(text: categoryName);
    });
  }

  void _cancelEditing(String categoryName) {
    setState(() {
      isEditing[categoryName] = false;
      editControllers[categoryName]?.dispose();
      editControllers.remove(categoryName);
    });
  }

  // Helper function to validate alphanumeric input
  bool _isValidAlphanumeric(String text) {
    if (text.trim().isEmpty) return false;
    // Check if the text contains only numbers
    if (RegExp(r'^[0-9]+$').hasMatch(text.trim())) {
      return false;
    }
    // Check if the text contains at least one letter and allows common characters
    return RegExp(r'^[a-zA-Z0-9\s\-_\.]+$').hasMatch(text.trim()) &&
        RegExp(r'[a-zA-Z]').hasMatch(text.trim());
  }

  Future<void> _saveEdit(String oldName) async {
    final newName = editControllers[oldName]?.text.trim();

    // Clear previous validation error
    setState(() {
      validationErrors[oldName] = null;
    });

    if (newName == null || newName.isEmpty) {
      setState(() {
        validationErrors[oldName] = 'Please enter a valid category name';
      });
      return;
    }

    // Validate alphanumeric input
    if (!_isValidAlphanumeric(newName)) {
      setState(() {
        validationErrors[oldName] =
            'Category name must contain letters and cannot be only numbers or special characters.';
      });
      return;
    }

    if (newName == oldName) {
      _cancelEditing(oldName);
      return;
    }

    // Show confirmation dialog first
    final confirmed = await _showEditConfirmation(oldName, newName);
    if (!confirmed) return;

    try {
      await categoriesController.updateCategory(oldName, newName);
      if (!mounted) return;
      // Force rebuild to show updated categories (stream updates automatically)
      setState(() {
        isEditing[oldName] = false;
        editControllers[oldName]?.dispose();
        editControllers.remove(oldName);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Category updated successfully!',
            style: TextStyle(fontFamily: 'SF Pro'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update category: $e',
            style: TextStyle(fontFamily: 'SF Pro'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteCategory(String categoryName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _buildDeleteDialog(context, categoryName),
    );

    if (confirmed == true) {
      try {
        await categoriesController.deleteCategory(categoryName);
        if (!mounted) return;
        // Force rebuild to show updated categories (stream updates automatically)
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Category deleted successfully!',
              style: TextStyle(fontFamily: 'SF Pro'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete category: $e',
              style: TextStyle(fontFamily: 'SF Pro'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Edit Categories",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontFamily: 'SF Pro',
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: theme.appBarTheme.elevation,
        shadowColor: theme.appBarTheme.shadowColor,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Force rebuild and wait for stream to emit
          setState(() {});
          // Wait for the stream to emit at least one event
          // This ensures the RefreshIndicator shows its animation
          await categoriesController.getCategoriesStream().first;
        },
        child: StreamBuilder<List<String>>(
          stream: categoriesController.getCategoriesStream(),
          builder: (context, snapshot) {
            // Handle errors
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading categories',
                  style: AppFonts.sfProStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
              );
            }

            // Show skeleton loader only on first load
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
              final highlightColor =
                  isDark ? Colors.grey[700]! : Colors.grey[100]!;

              return ResponsiveContainer(
                maxWidth: 1000,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
                    vertical: 12.0,
                  ),
                  child: ListView.separated(
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: 5,
                    separatorBuilder: (_, __) => SizedBox(height: 12),
                    itemBuilder: (_, __) => Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.category_outlined,
                        size: 48,
                        color: Color(0xFF4E38D4),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'No categories found',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add some categories to get started',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }

            final categories = snapshot.data!;
            return ResponsiveContainer(
              maxWidth: 800,
              child: ListView.builder(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal:
                      MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
                  vertical: 12.0,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final categoryName = categories[index];
                  final isCurrentlyEditing = isEditing[categoryName] == true;

                  return Container(
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // Category icon
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(0xFF4E38D4).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.category,
                              color: Color(0xFF4E38D4),
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),

                          // Category name or edit field
                          Expanded(
                            child: isCurrentlyEditing
                                ? TextField(
                                    controller: editControllers[categoryName],
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: validationErrors[
                                                        categoryName] !=
                                                    null
                                                ? Colors.red[600]!
                                                : Color(0xFF4E38D4)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: validationErrors[
                                                        categoryName] !=
                                                    null
                                                ? Colors.red[600]!
                                                : theme.dividerColor
                                                    .withOpacity(0.2)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: validationErrors[
                                                        categoryName] !=
                                                    null
                                                ? Colors.red[600]!
                                                : Color(0xFF4E38D4),
                                            width: 2),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      hintText: 'Enter category name',
                                      hintStyle: TextStyle(
                                        fontFamily: 'SF Pro',
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withOpacity(0.5),
                                        fontWeight: FontWeight.w500,
                                        fontStyle: FontStyle.normal,
                                      ),
                                      errorText: validationErrors[categoryName],
                                      errorStyle: TextStyle(
                                        fontFamily: 'SF Pro',
                                        fontSize: 12,
                                        color: Colors.red[600],
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontFamily: 'SF Pro',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FontStyle.normal,
                                    ),
                                    textCapitalization:
                                        TextCapitalization.words,
                                    onChanged: (value) {
                                      // Clear validation error when user starts typing
                                      if (validationErrors[categoryName] !=
                                          null) {
                                        setState(() {
                                          validationErrors[categoryName] = null;
                                        });
                                      }
                                    },
                                  )
                                : Text(
                                    categoryName,
                                    style: TextStyle(
                                      fontFamily: 'SF Pro',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                          ),

                          SizedBox(width: 12),

                          // Action buttons
                          if (isCurrentlyEditing) ...[
                            // Save button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(Icons.check,
                                    color: Colors.white, size: 20),
                                onPressed: () => _saveEdit(categoryName),
                                padding: EdgeInsets.all(8),
                                constraints:
                                    BoxConstraints(minWidth: 40, minHeight: 40),
                              ),
                            ),
                            SizedBox(width: 8),
                            // Cancel button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(Icons.close,
                                    color: Colors.white, size: 20),
                                onPressed: () => _cancelEditing(categoryName),
                                padding: EdgeInsets.all(8),
                                constraints:
                                    BoxConstraints(minWidth: 40, minHeight: 40),
                              ),
                            ),
                          ] else ...[
                            // Edit button
                            Container(
                              decoration: BoxDecoration(
                                color: Color(0xFF4E38D4).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(Icons.edit,
                                    color: Color(0xFF4E38D4), size: 20),
                                onPressed: () => _startEditing(categoryName),
                                padding: EdgeInsets.all(8),
                                constraints:
                                    BoxConstraints(minWidth: 40, minHeight: 40),
                              ),
                            ),
                            SizedBox(width: 8),
                            // Delete button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(Icons.delete,
                                    color: Colors.red, size: 20),
                                onPressed: () => _deleteCategory(categoryName),
                                padding: EdgeInsets.all(8),
                                constraints:
                                    BoxConstraints(minWidth: 40, minHeight: 40),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDeleteDialog(BuildContext context, String categoryName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 400,
          minWidth: 350,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon and Title
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete,
                color: Colors.red,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Delete Category',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Content
            Text(
              'Are you sure you want to delete "$categoryName"?\n\nThis action cannot be undone.',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.textTheme.bodyMedium?.color,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Buttons (Cancel first, then Delete - matching exit dialog pattern)
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade300,
                        ),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showEditConfirmation(String oldName, String newName) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                  minWidth: 350,
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon and Title
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4AA).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Color(0xFF00D4AA),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'Update Category',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Content
                    Text(
                      'Are you sure you want to change "$oldName" to "$newName"?',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Buttons (Cancel first, then Update - matching exit dialog pattern)
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade300,
                                ),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w500,
                                color: theme.textTheme.bodyMedium?.color,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00D4AA),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              'Update',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;
  }
}
