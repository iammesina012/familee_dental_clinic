import 'package:flutter/material.dart';
import '../controller/categories_controller.dart';

class EditCategoriesPage extends StatefulWidget {
  const EditCategoriesPage({super.key});

  @override
  State<EditCategoriesPage> createState() => _EditCategoriesPageState();
}

class _EditCategoriesPageState extends State<EditCategoriesPage> {
  final CategoriesController categoriesController = CategoriesController();
  final Map<String, TextEditingController> editControllers = {};
  final Map<String, bool> isEditing = {};

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

  Future<void> _saveEdit(String oldName) async {
    final newName = editControllers[oldName]?.text.trim();
    if (newName == null || newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a valid category name',
            style: TextStyle(fontFamily: 'SF Pro'),
          ),
        ),
      );
      return;
    }

    if (newName == oldName) {
      _cancelEditing(oldName);
      return;
    }

    try {
      await categoriesController.updateCategory(oldName, newName);
      if (!mounted) return;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9EFF2),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Edit Categories",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'SF Pro',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        toolbarHeight: 70,
        iconTheme: const IconThemeData(size: 30, color: Colors.black),
        elevation: 5,
        shadowColor: Colors.black54,
      ),
      body: StreamBuilder<List<String>>(
        stream: categoriesController.getCategoriesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF4E38D4)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading categories...',
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
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
          return ListView.builder(
            padding: EdgeInsets.all(20),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final categoryName = categories[index];
              final isCurrentlyEditing = isEditing[categoryName] == true;

              return Container(
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                                    borderSide:
                                        BorderSide(color: Color(0xFF4E38D4)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Color(0xFF4E38D4), width: 2),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  hintText: 'Enter category name',
                                  hintStyle: TextStyle(
                                    fontFamily: 'SF Pro',
                                    color: Colors.grey[400],
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.normal,
                                  ),
                                ),
                                style: TextStyle(
                                  fontFamily: 'SF Pro',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.normal,
                                ),
                                textCapitalization: TextCapitalization.words,
                              )
                            : Text(
                                categoryName,
                                style: TextStyle(
                                  fontFamily: 'SF Pro',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
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
                            icon:
                                Icon(Icons.delete, color: Colors.red, size: 20),
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
          );
        },
      ),
    );
  }

  Widget _buildDeleteDialog(BuildContext context, String categoryName) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
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
                color: Colors.black87,
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
                color: Colors.black54,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
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
}
