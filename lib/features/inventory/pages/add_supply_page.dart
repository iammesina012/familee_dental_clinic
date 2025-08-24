import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../controller/add_supply_controller.dart';
import '../controller/categories_controller.dart';

class AddSupplyPage extends StatefulWidget {
  const AddSupplyPage({super.key});

  @override
  State<AddSupplyPage> createState() => _AddSupplyPageState();
}

class _AddSupplyPageState extends State<AddSupplyPage> {
  final AddSupplyController controller = AddSupplyController();
  final CategoriesController categoriesController = CategoriesController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9EFF2),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          "Add Item",
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Required fields note
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fields marked with * are required. Supplier and Brand names are optional.',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
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
                      final url = await controller.uploadImageToSupabase(image);
                      setState(() {
                        controller.imageUrl = url;
                        controller.uploading = false;
                      });
                      if (url == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to upload image!')),
                        );
                      }
                    }
                  } catch (e) {
                    // Handle any picker errors gracefully
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error picking image: $e')),
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
                              color: Colors.grey[100],
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_not_supported,
                                    size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text(
                                  'No image',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
              const SizedBox(height: 32),

              // Name + Category
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: TextField(
                        controller: controller.nameController,
                        decoration: InputDecoration(
                          labelText: 'Item Name *',
                          border: OutlineInputBorder(),
                          errorStyle: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: StreamBuilder<List<String>>(
                        stream: categoriesController.getCategoriesStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return DropdownButtonFormField<String>(
                              value: null,
                              decoration: InputDecoration(
                                labelText: 'Category *',
                                border: OutlineInputBorder(),
                                errorStyle: TextStyle(color: Colors.red),
                              ),
                              items: [],
                              onChanged: null,
                            );
                          }

                          final categories = snapshot.data ?? [];
                          return DropdownButtonFormField<String>(
                            value: controller.selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Category *',
                              border: OutlineInputBorder(),
                              errorStyle: TextStyle(color: Colors.red),
                            ),
                            items: categories
                                .map((c) =>
                                    DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (value) => setState(
                                () => controller.selectedCategory = value),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Stock + Inventory units
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stock', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.purple[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove, color: Colors.purple),
                                splashRadius: 18,
                                onPressed: () {
                                  if (controller.stock > 0) {
                                    setState(() {
                                      controller.stock--;
                                      controller.stockController.text =
                                          controller.stock.toString();
                                    });
                                  }
                                },
                              ),
                              SizedBox(
                                width: 32,
                                child: Center(
                                  child: TextField(
                                    controller: controller.stockController,
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                        border: InputBorder.none),
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500),
                                    onChanged: (val) {
                                      setState(() {
                                        controller.stock =
                                            int.tryParse(val) ?? 0;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.add, color: Colors.purple),
                                splashRadius: 18,
                                onPressed: () {
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: controller.selectedUnit,
                          decoration: InputDecoration(
                            labelText: 'Inventory units *',
                            border: OutlineInputBorder(),
                            errorStyle: TextStyle(color: Colors.red),
                          ),
                          items: ['Box', 'Piece', 'Pack']
                              .map((u) =>
                                  DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => controller.selectedUnit = val),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Cost full width
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 0.0),
                child: TextField(
                  controller: controller.costController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                ),
              ),
              const SizedBox(height: 14),

              // Supplier + Brand
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: TextField(
                        controller: controller.supplierController,
                        decoration: InputDecoration(
                            labelText: 'Supplier Name (Optional)',
                            border: OutlineInputBorder()),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: TextField(
                        controller: controller.brandController,
                        decoration: InputDecoration(
                            labelText: 'Brand Name (Optional)',
                            border: OutlineInputBorder()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Expiry Date (disable if noExpiry checked)
              TextField(
                controller: controller.expiryController,
                enabled: !controller.noExpiry,
                decoration: InputDecoration(
                  labelText: 'Expiry Date *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                  errorStyle: TextStyle(color: Colors.red),
                  hintText:
                      controller.noExpiry ? 'No expiry date' : 'Select date',
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
                          });
                        }
                      }
                    : null,
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
                      padding:
                          EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6562F2),
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Save'),
                    onPressed: () async {
                      final error = controller.validateFields();
                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error)),
                        );
                        return;
                      }
                      final result = await controller.addSupply();
                      if (result == null) {
                        if (!mounted) return;
                        Navigator.of(context).pop(true);
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result)),
                        );
                      }
                    },
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
