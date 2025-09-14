import 'package:flutter/material.dart';
import 'package:projects/shared/themes/font.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';
import 'package:projects/features/inventory/controller/inventory_controller.dart';
import 'package:projects/features/inventory/controller/catalog_controller.dart';
import 'package:projects/features/purchase_order/pages/po_edit_supply_page.dart';

class AddSupplyPage extends StatefulWidget {
  const AddSupplyPage({super.key});

  @override
  State<AddSupplyPage> createState() => _AddSupplyPageState();
}

class _AddSupplyPageState extends State<AddSupplyPage> {
  final TextEditingController searchController = TextEditingController();
  String searchText = '';
  final InventoryController inventoryController = InventoryController();
  final CatalogController catalogController = CatalogController();

  List<InventoryItem> get filteredItems {
    // This will be populated from the stream
    return [];
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Receive existingIds from CreatePOPage to prevent duplicates
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final Set<String> existingIds = {
      if (routeArgs is Map && routeArgs['existingIds'] is List)
        ...List.from(routeArgs['existingIds']).map((e) => e.toString()),
    };
    return Scaffold(
      backgroundColor: Color(0xFFF9EFF2),
      appBar: AppBar(
        title: Text(
          "Add Supply",
          style: AppFonts.sfProStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        toolbarHeight: 70,
        iconTheme: const IconThemeData(size: 30, color: Colors.black),
        elevation: 5,
        shadowColor: Colors.black54,
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              TextField(
                controller: searchController,
                onChanged: (value) {
                  setState(() {
                    searchText = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search supplies...',
                  hintStyle: AppFonts.sfProStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                  prefixIcon: Icon(Icons.search, color: Colors.black),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              SizedBox(height: 16),

              // Items List
              Expanded(
                child: StreamBuilder<List<GroupedInventoryItem>>(
                  // Use catalog stream to include products even if only expired batches exist
                  stream:
                      catalogController.getAllProductsStream(archived: false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00D4AA),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading inventory',
                          style: AppFonts.sfProStyle(
                            fontSize: 16,
                            color: Colors.red,
                          ),
                        ),
                      );
                    }

                    final allGroups = snapshot.data ?? [];
                    final filteredGroups = searchText.isEmpty
                        ? allGroups
                        : allGroups.where((group) {
                            return group.mainItem.name
                                .toLowerCase()
                                .contains(searchText.toLowerCase());
                          }).toList();

                    if (filteredGroups.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              "No supplies found",
                              style: AppFonts.sfProStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Try adjusting your search terms",
                              style: AppFonts.sfProStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: filteredGroups.length,
                      itemBuilder: (context, index) {
                        final group = filteredGroups[index];
                        final item = group.mainItem;
                        return GestureDetector(
                          onTap: () => _handleTapItem(item, existingIds),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Show Firestore image (or placeholder) - NO BACKGROUND
                                  item.imageUrl.isNotEmpty
                                      ? Image.network(
                                          item.imageUrl,
                                          width: 96,
                                          height: 96,
                                          fit: BoxFit.contain,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Icon(
                                                Icons.image_not_supported,
                                                size: 96,
                                                color: Colors.grey);
                                          },
                                        )
                                      : Icon(Icons.image_not_supported,
                                          size: 96, color: Colors.grey),
                                  SizedBox(height: 16),
                                  // Flexible text container
                                  Flexible(
                                    child: Text(
                                      item.name,
                                      style: AppFonts.sfProStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Expiry chip intentionally hidden on Add Supply (PO)
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Expiry helpers removed for this page

  void _handleTapItem(InventoryItem item, Set<String> existingIds) async {
    // Check duplicate first
    if (existingIds.contains(item.id.toString())) {
      // Show duplicate dialog and stop
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
              '“${item.name}” is already added. Duplicate items are not allowed.',
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
      return;
    }

    _addItemToPurchaseOrder(item);
  }

  void _addItemToPurchaseOrder(InventoryItem item) async {
    // Convert InventoryItem to Map for EditSupplyPOPage
    final supplyMap = {
      'supplyId': item.id,
      'supplyName': item.name,
      'brandName': item.brand,
      'supplierName': item.supplier,
      'quantity': 1, // Default quantity
      'cost': item.cost, // Include cost from inventory item
      'imageUrl': item.imageUrl,
    };

    // Navigate directly to Edit Supply page and wait for result
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditSupplyPOPage(supply: supplyMap),
      ),
    );

    // If we got a result (supply was added), return it to the previous page
    if (result != null) {
      Navigator.of(context).pop(result);
    }
  }
}
