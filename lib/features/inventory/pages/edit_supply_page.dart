import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:familee_dental/features/inventory/controller/edit_supply_controller.dart';
import 'package:familee_dental/features/inventory/controller/categories_controller.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/services/connectivity_service.dart';
import 'package:familee_dental/shared/widgets/connection_error_dialog.dart';

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
    final currentType = controller.typeController.text.trim();
    final currentCategory = controller.selectedCategory ?? '';
    final currentStock = controller.stock;
    final currentUnit = controller.selectedUnit ?? '';
    final currentPackagingUnit = controller.selectedPackagingUnit ?? '';
    final currentPackagingContent = controller.selectedPackagingContent ?? '';
    final currentPackagingQuantity = controller.packagingQuantity;
    final currentPackagingContentQuantity = controller.packagingContent;
    final currentCost = controller.costController.text.trim();
    final currentSupplier = controller.supplierController.text.trim();
    final currentBrand = controller.brandController.text.trim();
    final currentExpiry = controller.expiryController.text.trim();
    final currentNoExpiry = controller.noExpiry;
    final currentLowStockThreshold = controller.lowStockThreshold;
    final currentImageUrl = controller.imageUrl ?? '';

    return currentName != _originalName ||
        currentType != _originalType ||
        currentCategory != _originalCategory ||
        currentStock != _originalStock ||
        currentUnit != _originalUnit ||
        currentPackagingUnit != _originalPackagingUnit ||
        currentPackagingContent != _originalPackagingContent ||
        currentPackagingQuantity != _originalPackagingQuantity ||
        currentPackagingContentQuantity != _originalPackagingContentQuantity ||
        currentCost != _originalCost.toString() ||
        currentSupplier != _originalSupplier ||
        currentBrand != _originalBrand ||
        currentExpiry != _originalExpiry ||
        currentNoExpiry != _originalNoExpiry ||
        currentLowStockThreshold != _originalLowStockThreshold ||
        currentImageUrl != _originalImageUrl;
  }

  // Store original values to compare against
  String _originalName = '';
  String _originalType = '';
  String _originalCategory = '';
  int _originalStock = 0;
  String _originalUnit = '';
  String _originalPackagingUnit = '';
  String _originalPackagingContent = '';
  int _originalPackagingQuantity = 1;
  int _originalPackagingContentQuantity = 1;
  double _originalCost = 0.0;
  String _originalSupplier = '';
  String _originalBrand = '';
  String _originalExpiry = '';
  bool _originalNoExpiry = false;
  int _originalLowStockThreshold = 1;
  String _originalImageUrl = '';
  List<String>? _cachedCategories;

  @override
  void initState() {
    super.initState();
    controller.initFromItem(widget.item);
    // Initialize original values after controller is populated
    _originalName = controller.nameController.text.trim();
    _originalType = controller.typeController.text.trim();
    _originalCategory = controller.selectedCategory ?? '';
    _originalStock = controller.stock;
    _originalUnit = controller.selectedUnit ?? '';
    _originalPackagingUnit = controller.selectedPackagingUnit ?? '';
    _originalPackagingContent = controller.selectedPackagingContent ?? '';
    _originalPackagingQuantity = controller.packagingQuantity;
    _originalPackagingContentQuantity = controller.packagingContent;
    _originalCost =
        double.tryParse(controller.costController.text.trim()) ?? 0.0;
    _originalSupplier = controller.supplierController.text.trim();
    _originalBrand = controller.brandController.text.trim();
    _originalExpiry = controller.expiryController.text.trim();
    _originalNoExpiry = controller.noExpiry;
    _originalLowStockThreshold = controller.lowStockThreshold;
    _originalImageUrl = controller.imageUrl ?? '';
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 400,
                minWidth: 350,
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_outlined,
                      color: Colors.red,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Unsaved Changes',
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You have unsaved changes. Are you sure you want to leave?',
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
                  Row(
                    children: [
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
                          child: const Text(
                            'Leave',
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                            'Stay',
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodyMedium?.color,
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
                                    child: CachedNetworkImage(
                                      imageUrl: controller.imageUrl!,
                                      width: 130,
                                      height: 130,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 130,
                                        height: 130,
                                        color: Colors.grey[300],
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        width: 130,
                                        height: 130,
                                        color: Colors.grey[300],
                                        child: Icon(Icons.error),
                                      ),
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
                                          'Upload image',
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

                      // Item Name + Type Name
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
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[a-zA-Z0-9 ]')),
                                    ],
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: controller.typeController,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[a-zA-Z0-9 ]')),
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Type Name',
                                      border: OutlineInputBorder(),
                                      errorStyle: TextStyle(color: Colors.red),
                                    ),
                                    onChanged: (value) {
                                      _markAsChanged();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Cost + Category
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
                              child: StreamBuilder<List<String>>(
                                stream:
                                    categoriesController.getCategoriesStream(),
                                builder: (context, snapshot) {
                                  // Always show UI immediately, don't wait for data
                                  // Cache categories when available
                                  if (snapshot.hasData &&
                                      snapshot.data != null) {
                                    _cachedCategories = snapshot.data;
                                  }

                                  // Use cached categories if available, otherwise empty list
                                  // This ensures UI is never blocked
                                  final categories = _cachedCategories ??
                                      (snapshot.hasData
                                          ? snapshot.data ?? []
                                          : []);

                                  // Don't show loading indicator - just show empty/available categories

                                  // Ensure the dropdown can open even before the categories stream arrives
                                  // by injecting the currently selected category into the items list if missing.
                                  final List<String> itemsList =
                                      List<String>.from(categories);
                                  final String? selectedCat =
                                      controller.selectedCategory;
                                  if (selectedCat != null &&
                                      selectedCat.trim().isNotEmpty &&
                                      !itemsList.contains(selectedCat)) {
                                    itemsList.insert(0, selectedCat);
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      DropdownButtonFormField<String>(
                                        value: selectedCat != null &&
                                                itemsList.contains(selectedCat)
                                            ? selectedCat
                                            : (itemsList.isNotEmpty
                                                ? itemsList.first
                                                : null),
                                        menuMaxHeight: 240,
                                        decoration: InputDecoration(
                                          labelText: 'Category *',
                                          border: OutlineInputBorder(),
                                          errorStyle:
                                              TextStyle(color: Colors.red),
                                        ),
                                        items: itemsList
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
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[a-zA-Z0-9 ]')),
                                    ],
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
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[a-zA-Z0-9 ]')),
                                    ],
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

                      // Packaging Unit + Quantity
                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Unit Quantity',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 6),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                                controller
                                                        .stockController.text =
                                                    controller.stock.toString();
                                              });
                                            }
                                          },
                                        ),
                                        Expanded(
                                          child: TextField(
                                            textAlign: TextAlign.center,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                  3),
                                            ],
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w500,
                                                color: theme.textTheme
                                                    .bodyMedium?.color),
                                            controller:
                                                controller.stockController,
                                            onChanged: (val) {
                                              _markAsChanged();
                                              setState(() {
                                                final qty =
                                                    int.tryParse(val) ?? 0;
                                                controller.stock =
                                                    qty < 0 ? 0 : qty;
                                              });
                                            },
                                            decoration: InputDecoration(
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
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
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
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
                                  Text('Packaging Unit',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: controller.selectedPackagingUnit,
                                    menuMaxHeight: 240,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                      errorStyle: TextStyle(color: Colors.red),
                                    ),
                                    items: [
                                      'Pack',
                                      'Box',
                                      'Bundle',
                                      'Bottle',
                                      'Jug',
                                      'Pad',
                                      'Pieces',
                                      'Spool',
                                      'Tub',
                                      'Syringe',
                                      'Roll'
                                    ]
                                        .map((u) => DropdownMenuItem(
                                            value: u, child: Text(u)))
                                        .toList(),
                                    onChanged: (val) {
                                      _markAsChanged();
                                      setState(() {
                                        controller.selectedPackagingUnit = val;
                                        // Reset packaging content if the new unit doesn't need it
                                        if (_isPackagingContentDisabled(val)) {
                                          controller.selectedPackagingContent =
                                              null;
                                          controller.packagingContent = 1;
                                          controller.packagingContentController
                                              .text = '1';
                                        } else {
                                          // Set default content based on unit
                                          final options =
                                              _getPackagingContentOptions(val);
                                          if (options.isNotEmpty) {
                                            controller
                                                    .selectedPackagingContent =
                                                options.first;
                                          }
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Packaging Content + Quantity
                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Content Quantity',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: theme.dividerColor
                                              .withOpacity(0.2)),
                                    ),
                                    child: Opacity(
                                      opacity: _isPackagingContentDisabled(
                                              controller.selectedPackagingUnit)
                                          ? 0.5
                                          : 1.0,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.remove,
                                                color: theme.iconTheme.color),
                                            splashRadius: 18,
                                            onPressed: _isPackagingContentDisabled(
                                                    controller
                                                        .selectedPackagingUnit)
                                                ? null
                                                : () {
                                                    if (controller
                                                            .packagingContent >
                                                        1) {
                                                      _markAsChanged();
                                                      setState(() {
                                                        controller
                                                            .packagingContent--;
                                                        controller
                                                                .packagingContentController
                                                                .text =
                                                            controller
                                                                .packagingContent
                                                                .toString();
                                                      });
                                                    }
                                                  },
                                          ),
                                          Expanded(
                                            child: TextField(
                                              textAlign: TextAlign.center,
                                              keyboardType:
                                                  TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                                LengthLimitingTextInputFormatter(
                                                    3),
                                              ],
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w500,
                                                  color: theme.textTheme
                                                      .bodyMedium?.color),
                                              controller: controller
                                                  .packagingContentController,
                                              enabled:
                                                  !_isPackagingContentDisabled(
                                                      controller
                                                          .selectedPackagingUnit),
                                              onChanged:
                                                  _isPackagingContentDisabled(
                                                          controller
                                                              .selectedPackagingUnit)
                                                      ? null
                                                      : (val) {
                                                          _markAsChanged();
                                                          setState(() {
                                                            final qty =
                                                                int.tryParse(
                                                                        val) ??
                                                                    1;
                                                            controller
                                                                    .packagingContent =
                                                                qty > 999
                                                                    ? 999
                                                                    : (qty < 1
                                                                        ? 1
                                                                        : qty);
                                                            if (qty > 999) {
                                                              controller
                                                                  .packagingContentController
                                                                  .text = '999';
                                                            } else if (qty <
                                                                1) {
                                                              controller
                                                                  .packagingContentController
                                                                  .text = '1';
                                                            }
                                                          });
                                                        },
                                              decoration: InputDecoration(
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.add,
                                                color: theme.iconTheme.color),
                                            splashRadius: 18,
                                            onPressed: _isPackagingContentDisabled(
                                                    controller
                                                        .selectedPackagingUnit)
                                                ? null
                                                : () {
                                                    if (controller
                                                            .packagingContent <
                                                        999) {
                                                      _markAsChanged();
                                                      setState(() {
                                                        controller
                                                            .packagingContent++;
                                                        controller
                                                                .packagingContentController
                                                                .text =
                                                            controller
                                                                .packagingContent
                                                                .toString();
                                                      });
                                                    }
                                                  },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
                                  Text('Packaging Content',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: _getValidPackagingContentValue(),
                                    menuMaxHeight: 240,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                      errorStyle: TextStyle(color: Colors.red),
                                    ),
                                    items: _getPackagingContentOptions(
                                            controller.selectedPackagingUnit)
                                        .map((c) => DropdownMenuItem(
                                            value: c, child: Text(c)))
                                        .toList(),
                                    onChanged: _isPackagingContentDisabled(
                                            controller.selectedPackagingUnit)
                                        ? null
                                        : (val) {
                                            _markAsChanged();
                                            setState(() {
                                              controller
                                                      .selectedPackagingContent =
                                                  val;
                                            });
                                          },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Expiry Date and Low Stock Threshold side by side
                      Row(
                        children: [
                          // Expiry Date (LEFT)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Expiry *',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: controller.expiryController,
                                    enabled: !controller.noExpiry,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                      suffixIcon:
                                          Icon(Icons.calendar_today, size: 18),
                                      errorStyle: TextStyle(color: Colors.red),
                                      hintText: controller.noExpiry
                                          ? 'No expiry date'
                                          : 'Select date',
                                    ),
                                    readOnly: true,
                                    onTap: !controller.noExpiry
                                        ? () async {
                                            DateTime? picked =
                                                await showDatePicker(
                                              context: context,
                                              initialDate:
                                                  controller.expiryDate ??
                                                      DateTime.now(),
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime(2100),
                                            );
                                            if (picked != null) {
                                              setState(() {
                                                controller.expiryDate = picked;
                                                controller
                                                        .expiryController.text =
                                                    "${picked.year.toString().padLeft(4, '0')}-"
                                                    "${picked.month.toString().padLeft(2, '0')}-"
                                                    "${picked.day.toString().padLeft(2, '0')}";
                                                // Clear validation error when user selects date
                                                if (validationErrors[
                                                        'expiry'] !=
                                                    null) {
                                                  validationErrors['expiry'] =
                                                      null;
                                                }
                                                _markAsChanged();
                                              });
                                            }
                                          }
                                        : null,
                                  ),
                                  _buildValidationError(
                                      validationErrors['expiry']),
                                ],
                              ),
                            ),
                          ),
                          // Low Stock Threshold (RIGHT)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Low Stock Threshold',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 6),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.remove,
                                              color: theme.iconTheme.color),
                                          splashRadius: 18,
                                          onPressed: () {
                                            if (controller.lowStockThreshold >
                                                1) {
                                              _markAsChanged();
                                              setState(() {
                                                controller.lowStockThreshold--;
                                                controller
                                                        .lowStockThresholdController
                                                        .text =
                                                    controller.lowStockThreshold
                                                        .toString();
                                              });
                                            }
                                          },
                                        ),
                                        Expanded(
                                          child: TextField(
                                            textAlign: TextAlign.center,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                  3),
                                            ],
                                            decoration: InputDecoration(
                                                border: InputBorder.none),
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w500,
                                                color: theme.textTheme
                                                    .bodyMedium?.color),
                                            controller: controller
                                                .lowStockThresholdController,
                                            onChanged: (val) {
                                              _markAsChanged();
                                              setState(() {
                                                final qty =
                                                    int.tryParse(val) ?? 1;
                                                controller.lowStockThreshold =
                                                    qty > 999
                                                        ? 999
                                                        : (qty < 1 ? 1 : qty);
                                                controller
                                                        .lowStockThresholdController
                                                        .text =
                                                    controller.lowStockThreshold
                                                        .toString();
                                              });
                                            },
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.add,
                                              color: theme.iconTheme.color),
                                          splashRadius: 18,
                                          onPressed: () {
                                            if (controller.lowStockThreshold <
                                                999) {
                                              _markAsChanged();
                                              setState(() {
                                                controller.lowStockThreshold++;
                                                controller
                                                        .lowStockThresholdController
                                                        .text =
                                                    controller.lowStockThreshold
                                                        .toString();
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                                      // Check connectivity before proceeding
                                      final hasConnection =
                                          await ConnectivityService()
                                              .hasInternetConnection();
                                      if (!hasConnection) {
                                        if (mounted) {
                                          await showConnectionErrorDialog(
                                              context);
                                          setState(() {
                                            _isSaving = false;
                                          });
                                        }
                                        return;
                                      }

                                      final errors =
                                          controller.validateFields();
                                      if (errors.isNotEmpty) {
                                        setState(() {
                                          validationErrors = errors;
                                          _isSaving = false;
                                        });
                                        return;
                                      }

                                      try {
                                        final result = await controller
                                            .updateSupply(widget.item.id);
                                        if (result == null) {
                                          if (!mounted) return;
                                          _hasUnsavedChanges =
                                              false; // Reset flag on successful save
                                          Navigator.of(context).pop(true);
                                        } else {
                                          // Check if result contains network error
                                          final errorString =
                                              result.toLowerCase();
                                          if (errorString.contains(
                                                  'socketexception') ||
                                              errorString.contains(
                                                  'failed host lookup') ||
                                              errorString.contains(
                                                  'no address associated') ||
                                              errorString.contains(
                                                  'network is unreachable') ||
                                              errorString.contains(
                                                  'connection refused') ||
                                              errorString.contains(
                                                  'connection timed out') ||
                                              errorString.contains(
                                                  'clientexception')) {
                                            if (mounted) {
                                              await showConnectionErrorDialog(
                                                  context);
                                            }
                                          } else {
                                            if (result ==
                                                'SUPPLY_NAME_EXISTS') {
                                              if (!mounted) return;
                                              await _showDuplicateSupplyWarning(
                                                  context);
                                            } else {
                                              // Other error - show generic error message
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(content: Text(result)),
                                              );
                                            }
                                          }
                                        }
                                      } catch (e) {
                                        // Catch any exceptions that weren't caught by controller
                                        final errorString =
                                            e.toString().toLowerCase();
                                        if (errorString
                                                .contains('socketexception') ||
                                            errorString.contains(
                                                'failed host lookup') ||
                                            errorString.contains(
                                                'no address associated') ||
                                            errorString.contains(
                                                'network is unreachable') ||
                                            errorString.contains(
                                                'connection refused') ||
                                            errorString.contains(
                                                'connection timed out')) {
                                          if (mounted) {
                                            await showConnectionErrorDialog(
                                                context);
                                          }
                                        } else {
                                          // Other error - show generic error message
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Failed to update supply: ${e.toString()}'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
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

                    // Buttons (Update Supply first, then Cancel)
                    Row(
                      children: [
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
                        const SizedBox(width: 12),
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

    final currentType = controller.typeController.text.trim();
    if (currentType != _originalType) {
      changes.add(_buildChangeRow('Type', _originalType, currentType));
    }

    final currentCategory = controller.selectedCategory ?? '';
    if (currentCategory != _originalCategory) {
      changes
          .add(_buildChangeRow('Category', _originalCategory, currentCategory));
    }

    final currentStock = controller.stock;
    if (currentStock != _originalStock) {
      changes.add(_buildChangeRow(
          'Stock', _originalStock.toString(), currentStock.toString()));
    }

    final currentCost = controller.costController.text.trim();
    final originalCostText = '₱$_originalCost';
    final currentCostText = '₱$currentCost';
    if (currentCostText != originalCostText) {
      changes.add(_buildChangeRow('Cost', originalCostText, currentCostText));
    }

    // Packaging Unit
    final currentPackagingUnit = controller.selectedPackagingUnit ?? '';
    if (currentPackagingUnit != _originalPackagingUnit) {
      changes.add(_buildChangeRow(
          'Packaging Unit', _originalPackagingUnit, currentPackagingUnit));
    }

    // Packaging Quantity
    if (controller.packagingQuantity != _originalPackagingQuantity) {
      changes.add(_buildChangeRow(
          'Packaging Quantity',
          _originalPackagingQuantity.toString(),
          controller.packagingQuantity.toString()));
    }

    // Packaging Content
    final currentPackagingContent = controller.selectedPackagingContent ?? '';
    final originalContentText =
        _originalPackagingContent.isEmpty ? 'N/A' : _originalPackagingContent;
    final currentContentText =
        currentPackagingContent.isEmpty ? 'N/A' : currentPackagingContent;
    if (currentPackagingContent != _originalPackagingContent) {
      changes.add(_buildChangeRow(
          'Packaging Content', originalContentText, currentContentText));
    }

    // Packaging Content Quantity
    if (controller.packagingContent != _originalPackagingContentQuantity) {
      final originalQtyText =
          _isPackagingContentDisabled(_originalPackagingUnit)
              ? 'N/A'
              : _originalPackagingContentQuantity.toString();
      final currentQtyText = controller.isPackagingContentDisabled()
          ? 'N/A'
          : controller.packagingContent.toString();
      changes.add(_buildChangeRow(
          'Packaging Content Quantity', originalQtyText, currentQtyText));
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

    // Low Stock Threshold
    final currentLowStockThreshold = controller.lowStockThreshold;
    if (currentLowStockThreshold != _originalLowStockThreshold) {
      changes.add(_buildChangeRow(
          'Threshold',
          _originalLowStockThreshold.toString(),
          currentLowStockThreshold.toString()));
    }

    // Image change detection
    final currentImageUrl = controller.imageUrl ?? '';
    if (currentImageUrl != _originalImageUrl) {
      final originalImageText =
          _originalImageUrl.isEmpty ? 'No image' : 'Image uploaded';
      final currentImageText =
          currentImageUrl.isEmpty ? 'No image' : 'Image uploaded';
      changes
          .add(_buildChangeRow('Image', originalImageText, currentImageText));
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

  // Helper method to get packaging content options based on selected unit
  List<String> _getPackagingContentOptions(String? packagingUnit) {
    switch (packagingUnit) {
      case 'Pack':
      case 'Box':
      case 'Bundle':
        return ['Pieces'];
      case 'Bottle':
        return ['mL', 'L'];
      case 'Jug':
        return ['mL', 'L'];
      case 'Pad':
        return ['Cartridge'];
      case 'Syringe':
        return ['mL', 'g'];
      case 'Pieces':
      case 'Spool':
      case 'Tub':
      case 'Roll':
        return []; // These don't need packaging content
      default:
        return ['Pieces', 'Units', 'Items', 'Count'];
    }
  }

  // Helper method to check if packaging content should be disabled
  bool _isPackagingContentDisabled(String? packagingUnit) {
    return packagingUnit == 'Pieces' ||
        packagingUnit == 'Spool' ||
        packagingUnit == 'Tub' ||
        packagingUnit == 'Roll';
  }

  // Helper method to get valid packaging content value
  String? _getValidPackagingContentValue() {
    final options =
        _getPackagingContentOptions(controller.selectedPackagingUnit);
    if (options.isEmpty) return null;

    // If current value is valid, use it; otherwise use first option
    if (controller.selectedPackagingContent != null &&
        options.contains(controller.selectedPackagingContent)) {
      return controller.selectedPackagingContent;
    }

    return options.first;
  }

  Future<void> _showDuplicateSupplyWarning(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showDialog(
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
                // X Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Update Supply Failed',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  'A supply with this name already exists in the inventory.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
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
              ],
            ),
          ),
        );
      },
    );
  }
}
