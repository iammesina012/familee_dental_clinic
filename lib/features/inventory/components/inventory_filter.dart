import 'package:flutter/material.dart';
import 'package:familee_dental/features/inventory/controller/filter_controller.dart';
import 'package:familee_dental/features/inventory/pages/manage_brands_suppliers_page.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:familee_dental/shared/services/connectivity_service.dart';
import 'package:familee_dental/shared/widgets/connection_error_dialog.dart';

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

  // Incremental display counts for brands/suppliers chips
  int _brandsVisibleCount = 5;
  int _suppliersVisibleCount = 5;

  // Controller for dynamic data
  final FilterController filterController = FilterController();

  // Static data lists
  final stockStatuses = ["In Stock", "Low Stock", "Out of Stock"];
  final expiryOptions = ["Expiring", "No Expiry"];
  final units = ['Box', 'Pieces', 'Pack'];

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
                        // Check connectivity FIRST before any network operations
                        final hasConnection =
                            await ConnectivityService().hasInternetConnection();
                        if (!hasConnection) {
                          if (context.mounted) {
                            await showConnectionErrorDialog(context);
                          }
                          return;
                        }

                        try {
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
                            try {
                              await filterController.updateBrandName(
                                  oldName, controller.text.trim());
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              // Check if it's a network error
                              final errorString = e.toString().toLowerCase();
                              if (errorString.contains('socketexception') ||
                                  errorString.contains('failed host lookup') ||
                                  errorString
                                      .contains('no address associated') ||
                                  errorString
                                      .contains('network is unreachable') ||
                                  errorString.contains('connection refused') ||
                                  errorString
                                      .contains('connection timed out') ||
                                  errorString.contains('clientexception')) {
                                if (context.mounted) {
                                  await showConnectionErrorDialog(context);
                                }
                              } else {
                                // Other error - show generic error message
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Failed to update brand: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          }
                        } catch (e) {
                          // Handle errors from brandExists check
                          final errorString = e.toString().toLowerCase();
                          if (errorString.contains('socketexception') ||
                              errorString.contains('failed host lookup') ||
                              errorString.contains('no address associated') ||
                              errorString.contains('network is unreachable') ||
                              errorString.contains('connection refused') ||
                              errorString.contains('connection timed out') ||
                              errorString.contains('clientexception')) {
                            if (context.mounted) {
                              await showConnectionErrorDialog(context);
                            }
                          } else {
                            // Other error - show generic error message
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
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
                        // Check connectivity FIRST before any network operations
                        final hasConnection =
                            await ConnectivityService().hasInternetConnection();
                        if (!hasConnection) {
                          if (context.mounted) {
                            await showConnectionErrorDialog(context);
                          }
                          return;
                        }

                        try {
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
                            try {
                              await filterController.updateSupplierName(
                                  oldName, controller.text.trim());
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              // Check if it's a network error
                              final errorString = e.toString().toLowerCase();
                              if (errorString.contains('socketexception') ||
                                  errorString.contains('failed host lookup') ||
                                  errorString
                                      .contains('no address associated') ||
                                  errorString
                                      .contains('network is unreachable') ||
                                  errorString.contains('connection refused') ||
                                  errorString
                                      .contains('connection timed out') ||
                                  errorString.contains('clientexception')) {
                                if (context.mounted) {
                                  await showConnectionErrorDialog(context);
                                }
                              } else {
                                // Other error - show generic error message
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Failed to update supplier: ${e.toString()}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          }
                        } catch (e) {
                          // Handle errors from supplierExists check
                          final errorString = e.toString().toLowerCase();
                          if (errorString.contains('socketexception') ||
                              errorString.contains('failed host lookup') ||
                              errorString.contains('no address associated') ||
                              errorString.contains('network is unreachable') ||
                              errorString.contains('connection refused') ||
                              errorString.contains('connection timed out') ||
                              errorString.contains('clientexception')) {
                            if (context.mounted) {
                              await showConnectionErrorDialog(context);
                            }
                          } else {
                            // Other error - show generic error message
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
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
              // Check connectivity before proceeding
              final hasConnection =
                  await ConnectivityService().hasInternetConnection();
              if (!hasConnection) {
                if (context.mounted) {
                  await showConnectionErrorDialog(context);
                }
                return;
              }

              try {
                await filterController.deleteBrand(brandName);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              } catch (e) {
                // Check if it's a network error
                final errorString = e.toString().toLowerCase();
                if (errorString.contains('socketexception') ||
                    errorString.contains('failed host lookup') ||
                    errorString.contains('no address associated') ||
                    errorString.contains('network is unreachable') ||
                    errorString.contains('connection refused') ||
                    errorString.contains('connection timed out') ||
                    errorString.contains('clientexception')) {
                  if (context.mounted) {
                    await showConnectionErrorDialog(context);
                  }
                } else {
                  // Other error - show generic error message
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Failed to delete brand: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
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
              // Check connectivity before proceeding
              final hasConnection =
                  await ConnectivityService().hasInternetConnection();
              if (!hasConnection) {
                if (context.mounted) {
                  await showConnectionErrorDialog(context);
                }
                return;
              }

              try {
                await filterController.deleteSupplier(supplierName);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              } catch (e) {
                // Check if it's a network error
                final errorString = e.toString().toLowerCase();
                if (errorString.contains('socketexception') ||
                    errorString.contains('failed host lookup') ||
                    errorString.contains('no address associated') ||
                    errorString.contains('network is unreachable') ||
                    errorString.contains('connection refused') ||
                    errorString.contains('connection timed out') ||
                    errorString.contains('clientexception')) {
                  if (context.mounted) {
                    await showConnectionErrorDialog(context);
                  }
                } else {
                  // Other error - show generic error message
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Failed to delete supplier: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
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
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return Material(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Search Filter",
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    // Only show edit icon for Admin and Owner roles
                    ListenableBuilder(
                      listenable: UserRoleProvider(),
                      builder: (context, child) {
                        final userRoleProvider = UserRoleProvider();
                        if (!userRoleProvider.isStaff) {
                          return IconButton(
                            icon:
                                Icon(Icons.edit, size: 24, color: Colors.green),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ManageBrandsSuppliersPage(),
                                ),
                              );
                            },
                            tooltip: 'Manage Brands & Suppliers',
                          );
                        }
                        return SizedBox.shrink(); // Hide for staff
                      },
                    ),
                  ],
                ),
                Divider(height: 28, color: theme.dividerColor),
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
                            // Show skeleton loader only if no data exists (no cached data available)
                            // If cached data exists, it will show immediately instead
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData &&
                                !snapshot.hasError) {
                              final isDark = Theme.of(context).brightness ==
                                  Brightness.dark;
                              final baseColor = isDark
                                  ? Colors.grey[800]!
                                  : Colors.grey[300]!;
                              final highlightColor = isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[100]!;

                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(
                                  4,
                                  (_) => Shimmer.fromColors(
                                    baseColor: baseColor,
                                    highlightColor: highlightColor,
                                    child: Container(
                                      width: 100,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                            final allBrands = (snapshot.data ?? []).toList();
                            final visible = allBrands
                                .take(_brandsVisibleCount.clamp(
                                    0, allBrands.length))
                                .toList();
                            final canViewMore =
                                _brandsVisibleCount < allBrands.length;
                            final canViewLess = _brandsVisibleCount > 5;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _filterChips(
                                  visible,
                                  selectedBrands,
                                  showViewMore: false,
                                ),
                                if (canViewMore) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _brandsVisibleCount =
                                            (_brandsVisibleCount + 5)
                                                .clamp(0, allBrands.length);
                                      });
                                    },
                                    child: const Text(
                                      'View More',
                                      style: TextStyle(
                                        color: Color(0xFF4E38D4),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                                if (!canViewMore && canViewLess) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _brandsVisibleCount = 5;
                                      });
                                    },
                                    child: const Text(
                                      'View Less',
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
                          },
                        ),
                        _sectionTitle("Supplier Name"),
                        StreamBuilder<List<String>>(
                          stream: filterController.getSupplierNamesStream(),
                          builder: (context, snapshot) {
                            // Show skeleton loader only if no data exists (no cached data available)
                            // If cached data exists, it will show immediately instead
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData &&
                                !snapshot.hasError) {
                              final isDark = Theme.of(context).brightness ==
                                  Brightness.dark;
                              final baseColor = isDark
                                  ? Colors.grey[800]!
                                  : Colors.grey[300]!;
                              final highlightColor = isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[100]!;

                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(
                                  4,
                                  (_) => Shimmer.fromColors(
                                    baseColor: baseColor,
                                    highlightColor: highlightColor,
                                    child: Container(
                                      width: 100,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }
                            final allSuppliers = (snapshot.data ?? []).toList();
                            final visible = allSuppliers
                                .take(_suppliersVisibleCount.clamp(
                                    0, allSuppliers.length))
                                .toList();
                            final canViewMore =
                                _suppliersVisibleCount < allSuppliers.length;
                            final canViewLess = _suppliersVisibleCount > 5;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _filterChips(
                                  visible,
                                  selectedSuppliers,
                                  showViewMore: false,
                                ),
                                if (canViewMore) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _suppliersVisibleCount =
                                            (_suppliersVisibleCount + 5)
                                                .clamp(0, allSuppliers.length);
                                      });
                                    },
                                    child: const Text(
                                      'View More',
                                      style: TextStyle(
                                        color: Color(0xFF4E38D4),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                                if (!canViewMore && canViewLess) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _suppliersVisibleCount = 5;
                                      });
                                    },
                                    child: const Text(
                                      'View Less',
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
                                  filled: true,
                                  fillColor: scheme.surface,
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
                                  filled: true,
                                  fillColor: scheme.surface,
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
      child: Builder(builder: (context) {
        final theme = Theme.of(context);
        return Text(
          text,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
        );
      }),
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

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
              selectedColor: theme.brightness == Brightness.dark
                  ? Color(0xFF3D356E)
                  : Color(0xFFE2DCFD),
              backgroundColor: theme.brightness == Brightness.dark
                  ? scheme.surface
                  : Colors.grey.shade200,
              labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
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
