import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:familee_dental/features/inventory/controller/add_supply_controller.dart';
import 'package:familee_dental/features/inventory/controller/categories_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/services/connectivity_service.dart';
import 'package:familee_dental/shared/widgets/connection_error_dialog.dart';

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
  bool _isSaving = false; // Add loading state for save button

  // Store original values to compare against
  String _originalName = '';
  String _originalType = '';
  String _originalCategory = '';
  int _originalPackagingQuantity = 1;
  int _originalPackagingContent = 1;
  String _originalPackagingUnit = 'Box';
  String _originalPackagingContentType = 'Pieces';
  double _originalCost = 0.0;
  String _originalSupplier = '';
  String _originalBrand = '';
  String _originalExpiry = '';
  bool _originalNoExpiry = false;
  int _originalLowStockThreshold = 1;
  List<String>? _cachedCategories;

  @override
  void initState() {
    super.initState();
    // Initialize original values to match controller's default state
    _originalName = controller.nameController.text.trim();
    _originalType = controller.typeController.text.trim();
    _originalCategory = controller.selectedCategory ?? '';
    _originalPackagingQuantity = controller.packagingQuantity;
    _originalPackagingContent = controller.packagingContent;
    _originalPackagingUnit = controller.selectedPackagingUnit ?? 'Box';
    _originalPackagingContentType =
        controller.selectedPackagingContent ?? 'Pieces';
    _originalCost =
        double.tryParse(controller.costController.text.trim()) ?? 0.0;
    _originalSupplier = controller.supplierController.text.trim();
    _originalBrand = controller.brandController.text.trim();
    _originalExpiry = controller.expiryController.text.trim();
    _originalNoExpiry = controller.noExpiry;
    _originalLowStockThreshold = controller.lowStockThreshold;
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
      case 'Pieces':
      case 'Spool':
      case 'Tub':
        return []; // These don't need packaging content
      default:
        return ['Pieces', 'Units', 'Items', 'Count'];
    }
  }

  // Helper method to check if packaging content should be disabled
  bool _isPackagingContentDisabled(String? packagingUnit) {
    return packagingUnit == 'Pieces' ||
        packagingUnit == 'Spool' ||
        packagingUnit == 'Tub';
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

  void _markAsChanged() {
    final currentName = controller.nameController.text.trim();
    final currentType = controller.typeController.text.trim();
    final currentCategory = controller.selectedCategory ?? '';
    final currentPackagingQuantity = controller.packagingQuantity;
    final currentPackagingContent = controller.packagingContent;
    final currentPackagingUnit = controller.selectedPackagingUnit ?? 'Box';
    final currentPackagingContentType =
        controller.selectedPackagingContent ?? 'Pieces';
    final currentCost =
        double.tryParse(controller.costController.text.trim()) ?? 0.0;
    final currentSupplier = controller.supplierController.text.trim();
    final currentBrand = controller.brandController.text.trim();
    final currentExpiry = controller.expiryController.text.trim();
    final currentNoExpiry = controller.noExpiry;
    final currentLowStockThreshold = controller.lowStockThreshold;

    final hasChanges = currentName != _originalName ||
        currentType != _originalType ||
        currentCategory != _originalCategory ||
        currentPackagingQuantity != _originalPackagingQuantity ||
        currentPackagingContent != _originalPackagingContent ||
        currentPackagingUnit != _originalPackagingUnit ||
        currentPackagingContentType != _originalPackagingContentType ||
        currentCost != _originalCost ||
        currentSupplier != _originalSupplier ||
        currentBrand != _originalBrand ||
        currentExpiry != _originalExpiry ||
        currentNoExpiry != _originalNoExpiry ||
        currentLowStockThreshold != _originalLowStockThreshold;

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
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 768
                    ? 1.0
                    : 16.0, // Reduce horizontal
                vertical: 12.0, // Keep vertical as needed
              ),
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
                                      'Upload image',
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
                                decoration: InputDecoration(
                                  labelText: 'Item Name *',
                                  border: OutlineInputBorder(),
                                  errorStyle: TextStyle(color: Colors.red),
                                ),
                                onChanged: (value) async {
                                  _markAsChanged();
                                  // Clear validation error when user types
                                  if (validationErrors['name'] != null) {
                                    setState(() {
                                      validationErrors['name'] = null;
                                    });
                                  }

                                  // Auto-fill supplier and brand if supply name exists
                                  if (value.trim().isNotEmpty) {
                                    await controller
                                        .autoFillFromExistingSupply(value);
                                    setState(
                                        () {}); // Refresh UI to show autofilled values
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: controller.typeController,
                                decoration: InputDecoration(
                                  labelText: 'Type Name',
                                  border: OutlineInputBorder(),
                                  errorStyle: TextStyle(color: Colors.red),
                                ),
                                onChanged: (value) {
                                  _markAsChanged();
                                  // Clear validation error when user types
                                  if (validationErrors['type'] != null) {
                                    setState(() {
                                      validationErrors['type'] = null;
                                    });
                                  }
                                },
                              ),
                              _buildValidationError(validationErrors['type']),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Supplier Name + Brand Name
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
                                keyboardType: TextInputType.numberWithOptions(
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
                              _buildValidationError(validationErrors['cost']),
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
                                      ?.copyWith(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 6),
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color:
                                          theme.dividerColor.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove,
                                          color: theme.iconTheme.color),
                                      splashRadius: 18,
                                      onPressed: () {
                                        if (controller.packagingQuantity > 0) {
                                          _markAsChanged();
                                          setState(() {
                                            controller.packagingQuantity--;
                                            controller
                                                    .packagingQuantityController
                                                    .text =
                                                controller.packagingQuantity
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
                                              controller.selectedPackagingUnit ==
                                                      'Pieces'
                                                  ? 3
                                                  : 2),
                                        ],
                                        decoration: InputDecoration(
                                            border: InputBorder.none),
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                            color: theme
                                                .textTheme.bodyMedium?.color),
                                        controller: controller
                                            .packagingQuantityController,
                                        onChanged: (val) {
                                          _markAsChanged();
                                          setState(() {
                                            final qty = int.tryParse(val) ?? 0;
                                            final maxValue = controller
                                                        .selectedPackagingUnit ==
                                                    'Pieces'
                                                ? 999
                                                : 99;
                                            controller.packagingQuantity =
                                                qty > maxValue
                                                    ? maxValue
                                                    : (qty < 0 ? 0 : qty);
                                            if (qty > maxValue) {
                                              controller
                                                  .packagingQuantityController
                                                  .text = maxValue.toString();
                                            } else if (qty < 0) {
                                              controller
                                                  .packagingQuantityController
                                                  .text = '0';
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.add,
                                          color: theme.iconTheme.color),
                                      splashRadius: 18,
                                      onPressed: () {
                                        final maxValue =
                                            controller.selectedPackagingUnit ==
                                                    'Pieces'
                                                ? 999
                                                : 99;
                                        if (controller.packagingQuantity <
                                            maxValue) {
                                          _markAsChanged();
                                          setState(() {
                                            controller.packagingQuantity++;
                                            controller
                                                    .packagingQuantityController
                                                    .text =
                                                controller.packagingQuantity
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
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Packaging Unit',
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: controller.selectedPackagingUnit,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  errorStyle: TextStyle(color: Colors.red),
                                ),
                                items: [
                                  'Pack',
                                  'Box',
                                  'Bottle',
                                  'Jug',
                                  'Pad',
                                  'Pieces',
                                  'Spool',
                                  'Tub'
                                ]
                                    .map((u) => DropdownMenuItem(
                                        value: u, child: Text(u)))
                                    .toList(),
                                onChanged: (val) {
                                  _markAsChanged();
                                  setState(() {
                                    final wasPieces =
                                        controller.selectedPackagingUnit ==
                                            'Pieces';
                                    final isPieces = val == 'Pieces';
                                    controller.selectedPackagingUnit = val;

                                    // If switching from Pieces to non-Pieces, cap quantity at 99
                                    if (wasPieces &&
                                        !isPieces &&
                                        controller.packagingQuantity > 99) {
                                      controller.packagingQuantity = 99;
                                      controller.packagingQuantityController
                                          .text = '99';
                                    }

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
                                        controller.selectedPackagingContent =
                                            options.first;
                                      }
                                    }
                                    // Clear validation error when user selects
                                    if (validationErrors['packagingUnit'] !=
                                        null) {
                                      validationErrors['packagingUnit'] = null;
                                    }
                                  });
                                },
                              ),
                              _buildValidationError(
                                  validationErrors['packagingUnit']),
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
                                      ?.copyWith(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 6),
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color:
                                          theme.dividerColor.withOpacity(0.2)),
                                ),
                                child: Opacity(
                                  opacity: _isPackagingContentDisabled(
                                          controller.selectedPackagingUnit)
                                      ? 0.5
                                      : 1.0,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            LengthLimitingTextInputFormatter(3),
                                          ],
                                          decoration: InputDecoration(
                                              border: InputBorder.none),
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                              color: theme
                                                  .textTheme.bodyMedium?.color),
                                          controller: controller
                                              .packagingContentController,
                                          enabled: !_isPackagingContentDisabled(
                                              controller.selectedPackagingUnit),
                                          onChanged: _isPackagingContentDisabled(
                                                  controller
                                                      .selectedPackagingUnit)
                                              ? null
                                              : (val) {
                                                  _markAsChanged();
                                                  setState(() {
                                                    final qty =
                                                        int.tryParse(val) ?? 1;
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
                                                    } else if (qty < 1) {
                                                      controller
                                                          .packagingContentController
                                                          .text = '1';
                                                    }
                                                  });
                                                },
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
                                      ?.copyWith(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _isPackagingContentDisabled(
                                        controller.selectedPackagingUnit)
                                    ? null
                                    : _getValidPackagingContentValue(),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(),
                                  errorStyle: TextStyle(color: Colors.red),
                                ),
                                items: _getPackagingContentOptions(
                                        controller.selectedPackagingUnit)
                                    .map((u) => DropdownMenuItem(
                                        value: u, child: Text(u)))
                                    .toList(),
                                onChanged: _isPackagingContentDisabled(
                                        controller.selectedPackagingUnit)
                                    ? null
                                    : (val) {
                                        _markAsChanged();
                                        setState(() {
                                          controller.selectedPackagingContent =
                                              val;
                                          // Clear validation error when user selects
                                          if (validationErrors[
                                                  'packagingContent'] !=
                                              null) {
                                            validationErrors[
                                                'packagingContent'] = null;
                                          }
                                        });
                                      },
                              ),
                              _buildValidationError(
                                  validationErrors['packagingContent']),
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
                                      ?.copyWith(fontWeight: FontWeight.w500)),
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
                                            if (validationErrors['expiry'] !=
                                                null) {
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
                                      ?.copyWith(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 6),
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color:
                                          theme.dividerColor.withOpacity(0.2)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove,
                                          color: theme.iconTheme.color),
                                      splashRadius: 18,
                                      onPressed: () {
                                        if (controller.lowStockThreshold > 1) {
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
                                          LengthLimitingTextInputFormatter(3),
                                        ],
                                        decoration: InputDecoration(
                                            border: InputBorder.none),
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                            color: theme
                                                .textTheme.bodyMedium?.color),
                                        controller: controller
                                            .lowStockThresholdController,
                                        onChanged: (val) {
                                          _markAsChanged();
                                          setState(() {
                                            final qty = int.tryParse(val) ?? 1;
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
                        onPressed: _isSaving
                            ? null
                            : () async {
                                if (_isSaving)
                                  return; // Prevent multiple submissions

                                // Show confirmation dialog first
                                final confirmed = await _showSaveConfirmation();
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
                                      await showConnectionErrorDialog(context);
                                      setState(() {
                                        _isSaving = false;
                                      });
                                    }
                                    return;
                                  }

                                  final errors = controller.validateFields();
                                  if (errors.isNotEmpty) {
                                    setState(() {
                                      validationErrors = errors;
                                      _isSaving = false;
                                    });
                                    return;
                                  }

                                  try {
                                    final result = await controller.addSupply();
                                    if (result == null) {
                                      if (!mounted) return;
                                      _hasUnsavedChanges =
                                          false; // Reset flag on successful save
                                      Navigator.of(context).pop(true);
                                    } else {
                                      // Check if archived supply exists
                                      if (result == 'ARCHIVED_SUPPLY_EXISTS') {
                                        if (!mounted) return;
                                        await _showArchivedSupplyWarning(
                                            context);
                                      } else if (result ==
                                          'DUPLICATE_SUPPLY_EXISTS') {
                                        if (!mounted) return;
                                        await _showDuplicateSupplyWarning(
                                            context);
                                      } else {
                                        // Check if result contains network error
                                        final errorString =
                                            result.toLowerCase();
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
                                                'connection timed out') ||
                                            errorString
                                                .contains('clientexception')) {
                                          if (mounted) {
                                            await showConnectionErrorDialog(
                                                context);
                                          }
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
                                        errorString
                                            .contains('failed host lookup') ||
                                        errorString.contains(
                                            'no address associated') ||
                                        errorString.contains(
                                            'network is unreachable') ||
                                        errorString
                                            .contains('connection refused') ||
                                        errorString
                                            .contains('connection timed out')) {
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
                                              'Failed to add supply: ${e.toString()}'),
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
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4AA).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.inventory_2,
                        color: Color(0xFF00D4AA),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'Confirm Add Supply',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Content - Show all input details
                    Text(
                      'Please review the details before adding this supply:',
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

                    // Details Container
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
                        children: [
                          _buildDetailRow(
                              'Name', controller.nameController.text.trim()),
                          _buildDetailRow(
                              'Type', controller.typeController.text.trim()),
                          _buildDetailRow(
                              'Supplier',
                              controller.supplierController.text.trim().isEmpty
                                  ? 'Not specified'
                                  : controller.supplierController.text.trim()),
                          _buildDetailRow(
                              'Brand',
                              controller.brandController.text.trim().isEmpty
                                  ? 'Not specified'
                                  : controller.brandController.text.trim()),
                          _buildDetailRow('Cost',
                              '₱${controller.costController.text.trim()}'),
                          _buildDetailRow('Category',
                              controller.selectedCategory ?? 'Not selected'),
                          _buildDetailRow('Packaging',
                              '${controller.packagingQuantity} ${controller.selectedPackagingUnit ?? 'Box'}'),
                          if (!_isPackagingContentDisabled(
                              controller.selectedPackagingUnit))
                            _buildDetailRow('Content',
                                '${controller.packagingContent} ${controller.selectedPackagingContent ?? 'Pieces'}'),
                          if (controller.noExpiry)
                            _buildDetailRow('Expiry', 'No expiry date')
                          else
                            _buildDetailRow(
                                'Expiry',
                                controller.expiryController.text.trim().isEmpty
                                    ? 'Not specified'
                                    : controller.expiryController.text.trim()),
                          _buildDetailRow('Threshold',
                              controller.lowStockThreshold.toString()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons
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
                              'Add Supply',
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

  Widget _buildDetailRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showArchivedSupplyWarning(BuildContext context) async {
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
                  'Add Supply Failed',
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
                  'The supply is already archived.',
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
                  'Add Supply Failed',
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
                  'The supply that you are trying to add already exists in the inventory.',
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
