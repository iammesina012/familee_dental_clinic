import 'package:flutter/material.dart';
import '../controller/categories_controller.dart';

class AddCategoryPage extends StatefulWidget {
  const AddCategoryPage({super.key});

  @override
  State<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  final TextEditingController categoryController = TextEditingController();
  final CategoriesController categoriesController = CategoriesController();
  bool isLoading = false;

  @override
  void dispose() {
    categoryController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    if (categoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a category name')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await categoriesController.addCategory(categoryController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category added successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add category: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
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
        title: const Text(
          "Add Category",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        toolbarHeight: 70,
        iconTheme: const IconThemeData(size: 30, color: Colors.black),
        elevation: 5,
        shadowColor: Colors.black54,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add New Category',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Enter the name of the new category',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 32),
            TextField(
              controller: categoryController,
              decoration: InputDecoration(
                labelText: 'Category Name *',
                border: OutlineInputBorder(),
                hintText: 'e.g., Dental Equipment',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _addCategory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6562F2),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Add Category',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
