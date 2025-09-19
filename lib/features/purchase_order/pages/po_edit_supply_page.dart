import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:projects/shared/themes/font.dart';

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

  @override
  void initState() {
    super.initState();
    brandController.text = widget.supply['brandName'] ?? '';
    supplierController.text = widget.supply['supplierName'] ?? '';
    costController.text = (widget.supply['cost'] ?? 0.0).toString();
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Supply Image Section
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
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
              ),
              SizedBox(height: 24),

              // Supply Name (disabled style, read-only)
              _buildFieldSection(
                title: "Supply Name",
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.disabledColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.disabledColor, width: 1),
                  ),
                  child: Text(
                    widget.supply['supplyName'] ?? 'Unknown Supply',
                    style: AppFonts.sfProStyle(
                      fontSize: 16,
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Brand Name (enabled again)
              _buildFieldSection(
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
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
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
                      borderSide:
                          BorderSide(color: Color(0xFF00D4AA), width: 2),
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
              SizedBox(height: 16),

              // Supplier Name
              _buildFieldSection(
                title: "Supplier Name",
                child: TextField(
                  controller: supplierController,
                  style: AppFonts.sfProStyle(
                      fontSize: 16, color: theme.textTheme.bodyMedium?.color),
                  decoration: InputDecoration(
                    hintText: 'Enter supplier name',
                    hintStyle: AppFonts.sfProStyle(
                      fontSize: 16,
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
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
                      borderSide:
                          BorderSide(color: Color(0xFF00D4AA), width: 2),
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
              SizedBox(height: 16),

              // Cost (moved above batches)
              _buildFieldSection(
                title: "Cost",
                child: TextField(
                  controller: costController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: AppFonts.sfProStyle(
                      fontSize: 16, color: theme.textTheme.bodyMedium?.color),
                  decoration: InputDecoration(
                    hintText: 'Enter cost (₱)',
                    hintStyle: AppFonts.sfProStyle(
                      fontSize: 16,
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
                    ),
                    prefixText: '₱ ',
                    prefixStyle: AppFonts.sfProStyle(
                      fontSize: 16,
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
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
                      borderSide:
                          BorderSide(color: Color(0xFF00D4AA), width: 2),
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
                              width: 150,
                              decoration: BoxDecoration(
                                color: scheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: theme.dividerColor.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 40,
                                    child: IconButton(
                                      onPressed: () {
                                        final currentQty = int.tryParse(
                                                _batchQtyControllers[i].text) ??
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
                                          size: 18),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _batchQtyControllers[i],
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: AppFonts.sfProStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: theme
                                              .textTheme.bodyMedium?.color),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding:
                                            EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: IconButton(
                                      onPressed: () {
                                        final currentQty = int.tryParse(
                                                _batchQtyControllers[i].text) ??
                                            1;
                                        setState(() {
                                          _batchQtyControllers[i].text =
                                              (currentQty + 1).toString();
                                        });
                                      },
                                      icon: const Icon(Icons.add,
                                          color: Color(0xFF00D4AA), size: 18),
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
                                    border: Border.all(
                                        color: theme.dividerColor
                                            .withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.event,
                                          color: Color(0xFF00D4AA), size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        _batchExpiries[i] != null
                                            ? '${_batchExpiries[i]!.year}/${_batchExpiries[i]!.month.toString().padLeft(2, '0')}/${_batchExpiries[i]!.day.toString().padLeft(2, '0')}'
                                            : _batchNoExpirySelected[i]
                                                ? 'No Expiry Date'
                                                : 'Set expiry date',
                                        style: AppFonts.sfProStyle(
                                            fontSize: 16,
                                            color: _batchExpiries[i] != null
                                                ? theme
                                                    .textTheme.bodyMedium?.color
                                                : _batchNoExpirySelected[i]
                                                    ? theme.textTheme.bodyMedium
                                                        ?.color
                                                        ?.withOpacity(0.8)
                                                    : theme.textTheme.bodyMedium
                                                        ?.color
                                                        ?.withOpacity(0.6)),
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
                                                  fontWeight: FontWeight.bold)),
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
      'brandName': brandController.text.trim(),
      'supplierName': supplierController.text.trim(),
      'quantity': totalQuantity,
      'cost': cost,
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
}
