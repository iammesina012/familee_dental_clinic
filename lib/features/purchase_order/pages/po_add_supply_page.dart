import 'package:flutter/material.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/inventory/controller/inventory_controller.dart';
import 'package:familee_dental/features/inventory/controller/catalog_controller.dart';
import 'package:familee_dental/features/purchase_order/pages/po_edit_supply_page.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  bool _isFirstLoad = true;

  List<InventoryItem> get filteredItems {
    // This will be populated from the stream
    return [];
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Column(
      children: [
        // Search bar skeleton
        Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            height: 56,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Supply grid skeleton
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 800
                  ? 4
                  : constraints.maxWidth > 600
                      ? 3
                      : 2;

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  return Shimmer.fromColors(
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Receive existingIds from CreatePOPage to prevent duplicates
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final Set<String> existingIds = {
      if (routeArgs is Map && routeArgs['existingIds'] is List)
        ...List.from(routeArgs['existingIds']).map((e) => e.toString()),
    };
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Add Supply",
          style: AppFonts.sfProStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.appBarTheme.titleTextStyle?.color ??
                  theme.textTheme.titleLarge?.color),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: 5,
        shadowColor: Colors.black54,
      ),
      body: ResponsiveContainer(
        maxWidth: 1200,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
              vertical: 12.0,
            ),
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
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                    prefixIcon:
                        Icon(Icons.search, color: theme.iconTheme.color),
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
                    fillColor: scheme.surface,
                  ),
                ),
                SizedBox(height: 16),

                // Items List
                Expanded(
                  child: StreamBuilder<List<GroupedInventoryItem>>(
                    // Use catalog stream to include products even if only expired batches exist
                    stream: catalogController.getAllProductsStream(
                        archived: false, expired: false),
                    builder: (context, snapshot) {
                      // Show skeleton loader only on first load
                      if (_isFirstLoad && !snapshot.hasData) {
                        return _buildSkeletonLoader(context);
                      }

                      // Mark first load as complete once we have data
                      if (snapshot.hasData && _isFirstLoad) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _isFirstLoad = false;
                            });
                          }
                        });
                      }

                      // Handle error gracefully
                      if (snapshot.hasError && !snapshot.hasData) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off_outlined,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Connection Issue',
                                style: AppFonts.sfProStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Please try again',
                                style: AppFonts.sfProStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
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
                                color: theme.iconTheme.color?.withOpacity(0.4),
                              ),
                              SizedBox(height: 16),
                              Text(
                                "No supplies found",
                                style: AppFonts.sfProStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Try adjusting your search terms",
                                style: AppFonts.sfProStyle(
                                  fontSize: 14,
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: constraints.maxWidth > 800
                                  ? 4
                                  : constraints.maxWidth > 600
                                      ? 3
                                      : 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: filteredGroups.length,
                            itemBuilder: (context, index) {
                              final group = filteredGroups[index];
                              final item = group.mainItem;
                              return GestureDetector(
                                onTap: () => _handleTapItem(item, existingIds),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: scheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            theme.shadowColor.withOpacity(0.12),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                    border: Border.all(
                                        color: theme.dividerColor
                                            .withOpacity(0.2)),
                                  ),
                                  child: Padding(
                                    padding:
                                        EdgeInsets.fromLTRB(12, 12, 12, 12),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // Show Supabase image (or placeholder) with caching - NO BACKGROUND
                                        item.imageUrl.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: item.imageUrl,
                                                width: 96,
                                                height: 96,
                                                fit: BoxFit.contain,
                                                placeholder: (context, url) {
                                                  return Container(
                                                    width: 96,
                                                    height: 96,
                                                    color: Colors.grey[200],
                                                    child: Icon(Icons.image,
                                                        size: 48,
                                                        color:
                                                            Colors.grey[400]),
                                                  );
                                                },
                                                errorWidget:
                                                    (context, url, error) {
                                                  return Icon(
                                                      Icons.image_not_supported,
                                                      size: 96,
                                                      color: Colors.grey);
                                                },
                                                fadeInDuration: const Duration(
                                                    milliseconds: 200),
                                                fadeOutDuration: const Duration(
                                                    milliseconds: 100),
                                              )
                                            : Icon(Icons.image_not_supported,
                                                size: 96, color: Colors.grey),
                                        SizedBox(height: 16),
                                        // Product Name (exact same as inventory)
                                        Flexible(
                                          child: Text(
                                            item.name,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: theme.textTheme
                                                    .bodyMedium?.color),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        // Stock Information (exact same as inventory)
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Stock: ${group.totalStock}',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 14,
                                                  color: theme.textTheme
                                                      .bodyMedium?.color),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
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
      ),
    );
  }

  // Expiry helpers removed for this page

  void _handleTapItem(InventoryItem item, Set<String> existingIds) async {
    // Allow selecting the same supply again; type differentiation happens in EditSupplyPOPage
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
