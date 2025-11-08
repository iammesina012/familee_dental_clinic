import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:familee_dental/features/inventory/controller/view_supply_controller.dart';
import 'package:familee_dental/shared/services/connectivity_service.dart';
import 'package:familee_dental/shared/widgets/connection_error_dialog.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';

class EditSupplyPOPage extends StatefulWidget {
  final Map<String, dynamic> supply;

  const EditSupplyPOPage({super.key, required this.supply});

  @override
  State<EditSupplyPOPage> createState() => _EditSupplyPOPageState();
}

class _EditSupplyPOPageState extends State<EditSupplyPOPage> {
  final TextEditingController brandController = TextEditingController();
  final TextEditingController supplierController = TextEditingController();
  final TextEditingController costController = TextEditingController();
  final TextEditingController _packagingQtyController = TextEditingController();
  final TextEditingController _packagingContentQtyController =
      TextEditingController();
  final FocusNode _packagingQtyFocus = FocusNode();
  final FocusNode _packagingContentQtyFocus = FocusNode();
  // Multiple expiry batches: each batch has its own qty + expiry
  final List<TextEditingController> _batchQtyControllers = [];
  final List<DateTime?> _batchExpiries = [];
  final List<bool> _batchNoExpirySelected = [];
  final ViewSupplyController _viewSupplyController = ViewSupplyController();
  List<_PackagingOption> _packagingContentOptions = [];
  List<String> _packagingUnitOptions = [];
  final Map<String, Map<String, dynamic>> _variantByUnitKey = {};
  bool _isApplyingVariant = false;
  int _typeRequestToken = 0;
  int _packagingRequestToken = 0;

  // Inventory unit (kept for saving; no longer editable in UI)
  String _selectedUnit = 'Box';

  // Packaging fields
  String _selectedPackagingUnit = 'Box';
  String _selectedPackagingContent = 'Pieces';
  int _packagingQuantity = 1;
  int _packagingContentQuantity = 1;

  // Type detection state
  bool _isTypeDetecting = true;
  String? _detectedType;

  // No packaging unit dropdown; unit comes from inventory data

