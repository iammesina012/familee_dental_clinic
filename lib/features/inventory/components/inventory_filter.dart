import 'package:flutter/material.dart';
import '../controller/filter_controller.dart';
import '../pages/manage_brands_suppliers_page.dart';

class InventoryFilterModal extends StatefulWidget {
  final void Function(Map<String, dynamic> filters)? onApply;
  final Map<String, dynamic>? currentFilters;
  const InventoryFilterModal({super.key, this.onApply, this.currentFilters});

  @override
  State<InventoryFilterModal> createState() => _InventoryFilterModalState();
}

class _InventoryFilterModalState extends State<InventoryFilterModal> {
  // Filter state variables
  final Set<String> selectedBrands = {};
  final Set<String> selectedSuppliers = {};
  final Set<String> selectedStockStatus = {};
  final Set<String> selectedExpiry = {};
  String? selectedUnit;
  String? minCost, maxCost;

  // View more state variables
  bool showAllBrands = false;
  bool showAllSuppliers = false;

  // Controller for dynamic data
  final FilterController filterController = FilterController();

  // Static data lists
  final stockStatuses = ["In Stock", "Low Stock", "Out of Stock"];
  final expiryOptions = ["Expiring", "Expired Items", "No Expiry"];
  final units = ['Box', 'Piece', 'Pack'];

  @override
  void initState() {
    super.initState();
    // Initialize with current filters if provided
    if (widget.currentFilters != null) {
      _loadCurrentFilters();
    }
  }

  void _loadCurrentFilters() {
    final filters = widget.currentFilters!;

    // Load brands
    if (filters['brands'] != null) {
      selectedBrands.addAll((filters['brands'] as List).cast<String>());
    }

    // Load suppliers
    if (filters['suppliers'] != null) {
      selectedSuppliers.addAll((filters['suppliers'] as List).cast<String>());
    }

    // Load stock status
    if (filters['stockStatus'] != null) {
      selectedStockStatus
          .addAll((filters['stockStatus'] as List).cast<String>());
    }

    // Load expiry
    if (filters['expiry'] != null) {
      selectedExpiry.addAll((filters['expiry'] as List).cast<String>());
    }

    // Load unit
    if (filters['unit'] != null) {
      selectedUnit = filters['unit'] as String?;
    }

    // Load cost range
    if (filters['minCost'] != null) {
      minCost = filters['minCost'].toString();
    }
    if (filters['maxCost'] != null) {
      maxCost = filters['maxCost'].toString();
    }
  }

  void _resetFilters() {
    setState(() {
      selectedBrands.clear();
      selectedSuppliers.clear();
      selectedStockStatus.clear();
      selectedExpiry.clear();
      selectedUnit = null;
      minCost = null;
      maxCost = null;
    });
    // Clear parent filters and close modal
    if (widget.onApply != null) {
      widget.onApply!({});
    }
    Navigator.pop(context);
  }

  void _applyFilters() {
    // Collect selected filters into a map
    final filters = {
      "brands": selectedBrands.toList(),
      "suppliers": selectedSuppliers.toList(),
      "stockStatus": selectedStockStatus.toList(),
      "expiry": selectedExpiry.toList(),
      "unit": selectedUnit,
      "minCost": minCost,
      "maxCost": maxCost,
    };
    if (widget.onApply != null) widget.onApply!(filters);
    Navigator.pop(context);
  }

