import 'package:flutter/material.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/inventory/components/inventory_item_card.dart';
import 'package:familee_dental/features/inventory/controller/archive_supply_controller.dart';
import 'package:familee_dental/features/inventory/pages/view_supply_page.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:shimmer/shimmer.dart';

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

  // ─── Grouping Helpers (archived page) ─────────────────────────────────────
  String _normalizeName(String name) => name.trim().toLowerCase();

  DateTime? _parseExpiry(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw) ??
        DateTime.tryParse(raw.replaceAll('/', '-'));
  }

  List<_ArchivedGroup> _groupByName(List<InventoryItem> items) {
    final Map<String, List<InventoryItem>> byName = {};
    for (final item in items) {
      final key = _normalizeName(item.name);
      byName.putIfAbsent(key, () => <InventoryItem>[]).add(item);
    }
    final List<_ArchivedGroup> groups = [];
    byName.forEach((key, list) {
      final withImage = list.where((i) => i.imageUrl.isNotEmpty).toList();
      final candidates = withImage.isNotEmpty ? withImage : list;
      candidates.sort((a, b) {
        final ae = _parseExpiry(a.expiry);
        final be = _parseExpiry(b.expiry);
        if (ae == null && be == null) return 0;
        if (ae == null) return 1;
        if (be == null) return -1;
        return ae.compareTo(be);
      });
      final representative = candidates.first;
      groups.add(_ArchivedGroup(
        key: key,
        displayName: representative.name,
        representative: representative,
        otherCount: list.length - 1,
        items: List<InventoryItem>.from(list),
      ));
    });
    groups.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return groups;
  }

  // (no formatting helpers needed here)

  // Bottom sheet removed; tap navigates to InventoryViewSupplyPage

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
        child: ResponsiveContainer(
          maxWidth: 1200,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width < 768
                  ? 1.0
                  : 16.0, // Reduce horizontal
              vertical: 12.0, // Keep vertical as needed
            ),
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
                        onChanged: (value) =>
                            setState(() => searchText = value),
                      ),
                    ),
                    // (Optional) filter/sort buttons can go here
                  ],
                ),
                const SizedBox(height: 16),
                // ─── Filtered Grid ────────────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      // Force rebuild and wait for stream
                      setState(() {});
                      // Wait for the stream to emit at least one event
                      // This ensures the RefreshIndicator shows its animation
                      await controller.getArchivedSupplies().first;
                    },
                    child: StreamBuilder<List<InventoryItem>>(
                      stream: controller.getArchivedSupplies(),
                      builder: (context, snapshot) {
                        // Handle errors
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading archived supplies',
                              style: AppFonts.sfProStyle(
                                fontSize: 16,
                                color: Colors.red,
                              ),
                            ),
                          );
                        }

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
                                  color:
                                      theme.iconTheme.color?.withOpacity(0.6),
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
                                  color:
                                      theme.iconTheme.color?.withOpacity(0.6),
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

                        final groups = _groupByName(supplies);
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            return GridView.builder(
                              physics: AlwaysScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: constraints.maxWidth > 800
                                    ? 4
                                    : constraints.maxWidth > 600
                                        ? 3
                                        : 2,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: groups.length,
                              itemBuilder: (context, index) {
                                final group = groups[index];
                                return LayoutBuilder(
                                  builder: (context, box) {
                                    final bool bounded = box.hasBoundedHeight;
                                    final double maxH =
                                        bounded ? box.maxHeight : 260;
                                    return ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: maxH,
                                        minHeight: 0,
                                      ),
                                      child: InkWell(
                                        onTap: () async {
                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  InventoryViewSupplyPage(
                                                item: group.representative,
                                                skipAutoRedirect: true,
                                              ),
                                            ),
                                          );
                                          // Force rebuild when returning from view page (stream updates automatically)
                                          if (result == true ||
                                              result == 'unarchived') {
                                            setState(() {});
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            Expanded(
                                              child: InventoryItemCard(
                                                item: group.representative,
                                                showExpiryDate: true,
                                                hideStock: true,
                                                hideExpiry: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
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

class _ArchivedGroup {
  final String key;
  final String displayName;
  final InventoryItem representative;
  final int otherCount;
  final List<InventoryItem> items;
  const _ArchivedGroup({
    required this.key,
    required this.displayName,
    required this.representative,
    required this.otherCount,
    required this.items,
  });
}
