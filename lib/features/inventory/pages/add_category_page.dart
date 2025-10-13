import 'package:flutter/material.dart';
import 'package:familee_dental/features/inventory/controller/categories_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';

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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Add Category",
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: theme.appBarTheme.elevation,
        shadowColor: theme.appBarTheme.shadowColor,
      ),
      body: ResponsiveContainer(
        maxWidth: 900,
        child: Padding(
          padding: EdgeInsets.all(
              MediaQuery.of(context).size.width < 768 ? 8.0 : 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the name of the new category',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}
