import 'package:flutter/material.dart';
import '../controller/filter_controller.dart';
import '../data/inventory_item.dart';

class ManageBrandsSuppliersPage extends StatefulWidget {
  const ManageBrandsSuppliersPage({super.key});

  @override
  State<ManageBrandsSuppliersPage> createState() =>
      _ManageBrandsSuppliersPageState();
}

class _ManageBrandsSuppliersPageState extends State<ManageBrandsSuppliersPage> {
  final FilterController filterController = FilterController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9EFF2),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Manage Brands & Suppliers",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        toolbarHeight: 70,
        iconTheme: const IconThemeData(size: 30, color: Colors.black),
        elevation: 5,
        shadowColor: Colors.black54,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add New Section
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.add_business, size: 20),
                          label: Text('Add Brand'),
                          onPressed: () => _showAddBrandDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.normal,
                              inherit: false,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.local_shipping, size: 20),
                          label: Text('Add Supplier'),
                          onPressed: () => _showAddSupplierDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.normal,
                              inherit: false,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            // Brands Section
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
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
                      Icon(Icons.business, color: Colors.green[600], size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Brands',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  StreamBuilder<List<Brand>>(
                    stream: filterController.getBrandsStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
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

                      return Column(
                        children: validBrands
                            .map((brand) => Container(
                                  margin: EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.grey[200]!),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
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
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  StreamBuilder<List<Supplier>>(
                    stream: filterController.getSuppliersStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
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

                      return Column(
                        children: validSuppliers
                            .map((supplier) => Container(
                                  margin: EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.grey[200]!),
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
    );
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
                          // Check if there are supplies that might belong to this brand
                          final potentialMatches = await filterController
                              .getSuppliesWithNABrand(controller.text.trim());

                          if (potentialMatches > 0) {
                            Navigator.pop(context);
                            // Show restoration dialog
                            _showRestoreBrandDialog(
                                controller.text.trim(), potentialMatches);
                          } else {
                            Navigator.pop(context);
                          }
                        } else {
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
                          // Check if there are supplies that might belong to this supplier
                          final potentialMatches =
                              await filterController.getSuppliesWithNASupplier(
                                  controller.text.trim());

                          if (potentialMatches > 0) {
                            Navigator.pop(context);
                            // Show restoration dialog
                            _showRestoreSupplierDialog(
                                controller.text.trim(), potentialMatches);
                          } else {
                            Navigator.pop(context);
                          }
                        } else {
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
        await filterController.deleteBrand(brandName);
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
        await filterController.deleteSupplier(supplierName);
      }
    });
  }

  void _showRestoreBrandDialog(String brandName, int matchCount) {
    showDialog(
      context: context,
      builder: (context) => _buildCustomDialog(
        context,
        title: 'Restore Supplies?',
        content:
            'Found $matchCount supplies that might belong to "$brandName". Would you like to restore them to this brand?',
        confirmText: 'Restore',
        confirmColor: Colors.green[600]!,
        icon: Icons.restore,
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        await filterController.restoreSuppliesToBrand(brandName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully restored $matchCount supplies to "$brandName"'),
            backgroundColor: Colors.green[600],
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _showRestoreSupplierDialog(String supplierName, int matchCount) {
    showDialog(
      context: context,
      builder: (context) => _buildCustomDialog(
        context,
        title: 'Restore Supplies?',
        content:
            'Found $matchCount supplies that might belong to "$supplierName". Would you like to restore them to this supplier?',
        confirmText: 'Restore',
        confirmColor: Colors.green[600]!,
        icon: Icons.restore,
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        await filterController.restoreSuppliesToSupplier(supplierName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully restored $matchCount supplies to "$supplierName"'),
            backgroundColor: Colors.green[600],
            duration: Duration(seconds: 2),
          ),
        );
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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.black87,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Content
            Text(
              content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black54,
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
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
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
    );
  }
}
