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

  // ─── Real-time State ─────────────────────────────────────────────────────
  Key _streamKey = UniqueKey();

  // Method to refresh the stream
  void _refreshStream() {
    setState(() {
      _streamKey = UniqueKey();
    });
  }

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
                child: RefreshIndicator(
                  onRefresh: () async {
                    _refreshStream();
                    // Wait a bit for the stream to update
                    await Future.delayed(Duration(milliseconds: 500));
                  },
                  child: StreamBuilder<List<InventoryItem>>(
                    key: _streamKey,
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

                      final groups = _groupByName(supplies);
                      return GridView.builder(
                        physics: AlwaysScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return LayoutBuilder(
                            builder: (context, box) {
                              final bool bounded = box.hasBoundedHeight;
                              final double maxH = bounded ? box.maxHeight : 260;
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
                                        builder: (_) => InventoryViewSupplyPage(
                                          item: group.representative,
                                          skipAutoRedirect: true,
                                        ),
                                      ),
                                    );
                                    // Refresh the stream when returning from view page
                                    // This ensures real-time updates after unarchiving
                                    if (result == true ||
                                        result == 'unarchived') {
                                      _refreshStream();
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
                  ),
                ),
              ),
            ],
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
