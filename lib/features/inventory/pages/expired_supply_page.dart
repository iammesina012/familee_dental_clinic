import 'package:flutter/material.dart';
import 'package:projects/shared/themes/font.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';
import 'package:projects/features/inventory/components/inventory_item_card.dart';
import 'package:projects/features/inventory/pages/expired_view_supply_page.dart';
import '../controller/expired_supply_controller.dart';

class ExpiredSupplyPage extends StatefulWidget {
  const ExpiredSupplyPage({super.key});

  @override
  State<ExpiredSupplyPage> createState() => _ExpiredSupplyPageState();
}

class _ExpiredSupplyPageState extends State<ExpiredSupplyPage> {
  final ExpiredSupplyController controller = ExpiredSupplyController();
  String searchText = '';

  // ─── Real-time State ─────────────────────────────────────────────────────
  Key _streamKey = UniqueKey();

  // Method to force complete refresh
  void _forceRefresh() {
    setState(() {
      _streamKey = UniqueKey();
    });
    // Also trigger a rebuild of the entire widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
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
            _forceRefresh();
            // Wait a bit for the stream to update
            await Future.delayed(Duration(milliseconds: 500));
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
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
                    key: _streamKey,
                    stream: controller.getSuppliesStream(archived: false),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(),
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

                      // Use controller to filter expired items and apply search
                      final expiredItems =
                          controller.getFilteredExpiredSupplies(
                              snapshot.data!, searchText);

                      if (expiredItems.isEmpty) {
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
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: aspectRatio,
                            ),
                            itemCount: expiredItems.length,
                            itemBuilder: (context, index) {
                              final item = expiredItems[index];
                              return GestureDetector(
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ExpiredViewSupplyPage(item: item),
                                    ),
                                  );
                                  // Refresh the stream when returning from view page
                                  if (result == true ||
                                      result == 'deleted' ||
                                      result == 'disposed') {
                                    _forceRefresh();
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
    );
  }
}
