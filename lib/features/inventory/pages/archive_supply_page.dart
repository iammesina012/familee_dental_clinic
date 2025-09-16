import 'package:flutter/material.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';
import 'package:projects/features/inventory/components/inventory_item_card.dart';
import 'package:projects/features/inventory/controller/archive_supply_controller.dart';
import 'package:projects/features/inventory/pages/view_supply_page.dart';

class ArchiveSupplyPage extends StatefulWidget {
  const ArchiveSupplyPage({super.key});

  @override
  ArchiveSupplyPageState createState() => ArchiveSupplyPageState();
}

class ArchiveSupplyPageState extends State<ArchiveSupplyPage> {
  final ArchiveSupplyController controller = ArchiveSupplyController();

  // ─── Search State ────────────────────────────────────────────────────────
  final TextEditingController searchController = TextEditingController();
  String searchText = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<InventoryItem> filterSupplies(List<InventoryItem> supplies) {
    if (searchText.isEmpty) {
      return supplies;
    }
    return supplies
        .where((supply) =>
            supply.name.toLowerCase().contains(searchText.toLowerCase()) ||
            supply.category.toLowerCase().contains(searchText.toLowerCase()) ||
            supply.brand.toLowerCase().contains(searchText.toLowerCase()) ||
            supply.supplier.toLowerCase().contains(searchText.toLowerCase()))
        .toList();
  }

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
          "Archived Supplies",
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ─── Search Bar ────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search archived...',
                        prefixIcon:
                            Icon(Icons.search, color: theme.iconTheme.color),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) => setState(() => searchText = value),
                    ),
                  ),
                  // (Optional) filter/sort buttons can go here
                ],
              ),
              const SizedBox(height: 16),
              // ─── Filtered Grid ────────────────────────────────────────
              Expanded(
                child: StreamBuilder<List<InventoryItem>>(
                  stream: controller.getArchivedSupplies(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.archive_outlined,
                              size: 64,
                              color: theme.iconTheme.color?.withOpacity(0.6),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No archived supplies found',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 18,
                                color: theme.textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Archived supplies will appear here',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final supplies = filterSupplies(snapshot.data!);

                    if (supplies.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: theme.iconTheme.color?.withOpacity(0.6),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No supplies match your search',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 18,
                                color: theme.textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: supplies.length,
                      itemBuilder: (context, index) {
                        final supply = supplies[index];
                        return GestureDetector(
                          onTap: () {
                            // Navigate to view supply page
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    InventoryViewSupplyPage(item: supply),
                              ),
                            );
                          },
                          child: InventoryItemCard(
                            item: supply,
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
}
