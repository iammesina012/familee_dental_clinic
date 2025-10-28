import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  // Multiple expiry batches: each batch has its own qty + expiry
  final List<TextEditingController> _batchQtyControllers = [];
  final List<DateTime?> _batchExpiries = [];
  final List<bool> _batchNoExpirySelected = [];

  // Inventory units dropdown
  String _selectedUnit = 'Box';
  final List<String> _availableUnits = ['Box', 'Piece', 'Pack'];

  // Packaging fields
  String _selectedPackagingUnit = 'Box';
  String _selectedPackagingContent = 'Pieces';
  int _packagingQuantity = 1;
  int _packagingContentQuantity = 1;

  // Type detection state
  bool _isTypeDetecting = true;
  String? _detectedType;

  final List<String> _packagingUnits = [
    'Pack',
    'Box',
    'Bottle',
    'Jug',
    'Pad',
    'Piece',
    'Spool',
    'Tub'
  ];

  @override
  void initState() {
    super.initState();
    brandController.text = widget.supply['brandName'] ?? '';
    supplierController.text = widget.supply['supplierName'] ?? '';
    costController.text = (widget.supply['cost'] ?? 0.0).toString();
    _selectedUnit =
        widget.supply['unit'] ?? 'Box'; // Initialize unit from existing data

    // Initialize packaging fields
    _selectedPackagingUnit = widget.supply['packagingUnit'] ?? 'Box';
    _selectedPackagingContent = widget.supply['packagingContent'] ?? 'Pieces';
    _packagingQuantity = widget.supply['packagingQuantity'] ?? 1;
    _packagingContentQuantity = widget.supply['packagingContentQuantity'] ?? 1;

    // Initialize the correct type if not already set
    _initializeCorrectType();

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
    for (final c in _batchQtyControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Edit Supply",
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: Colors.red, size: 30),
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.pushNamed(context, '/notifications');
              },
            ),
          ),
        ],
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
                        ? Image.network(
                            widget.supply['imageUrl'],
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.image_not_supported,
                                  size: 60, color: Colors.grey);
                            },
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
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.dividerColor,
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

                              if (_isTypeDetecting) {
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
                                        _updateSupplyForType(newValue);
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
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
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
                            fillColor: scheme.surface,
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
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
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
                            fillColor: scheme.surface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Cost and Inventory Units (horizontal layout)
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
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
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
                            fillColor: scheme.surface,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildFieldSection(
                        title: "Unit",
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedUnit,
                              isExpanded: true,
                              style: AppFonts.sfProStyle(
                                fontSize: 16,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                              items: _availableUnits.map((String unit) {
                                return DropdownMenuItem<String>(
                                  value: unit,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      unit,
                                      style: AppFonts.sfProStyle(
                                        fontSize: 16,
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedUnit = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Quantity + Packaging Unit
                Row(
                  children: [
                    Expanded(
                      child: _buildFieldSection(
                        title: "Quantity",
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  if (_packagingQuantity > 1) {
                                    setState(() {
                                      _packagingQuantity--;
                                    });
                                  }
                                },
                                icon: Icon(Icons.remove,
                                    color: theme.textTheme.bodyMedium?.color),
                              ),
                              Expanded(
                                child: Text(
                                  _packagingQuantity.toString(),
                                  textAlign: TextAlign.center,
                                  style: AppFonts.sfProStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _packagingQuantity++;
                                  });
                                },
                                icon: Icon(Icons.add,
                                    color: theme.textTheme.bodyMedium?.color),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildFieldSection(
                        title: "Packaging Unit",
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedPackagingUnit,
                              isExpanded: true,
                              style: AppFonts.sfProStyle(
                                fontSize: 16,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                              items: _packagingUnits.map((String unit) {
                                return DropdownMenuItem<String>(
                                  value: unit,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      unit,
                                      style: AppFonts.sfProStyle(
                                        fontSize: 16,
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedPackagingUnit = newValue;
                                    // Reset packaging content when unit changes
                                    _selectedPackagingContent =
                                        _getValidPackagingContentValue();
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Quantity + Packaging Content
                Row(
                  children: [
                    Expanded(
                      child: _buildFieldSection(
                        title: "Quantity",
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _isPackagingContentDisabled()
                                    ? null
                                    : () {
                                        if (_packagingContentQuantity > 1) {
                                          setState(() {
                                            _packagingContentQuantity--;
                                          });
                                        }
                                      },
                                icon: Icon(Icons.remove,
                                    color: _isPackagingContentDisabled()
                                        ? theme.textTheme.bodyMedium?.color
                                            ?.withOpacity(0.3)
                                        : theme.textTheme.bodyMedium?.color),
                              ),
                              Expanded(
                                child: Text(
                                  _packagingContentQuantity.toString(),
                                  textAlign: TextAlign.center,
                                  style: AppFonts.sfProStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _isPackagingContentDisabled()
                                    ? null
                                    : () {
                                        setState(() {
                                          _packagingContentQuantity++;
                                        });
                                      },
                                icon: Icon(Icons.add,
                                    color: _isPackagingContentDisabled()
                                        ? theme.textTheme.bodyMedium?.color
                                            ?.withOpacity(0.3)
                                        : theme.textTheme.bodyMedium?.color),
                              ),
                            ],
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
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _getValidPackagingContentValue(),
                              isExpanded: true,
                              style: AppFonts.sfProStyle(
                                fontSize: 16,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                              items: _getPackagingContentOptions()
                                  .map((String content) {
                                return DropdownMenuItem<String>(
                                  value: content,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      content,
                                      style: AppFonts.sfProStyle(
                                        fontSize: 16,
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: _isPackagingContentDisabled()
                                  ? null
                                  : (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedPackagingContent = newValue;
                                        });
                                      }
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
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
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
                                      color: scheme.surface,
                                      borderRadius: BorderRadius.circular(8),
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

  void _saveSupply() {
    // Validate fields
    if (brandController.text.trim().isEmpty) {
      _showErrorDialog('Please enter a brand name.');
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
      'packagingQuantity': _packagingQuantity,
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

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Supply updated successfully!',
          style: AppFonts.sfProStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF00D4AA),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
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
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: theme.dividerColor.withOpacity(0.2)),
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

      // Query database for existing types of this supply
      final response = await Supabase.instance.client
          .from('supplies')
          .select('type')
          .eq('name', supplyName)
          .not('type', 'is', null)
          .not('type', 'eq', '');

      // Extract unique types and filter out null/empty values
      final types = response
          .map((row) => row['type'] as String?)
          .where((type) => type != null && type.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

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
      if (availableTypes.isEmpty) return;

      // If type is already set and valid, keep it
      final currentType = widget.supply['type'] ?? '';
      if (availableTypes.contains(currentType)) {
        print('Type already correctly set: $currentType');
        setState(() {
          _detectedType = currentType;
          _isTypeDetecting = false;
        });
        return;
      }

      // Try to find the correct type by matching current supply data with database records
      final correctType =
          await _findCorrectTypeFromDatabase(supplyName, availableTypes);
      if (correctType.isNotEmpty) {
        print('Found correct type from database: $correctType');
        setState(() {
          widget.supply['type'] = correctType;
          _detectedType = correctType;
          _isTypeDetecting = false;
        });
        return;
      }

      // Try to detect the correct type
      final detectedType = _detectTypeFromSupplyData(availableTypes);
      if (detectedType.isNotEmpty) {
        print('Detected correct type on initialization: $detectedType');
        setState(() {
          widget.supply['type'] = detectedType;
          _detectedType = detectedType;
          _isTypeDetecting = false;
        });
      } else {
        print(
            'Could not detect type, using first available: ${availableTypes.first}');
        setState(() {
          widget.supply['type'] = availableTypes.first;
          _detectedType = availableTypes.first;
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

  // Update supply details when type changes
  Future<void> _updateSupplyForType(String newType) async {
    try {
      final supplyName = widget.supply['supplyName'] ?? '';
      print('Updating supply for type: $newType, supply: $supplyName');

      // Query database for supply with the same name and new type
      final response = await Supabase.instance.client
          .from('supplies')
          .select('*')
          .eq('name', supplyName)
          .eq('type', newType)
          .maybeSingle(); // Use maybeSingle() instead of single() to handle null cases

      print('Database response: $response');

      if (response != null) {
        setState(() {
          // Update all supply details with the new type's data
          widget.supply['type'] = newType;
          widget.supply['imageUrl'] = response['image_url'] ?? '';
          widget.supply['brand'] = response['brand'] ?? '';
          widget.supply['supplier'] = response['supplier'] ?? '';
          widget.supply['cost'] = response['cost'] ?? 0.0;
          widget.supply['packagingUnit'] = response['packaging_unit'] ?? 'Box';
          widget.supply['packagingQuantity'] =
              response['packaging_quantity'] ?? 1;
          widget.supply['packagingContent'] =
              response['packaging_content'] ?? 'Pieces';
          widget.supply['packagingContentQuantity'] =
              response['packaging_content_quantity'] ?? 1;

          // Update controllers with new values
          brandController.text = response['brand']?.toString() ?? '';
          supplierController.text = response['supplier']?.toString() ?? '';
          costController.text = response['cost']?.toString() ?? '';
          _selectedPackagingUnit =
              response['packaging_unit']?.toString() ?? 'Box';
          _packagingQuantity = response['packaging_quantity'] ?? 1;
          _selectedPackagingContent =
              response['packaging_content']?.toString() ?? 'Pieces';
          _packagingContentQuantity =
              response['packaging_content_quantity'] ?? 1;
        });
        print('Successfully updated supply for type: $newType');
      } else {
        print('No supply found for type: $newType');
      }
    } catch (e) {
      print('Error updating supply for type: $e');
    }
  }

  // Get packaging content options based on selected packaging unit
  List<String> _getPackagingContentOptions() {
    switch (_selectedPackagingUnit) {
      case 'Pack':
      case 'Box':
        return ['Pieces'];
      case 'Bottle':
      case 'Jug':
        return ['mL', 'L'];
      case 'Pad':
        return ['Cartridge'];
      case 'Piece':
      case 'Spool':
      case 'Tub':
        return ['Pieces']; // These don't need packaging content
      default:
        return ['Pieces'];
    }
  }

  // Check if packaging content should be disabled
  bool _isPackagingContentDisabled() {
    return ['Piece', 'Spool', 'Tub'].contains(_selectedPackagingUnit);
  }

  // Get valid packaging content value
  String _getValidPackagingContentValue() {
    final options = _getPackagingContentOptions();
    if (options.contains(_selectedPackagingContent)) {
      return _selectedPackagingContent;
    }
    return options.isNotEmpty ? options.first : 'Pieces';
  }
}
