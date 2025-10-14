import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:familee_dental/features/inventory/controller/add_supply_controller.dart';
import 'package:familee_dental/features/inventory/controller/categories_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';

class AddSupplyPage extends StatefulWidget {
  const AddSupplyPage({super.key});

  @override
  State<AddSupplyPage> createState() => _AddSupplyPageState();
}

class _AddSupplyPageState extends State<AddSupplyPage> {
  final AddSupplyController controller = AddSupplyController();
  final CategoriesController categoriesController = CategoriesController();
  Map<String, String?> validationErrors = {};
  bool _hasUnsavedChanges = false;

  // Store original values to compare against
  String _originalName = '';
  String _originalCategory = '';
  int _originalStock = 0;
  String _originalUnit = '';
  double _originalCost = 0.0;
  String _originalSupplier = '';
  String _originalBrand = '';
  String _originalExpiry = '';
  bool _originalNoExpiry = false;
  List<String>? _cachedCategories;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget _buildValidationError(String? error) {
    if (error == null) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 12.0),
      child: Text(
        error,
        style: TextStyle(
          color: Colors.red,
          fontSize: 12,
        ),
      ),
    );
  }

  void _markAsChanged() {
    final currentName = controller.nameController.text.trim();
    final currentCategory = controller.selectedCategory ?? '';
    final currentStock = controller.stock;
    final currentUnit = controller.selectedUnit ?? '';
    final currentCost =
        double.tryParse(controller.costController.text.trim()) ?? 0.0;
    final currentSupplier = controller.supplierController.text.trim();
    final currentBrand = controller.brandController.text.trim();
    final currentExpiry = controller.expiryController.text.trim();
    final currentNoExpiry = controller.noExpiry;

    final hasChanges = currentName != _originalName ||
        currentCategory != _originalCategory ||
        currentStock != _originalStock ||
        currentUnit != _originalUnit ||
        currentCost != _originalCost ||
        currentSupplier != _originalSupplier ||
        currentBrand != _originalBrand ||
        currentExpiry != _originalExpiry ||
        currentNoExpiry != _originalNoExpiry;

    if (_hasUnsavedChanges != hasChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Unsaved Changes',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'You have unsaved changes. Are you sure you want to leave?',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Stay',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Leave',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            "Add Supply",
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: theme.appBarTheme.backgroundColor,
          toolbarHeight: 70,
          iconTheme: theme.appBarTheme.iconTheme,
          elevation: theme.appBarTheme.elevation,
          shadowColor: theme.appBarTheme.shadowColor,
        ),
        body: SingleChildScrollView(
          child: ResponsiveContainer(
            maxWidth: 900,
            child: Padding(
              padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width < 768 ? 8.0 : 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Image picker + upload
                  GestureDetector(
                    onTap: () async {
                      // Prevent multiple simultaneous picker calls
                      if (controller.isPickingImage || controller.uploading) {
                        return;
                      }

                      setState(() {
                        controller.isPickingImage = true;
                      });

                      try {
                        final image = await controller.picker
                            .pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          setState(() {
                            controller.pickedImage = image;
                            controller.uploading = true;
                          });
                          final url =
                              await controller.uploadImageToSupabase(image);
                          setState(() {
                            controller.imageUrl = url;
                            controller.uploading = false;
                          });
                          if (url == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Failed to upload image! Please try again.'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 5),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Image uploaded successfully!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        // Handle any picker errors gracefully
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error picking image: $e'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      } finally {
                        setState(() {
                          controller.isPickingImage = false;
                        });
                      }
                    },
                    child: controller.uploading
                        ? SizedBox(
                            width: 130,
                            height: 130,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : (controller.pickedImage != null &&
                                controller.imageUrl != null)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  controller.imageUrl!,
                                  width: 130,
                                  height: 130,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: theme.colorScheme.surface,
                                  border: Border.all(
                                      color:
                                          theme.dividerColor.withOpacity(0.2)),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image_not_supported,
                                        size: 40,
                                        color: theme.iconTheme.color
                                            ?.withOpacity(0.6)),
                                    SizedBox(height: 8),
                                    Text(
                                      'No image',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 12,
                                        color: theme.textTheme.bodyMedium?.color
                                            ?.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                  ),
                  const SizedBox(height: 32),

                  // Name + Category
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: controller.nameController,
                                decoration: InputDecoration(
                                  labelText: 'Item Name *',
                                  border: OutlineInputBorder(),
                                  errorStyle: TextStyle(color: Colors.red),
                                ),
                                onChanged: (value) {
                                  _markAsChanged();
                                  // Clear validation error when user types
                                  if (validationErrors['name'] != null) {
                                    setState(() {
                                      validationErrors['name'] = null;
                                    });
                                  }
                                },
                              ),
                              _buildValidationError(validationErrors['name']),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: StreamBuilder<List<String>>(
                            stream: categoriesController.getCategoriesStream(),
                            builder: (context, snapshot) {
                              // Cache categories when available
                              if (snapshot.hasData && snapshot.data != null) {
                                _cachedCategories = snapshot.data;
                              }

                              // Use cached categories if available
                              final categories = _cachedCategories ?? [];

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: controller.selectedCategory,
                                    decoration: InputDecoration(
                                      labelText: 'Category *',
                                      border: OutlineInputBorder(),
                                      errorStyle: TextStyle(color: Colors.red),
                                    ),
                                    items: categories
                                        .map((c) => DropdownMenuItem(
                                            value: c, child: Text(c)))
                                        .toList(),
                                    onChanged: (value) {
                                      _markAsChanged();
                                      setState(() {
                                        controller.selectedCategory = value;
                                        // Clear validation error when user selects
                                        if (validationErrors['category'] !=
                                            null) {
                                          validationErrors['category'] = null;
                                        }
                                      });
                                    },
                                  ),
                                  _buildValidationError(
                                      validationErrors['category']),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Stock + Inventory units
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stock',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: theme.dividerColor
                                            .withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.remove,
                                            color: theme.iconTheme.color),
                                        splashRadius: 18,
                                        onPressed: () {
                                          if (controller.stock > 0) {
                                            _markAsChanged();
                                            setState(() {
                                              controller.stock--;
                                              controller.stockController.text =
                                                  controller.stock.toString();
                                              // Clear validation error when user changes
                                              if (validationErrors['stock'] !=
                                                  null) {
                                                validationErrors['stock'] =
                                                    null;
                                              }
                                            });
                                          }
                                        },
                                      ),
                                      SizedBox(
                                        width: 32,
                                        child: Center(
                                          child: TextField(
                                            controller:
                                                controller.stockController,
                                            textAlign: TextAlign.center,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                                border: InputBorder.none),
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w500,
                                                color: theme.textTheme
                                                    .bodyMedium?.color),
                                            onChanged: (val) {
                                              _markAsChanged();
                                              setState(() {
                                                controller.stock =
                                                    int.tryParse(val) ?? 0;
                                                // Clear validation error when user types
                                                if (validationErrors['stock'] !=
                                                    null) {
                                                  validationErrors['stock'] =
                                                      null;
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.add,
                                            color: theme.iconTheme.color),
                                        splashRadius: 18,
                                        onPressed: () {
                                          _markAsChanged();
                                          setState(() {
                                            controller.stock++;
                                            controller.stockController.text =
                                                controller.stock.toString();
                                            // Clear validation error when user changes
                                            if (validationErrors['stock'] !=
                                                null) {
                                              validationErrors['stock'] = null;
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                _buildValidationError(
                                    validationErrors['stock']),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<String>(
                                  value: controller.selectedUnit,
                                  decoration: InputDecoration(
                                    labelText: 'Inventory units *',
                                    border: OutlineInputBorder(),
                                    errorStyle: TextStyle(color: Colors.red),
                                  ),
                                  items: ['Box', 'Piece', 'Pack']
                                      .map((u) => DropdownMenuItem(
                                          value: u, child: Text(u)))
                                      .toList(),
                                  onChanged: (val) {
                                    _markAsChanged();
                                    setState(() {
                                      controller.selectedUnit = val;
                                      // Clear validation error when user selects
                                      if (validationErrors['unit'] != null) {
                                        validationErrors['unit'] = null;
                                      }
                                    });
                                  },
                                ),
                                _buildValidationError(validationErrors['unit']),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Cost full width
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: controller.costController,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Cost *',
                          border: OutlineInputBorder(),
                          errorStyle: TextStyle(color: Colors.red),
                          hintText: 'Enter amount (e.g., 150.00)',
                        ),
                        onChanged: (value) {
                          _markAsChanged();
                          // Clear validation error when user types
                          if (validationErrors['cost'] != null) {
                            setState(() {
                              validationErrors['cost'] = null;
                            });
                          }
                        },
                      ),
                      _buildValidationError(validationErrors['cost']),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Supplier + Brand
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: controller.supplierController,
                                decoration: InputDecoration(
                                    labelText: 'Supplier Name *',
                                    border: OutlineInputBorder(),
                                    errorStyle: TextStyle(color: Colors.red)),
                                onChanged: (value) {
                                  _markAsChanged();
                                  // Clear validation error when user types
                                  if (validationErrors['supplier'] != null) {
                                    setState(() {
                                      validationErrors['supplier'] = null;
                                    });
                                  }
                                },
                              ),
                              _buildValidationError(
                                  validationErrors['supplier']),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: controller.brandController,
                                decoration: InputDecoration(
                                    labelText: 'Brand Name *',
                                    border: OutlineInputBorder(),
                                    errorStyle: TextStyle(color: Colors.red)),
                                onChanged: (value) {
                                  _markAsChanged();
                                  // Clear validation error when user types
                                  if (validationErrors['brand'] != null) {
                                    setState(() {
                                      validationErrors['brand'] = null;
                                    });
                                  }
                                },
                              ),
                              _buildValidationError(validationErrors['brand']),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Expiry Date (disable if noExpiry checked)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: controller.expiryController,
                        enabled: !controller.noExpiry,
                        decoration: InputDecoration(
                          labelText: 'Expiry Date *',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today, size: 18),
                          errorStyle: TextStyle(color: Colors.red),
                          hintText: controller.noExpiry
                              ? 'No expiry date'
                              : 'Select date',
                        ),
                        readOnly: true,
                        onTap: !controller.noExpiry
                            ? () async {
                                DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setState(() {
                                    controller.expiryDate = picked;
                                    controller.expiryController.text =
                                        "${picked.year.toString().padLeft(4, '0')}-"
                                        "${picked.month.toString().padLeft(2, '0')}-"
                                        "${picked.day.toString().padLeft(2, '0')}";
                                    _markAsChanged();
                                    // Clear validation error when user selects date
                                    if (validationErrors['expiry'] != null) {
                                      validationErrors['expiry'] = null;
                                    }
                                  });
                                }
                              }
                            : null,
                      ),
                      _buildValidationError(validationErrors['expiry']),
                    ],
                  ),
                  // Checkbox for "No expiry date?"
                  Row(
                    children: [
                      Checkbox(
                        value: controller.noExpiry,
                        onChanged: (value) {
                          setState(() {
                            controller.noExpiry = value ?? false;
                            if (controller.noExpiry) {
                              controller.expiryController.clear();
                              controller.expiryDate = null;
                            }
                            _markAsChanged();
                            // Clear validation error when user toggles checkbox
                            if (validationErrors['expiry'] != null) {
                              validationErrors['expiry'] = null;
                            }
                          });
                        },
                      ),
                      Text("No expiry date?"),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Cancel'),
                        onPressed: () async {
                          if (await _onWillPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6562F2),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 28, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Save'),
                        onPressed: () async {
                          final errors = controller.validateFields();
                          if (errors.isNotEmpty) {
                            setState(() {
                              validationErrors = errors;
                            });
                            return;
                          }
                          final result = await controller.addSupply();
                          if (result == null) {
                            if (!mounted) return;
                            _hasUnsavedChanges =
                                false; // Reset flag on successful save
                            Navigator.of(context).pop(true);
                          } else {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result)),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