  @override
  void initState() {
    super.initState();
    brandController.text = widget.supply['brandName'] ?? '';
    supplierController.text = widget.supply['supplierName'] ?? '';
    costController.text = (widget.supply['cost'] ?? 0.0).toString();
    _selectedUnit =
        widget.supply['unit'] ?? 'Box'; // Initialize unit from existing data

    // Initialize packaging fields from widget.supply as fallback
    // These will be updated from inventory when _initializeCorrectType() runs
    _selectedPackagingUnit = widget.supply['packagingUnit'] ?? 'Box';
    _selectedPackagingContent = widget.supply['packagingContent'] ?? 'Pieces';
    _packagingQuantity = widget.supply['packagingQuantity'] ?? 1;
    _packagingContentQuantity = widget.supply['packagingContentQuantity'] ?? 1;

    // Initialize controllers and focus behavior for quantity inputs
    _packagingQtyController.text = _packagingQuantity.toString();
    _packagingContentQtyController.text = _packagingContentQuantity.toString();
    if (_selectedPackagingUnit.isNotEmpty) {
      _packagingUnitOptions = [_selectedPackagingUnit];
    }

    _packagingQtyFocus.addListener(() {
      if (!_packagingQtyFocus.hasFocus) {
        final v = int.tryParse(_packagingQtyController.text) ?? 1;
        final clamped = v < 1 ? 1 : (v > 99 ? 99 : v);
        if (clamped != _packagingQuantity) {
          setState(() {
            _packagingQuantity = clamped;
          });
        } else {
          // still update text to clamped to remove empty value
          _packagingQtyController.text = clamped.toString();
        }
      }
    });

    _packagingContentQtyFocus.addListener(() {
      if (!_packagingContentQtyFocus.hasFocus) {
        final v = int.tryParse(_packagingContentQtyController.text) ?? 1;
        final clamped = v < 1 ? 1 : (v > 999 ? 999 : v);
        if (clamped != _packagingContentQuantity) {
          setState(() {
            _packagingContentQuantity = clamped;
          });
        } else {
          _packagingContentQtyController.text = clamped.toString();
        }
      }
    });

    // Initialize the correct type if not already set
    _initializeCorrectType();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPackagingContentOptions(
        supplyName: widget.supply['supplyName']?.toString() ?? '',
        type: widget.supply['type']?.toString(),
      );
    });

    // Initialize batches from existing data if present
    final List<dynamic>? existingBatches =
        widget.supply['expiryBatches'] as List<dynamic>?;
    if (existingBatches != null && existingBatches.isNotEmpty) {
      for (final b in existingBatches) {
        final qty = int.tryParse('${b['quantity'] ?? 1}') ?? 1;
        final ctrl = TextEditingController(text: qty.toString());
        _batchQtyControllers.add(ctrl);
        DateTime? dt;
        final s = (b['expiryDate'] ?? '').toString();
        if (s.isNotEmpty) {
          try {
            final p = s.contains('-') ? s.split('-') : s.split('/');
            if (p.length == 3) {
              dt = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
            }
          } catch (_) {}
        }
        _batchExpiries.add(dt);
        _batchNoExpirySelected.add(false);
      }
    } else {
      // Fallback to single batch from existing single fields
      final initialQty = (widget.supply['quantity'] ?? 1) as int;
      _batchQtyControllers
          .add(TextEditingController(text: initialQty.toString()));
      DateTime? dt;
      final existingExpiry = widget.supply['expiryDate'];
      if (existingExpiry is String && existingExpiry.isNotEmpty) {
        try {
          final parts = existingExpiry.contains('-')
              ? existingExpiry.split('-')
              : existingExpiry.split('/');
          if (parts.length == 3) {
            dt = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          }
        } catch (_) {}
      }
      _batchExpiries.add(dt);
      _batchNoExpirySelected.add(false);
    }
  }

  @override
  void dispose() {
    brandController.dispose();
    supplierController.dispose();
    costController.dispose();
    _packagingQtyController.dispose();
    _packagingContentQtyController.dispose();
    _packagingQtyFocus.dispose();
    _packagingContentQtyFocus.dispose();
    for (final c in _batchQtyControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fieldFillColor = theme.brightness == Brightness.dark
        ? scheme.surface
        : const Color(0xFFF4F5F9);
    final fieldBorderColor = theme.brightness == Brightness.dark
        ? Colors.white.withOpacity(0.1)
        : const Color(0xFFE0E4EC);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Edit Supply (PO)",
          style: AppFonts.sfProStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.appBarTheme.titleTextStyle?.color ??
                theme.textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: theme.appBarTheme.elevation ?? 5,
        shadowColor: theme.appBarTheme.shadowColor ?? theme.shadowColor,
      ),
      body: ResponsiveContainer(
        maxWidth: 1000,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Supply Image Section
                Center(
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: widget.supply['imageUrl'] != null &&
                            widget.supply['imageUrl'].isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.supply['imageUrl'],
                            fit: BoxFit.contain,
                            placeholder: (context, url) {
                              return Container(
                                width: 120,
                                height: 120,
                                color: Colors.grey[200],
                                child: Icon(Icons.image,
                                    size: 48, color: Colors.grey[400]),
                              );
                            },
                            errorWidget: (context, url, error) {
                              return Icon(Icons.image_not_supported,
                                  size: 60, color: Colors.grey);
                            },
                            fadeInDuration: const Duration(milliseconds: 200),
                            fadeOutDuration: const Duration(milliseconds: 100),
                          )
                        : Icon(Icons.image_not_supported,
                            size: 60, color: Colors.grey),
                  ),
                ),
                SizedBox(height: 14),

                // Supply Name with Type Name dropdown
                Container(
                  height: 60, // Give the Stack a fixed height to prevent cutoff
                  child: Stack(
                    children: [
                      // Centered Supply Name
                      Center(
                        child: Text(
                          widget.supply['supplyName'] ?? 'Unknown Supply',
                          style: AppFonts.sfProStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Type Name dropdown positioned on the right
                      Positioned(
                        right: 0,
                        child: Container(
                          width: 120,
                          decoration: BoxDecoration(
                            color: fieldFillColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: fieldBorderColor,
                              width: 1,
                            ),
                          ),
                          child: FutureBuilder<List<String>>(
                            future: _getAvailableTypes(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                );
                              }

                              final availableTypes = snapshot.data ?? [];

                              if (_isTypeDetecting &&
                                  availableTypes.isNotEmpty) {
                                return Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  child: Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  ),
                                );
                              }

                              if (availableTypes.isEmpty) {
                                // Ensure we exit detection state if nothing to detect
                                if (_isTypeDetecting) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (mounted) {
                                      setState(() {
                                        _isTypeDetecting = false;
                                        _detectedType = '';
                                      });
                                    }
                                  });
                                }
                                // Show a static disabled state when no types exist
                                return Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  child: Text(
                                    'No types',
                                    style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.5),
                                    ),
                                  ),
                                );
                              }

                              return DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _getValidTypeValue(availableTypes),
                                  isExpanded: true,
                                  items: availableTypes.map((String type) {
                                    return DropdownMenuItem<String>(
                                      value: type,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text(type),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        widget.supply['type'] = newValue;
                                        _detectedType =
                                            newValue; // Update detected type when manually changed
                                        // Update image and other details based on type
                                        // When manually changing type, load all data from inventory for that type
                                        _updateSupplyForType(newValue,
                                            preservePOData: false);
                                      });
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 26),

                // Brand Name and Supplier Name (horizontal layout)
                Row(
                  children: [
                    Expanded(
                      child: _buildFieldSection(
                        title: "Brand Name",
                        child: TextField(
                          controller: brandController,
                          enabled: true,
                          readOnly: false,
                          enableInteractiveSelection: true,
                          style: AppFonts.sfProStyle(
                            fontSize: 16,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter brand name',
                            hintStyle: AppFonts.sfProStyle(
                              fontSize: 16,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.4),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: fieldBorderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: fieldBorderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Color(0xFF00D4AA), width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            filled: true,
                            fillColor: fieldFillColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildFieldSection(
                        title: "Supplier Name",
                        child: TextField(
                          controller: supplierController,
                          style: AppFonts.sfProStyle(
                              fontSize: 16,
                              color: theme.textTheme.bodyMedium?.color),
                          decoration: InputDecoration(
                            hintText: 'Enter supplier name',
                            hintStyle: AppFonts.sfProStyle(
                              fontSize: 16,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.4),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: fieldBorderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: fieldBorderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Color(0xFF00D4AA), width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            filled: true,
                            fillColor: fieldFillColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Cost (full width)
                Row(
                  children: [
                    Expanded(
                      child: _buildFieldSection(
                        title: "Cost",
                        child: TextField(
                          controller: costController,
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          style: AppFonts.sfProStyle(
                              fontSize: 16,
                              color: theme.textTheme.bodyMedium?.color),
                          decoration: InputDecoration(
                            hintText: 'Enter cost (₱)',
                            hintStyle: AppFonts.sfProStyle(
                              fontSize: 16,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.4),
                            ),
                            prefixText: '₱ ',
                            prefixStyle: AppFonts.sfProStyle(
                              fontSize: 16,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.7),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: fieldBorderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: fieldBorderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Color(0xFF00D4AA), width: 2),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            filled: true,
                            fillColor: fieldFillColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Removed Quantity + Packaging Unit (handled in Quantity & Expiry)
                SizedBox(height: 16),

                // Packaging Unit & Content
                Row(
                  children: [
                    Expanded(
                      child: _buildFieldSection(
                        title: "Packaging Unit",
                        child: Container(
                          decoration: BoxDecoration(
                            color: fieldFillColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: fieldBorderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: () {
                                final options = _packagingUnitOptions.isNotEmpty
                                    ? _packagingUnitOptions
                                    : (_selectedPackagingUnit.isNotEmpty
                                        ? [_selectedPackagingUnit]
                                        : ['Box']);
                                final currentValue =
                                    _getValidPackagingUnitValue();
                                return options.contains(currentValue)
                                    ? currentValue
                                    : null;
                              }(),
                              hint: Text(
                                'Select unit',
                                style: AppFonts.sfProStyle(
                                  fontSize: 16,
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.6),
                                ),
                              ),
                              isExpanded: true,
                              style: AppFonts.sfProStyle(
                                fontSize: 16,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                              items: (_packagingUnitOptions.isNotEmpty
                                      ? _packagingUnitOptions
                                      : (_selectedPackagingUnit.isNotEmpty
                                          ? [_selectedPackagingUnit]
                                          : ['Box']))
                                  .map(
                                    (optionLabel) => DropdownMenuItem<String>(
                                      value: optionLabel,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text(
                                          optionLabel,
                                          style: AppFonts.sfProStyle(
                                            fontSize: 16,
                                            color: theme
                                                .textTheme.bodyMedium?.color,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (String? newValue) {
                                if (newValue == null) return;
                                setState(() {
                                  _ensureValidPackagingSelection(
                                      forcedUnit: newValue);
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildFieldSection(
                        title: "Packaging Content",
                        child: Container(
                          decoration: BoxDecoration(
                            color: fieldFillColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: fieldBorderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: () {
                                final options = _getPackagingContentOptions();
                                final value = _getValidPackagingContentValue();
                                return (value != null &&
                                        options.contains(value))
                                    ? value
                                    : null;
                              }(),
                              hint: Text(
                                _isPackagingContentDisabled()
                                    ? 'Not applicable'
                                    : 'Select content',
                                style: AppFonts.sfProStyle(
                                  fontSize: 16,
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.6),
                                ),
                              ),
                              isExpanded: true,
                              style: AppFonts.sfProStyle(
                                fontSize: 16,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                              items: _getPackagingContentOptions()
                                  .map(
                                    (optionLabel) => DropdownMenuItem<String>(
                                      value: optionLabel,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16),
                                        child: Text(
                                          optionLabel,
                                          style: AppFonts.sfProStyle(
                                            fontSize: 16,
                                            color: theme
                                                .textTheme.bodyMedium?.color,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _isPackagingContentDisabled()
                                  ? null
                                  : (String? newValue) {
                                      if (newValue == null) return;
                                      setState(() {
                                        _applySelectedContent(newValue);
                                      });
                                    },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Quantity + Expiry batches
                _buildFieldSection(
                  title: "Quantity & Expiry",
                  child: Column(
                    children: [
                      for (int i = 0; i < _batchQtyControllers.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              // Qty stepper
                              Container(
                                width: 120,
                                decoration: BoxDecoration(
                                  color: fieldFillColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: fieldBorderColor),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      child: IconButton(
                                        onPressed: () {
                                          final currentQty = int.tryParse(
                                                  _batchQtyControllers[i]
                                                      .text) ??
                                              1;
                                          if (currentQty > 1) {
                                            setState(() {
                                              _batchQtyControllers[i].text =
                                                  (currentQty - 1).toString();
                                            });
                                          }
                                        },
                                        icon: Icon(Icons.remove,
                                            color: theme.iconTheme.color
                                                ?.withOpacity(0.7),
                                            size: 16),
                                      ),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _batchQtyControllers[i],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          LengthLimitingTextInputFormatter(2),
                                        ],
                                        onChanged: (value) {
                                          final qty = int.tryParse(value);
                                          if (qty != null && qty > 99) {
                                            _batchQtyControllers[i].text = '99';
                                          }
                                        },
                                        style: AppFonts.sfProStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: theme
                                                .textTheme.bodyMedium?.color),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                              vertical: 12),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 32,
                                      child: IconButton(
                                        onPressed: () {
                                          final currentQty = int.tryParse(
                                                  _batchQtyControllers[i]
                                                      .text) ??
                                              1;
                                          if (currentQty < 99) {
                                            setState(() {
                                              _batchQtyControllers[i].text =
                                                  (currentQty + 1).toString();
                                            });
                                          }
                                        },
                                        icon: const Icon(Icons.add,
                                            color: Color(0xFF00D4AA), size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Expiry date picker
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final result = await _showCustomDatePicker(
                                      context: context,
                                      initialDate: _batchExpiries[i],
                                    );
                                    if (result is DateTime) {
                                      setState(() {
                                        _batchExpiries[i] = result;
                                        _batchNoExpirySelected[i] = false;
                                      });
                                    } else if (result == 'NO_EXPIRY') {
                                      // User explicitly selected "No Expiry Date"
                                      setState(() {
                                        _batchExpiries[i] = null;
                                        _batchNoExpirySelected[i] = true;
                                      });
                                    } else {
                                      // Cancel or tap outside → do nothing
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: fieldFillColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: fieldBorderColor,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.event,
                                            color: Color(0xFF00D4AA), size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _batchExpiries[i] != null
                                                ? '${_batchExpiries[i]!.year}/${_batchExpiries[i]!.month.toString().padLeft(2, '0')}/${_batchExpiries[i]!.day.toString().padLeft(2, '0')}'
                                                : _batchNoExpirySelected[i]
                                                    ? 'No Expiry Date'
                                                    : 'Set expiry date',
                                            style: AppFonts.sfProStyle(
                                                fontSize: 16,
                                                color: _batchExpiries[i] != null
                                                    ? theme.textTheme.bodyMedium
                                                        ?.color
                                                    : _batchNoExpirySelected[i]
                                                        ? theme.textTheme
                                                            .bodyMedium?.color
                                                            ?.withOpacity(0.8)
                                                        : theme.textTheme
                                                            .bodyMedium?.color
                                                            ?.withOpacity(0.6)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Remove batch button
                              if (_batchQtyControllers.length > 1)
                                IconButton(
                                  constraints: const BoxConstraints(
                                      minWidth: 36, minHeight: 36),
                                  padding: EdgeInsets.zero,
                                  tooltip: 'Remove',
                                  iconSize: 22,
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text('Remove expiry batch?',
                                                style: AppFonts.sfProStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            content: Text(
                                              'This will remove this quantity and expiry date row.',
                                              style: AppFonts.sfProStyle(
                                                  fontSize: 14),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(false),
                                                child: Text('Cancel',
                                                    style: AppFonts.sfProStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(true),
                                                child: Text('Remove',
                                                    style: AppFonts.sfProStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        ) ??
                                        false;
                                    if (!confirmed) return;
                                    setState(() {
                                      _batchQtyControllers[i].dispose();
                                      _batchQtyControllers.removeAt(i);
                                      _batchExpiries.removeAt(i);
                                      _batchNoExpirySelected.removeAt(i);
                                    });
                                  },
                                ),
                            ],
                          ),
                        ),
                      // Add another expiry row button
                      InkWell(
                        onTap: () {
                          setState(() {
                            _batchQtyControllers
                                .add(TextEditingController(text: '1'));
                            _batchExpiries.add(null);
                            _batchNoExpirySelected.add(false);
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFF00D4AA).withOpacity(0.6),
                                width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add, color: Color(0xFF00D4AA)),
                              const SizedBox(width: 8),
                              Text('Add another expiry date',
                                  style: AppFonts.sfProStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF00D4AA))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _saveSupply();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00D4AA),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Save Supply',
                      style: AppFonts.sfProStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppFonts.sfProStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).textTheme.bodyMedium?.color
                : const Color(0xFF8B5A8B),
          ),
        ),
        SizedBox(height: 8),
        child,
      ],
    );
  }

  Future<void> _saveSupply() async {
    // Validate fields
    if (brandController.text.trim().isEmpty) {
      _showErrorDialog('Please enter a brand name.');
      return;
    }

    final hasConnection = await ConnectivityService().hasInternetConnection();
    if (!hasConnection) {
      await showConnectionErrorDialog(context);
      return;
    }

    if (supplierController.text.trim().isEmpty) {
      _showErrorDialog('Please enter a supplier name.');
      return;
    }

    // Validate batches
    int totalQuantity = 0;
    for (int i = 0; i < _batchQtyControllers.length; i++) {
      final t = _batchQtyControllers[i].text.trim();
      final q = int.tryParse(t) ?? 0;
      if (q <= 0) {
        _showErrorDialog('Please enter a valid quantity for batch ${i + 1}.');
        return;
      }
      // Allow null expiry dates (no expiry)
      totalQuantity += q;
    }

    if (costController.text.trim().isEmpty) {
      _showErrorDialog('Please enter a cost.');
      return;
    }

    final cost = double.tryParse(costController.text.trim());
    if (cost == null || cost < 0) {
      _showErrorDialog(
          'Please enter a valid cost (greater than or equal to 0).');
      return;
    }

    // Build batches payload (aggregate same expiry dates, including no-expiry)
    final Map<String, int> aggregatedByDate = {};
    for (int i = 0; i < _batchQtyControllers.length; i++) {
      final quantityForBatch = int.parse(_batchQtyControllers[i].text.trim());
      final pickedDate = _batchExpiries[i];
      final String expiryKey = pickedDate != null
          ? '${pickedDate.year}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.day.toString().padLeft(2, '0')}'
          : '';
      aggregatedByDate[expiryKey] =
          (aggregatedByDate[expiryKey] ?? 0) + quantityForBatch;
    }
    final expiryBatches = <Map<String, dynamic>>[
      for (final entry in aggregatedByDate.entries)
        {
          'quantity': entry.value,
          'expiryDate': entry.key,
        }
    ];

    // Create the updated supply data
    final updatedSupplyData = {
      'supplyId': widget.supply['supplyId'],
      'supplyName': widget.supply['supplyName'],
      'type': widget.supply['type'] ?? '',
      'brandName': brandController.text.trim(),
      'supplierName': supplierController.text.trim(),
      'quantity': totalQuantity,
      'cost': cost,
      'unit': _selectedUnit, // Add inventory units
      'packagingUnit': _selectedPackagingUnit,
      'packagingQuantity': totalQuantity,
      'packagingContent':
          _isPackagingContentDisabled() ? '' : _selectedPackagingContent,
      'packagingContentQuantity':
          _isPackagingContentDisabled() ? 1 : _packagingContentQuantity,
      'imageUrl': widget.supply['imageUrl'],
      'status': 'Pending', // Initialize as pending
      // Keep first expiry for backward compatibility
      'expiryDate': expiryBatches.first['expiryDate'],
      // New multi-batch structure (non-breaking)
      'expiryBatches': expiryBatches,
    };

    // Return to previous page with the updated supply data
    Navigator.of(context).pop(updatedSupplyData);
  }

  Future<Object?> _showCustomDatePicker({
    required BuildContext context,
    DateTime? initialDate,
  }) async {
    return showDialog<Object?>(
      context: context,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        final scheme = theme.colorScheme;
        final fieldFillColor = theme.brightness == Brightness.dark
            ? scheme.surface
            : const Color(0xFFF4F5F9);
        final fieldBorderColor = theme.brightness == Brightness.dark
            ? Colors.white.withOpacity(0.1)
            : const Color(0xFFE0E4EC);
        return AlertDialog(
          title: Text(
            'Select Expiry Date',
            style: AppFonts.sfProStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // No Expiry option
              InkWell(
                onTap: () => Navigator.of(dialogContext).pop('NO_EXPIRY'),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: fieldFillColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: fieldBorderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.block,
                          color: theme.iconTheme.color?.withOpacity(0.7),
                          size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'No Expiry Date',
                        style: AppFonts.sfProStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Divider
              Container(
                height: 1,
                color: theme.dividerColor,
                child: Row(
                  children: [
                    Expanded(child: Container()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'OR',
                        style: AppFonts.sfProStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color
                              ?.withOpacity(0.8),
                        ),
                      ),
                    ),
                    Expanded(child: Container()),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Date picker option
              InkWell(
                onTap: () async {
                  // Use the outer page context for the date picker
                  final navigator = Navigator.of(dialogContext);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initialDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (picked != null) {
                    navigator.pop(picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4AA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00D4AA)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: const Color(0xFF00D4AA), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Select Date',
                        style: AppFonts.sfProStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF00D4AA),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: AppFonts.sfProStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Error',
            style: AppFonts.sfProStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: AppFonts.sfProStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF00D4AA),
              ),
              child: Text(
                'OK',
                style: AppFonts.sfProStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Get available types for the supply name from database
  Future<List<String>> _getAvailableTypes() async {
    try {
      final supplyName = widget.supply['supplyName'] ?? '';
      if (supplyName.isEmpty) return [];

      // Use ViewSupplyController to leverage cached types (supports offline usage)
      final types = await _viewSupplyController.getSupplyTypes(supplyName);
      return types;
    } catch (e) {
      print('Error fetching available types: $e');
      return [];
    }
  }

  // Get valid type value for dropdown
  String _getValidTypeValue(List<String> availableTypes) {
    // If we're still detecting type, don't show anything yet
    if (_isTypeDetecting) {
      return '';
    }

    // Use detected type if available
    if (_detectedType != null && availableTypes.contains(_detectedType!)) {
      return _detectedType!;
    }

    final currentType = widget.supply['type'] ?? '';
    print('Current type in widget.supply: $currentType');
    print('Available types: $availableTypes');

    if (availableTypes.contains(currentType)) {
      print('Using current type: $currentType');
      return currentType;
    }

    // If current type is empty, try to detect from image URL or other data
    if (currentType.isEmpty) {
      final detectedType = _detectTypeFromSupplyData(availableTypes);
      if (detectedType.isNotEmpty) {
        print('Detected type from supply data: $detectedType');
        return detectedType;
      }
    }

    // If current type is not in available types, return the first available type
    final fallbackType = availableTypes.isNotEmpty ? availableTypes.first : '';
    print('Using fallback type: $fallbackType');
    return fallbackType;
  }

  // Detect type from supply data (image URL, brand, etc.)
  String _detectTypeFromSupplyData(List<String> availableTypes) {
    print('=== Type Detection Debug ===');
    print('Available types: $availableTypes');

    // Try to detect from image URL
    final imageUrl = widget.supply['imageUrl']?.toString() ?? '';
    print('Image URL: $imageUrl');
    if (imageUrl.isNotEmpty) {
      for (final type in availableTypes) {
        if (imageUrl.toLowerCase().contains(type.toLowerCase())) {
          print('Found type "$type" in image URL');
          return type;
        }
      }
    }

    // Try to detect from brand or supplier
    final brand = widget.supply['brand']?.toString() ?? '';
    final supplier = widget.supply['supplier']?.toString() ?? '';
    print('Brand: $brand, Supplier: $supplier');

    for (final type in availableTypes) {
      if (brand.toLowerCase().contains(type.toLowerCase()) ||
          supplier.toLowerCase().contains(type.toLowerCase())) {
        print('Found type "$type" in brand/supplier');
        return type;
      }
    }

    // Try to detect from supply name
    final supplyName = widget.supply['supplyName']?.toString() ?? '';
    print('Supply name: $supplyName');
    for (final type in availableTypes) {
      if (supplyName.toLowerCase().contains(type.toLowerCase())) {
        print('Found type "$type" in supply name');
        return type;
      }
    }

    // Try to detect from cost or other unique identifiers
    final cost = widget.supply['cost']?.toString() ?? '';
    print('Cost: $cost');

    // If we have specific cost values for different types, we could use those
    // For now, let's try a different approach - query the database to find which type matches this supply's data

    print('No type detected from supply data');
    return '';
  }

  // Initialize the correct type when page loads
  Future<void> _initializeCorrectType() async {
    try {
      final supplyName = widget.supply['supplyName'] ?? '';
      if (supplyName.isEmpty) return;

      // Get available types
      final availableTypes = await _getAvailableTypes();
      if (availableTypes.isEmpty) {
        // No types available, but still try to fetch packaging info from inventory
        // using the supply name (without type filter)
        await _fetchPackagingInfoFromInventory(supplyName);
        if (mounted) {
          setState(() {
            _isTypeDetecting = false;
            _detectedType = '';
          });
        }
        return;
      }

      // If type is already set and valid, keep it but still fetch packaging info from inventory
      final currentType = widget.supply['type'] ?? '';
      if (availableTypes.contains(currentType)) {
        print('Type already correctly set: $currentType');
        // Only fetch packaging unit and content type from inventory, preserve cost and packaging content quantity from PO
        await _updatePackagingInfoOnly(currentType);
        if (mounted) {
          setState(() {
            _detectedType = currentType;
            _isTypeDetecting = false;
          });
        }
        return;
      }

      // Try to find the correct type by matching current supply data with database records
      final correctType =
          await _findCorrectTypeFromDatabase(supplyName, availableTypes);
      if (correctType.isNotEmpty) {
        print('Found correct type from database: $correctType');
        // Fetch all supply details including packaging information from inventory
        await _updateSupplyForType(correctType);
        if (mounted) {
          setState(() {
            widget.supply['type'] = correctType;
            _detectedType = correctType;
            _isTypeDetecting = false;
          });
        }
        return;
      }

      // Try to detect the correct type
      final detectedType = _detectTypeFromSupplyData(availableTypes);
      String finalType;
      if (detectedType.isNotEmpty) {
        print('Detected correct type on initialization: $detectedType');
        finalType = detectedType;
      } else {
        print(
            'Could not detect type, using first available: ${availableTypes.first}');
        finalType = availableTypes.first;
      }

      // Fetch all supply details including packaging information from inventory
      await _updateSupplyForType(finalType);
      if (mounted) {
        setState(() {
          widget.supply['type'] = finalType;
          _detectedType = finalType;
          _isTypeDetecting = false;
        });
      }
    } catch (e) {
      print('Error initializing correct type: $e');
    }
  }

  // Find the correct type by matching current supply data with database records
  Future<String> _findCorrectTypeFromDatabase(
      String supplyName, List<String> availableTypes) async {
    try {
      // Get current supply data to match against
      final currentImageUrl = widget.supply['imageUrl']?.toString() ?? '';
      final currentBrand = widget.supply['brand']?.toString() ?? '';
      final currentSupplier = widget.supply['supplier']?.toString() ?? '';
      final currentCost = widget.supply['cost']?.toString() ?? '';

      print(
          'Matching against: imageUrl=$currentImageUrl, brand=$currentBrand, supplier=$currentSupplier, cost=$currentCost');

      // Query all supplies with the same name
      final response = await Supabase.instance.client
          .from('supplies')
          .select('*')
          .eq('name', supplyName);

      print('Found ${response.length} supplies with name "$supplyName"');

      // Find the best match
      for (final supply in response) {
        final supplyType = supply['type']?.toString() ?? '';
        if (availableTypes.contains(supplyType)) {
          // Check if this supply matches our current data
          final supplyImageUrl = supply['image_url']?.toString() ?? '';
          final supplyBrand = supply['brand']?.toString() ?? '';
          final supplySupplier = supply['supplier']?.toString() ?? '';
          final supplyCost = supply['cost']?.toString() ?? '';

          print(
              'Checking supply type "$supplyType": imageUrl=$supplyImageUrl, brand=$supplyBrand, supplier=$supplySupplier, cost=$supplyCost');

          // Match by image URL first (most reliable)
          if (currentImageUrl.isNotEmpty &&
              supplyImageUrl.isNotEmpty &&
              currentImageUrl == supplyImageUrl) {
            print('Matched by image URL: $supplyType');
            return supplyType;
          }

          // Match by brand and supplier
          if (currentBrand.isNotEmpty &&
              currentSupplier.isNotEmpty &&
              currentBrand == supplyBrand &&
              currentSupplier == supplySupplier) {
            print('Matched by brand and supplier: $supplyType');
            return supplyType;
          }

          // Match by cost
          if (currentCost.isNotEmpty &&
              supplyCost.isNotEmpty &&
              currentCost == supplyCost) {
            print('Matched by cost: $supplyType');
            return supplyType;
          }
        }
      }

      print('No matching supply found in database');
      return '';
    } catch (e) {
      print('Error finding correct type from database: $e');
      return '';
    }
  }

  // Fetch packaging information from inventory by supply name (without type)
  Future<void> _fetchPackagingInfoFromInventory(String supplyName,
      {int? typeRequestToken}) async {
    try {
      print('Fetching packaging info from inventory for: $supplyName');

      // Query database for supply with the same name (get first match)
      final response = await Supabase.instance.client
          .from('supplies')
          .select('*')
          .eq('name', supplyName)
          .limit(1)
          .maybeSingle();

      print('Packaging info response: $response');

      if (typeRequestToken != null && _typeRequestToken != typeRequestToken) {
        return;
      }

      if (response != null && mounted) {
        setState(() {
          if (typeRequestToken != null &&
              _typeRequestToken != typeRequestToken) {
            return;
          }
          // Only update packaging unit and content type from inventory
          // Preserve packaging content quantity from PO supply
          _selectedPackagingUnit =
              response['packaging_unit']?.toString() ?? 'Box';
          _selectedPackagingContent =
              response['packaging_content']?.toString() ?? 'Pieces';
          widget.supply['packagingUnit'] = _selectedPackagingUnit;
          widget.supply['packagingContent'] = _selectedPackagingContent;
          // Don't overwrite packagingContentQuantity - preserve from PO
        });
        print(
            'Successfully updated packaging info from inventory (preserved packaging content quantity)');
        await _loadPackagingContentOptions(
          supplyName: supplyName,
          type: widget.supply['type']?.toString(),
          requestToken: typeRequestToken,
        );
        if (typeRequestToken != null && _typeRequestToken != typeRequestToken) {
          return;
        }
      } else {
        print('No supply found in inventory for: $supplyName');
      }
    } catch (e) {
      print('Error fetching packaging info from inventory: $e');
    }
  }

  // Update only packaging unit and content type from inventory, preserve cost and packaging content quantity from PO
  Future<void> _updatePackagingInfoOnly(String type) async {
    try {
      final supplyName = widget.supply['supplyName'] ?? '';
      print(
          'Updating packaging info only for type: $type, supply: $supplyName');

      // Query database for supply with the same name and type
      final response = await Supabase.instance.client
          .from('supplies')
          .select('*')
          .eq('name', supplyName)
          .eq('type', type)
          .maybeSingle();

      print('Packaging info response: $response');

      if (response != null && mounted) {
        setState(() {
          // Only update packaging unit and content type from inventory
          // Preserve cost, brand, supplier, and packaging content quantity from PO supply if they exist
          // Otherwise, load them from inventory for the correct type
          _selectedPackagingUnit =
              response['packaging_unit']?.toString() ?? 'Box';
          widget.supply['packagingUnit'] = _selectedPackagingUnit;

          _selectedPackagingContent =
              response['packaging_content']?.toString() ?? 'Pieces';
          widget.supply['packagingContent'] = _selectedPackagingContent;

          // Load cost from inventory if PO supply doesn't have it, otherwise preserve PO cost
          final poCost = widget.supply['cost'];
          if (poCost == null || !(poCost is num && poCost > 0)) {
            // PO supply doesn't have cost, load from inventory for this specific type
            final invCost = response['cost'] ?? 0.0;
            widget.supply['cost'] = invCost;
            costController.text = invCost.toString();
          }
          // Otherwise, cost is already set from widget.supply in initState() and preserved

          // Load brand from inventory if PO supply doesn't have it, otherwise preserve PO brand
          final poBrand = widget.supply['brandName'];
          if (poBrand == null || poBrand.toString().trim().isEmpty) {
            final invBrand = response['brand']?.toString() ?? '';
            widget.supply['brand'] = invBrand;
            widget.supply['brandName'] = invBrand;
            brandController.text = invBrand;
          }

          // Load supplier from inventory if PO supply doesn't have it, otherwise preserve PO supplier
          final poSupplier = widget.supply['supplierName'];
          if (poSupplier == null || poSupplier.toString().trim().isEmpty) {
            final invSupplier = response['supplier']?.toString() ?? '';
            widget.supply['supplier'] = invSupplier;
            widget.supply['supplierName'] = invSupplier;
            supplierController.text = invSupplier;
          }

          // Preserve packaging content quantity from PO supply (don't overwrite with inventory quantity)
          // This should already be set from widget.supply in initState()
        });
        print(
            'Successfully updated packaging info only (loaded cost/brand/supplier for correct type if PO supply missing them)');
        await _loadPackagingContentOptions(
          supplyName: supplyName,
          type: type,
        );
      } else {
        // Fallback: try to fetch packaging info by name only
        await _fetchPackagingInfoOnly(supplyName);
      }
    } catch (e) {
      print('Error updating packaging info only: $e');
    }
  }

  // Fetch only packaging unit and content type by supply name (without type)
  Future<void> _fetchPackagingInfoOnly(String supplyName) async {
    try {
      print('Fetching packaging info only from inventory for: $supplyName');

      // Query database for supply with the same name (get first match)
      final response = await Supabase.instance.client
          .from('supplies')
          .select('*')
          .eq('name', supplyName)
          .limit(1)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          // Only update packaging unit and content type from inventory
          // Preserve cost and packaging content quantity from PO supply
          _selectedPackagingUnit =
              response['packaging_unit']?.toString() ?? 'Box';
          widget.supply['packagingUnit'] = _selectedPackagingUnit;

          _selectedPackagingContent =
              response['packaging_content']?.toString() ?? 'Pieces';
          widget.supply['packagingContent'] = _selectedPackagingContent;
        });
        print('Successfully updated packaging info only from inventory');
        await _loadPackagingContentOptions(supplyName: supplyName);
      }
    } catch (e) {
      print('Error fetching packaging info only from inventory: $e');
    }
  }

  // Update supply details when type changes
  // preservePOData: If true, preserves cost, brand, supplier from PO supply if they exist
  //                 If false, loads all data from inventory for the new type (used when manually changing type)
  Future<void> _updateSupplyForType(String newType,
      {bool preservePOData = true}) async {
    try {
      final supplyName = widget.supply['supplyName'] ?? '';
      print('Updating supply for type: $newType, supply: $supplyName');

      final int requestToken = ++_typeRequestToken;

      InventoryItem? inventoryItem = await _viewSupplyController
          .getSupplyByNameAndType(supplyName, newType);

      if (!mounted || requestToken != _typeRequestToken) {
        return;
      }

      Map<String, dynamic>? supplyData;

      if (inventoryItem != null) {
        supplyData = {
          'id': inventoryItem.id,
          'name': inventoryItem.name,
          'type': inventoryItem.type,
          'image_url': inventoryItem.imageUrl,
          'brand': inventoryItem.brand,
          'supplier': inventoryItem.supplier,
          'cost': inventoryItem.cost,
          'unit': inventoryItem.unit,
          'packaging_unit': inventoryItem.packagingUnit,
          'packaging_quantity': inventoryItem.packagingQuantity,
          'packaging_content': inventoryItem.packagingContent,
          'packaging_content_quantity': inventoryItem.packagingContentQuantity,
        };
      } else {
        final response = await Supabase.instance.client
            .from('supplies')
            .select('*')
            .eq('name', supplyName)
            .eq('type', newType)
            .maybeSingle();

        if (!mounted || requestToken != _typeRequestToken) {
          return;
        }

        print('Database response (fallback): $response');

        if (response != null) {
          supplyData = response;
        }
      }

      if (supplyData != null) {
        final data = Map<String, dynamic>.from(supplyData);
        setState(() {
          if (requestToken != _typeRequestToken) {
            return;
          }
          _applySupplyData(
            newType: newType,
            supplyData: data,
            preservePOData: preservePOData,
          );
        });
        print('Successfully updated supply for type: $newType');
        await _loadPackagingContentOptions(
          supplyName: supplyName,
          type: newType,
          requestToken: requestToken,
        );
        return;
      }

      print('No supply found for type: $newType, trying fallback by name only');
      await _fetchPackagingInfoFromInventory(
        supplyName,
        typeRequestToken: requestToken,
      );
    } catch (e) {
      print('Error updating supply for type: $e');
    }
  }

  Future<void> _loadPackagingContentOptions({
    required String supplyName,
    String? type,
    int? requestToken,
  }) async {
    if (supplyName.trim().isEmpty || _isPackagingContentDisabled()) {
      if (_packagingContentOptions.isNotEmpty && mounted) {
        setState(() {
          _packagingContentOptions = [];
        });
      }
      return;
    }

    int token;
    if (requestToken != null) {
      token = requestToken;
      _packagingRequestToken = token;
    } else {
      token = ++_packagingRequestToken;
    }

    if (mounted && _packagingContentOptions.isNotEmpty) {
      setState(() {
        if (_packagingRequestToken == token) {
          _packagingContentOptions = [];
        }
      });
    }

    try {
      final Set<String> units = {};
      var query = Supabase.instance.client
          .from('supplies')
          .select(
              'id, name, type, image_url, brand, supplier, cost, unit, packaging_unit, packaging_quantity, packaging_content, packaging_content_quantity')
          .eq('name', supplyName);

      if (type != null && type.trim().isNotEmpty) {
        query = query.eq('type', type);
      }

      final response = await query.order('packaging_content_quantity');

      if (!mounted || _packagingRequestToken != token) {
        return;
      }

      final List<_PackagingOption> options = [];
      final Set<String> seen = {};
      final Map<String, Map<String, dynamic>> variants = {};

      for (final row in response) {
        final rawQuantity = row['packaging_content_quantity'];
        final quantity = rawQuantity is int
            ? rawQuantity
            : int.tryParse(rawQuantity?.toString() ?? '');
        final content = (row['packaging_content'] ?? '').toString().trim();
        final unit = (row['packaging_unit'] ?? row['packagingUnit'] ?? '')
            .toString()
            .trim();

        if (quantity == null || quantity <= 0) continue;
        final resolvedUnit = unit.isNotEmpty ? unit : 'Box';
        units.add(resolvedUnit);
        final option = _PackagingOption(
          unit: resolvedUnit,
          quantity: quantity,
          content: content,
        );
        final key =
            '${option.unit.toLowerCase()}|${option.quantity}|${option.content.toLowerCase()}';
        if (seen.contains(key)) continue;
        seen.add(key);
        options.add(option);

        final variantKey =
            '${option.unit.toLowerCase()}|${option.content.toLowerCase()}|${option.quantity}';
        variants[variantKey] = Map<String, dynamic>.from(row);
      }

      options.sort((a, b) => a.quantity.compareTo(b.quantity));

      if (!mounted || _packagingRequestToken != token) return;

      setState(() {
        if (_packagingRequestToken != token) {
          return;
        }
        _packagingContentOptions = options;
        _packagingUnitOptions = units.isNotEmpty
            ? (units.toList()..sort())
            : (_selectedPackagingUnit.isNotEmpty
                ? [_selectedPackagingUnit]
                : ['Box']);
        _variantByUnitKey
          ..clear()
          ..addAll(variants);
        _ensureValidPackagingSelection();
      });
    } catch (e) {
      print('Error loading packaging content options: $e');
    }
  }

  // Get packaging content options based on selected packaging unit
  List<String> _getPackagingContentOptions() {
    if (_isPackagingContentDisabled()) {
      return [];
    }

    final filtered = _getFilteredPackagingOptions();
    if (filtered.isNotEmpty) {
      return filtered.map((option) => option.label).toList();
    }

    if (_packagingContentOptions.isNotEmpty) {
      return _packagingContentOptions.map((option) => option.label).toList();
    }

    final fallbackQuantity =
        _packagingContentQuantity > 0 ? _packagingContentQuantity : 1;
    final fallbackContent = _selectedPackagingContent.isNotEmpty
        ? _selectedPackagingContent
        : 'Pieces';
    return [_formatPackagingLabel(fallbackQuantity, fallbackContent)];
  }

  // Check if packaging content should be disabled
  bool _isPackagingContentDisabled() {
    return ['Pieces', 'Spool', 'Tub'].contains(_selectedPackagingUnit);
  }

  // Get valid packaging content value
  String? _getValidPackagingContentValue() {
    final options = _getPackagingContentOptions();
    if (options.isEmpty) {
      return null;
    }

    if (_packagingContentOptions.isNotEmpty) {
      final filtered = _getFilteredPackagingOptions();
      final searchPool =
          filtered.isNotEmpty ? filtered : _packagingContentOptions;
      final matchingOption = searchPool.firstWhere(
        (option) =>
            option.quantity == _packagingContentQuantity &&
            option.content.toLowerCase() ==
                _selectedPackagingContent.toLowerCase(),
        orElse: () => searchPool.first,
      );
      return matchingOption.label;
    }

    final fallbackLabel = _formatPackagingLabel(
      _packagingContentQuantity > 0 ? _packagingContentQuantity : 1,
      _selectedPackagingContent.isNotEmpty
          ? _selectedPackagingContent
          : 'Pieces',
    );

    if (options.contains(fallbackLabel)) {
      return fallbackLabel;
    }

    return options.first;
  }

  String _formatPackagingLabel(int quantity, String content) {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      return quantity.toString();
    }
    return '$quantity $trimmedContent';
  }

  List<_PackagingOption> _getFilteredPackagingOptions() {
    if (_packagingContentOptions.isEmpty) return [];
    return _packagingContentOptions
        .where((option) => option.unit == _selectedPackagingUnit)
        .toList();
  }

  void _ensureValidPackagingSelection({String? forcedUnit}) {
    String unit = forcedUnit ?? _selectedPackagingUnit;
    if (_packagingUnitOptions.isEmpty && unit.isNotEmpty) {
      _packagingUnitOptions = [unit];
    }
    if (_packagingUnitOptions.isNotEmpty) {
      if (unit.isEmpty || !_packagingUnitOptions.contains(unit)) {
        unit = _packagingUnitOptions.first;
      }
    } else if (unit.isEmpty) {
      unit = 'Box';
    }
    _selectedPackagingUnit = unit;
    widget.supply['packagingUnit'] = _selectedPackagingUnit;

    final optionsForUnit = _getFilteredPackagingOptions();
    if (optionsForUnit.isNotEmpty) {
      final match = optionsForUnit.firstWhere(
        (option) =>
            option.quantity == _packagingContentQuantity &&
            option.content.toLowerCase() ==
                _selectedPackagingContent.toLowerCase(),
        orElse: () => optionsForUnit.first,
      );
      _selectedPackagingContent = match.content;
      _packagingContentQuantity = match.quantity;
    }

    _syncPackagingContentToSupply();

    if (_isApplyingVariant) {
      return;
    }

    final variant = _getVariantForCurrentSelection();
    if (variant != null) {
      _applyVariantData(variant);
    }
  }

  void _applySelectedContent(String label) {
    if (_packagingContentOptions.isNotEmpty) {
      final optionsForUnit = _getFilteredPackagingOptions();
      final searchPool =
          optionsForUnit.isNotEmpty ? optionsForUnit : _packagingContentOptions;
      final option = searchPool.firstWhere(
        (opt) => opt.label == label,
        orElse: () => searchPool.first,
      );
      _selectedPackagingContent = option.content;
      _packagingContentQuantity = option.quantity;
    } else {
      final parts = label.split(' ');
      if (parts.length >= 2) {
        _packagingContentQuantity =
            int.tryParse(parts.first) ?? _packagingContentQuantity;
        _selectedPackagingContent = parts.sublist(1).join(' ');
      } else {
        _selectedPackagingContent = label;
      }
    }
    _syncPackagingContentToSupply();

    final variant = _getVariantForCurrentSelection();
    if (variant != null) {
      _applyVariantData(variant);
    }
  }

  void _syncPackagingContentToSupply() {
    if (_packagingContentQuantity <= 0) {
      _packagingContentQuantity = 1;
    }
    _packagingContentQtyController.text = _packagingContentQuantity.toString();
    widget.supply['packagingContentQuantity'] = _packagingContentQuantity;
    widget.supply['packagingContent'] = _selectedPackagingContent;
  }

  String? _getValidPackagingUnitValue() {
    if (_selectedPackagingUnit.isEmpty) return null;
    if (_packagingUnitOptions.isEmpty) return _selectedPackagingUnit;
    return _packagingUnitOptions.contains(_selectedPackagingUnit)
        ? _selectedPackagingUnit
        : _packagingUnitOptions.first;
  }

  Map<String, dynamic>? _getVariantForCurrentSelection() {
    final unitKey = _selectedPackagingUnit.toLowerCase();
    final contentKey = _selectedPackagingContent.toLowerCase();
    final qtyKey = _packagingContentQuantity;
    final key = '$unitKey|$contentKey|$qtyKey';
    return _variantByUnitKey[key];
  }

  void _applyVariantData(Map<String, dynamic> variant) {
    _isApplyingVariant = true;
    try {
      final supplyData = Map<String, dynamic>.from(variant);
      final variantType = supplyData['type']?.toString() ??
          widget.supply['type']?.toString() ??
          '';
      _applySupplyData(
        newType: variantType,
        supplyData: supplyData,
        preservePOData: false,
      );
    } finally {
      _isApplyingVariant = false;
    }
  }

  void _applySupplyData({
    required String newType,
    required Map<String, dynamic> supplyData,
    required bool preservePOData,
  }) {
    final poCost = widget.supply['cost'];
    final poBrand = widget.supply['brandName'];
    final poSupplier = widget.supply['supplierName'];
    final poPackagingContentQty = widget.supply['packagingContentQuantity'];

    final double inventoryCost =
        _parseDouble(supplyData['cost'], fallback: 0.0);
    final String imageUrl =
        (supplyData['image_url'] ?? supplyData['imageUrl'] ?? '').toString();
    final String brandFromInventory =
        (supplyData['brand'] ?? '').toString().trim();
    final String supplierFromInventory =
        (supplyData['supplier'] ?? '').toString().trim();
    final String unitFromInventory =
        (supplyData['unit'] ?? '').toString().trim();
    final String packagingUnitFromInventory =
        (supplyData['packaging_unit'] ?? supplyData['packagingUnit'] ?? '')
            .toString()
            .trim();
    final String packagingContentFromInventory =
        (supplyData['packaging_content'] ??
                supplyData['packagingContent'] ??
                '')
            .toString()
            .trim();
    final int packagingQuantityFromInventory = _parseInt(
      supplyData['packaging_quantity'] ?? supplyData['packagingQuantity'],
      fallback: 1,
    );
    final int packagingContentQuantityFromInventory = _parseInt(
      supplyData['packaging_content_quantity'] ??
          supplyData['packagingContentQuantity'],
      fallback: 1,
    );

    widget.supply['type'] = newType;
    widget.supply['imageUrl'] = imageUrl;

    if (!preservePOData) {
      widget.supply['brand'] = brandFromInventory;
      widget.supply['brandName'] = brandFromInventory;
      widget.supply['supplier'] = supplierFromInventory;
      widget.supply['supplierName'] = supplierFromInventory;
      widget.supply['cost'] = inventoryCost;
    } else {
      if (poBrand != null && poBrand.toString().trim().isNotEmpty) {
        widget.supply['brand'] = poBrand;
        widget.supply['brandName'] = poBrand;
      } else {
        widget.supply['brand'] = brandFromInventory;
        widget.supply['brandName'] = brandFromInventory;
      }

      if (poSupplier != null && poSupplier.toString().trim().isNotEmpty) {
        widget.supply['supplier'] = poSupplier;
        widget.supply['supplierName'] = poSupplier;
      } else {
        widget.supply['supplier'] = supplierFromInventory;
        widget.supply['supplierName'] = supplierFromInventory;
      }

      if (poCost != null && poCost is num && poCost > 0) {
        widget.supply['cost'] = poCost;
      } else {
        widget.supply['cost'] = inventoryCost;
      }
    }

    widget.supply['packagingUnit'] = packagingUnitFromInventory.isNotEmpty
        ? packagingUnitFromInventory
        : 'Box';
    widget.supply['packagingQuantity'] =
        packagingQuantityFromInventory > 0 ? packagingQuantityFromInventory : 1;
    widget.supply['packagingContent'] = packagingContentFromInventory.isNotEmpty
        ? packagingContentFromInventory
        : 'Pieces';

    if (preservePOData &&
        poPackagingContentQty != null &&
        poPackagingContentQty is int &&
        poPackagingContentQty > 0) {
      widget.supply['packagingContentQuantity'] = poPackagingContentQty;
    } else {
      widget.supply['packagingContentQuantity'] =
          packagingContentQuantityFromInventory > 0
              ? packagingContentQuantityFromInventory
              : 1;
    }

    _selectedUnit =
        unitFromInventory.isNotEmpty ? unitFromInventory : _selectedUnit;
    _selectedPackagingUnit =
        widget.supply['packagingUnit']?.toString() ?? 'Box';
    _packagingQuantity =
        _parseInt(widget.supply['packagingQuantity'], fallback: 1);
    _packagingQtyController.text = _packagingQuantity.toString();

    _selectedPackagingContent =
        widget.supply['packagingContent']?.toString() ?? 'Pieces';
    _packagingContentQuantity =
        _parseInt(widget.supply['packagingContentQuantity'], fallback: 1);
    _packagingContentQtyController.text = _packagingContentQuantity.toString();

    brandController.text = widget.supply['brandName']?.toString() ?? '';
    supplierController.text = widget.supply['supplierName']?.toString() ?? '';

    final double costValue = _parseDouble(widget.supply['cost'], fallback: 0.0);
    widget.supply['cost'] = costValue;
    if (costValue == costValue.roundToDouble()) {
      costController.text = costValue.toInt().toString();
    } else {
      costController.text = costValue.toStringAsFixed(2);
    }

    _ensureValidPackagingSelection();
  }

  int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  double _parseDouble(dynamic value, {double fallback = 0.0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    return fallback;
  }
}

class _PackagingOption {
  final String unit;
  final int quantity;
  final String content;

  const _PackagingOption({
    required this.unit,
    required this.quantity,
    required this.content,
  });

  String get label {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      return quantity.toString();
    }
    return '$quantity $trimmedContent';
  }
}
