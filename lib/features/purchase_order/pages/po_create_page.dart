import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:projects/features/purchase_order/data/purchase_order.dart';
import 'package:projects/features/purchase_order/controller/po_create_controller.dart';
import 'package:projects/shared/themes/font.dart';

class CreatePOPage extends StatefulWidget {
  const CreatePOPage({super.key});

  @override
  State<CreatePOPage> createState() => _CreatePOPageState();
}

class _CreatePOPageState extends State<CreatePOPage> {
  final TextEditingController purchaseNameController = TextEditingController();
  List<Map<String, dynamic>> addedSupplies = [];
  bool _isSaving = false; // Prevent double-save
  final CreatePOController _controller = CreatePOController();
  TextEditingController? _autocompleteController;
  bool _nameListenerAttached = false;

  // Editing mode variables
  bool _isEditing = false;
  PurchaseOrder? _editingPO;
  bool _shouldSetAutocompleteText = false;
  bool _hasInitializedEditingMode = false;
  String _originalName = '';
  List<Map<String, dynamic>> _originalSupplies = [];

  @override
  void initState() {
    super.initState();
    _controller.initializeDefaultSuggestions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkForEditingMode();
  }

  void _checkForEditingMode() {
    // Check if we're in editing mode and haven't initialized yet
    if (_hasInitializedEditingMode) return;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null &&
        args['isEditing'] == true &&
        args['editingPO'] != null) {
      _isEditing = true;
      _editingPO = args['editingPO'] as PurchaseOrder;

      // Pre-populate the form with existing PO data
      purchaseNameController.text = _editingPO!.name;
      addedSupplies = List<Map<String, dynamic>>.from(_editingPO!.supplies);
      _originalName = _editingPO!.name;
      _originalSupplies = List<Map<String, dynamic>>.from(_editingPO!.supplies);
      _shouldSetAutocompleteText = true;
      _hasInitializedEditingMode = true;

      setState(() {
        // Trigger rebuild to show the pre-populated data
      });
    }
  }

  String _getCurrentName() {
    final controllerToCheck = _autocompleteController ?? purchaseNameController;
    return controllerToCheck.text.trim();
  }

  bool _hasUnsavedChanges() {
    if (!_isEditing) {
      return addedSupplies.isNotEmpty && _getCurrentName().isNotEmpty;
    }
    final bool nameChanged = _getCurrentName() != _originalName;
    final bool suppliesChanged =
        jsonEncode(addedSupplies) != jsonEncode(_originalSupplies);
    return nameChanged || suppliesChanged;
  }

  @override
  void dispose() {
    purchaseNameController.dispose();
    super.dispose();
  }

  double _calculateTotalCost() {
    return _controller.calculateTotalCost(addedSupplies);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9EFF2),
      appBar: AppBar(
        title: Text(
          _isEditing ? "Edit PO" : "Create PO",
          style: AppFonts.sfProStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        toolbarHeight: 70,
        iconTheme: const IconThemeData(size: 30, color: Colors.black),
        elevation: 5,
        shadowColor: Colors.black54,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black, size: 30),
          onPressed: () => _handleBackPress(),
        ),
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
        child: Padding(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Purchase Name Section
              Container(
                padding:
                    EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                decoration: BoxDecoration(
                  color: Color(0xFFE8D5E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Use column layout for smaller screens
                    if (constraints.maxWidth < 600) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Purchase Name:",
                            style: AppFonts.sfProStyle(
                              fontSize:
                                  MediaQuery.of(context).size.width * 0.04,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B5A8B),
                            ),
                          ),
                          SizedBox(height: 8),
                          Autocomplete<String>(
                            fieldViewBuilder: (context, textEditingController,
                                focusNode, onFieldSubmitted) {
                              // Store reference to the autocomplete controller
                              _autocompleteController = textEditingController;
                              if (!_nameListenerAttached) {
                                _autocompleteController!.addListener(() {
                                  if (mounted) setState(() {});
                                });
                                _nameListenerAttached = true;
                              }

                              // Set the text if we're in editing mode and haven't set it yet
                              if (_shouldSetAutocompleteText &&
                                  _editingPO != null) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (mounted) {
                                    textEditingController.text =
                                        _editingPO!.name;
                                    setState(() {
                                      _shouldSetAutocompleteText = false;
                                    });
                                  }
                                });
                              }

                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                style: AppFonts.sfProStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width * 0.04,
                                  color: Colors.black,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Type here...',
                                  hintStyle: AppFonts.sfProStyle(
                                    fontSize:
                                        MediaQuery.of(context).size.width *
                                            0.04,
                                    color: Colors.grey[400],
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
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              );
                            },
                            optionsBuilder:
                                (TextEditingValue textEditingValue) async {
                              if (textEditingValue.text.trim().isEmpty) {
                                return const Iterable<String>.empty();
                              }
                              return await _controller
                                  .getSuggestions(textEditingValue.text);
                            },
                            onSelected: (String selection) {
                              // This is called when a suggestion is selected
                              // The text field will be automatically updated
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Material(
                                elevation: 4.0,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxHeight: options.length *
                                        56.0, // Increased height for better spacing
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap:
                                        true, // Make it only as tall as needed
                                    itemCount: options.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      final option = options.elementAt(index);
                                      return ListTile(
                                        dense: true, // Make tiles more compact
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                        title: Text(
                                          option,
                                          style: AppFonts.sfProStyle(
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        onTap: () {
                                          onSelected(option);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: Builder(builder: (context) {
                              final bool disabled = _isSaving ||
                                  (_isEditing
                                      ? !_hasUnsavedChanges()
                                      : addedSupplies.isEmpty);
                              return ElevatedButton(
                                onPressed: disabled ? null : _savePurchaseOrder,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: disabled
                                      ? Colors.grey[400]
                                      : Color(0xFF00D4AA),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  _isSaving
                                      ? (_isEditing
                                          ? 'Updating...'
                                          : 'Saving...')
                                      : (_isEditing ? 'Update' : 'Save'),
                                  style: AppFonts.sfProStyle(
                                    fontSize:
                                        MediaQuery.of(context).size.width *
                                            0.04,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      );
                    } else {
                      // Use row layout for larger screens
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Purchase Name:",
                                  style: AppFonts.sfProStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8B5A8B),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Autocomplete<String>(
                                  fieldViewBuilder: (context,
                                      textEditingController,
                                      focusNode,
                                      onFieldSubmitted) {
                                    // Store reference to the autocomplete controller
                                    _autocompleteController =
                                        textEditingController;
                                    if (!_nameListenerAttached) {
                                      _autocompleteController!.addListener(() {
                                        if (mounted) setState(() {});
                                      });
                                      _nameListenerAttached = true;
                                    }

                                    // Set the text if we're in editing mode and haven't set it yet
                                    if (_shouldSetAutocompleteText &&
                                        _editingPO != null) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (mounted) {
                                          textEditingController.text =
                                              _editingPO!.name;
                                          setState(() {
                                            _shouldSetAutocompleteText = false;
                                          });
                                        }
                                      });
                                    }

                                    return TextField(
                                      controller: textEditingController,
                                      focusNode: focusNode,
                                      style: AppFonts.sfProStyle(
                                        fontSize: 16,
                                        color: Colors.black,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Type here...',
                                        hintStyle: AppFonts.sfProStyle(
                                          fontSize: 16,
                                          color: Colors.grey[400],
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 16,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white,
                                      ),
                                    );
                                  },
                                  optionsBuilder: (TextEditingValue
                                      textEditingValue) async {
                                    if (textEditingValue.text.trim().isEmpty) {
                                      return const Iterable<String>.empty();
                                    }
                                    return await _controller
                                        .getSuggestions(textEditingValue.text);
                                  },
                                  onSelected: (String selection) {
                                    // This is called when a suggestion is selected
                                    // The text field will be automatically updated
                                  },
                                  optionsViewBuilder:
                                      (context, onSelected, options) {
                                    return Material(
                                      elevation: 4.0,
                                      child: Container(
                                        constraints: BoxConstraints(
                                          maxHeight: options.length *
                                              56.0, // Increased height for better spacing
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap:
                                              true, // Make it only as tall as needed
                                          itemCount: options.length,
                                          itemBuilder: (BuildContext context,
                                              int index) {
                                            final option =
                                                options.elementAt(index);
                                            return ListTile(
                                              dense:
                                                  true, // Make tiles more compact
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 4,
                                              ),
                                              title: Text(
                                                option,
                                                style: AppFonts.sfProStyle(
                                                  fontSize: 16,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              onTap: () {
                                                onSelected(option);
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 16),
                          Builder(builder: (context) {
                            final bool disabled = _isSaving ||
                                (_isEditing
                                    ? !_hasUnsavedChanges()
                                    : addedSupplies.isNotEmpty
                                        ? false
                                        : true);
                            return ElevatedButton(
                              onPressed: disabled ? null : _savePurchaseOrder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: disabled
                                    ? Colors.grey[400]
                                    : Color(0xFF00D4AA),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                _isSaving
                                    ? (_isEditing ? 'Updating...' : 'Saving...')
                                    : (_isEditing ? 'Update' : 'Save'),
                                style: AppFonts.sfProStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    }
                  },
                ),
              ),
              SizedBox(height: 16),

              // Supplies List Section
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFE8D5E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: addedSupplies.isEmpty
                      ? _buildEmptyState()
                      : _buildSuppliesList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final existingIds = addedSupplies
              .map((s) => s['supplyId']?.toString())
              .whereType<String>()
              .toList();
          final result = await Navigator.pushNamed(
            context,
            '/add-supply',
            arguments: {
              'existingIds': existingIds,
            },
          );
          if (result != null) {
            final newSupply = result as Map<String, dynamic>;
            final bool alreadyExists = addedSupplies.any(
              (s) =>
                  s['supplyId']?.toString() ==
                  newSupply['supplyId']?.toString(),
            );

            if (alreadyExists) {
              // Show duplicate dialog
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(
                      'Already in Restocking List',
                      style: AppFonts.sfProStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Text(
                      '"${newSupply['supplyName'] ?? 'This supply'}" is already added. Duplicate items are not allowed.',
                      style: AppFonts.sfProStyle(fontSize: 16),
                    ),
                    actions: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4AA),
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
            } else {
              setState(() {
                addedSupplies.add(newSupply);
              });
            }
          }
        },
        backgroundColor: Color(0xFF00D4AA),
        child: Icon(Icons.add, color: Colors.white, size: 28),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.shopping_basket_outlined,
              size: 60,
              color: Color(0xFF8B5A8B),
            ),
          ),
          SizedBox(height: 24),
          Text(
            "No Supplies Added Yet",
            style: AppFonts.sfProStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B5A8B),
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Tap the + button to add supplies",
            style: AppFonts.sfProStyle(
              fontSize: 14,
              color: Color(0xFF8B5A8B).withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuppliesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Restocking List (${addedSupplies.length})",
                style: AppFonts.sfProStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B5A8B),
                ),
              ),
              // Clear All Button
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    addedSupplies.clear();
                  });
                },
                icon: Icon(Icons.clear_all, color: Colors.red, size: 20),
                label: Text(
                  'Clear All',
                  style: AppFonts.sfProStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Total Cost Section - Moved to top for better visibility
        if (addedSupplies.isNotEmpty) ...[
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF8B5A8B).withOpacity(0.1),
                  Color(0xFF8B5A8B).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Color(0xFF8B5A8B).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Cost:',
                  style: AppFonts.sfProStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B5A8B),
                  ),
                ),
                Text(
                  '₱${_calculateTotalCost().toStringAsFixed(2)}',
                  style: AppFonts.sfProStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B5A8B),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              // Build a flattened view for display if expiryBatches exist
              final List<Map<String, dynamic>> displaySupplies = [];
              final List<int> baseIndexes = [];
              final List<int?> batchIndexes = [];
              for (int i = 0; i < addedSupplies.length; i++) {
                final s = addedSupplies[i];
                final batches = s['expiryBatches'] as List<dynamic>?;
                if (batches != null && batches.isNotEmpty) {
                  for (int bi = 0; bi < batches.length; bi++) {
                    final b = batches[bi];
                    final disp = Map<String, dynamic>.from(s);
                    disp['quantity'] = b['quantity'];
                    disp['expiryDate'] = b['expiryDate'];
                    displaySupplies.add(disp);
                    baseIndexes.add(i);
                    batchIndexes.add(bi);
                  }
                } else {
                  displaySupplies.add(s);
                  baseIndexes.add(i);
                  batchIndexes.add(null);
                }
              }

              if (index >= displaySupplies.length) {
                return const SizedBox.shrink();
              }
              final displaySupply = displaySupplies[index];
              final baseIndex = baseIndexes[index];
              final int? batchIndex = batchIndexes[index];
              return _buildSupplyCard(displaySupply, baseIndex, batchIndex);
            },
            itemCount: (() {
              int count = 0;
              for (final s in addedSupplies) {
                final batches = s['expiryBatches'] as List<dynamic>?;
                count += (batches != null && batches.isNotEmpty)
                    ? batches.length
                    : 1;
              }
              return count;
            })(),
          ),
        ),
      ],
    );
  }

  Widget _buildSupplyCard(
      Map<String, dynamic> supply, int baseIndex, int? batchIndex) {
    return Slidable(
      key: Key('slidable-$baseIndex-${batchIndex ?? 'base'}'),
      closeOnScroll: true,
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.35, // compact reveal, entire tile slides
        children: [
          SlidableAction(
            onPressed: (_) => _editSupply(supply, baseIndex),
            backgroundColor: const Color(0xFF00D4AA),
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.35,
        children: [
          SlidableAction(
            onPressed: (_) async {
              final confirmed =
                  await _showDeleteConfirmation(baseIndex, batchIndex);
              if (confirmed) {
                // state already updated in dialog
              }
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.only(bottom: 10),
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              // Supply Image (responsive)
              Container(
                width: MediaQuery.of(context).size.width * 0.13,
                height: MediaQuery.of(context).size.width * 0.13,
                constraints: BoxConstraints(
                  minWidth: 52,
                  maxWidth: 72,
                  minHeight: 52,
                  maxHeight: 72,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: supply['imageUrl'] != null &&
                          supply['imageUrl'].isNotEmpty
                      ? Image.network(
                          supply['imageUrl'],
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.image_not_supported,
                                size: MediaQuery.of(context).size.width * 0.08,
                                color: Colors.grey);
                          },
                        )
                      : Icon(Icons.image_not_supported,
                          size: MediaQuery.of(context).size.width * 0.08,
                          color: Colors.grey),
                ),
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.035),

              // Supply Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supply['supplyName'] ?? 'Unknown Supply',
                      style: AppFonts.sfProStyle(
                        fontSize: MediaQuery.of(context).size.width * 0.04,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Brand:',
                          style: AppFonts.sfProStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            (supply['brandName'] ?? 'N/A').toString(),
                            style: AppFonts.sfProStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Supplier:',
                          style: AppFonts.sfProStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            (supply['supplierName'] ?? 'N/A').toString(),
                            style: AppFonts.sfProStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFF00D4AA).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Color(0xFF00D4AA).withOpacity(0.35),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF00D4AA).withOpacity(0.08),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2,
                                  size: 12, color: Color(0xFF00D4AA)),
                              SizedBox(width: 3),
                              Text(
                                'Qty: ${supply['quantity'] ?? 0}',
                                style: AppFonts.sfProStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF00D4AA),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 4),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.35),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.08),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '₱${((supply['quantity'] ?? 0) * (supply['cost'] ?? 0.0)).toStringAsFixed(2)}',
                            style: AppFonts.sfProStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                        SizedBox(width: 4),
                        if ((supply['expiryDate'] ?? '').toString().isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.35),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event, size: 12, color: Colors.blue),
                                SizedBox(width: 3),
                                Text(
                                  (supply['expiryDate'] as String),
                                  style: AppFonts.sfProStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Empty space for swipe gestures
              SizedBox(width: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePurchaseOrder() async {
    if (_isSaving) return; // Prevent double-save

    // Use the autocomplete controller if available, otherwise fall back to purchaseNameController
    final controllerToCheck = _autocompleteController ?? purchaseNameController;

    if (controllerToCheck.text.trim().isEmpty) {
      _showErrorDialog('Please enter a purchase order name.');
      return;
    }

    if (addedSupplies.isEmpty) {
      _showErrorDialog(
          'Please add at least one supply to the restocking list.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    if (_isEditing && _editingPO != null) {
      // Update existing PO
      final recalculatedReceived = addedSupplies
          .where((s) => (s['status'] ?? 'Pending') == 'Received')
          .length;
      final updatedPO = PurchaseOrder(
        id: _editingPO!.id,
        code: _editingPO!.code,
        name: controllerToCheck.text.trim(),
        createdAt: _editingPO!.createdAt, // Keep original creation date
        status: _editingPO!.status, // Keep original status
        supplies: List<Map<String, dynamic>>.from(addedSupplies),
        receivedCount: recalculatedReceived, // Recalculate received count
      );
      await _controller.updatePO(updatedPO, previousPO: _editingPO);
    } else {
      // Create new PO
      final now = DateTime.now();
      final code = await _controller.getNextCodeAndIncrement();
      final po = PurchaseOrder(
        id: '${now.millisecondsSinceEpoch}',
        code: code,
        name: controllerToCheck.text.trim(),
        createdAt: now,
        status: 'Open',
        supplies: List<Map<String, dynamic>>.from(addedSupplies),
        receivedCount: 0,
      );
      await _controller.savePO(po);
    }

    // Add PO name to suggestions for future use
    await _controller.addSuggestion(controllerToCheck.text.trim());

    setState(() {
      _isSaving = false;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? 'Purchase Order updated successfully!'
              : 'Purchase Order saved successfully!',
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

    // Navigate back to Purchase Order page and signal success
    Navigator.of(context).pop(true);
  }

  void _editSupply(Map<String, dynamic> supply, int index) async {
    // Navigate to edit supply page
    final result = await Navigator.pushNamed(
      context,
      '/edit-supply-po',
      arguments: supply,
    );

    if (result != null) {
      setState(() {
        addedSupplies[index] = result as Map<String, dynamic>;
      });
    }
  }

  Future<bool> _showDeleteConfirmation(int baseIndex, int? batchIndex) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                'Delete Supply?',
                style: AppFonts.sfProStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                batchIndex == null
                    ? 'Are you sure you want to remove this supply from the restocking list?'
                    : 'Are you sure you want to remove this batch from the supply?',
                style: AppFonts.sfProStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text(
                    'Cancel',
                    style: AppFonts.sfProStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      if (batchIndex == null) {
                        // Remove entire item
                        addedSupplies.removeAt(baseIndex);
                      } else {
                        // Remove only the specific batch and update quantity
                        final supply = addedSupplies[baseIndex];
                        final List<dynamic> batches =
                            List<dynamic>.from(supply['expiryBatches'] ?? []);
                        if (batchIndex >= 0 && batchIndex < batches.length) {
                          final removed = batches.removeAt(batchIndex);
                          final int removedQty =
                              int.tryParse('${removed['quantity'] ?? 0}') ?? 0;
                          final int currentQty = (supply['quantity'] ?? 0)
                                  is int
                              ? supply['quantity'] as int
                              : int.tryParse('${supply['quantity'] ?? 0}') ?? 0;
                          final int newQty = currentQty - removedQty;
                          if (batches.isEmpty) {
                            if (newQty <= 0) {
                              // No batches left and no quantity – remove supply entirely
                              addedSupplies.removeAt(baseIndex);
                            } else {
                              // Keep supply without batches
                              supply['expiryBatches'] = [];
                              supply['expiryDate'] = null;
                              supply['quantity'] = newQty;
                              addedSupplies[baseIndex] = supply;
                            }
                          } else {
                            // Keep remaining batches and update aggregate quantity
                            supply['expiryBatches'] = batches;
                            supply['quantity'] = newQty < 0 ? 0 : newQty;
                            addedSupplies[baseIndex] = supply;
                          }
                        }
                      }
                    });
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: Text(
                    'Delete',
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
        ) ??
        false;
  }

  void _handleBackPress() {
    // If there are supplies in the list, show confirmation dialog
    if (addedSupplies.isNotEmpty ||
        purchaseNameController.text.trim().isNotEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              _isEditing ? 'Cancel Editing?' : 'Cancel Purchase Order?',
              style: AppFonts.sfProStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              _isEditing
                  ? 'You have unsaved changes. Are you sure you want to cancel editing this purchase order?'
                  : 'You have unsaved changes. Are you sure you want to cancel this purchase order?',
              style: AppFonts.sfProStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                },
                child: Text(
                  'Continue Editing',
                  style: AppFonts.sfProStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back to previous page
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: Text(
                  _isEditing ? 'Cancel Edit' : 'Cancel PO',
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
    } else {
      // No changes, go back directly
      Navigator.of(context).pop();
    }
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
