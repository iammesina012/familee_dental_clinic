import 'package:flutter/material.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/inventory/components/inventory_item_card.dart';
import 'package:familee_dental/features/inventory/pages/expired_view_supply_page.dart';
import 'package:familee_dental/features/inventory/controller/expired_supply_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:shimmer/shimmer.dart';

class ExpiredSupplyPage extends StatefulWidget {
  const ExpiredSupplyPage({super.key});

  @override
  State<ExpiredSupplyPage> createState() => _ExpiredSupplyPageState();
}

class _ExpiredSupplyPageState extends State<ExpiredSupplyPage> {
  final ExpiredSupplyController controller = ExpiredSupplyController();
  String searchText = '';

  @override
  void initState() {
    super.initState();
    // Convert expired supplies to placeholders when page loads
    _convertExpiredToPlaceholders();
  }

  void _convertExpiredToPlaceholders() async {
    try {
      await controller.convertExpiredToPlaceholders();
    } catch (e) {
      // Handle error silently for now
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Expired Supply",
          style: AppFonts.sfProStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: theme.appBarTheme.elevation,
        shadowColor: theme.appBarTheme.shadowColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Force rebuild and wait for stream
            setState(() {});
            // Wait for the stream to emit at least one event
            // This ensures the RefreshIndicator shows its animation
            await controller.getSuppliesStream(archived: false).first;
          },
          child: ResponsiveContainer(
            maxWidth: 1200,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal:
                    MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
                vertical: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search bar
                  Container(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search expired supplies...',
                        hintStyle: AppFonts.sfProStyle(
                          fontSize: 16,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.6),
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
                        fillColor: theme.colorScheme.surface,
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchText = value;
                        });
                      },
                    ),
                  ),

                  // Expired supplies grid
                  Expanded(
                    child: StreamBuilder<List<InventoryItem>>(
                      stream: controller.getSuppliesStream(archived: false),
                      builder: (context, snapshot) {
                        // Only show loading on first load, not on refresh
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          final baseColor =
                              isDark ? Colors.grey[800]! : Colors.grey[300]!;
                          final highlightColor =
                              isDark ? Colors.grey[700]! : Colors.grey[100]!;

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              return GridView.builder(
                                physics: NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: constraints.maxWidth > 800
                                      ? 4
                                      : constraints.maxWidth > 600
                                          ? 3
                                          : 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio:
                                      constraints.maxWidth < 400 ? 0.7 : 0.85,
                                ),
                                itemCount: 8,
                                itemBuilder: (context, index) {
                                  return Shimmer.fromColors(
                                    baseColor: baseColor,
                                    highlightColor: highlightColor,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    size: 64, color: Colors.red),
                                SizedBox(height: 16),
                                Text(
                                  'Error loading expired supplies',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Please try again later',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    size: 64, color: Colors.green),
                                SizedBox(height: 16),
                                Text(
                                  'No Expired Supplies',
                                  style: AppFonts.sfProStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'All your supplies are up to date!',
                                  style: AppFonts.sfProStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Filter expired items from stream data and apply search
                        final allItems = snapshot.data!;
                        final expiredItems =
                            controller.filterExpiredItems(allItems);
                        final grouped =
                            controller.groupExpiredByProduct(expiredItems);
                        final filteredItems =
                            controller.applySearchFilter(grouped, searchText);

                        if (filteredItems.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    searchText.isNotEmpty
                                        ? Icons.search_off
                                        : Icons.check_circle_outline,
                                    size: 64,
                                    color: searchText.isNotEmpty
                                        ? Colors.grey
                                        : Colors.green),
                                SizedBox(height: 16),
                                Text(
                                  searchText.isNotEmpty
                                      ? 'No Results Found'
                                      : 'No Expired Supplies',
                                  style: AppFonts.sfProStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  searchText.isNotEmpty
                                      ? 'Try adjusting your search terms'
                                      : 'All your supplies are up to date!',
                                  style: AppFonts.sfProStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            double aspectRatio =
                                constraints.maxWidth < 400 ? 0.7 : 0.85;
                            return GridView.builder(
                              physics: AlwaysScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: constraints.maxWidth > 800
                                    ? 4
                                    : constraints.maxWidth > 600
                                        ? 3
                                        : 2,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: aspectRatio,
                              ),
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                return GestureDetector(
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ExpiredViewSupplyPage(item: item),
                                      ),
                                    );
                                    // Force rebuild when returning from view page (stream updates automatically)
                                    if (result == true ||
                                        result == 'deleted' ||
                                        result == 'disposed') {
                                      setState(() {});
                                    }
                                  },
                                  child: InventoryItemCard(
                                    item: item,
                                    status: "Expired", // Force expired status
                                    currentSort: null,
                                    overrideStock: null,
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
      ),
    );
  }
}
