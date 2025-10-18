import 'package:flutter/material.dart';
import 'package:familee_dental/features/inventory/controller/filter_controller.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:shimmer/shimmer.dart';

class ManageBrandsSuppliersPage extends StatefulWidget {
  const ManageBrandsSuppliersPage({super.key});

  @override
  State<ManageBrandsSuppliersPage> createState() =>
      _ManageBrandsSuppliersPageState();
}

class _ManageBrandsSuppliersPageState extends State<ManageBrandsSuppliersPage> {
  final FilterController filterController = FilterController();

  // View more state variables
  bool showAllBrands = false;
  bool showAllSuppliers = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Manage Brands & Suppliers",
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: theme.appBarTheme.elevation,
        shadowColor: theme.appBarTheme.shadowColor,
      ),
      body: ResponsiveContainer(
        maxWidth: 1000,
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            // Wait for the brands stream to emit at least one event
            // This ensures the RefreshIndicator shows its animation
            await filterController.getBrandsStream().first;
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brands Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.business,
                              color: Colors.green[600], size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Brands',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      StreamBuilder<List<Brand>>(
                        stream: filterController.getBrandsStream(),
                        builder: (context, snapshot) {
                          // Handle errors
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error loading brands',
                                style: AppFonts.sfProStyle(
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                              ),
                            );
                          }

                          // Show skeleton loader on first load only
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final baseColor =
                                isDark ? Colors.grey[800]! : Colors.grey[300]!;
                            final highlightColor =
                                isDark ? Colors.grey[700]! : Colors.grey[100]!;

                            return Column(
                              children: List.generate(
                                3,
                                (index) => Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Shimmer.fromColors(
                                    baseColor: baseColor,
                                    highlightColor: highlightColor,
                                    child: Container(
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          final brands = snapshot.data ?? [];
                          final validBrands =
                              brands.where((b) => b.name != "N/A").toList();

                          if (validBrands.isEmpty) {
                            return Container(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'No brands available',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            );
                          }

                          // Determine which brands to show
                          List<Brand> displayBrands = validBrands;
                          bool shouldShowViewMore = validBrands.length > 4;

                          if (shouldShowViewMore && !showAllBrands) {
                            displayBrands = validBrands.take(4).toList();
                          }

                          return Column(
                            children: [
                              ...displayBrands
                                  .map((brand) => Container(
                                        margin: EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: theme.dividerColor
                                                  .withOpacity(0.2)),
                                        ),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 8),
                                          title: Text(
                                            brand.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[50],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: IconButton(
                                                  icon: Icon(Icons.edit,
                                                      size: 20,
                                                      color: Colors.blue[600]),
                                                  onPressed: () =>
                                                      _showEditBrandDialog(
                                                          brand.name),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.red[50],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: IconButton(
                                                  icon: Icon(Icons.delete,
                                                      size: 20,
                                                      color: Colors.red[600]),
                                                  onPressed: () =>
                                                      _showDeleteBrandDialog(
                                                          brand.name),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ))
                                  .toList(),
                              // View More/Less button
                              if (shouldShowViewMore) ...[
                                SizedBox(height: 12),
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        showAllBrands = !showAllBrands;
                                      });
                                    },
                                    child: Text(
                                      showAllBrands ? 'View Less' : 'View More',
                                      style: TextStyle(
                                        color: Color(0xFF4E38D4),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                // Suppliers Section
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_shipping,
                              color: Colors.blue[600], size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Suppliers',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      StreamBuilder<List<Supplier>>(
                        stream: filterController.getSuppliersStream(),
                        builder: (context, snapshot) {
                          // Handle errors
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error loading suppliers',
                                style: AppFonts.sfProStyle(
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                              ),
                            );
                          }

                          // Show skeleton loader on first load only
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final baseColor =
                                isDark ? Colors.grey[800]! : Colors.grey[300]!;
                            final highlightColor =
                                isDark ? Colors.grey[700]! : Colors.grey[100]!;

                            return Column(
                              children: List.generate(
                                3,
                                (index) => Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Shimmer.fromColors(
                                    baseColor: baseColor,
                                    highlightColor: highlightColor,
                                    child: Container(
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          final suppliers = snapshot.data ?? [];
                          final validSuppliers =
                              suppliers.where((s) => s.name != "N/A").toList();

                          if (validSuppliers.isEmpty) {
                            return Container(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'No suppliers available',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            );
                          }

                          // Determine which suppliers to show
                          List<Supplier> displaySuppliers = validSuppliers;
                          bool shouldShowViewMore = validSuppliers.length > 4;

                          if (shouldShowViewMore && !showAllSuppliers) {
                            displaySuppliers = validSuppliers.take(4).toList();
                          }

                          return Column(
                            children: [
                              ...displaySuppliers
                                  .map((supplier) => Container(
                                        margin: EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: theme.dividerColor
                                                  .withOpacity(0.2)),
                                        ),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 8),
                                          title: Text(
                                            supplier.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.blue[50],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: IconButton(
                                                  icon: Icon(Icons.edit,
                                                      size: 20,
                                                      color: Colors.blue[600]),
                                                  onPressed: () =>
                                                      _showEditSupplierDialog(
                                                          supplier.name),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.red[50],
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: IconButton(
                                                  icon: Icon(Icons.delete,
                                                      size: 20,
                                                      color: Colors.red[600]),
                                                  onPressed: () =>
                                                      _showDeleteSupplierDialog(
                                                          supplier.name),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ))
                                  .toList(),
                              // View More/Less button
                              if (shouldShowViewMore) ...[
                                SizedBox(height: 12),
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        showAllSuppliers = !showAllSuppliers;
                                      });
                                    },
                                    child: Text(
                                      showAllSuppliers
                                          ? 'View Less'
                                          : 'View More',
                                      style: TextStyle(
                                        color: Color(0xFF4E38D4),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditBrandDialog(String oldName) {
    final TextEditingController controller =
        TextEditingController(text: oldName);
    showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: theme.dialogBackgroundColor,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width < 768 ? 400 : 500,
            ),
            child: Container(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue[600], size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Edit Brand',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Brand Name',
                      labelStyle: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      hintText: 'Enter new brand name',
                      hintStyle: TextStyle(
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.blue[600]!, width: 2),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  SizedBox(height: 32),
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
                            final exists = await filterController
                                .brandExists(controller.text.trim());
                            if (exists) {
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
                              Navigator.pop(context,
                                  true); // Return true to indicate update was made
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
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
      },
    ).then((updated) {
      // Force rebuild if brand was updated
      if (updated == true && mounted) {
        setState(() {});
      }
    });
  }

  void _showEditSupplierDialog(String oldName) {
    final TextEditingController controller =
        TextEditingController(text: oldName);
    showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: theme.dialogBackgroundColor,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width < 768 ? 400 : 500,
            ),
            child: Container(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue[600], size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Edit Supplier',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Supplier Name',
                      labelStyle: TextStyle(
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                      hintText: 'Enter new supplier name',
                      hintStyle: TextStyle(
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.blue[600]!, width: 2),
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  SizedBox(height: 32),
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
                            final exists = await filterController
                                .supplierExists(controller.text.trim());
                            if (exists) {
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
                              Navigator.pop(context,
                                  true); // Return true to indicate update was made
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
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
      },
    ).then((updated) {
      // Force rebuild if supplier was updated
      if (updated == true && mounted) {
        setState(() {});
      }
    });
  }

  void _showDeleteBrandDialog(String brandName) {
    showDialog(
      context: context,
      builder: (context) => _buildCustomDialog(
        context,
        title: 'Delete Brand',
        content:
            'Are you sure you want to delete "$brandName"? This will update all supplies with this brand to "N/A".',
        confirmText: 'Delete',
        confirmColor: Colors.red[600]!,
        icon: Icons.delete_forever,
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await filterController.deleteBrand(brandName);
          // Force rebuild to show updated list immediately
          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Brand "$brandName" deleted successfully'),
                backgroundColor: Colors.green[600],
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting brand: $e'),
                backgroundColor: Colors.red[600],
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    });
  }

  void _showDeleteSupplierDialog(String supplierName) {
    showDialog(
      context: context,
      builder: (context) => _buildCustomDialog(
        context,
        title: 'Delete Supplier',
        content:
            'Are you sure you want to delete "$supplierName"? This will update all supplies with this supplier to "N/A".',
        confirmText: 'Delete',
        confirmColor: Colors.red[600]!,
        icon: Icons.delete_forever,
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        try {
          await filterController.deleteSupplier(supplierName);
          // Force rebuild to show updated list immediately
          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Supplier "$supplierName" deleted successfully'),
                backgroundColor: Colors.green[600],
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting supplier: $e'),
                backgroundColor: Colors.red[600],
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    });
  }

  Widget _buildCustomDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      backgroundColor: theme.dialogBackgroundColor,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width < 768 ? 300 : 400,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: theme.dialogBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon and Title
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: confirmColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: confirmColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Content
              Text(
                content,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodyMedium?.color,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Buttons
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
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
    );
  }
}
