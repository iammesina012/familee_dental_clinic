import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:familee_dental/features/inventory/controller/edit_supply_controller.dart';
import 'package:familee_dental/features/inventory/controller/categories_controller.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';

class EditSupplyPage extends StatefulWidget {
  final InventoryItem item;
  const EditSupplyPage({super.key, required this.item});

  @override
  State<EditSupplyPage> createState() => _EditSupplyPageState();
}

class _EditSupplyPageState extends State<EditSupplyPage> {
  final EditSupplyController controller = EditSupplyController();
  final CategoriesController categoriesController = CategoriesController();
  Map<String, String?> validationErrors = {};
  bool _hasUnsavedChanges = false;
  bool _isSaving = false; // Add loading state for save button

  bool _hasChanges() {
    final currentName = controller.nameController.text.trim();
    final currentCategory = controller.selectedCategory ?? '';
    final currentStock = controller.stock;
    final currentUnit = controller.selectedUnit ?? '';
    final currentCost = controller.costController.text.trim();
    final currentSupplier = controller.supplierController.text.trim();
    final currentBrand = controller.brandController.text.trim();
    final currentExpiry = controller.expiryController.text.trim();
    final currentNoExpiry = controller.noExpiry;

    return currentName != _originalName ||
        currentCategory != _originalCategory ||
        currentStock != _originalStock ||
        currentUnit != _originalUnit ||
        currentCost != _originalCost.toString() ||
        currentSupplier != _originalSupplier ||
        currentBrand != _originalBrand ||
        currentExpiry != _originalExpiry ||
        currentNoExpiry != _originalNoExpiry;
  }

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
  void initState() {
    super.initState();
    controller.initFromItem(widget.item);
    // Initialize original values after controller is populated
    _originalName = controller.nameController.text.trim();
    _originalCategory = controller.selectedCategory ?? '';
    _originalStock = controller.stock;
    _originalUnit = controller.selectedUnit ?? '';
    _originalCost =
        double.tryParse(controller.costController.text.trim()) ?? 0.0;
    _originalSupplier = controller.supplierController.text.trim();
    _originalBrand = controller.brandController.text.trim();
    _originalExpiry = controller.expiryController.text.trim();
    _originalNoExpiry = controller.noExpiry;
  }

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
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            "Edit Supply",
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
        body: ResponsiveContainer(
          maxWidth: 900,
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal:
                      MediaQuery.of(context).size.width < 768 ? 1.0 : 20.0,
                  vertical: 12.0,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 500,
                    minWidth: 0,
                    minHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Image picker + upload
                      GestureDetector(
                        onTap: () async {
                          // Prevent multiple simultaneous picker calls
                          if (controller.isPickingImage ||
                              controller.uploading) {
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
                                    content:
                                        Text('Image uploaded successfully!'),
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
                                  content: Text('Error picking image: $e')),
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
                                child:
                                    Center(child: CircularProgressIndicator()),
                              )
                            : (controller.imageUrl != null &&
                                    controller.imageUrl!.isNotEmpty)
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
                                          color: theme.dividerColor
                                              .withOpacity(0.2)),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.image_not_supported,
                                            size: 40,
                                            color: theme.iconTheme.color
                                                ?.withOpacity(0.6)),
                                        SizedBox(height: 8),
                                        Text(
                                          'No image',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            fontSize: 12,
                                            color: theme
                                                .textTheme.bodyMedium?.color
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
                                  _buildValidationError(
                                      validationErrors['name']),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: StreamBuilder<List<String>>(
                                stream:
                                    categoriesController.getCategoriesStream(),
                                builder: (context, snapshot) {
                                  // Cache categories when available
                                  if (snapshot.hasData &&
                                      snapshot.data != null) {
                                    _cachedCategories = snapshot.data;
                                  }

                                  // Use cached categories if available
                                  final categories = _cachedCategories ?? [];

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      DropdownButtonFormField<String>(
                                        value: controller.selectedCategory,
                                        decoration: InputDecoration(
                                          labelText: 'Category *',
                                          border: OutlineInputBorder(),
                                          errorStyle:
                                              TextStyle(color: Colors.red),
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
                                              validationErrors['category'] =
                                                  null;
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

                      // Cost + Inventory units
                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: controller.costController,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                            decimal: true),
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
                                  _buildValidationError(
                                      validationErrors['cost']),
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
                                  _buildValidationError(
                                      validationErrors['unit']),
                                ],
                              ),
                            ),
                          ),
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
                                      errorStyle: TextStyle(color: Colors.red),
                                    ),
                                    onChanged: (value) {
                                      _markAsChanged();
                                      // Clear validation error when user types
                                      if (validationErrors['supplier'] !=
                                          null) {
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
                                      errorStyle: TextStyle(color: Colors.red),
                                    ),
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
                                  _buildValidationError(
                                      validationErrors['brand']),
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
                                      initialDate: controller.expiryDate ??
                                          DateTime.now(),
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
                                        // Clear validation error when user selects date
                                        if (validationErrors['expiry'] !=
                                            null) {
                                          validationErrors['expiry'] = null;
                                        }
                                        _markAsChanged();
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
                                // Clear validation error when user toggles checkbox
                                if (validationErrors['expiry'] != null) {
                                  validationErrors['expiry'] = null;
                                }
                                _markAsChanged();
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
                            onPressed: _isSaving
                                ? null
                                : () async {
                                    if (_isSaving)
                                      return; // Prevent canceling while saving
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
                            child: _isSaving
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text('Save'),
                            onPressed: (_isSaving || !_hasChanges())
                                ? null
                                : () async {
                                    if (_isSaving)
                                      return; // Prevent multiple submissions

                                    // Show confirmation dialog first (only if there are changes)
                                    final confirmed =
                                        await _showSaveConfirmation();
                                    if (!confirmed) return;

                                    setState(() {
                                      _isSaving = true;
                                    });

                                    try {
                                      final errors =
                                          controller.validateFields();
                                      if (errors.isNotEmpty) {
                                        setState(() {
                                          validationErrors = errors;
                                          _isSaving = false;
                                        });
                                        return;
                                      }
                                      final result = await controller
                                          .updateSupply(widget.item.id);
                                      if (result == null) {
                                        if (!mounted) return;
                                        _hasUnsavedChanges =
                                            false; // Reset flag on successful save
                                        Navigator.of(context).pop(true);
                                      } else {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(content: Text(result)),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() {
                                          _isSaving = false;
                                        });
                                      }
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
        ),
      ),
    );
  }

  Future<bool> _showSaveConfirmation() async {
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
                      'Confirm Edit Supply',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Content - Show changes being made
                    Text(
                      'Please review the changes before updating this supply:',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Changes Container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.dividerColor.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildChangesList(),
                      ),
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
                              'Update Supply',
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

  List<Widget> _buildChangesList() {
    final changes = <Widget>[];

    // Check each field for changes
    final currentName = controller.nameController.text.trim();
    if (currentName != _originalName) {
      changes.add(_buildChangeRow('Name', _originalName, currentName));
    }

    final currentCategory = controller.selectedCategory ?? '';
    if (currentCategory != _originalCategory) {
      changes
          .add(_buildChangeRow('Category', _originalCategory, currentCategory));
    }

    final currentStock = controller.stock;
    final currentUnit = controller.selectedUnit ?? '';
    final currentStockText = '$currentStock $currentUnit';
    final originalStockText = '$_originalStock $_originalUnit';
    if (currentStockText != originalStockText) {
      changes
          .add(_buildChangeRow('Stock', originalStockText, currentStockText));
    }

    final currentCost = controller.costController.text.trim();
    final originalCostText = '₱$_originalCost';
    final currentCostText = '₱$currentCost';
    if (currentCostText != originalCostText) {
      changes.add(_buildChangeRow('Cost', originalCostText, currentCostText));
    }

    final currentSupplier = controller.supplierController.text.trim();
    if (currentSupplier != _originalSupplier) {
      changes
          .add(_buildChangeRow('Supplier', _originalSupplier, currentSupplier));
    }

    final currentBrand = controller.brandController.text.trim();
    if (currentBrand != _originalBrand) {
      changes.add(_buildChangeRow('Brand', _originalBrand, currentBrand));
    }

    final currentExpiry = controller.expiryController.text.trim();
    final currentNoExpiry = controller.noExpiry;
    String currentExpiryText;
    String originalExpiryText;

    if (currentNoExpiry) {
      currentExpiryText = 'No expiry date';
    } else {
      currentExpiryText =
          currentExpiry.isEmpty ? 'Not specified' : currentExpiry;
    }

    if (_originalNoExpiry) {
      originalExpiryText = 'No expiry date';
    } else {
      originalExpiryText =
          _originalExpiry.isEmpty ? 'Not specified' : _originalExpiry;
    }

    if (currentExpiryText != originalExpiryText) {
      changes.add(
          _buildChangeRow('Expiry', originalExpiryText, currentExpiryText));
    }

    return changes;
  }

  Widget _buildChangeRow(String label, String originalValue, String newValue) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          Text(
            originalValue,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 14,
              color: Colors.red[600],
              decoration: TextDecoration.lineThrough,
            ),
          ),
          Text(
            ' → ',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 14,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          Text(
            newValue,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 14,
              color: Colors.green[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