  void _showAddBrandDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.add_business, color: Colors.green[600], size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Add Brand',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              // Input Field
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Brand Name',
                  hintText: 'Enter brand name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[600]!, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                autofocus: true,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 32),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.normal,
                        inherit: false,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (controller.text.trim().isNotEmpty) {
                        final success = await filterController
                            .addBrandIfNotExists(controller.text.trim());
                        if (success) {
                          Navigator.pop(context);
                        } else {
                          // Close dialog first, then show error message
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Brand "${controller.text.trim()}" already exists!'),
                              backgroundColor: Colors.red[600],
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Add Brand',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.normal,
                        inherit: false,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSupplierDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.local_shipping, color: Colors.blue[600], size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Add Supplier',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              // Input Field
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Supplier Name',
                  hintText: 'Enter supplier name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                autofocus: true,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 32),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.normal,
                        inherit: false,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (controller.text.trim().isNotEmpty) {
                        final success = await filterController
                            .addSupplierIfNotExists(controller.text.trim());
                        if (success) {
                          Navigator.pop(context);
                        } else {
                          // Close dialog first, then show error message
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Supplier "${controller.text.trim()}" already exists!'),
                              backgroundColor: Colors.red[600],
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Add Supplier',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.normal,
                        inherit: false,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditBrandDialog(String oldName) {
    final TextEditingController controller =
        TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue[600], size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Edit Brand',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              // Input Field
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Brand Name',
                  hintText: 'Enter new brand name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                autofocus: true,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 32),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.normal,
                        inherit: false,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (controller.text.trim().isNotEmpty &&
                          controller.text.trim() != oldName) {
                        // Check if the new name already exists
                        final exists = await filterController
                            .brandExists(controller.text.trim());
                        if (exists) {
                          // Close dialog first, then show error message
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Brand "${controller.text.trim()}" already exists!'),
                              backgroundColor: Colors.red[600],
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } else {
                          await filterController.updateBrandName(
                              oldName, controller.text.trim());
                          Navigator.pop(context);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Update Brand',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.normal,
                        inherit: false,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSupplierDialog(String oldName) {
    final TextEditingController controller =
        TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue[600], size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Edit Supplier',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              // Input Field
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Supplier Name',
                  hintText: 'Enter new supplier name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                autofocus: true,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 32),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.normal,
                        inherit: false,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (controller.text.trim().isNotEmpty &&
                          controller.text.trim() != oldName) {
                        // Check if the new name already exists
                        final exists = await filterController
                            .supplierExists(controller.text.trim());
                        if (exists) {
                          // Close dialog first, then show error message
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Supplier "${controller.text.trim()}" already exists!'),
                              backgroundColor: Colors.red[600],
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } else {
                          await filterController.updateSupplierName(
                              oldName, controller.text.trim());
                          Navigator.pop(context);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Update Supplier',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.normal,
                        inherit: false,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteBrandDialog(String brandName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Brand'),
        content: Text(
            'Are you sure you want to delete "$brandName"? This will update all supplies with this brand to "N/A".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.red[600],
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.normal,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await filterController.deleteBrand(brandName);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteSupplierDialog(String supplierName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Supplier'),
        content: Text(
            'Are you sure you want to delete "$supplierName"? This will update all supplies with this supplier to "N/A".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.red[600],
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.normal,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await filterController.deleteSupplier(supplierName);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, scrollController) {
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Search Filter",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: Icon(Icons.edit, size: 24, color: Colors.green),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ManageBrandsSuppliersPage(),
                          ),
                        );
                      },
                      tooltip: 'Manage Brands & Suppliers',
                    ),
                  ],
                ),
                Divider(height: 28),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle("Brand Name"),
                        StreamBuilder<List<String>>(
                          stream: filterController.getBrandNamesStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }
                            final brands = snapshot.data ?? [];
                            return _filterChips(
                              brands,
                              selectedBrands,
                              showViewMore: true,
                              isExpanded: showAllBrands,
                              onToggleViewMore: () {
                                setState(() {
                                  showAllBrands = !showAllBrands;
                                });
                              },
                            );
                          },
                        ),
                        _sectionTitle("Supplier Name"),
                        StreamBuilder<List<String>>(
                          stream: filterController.getSupplierNamesStream(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }
                            final suppliers = snapshot.data ?? [];
                            return _filterChips(
                              suppliers,
                              selectedSuppliers,
                              showViewMore: true,
                              isExpanded: showAllSuppliers,
                              onToggleViewMore: () {
                                setState(() {
                                  showAllSuppliers = !showAllSuppliers;
                                });
                              },
                            );
                          },
                        ),
                        _sectionTitle("Stock Status"),
                        _filterChips(stockStatuses, selectedStockStatus,
                            showViewMore: false),
                        _sectionTitle("Expiry Date"),
                        _filterChips(expiryOptions, selectedExpiry,
                            showViewMore: false),
                        _sectionTitle("Cost Range (₱)"),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: "MIN",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => minCost = val,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: "MAX",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (val) => maxCost = val,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: selectedUnit,
                          decoration: InputDecoration(
                            labelText: "Inventory Unit",
                            border: OutlineInputBorder(),
                          ),
                          items: units
                              .map((unit) => DropdownMenuItem(
                                    value: unit,
                                    child: Text(unit,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w500)),
                                  ))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => selectedUnit = val),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                // Apply and Reset buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton(
                      onPressed: _resetFilters,
                      child: Text("Reset",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      onPressed: _applyFilters,
                      child: Text("Apply",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                        backgroundColor: Color(0xFF4E38D4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  Widget _filterChips(List<String> options, Set<String> selectedSet,
      {bool showViewMore = false,
      bool isExpanded = false,
      VoidCallback? onToggleViewMore}) {
    // Determine which options to show
    List<String> displayOptions = options;
    bool shouldShowViewMore = showViewMore && options.length > 4;

    if (shouldShowViewMore && !isExpanded) {
      displayOptions = options.take(4).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: displayOptions.map((option) {
            final selected = selectedSet.contains(option);
            return FilterChip(
              label:
                  Text(option, style: TextStyle(fontWeight: FontWeight.w500)),
              selected: selected,
              onSelected: (val) {
                setState(() {
                  if (selected) {
                    selectedSet.remove(option);
                  } else {
                    selectedSet.add(option);
                  }
                });
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              selectedColor: Color(0xFFE2DCFD),
              backgroundColor: Colors.grey.shade200,
              labelStyle: TextStyle(color: Colors.black),
            );
          }).toList(),
        ),
        // View More/Less button
        if (shouldShowViewMore) ...[
          SizedBox(height: 8),
          TextButton(
            onPressed: onToggleViewMore,
            child: Text(
              isExpanded ? 'View Less' : 'View More',
              style: TextStyle(
                color: Color(0xFF4E38D4),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
