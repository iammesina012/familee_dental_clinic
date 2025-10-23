import 'package:flutter/material.dart';
import 'package:familee_dental/shared/drawer.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/inventory/components/inventory_item_card.dart';
import 'package:familee_dental/features/inventory/components/inventory_fab.dart';
import 'package:familee_dental/features/inventory/components/inventory_filter.dart';
import 'package:familee_dental/features/inventory/components/inventory_sort.dart'; // Your sort modal
import 'package:familee_dental/features/inventory/pages/add_supply_page.dart';
import 'package:familee_dental/features/inventory/pages/view_supply_page.dart';
import 'package:familee_dental/features/inventory/pages/add_category_page.dart';
import 'package:familee_dental/features/inventory/pages/edit_categories_page.dart';
import 'package:familee_dental/features/inventory/controller/inventory_controller.dart';
import 'package:familee_dental/features/inventory/pages/expired_supply_page.dart';
import 'package:familee_dental/features/inventory/controller/filter_controller.dart';
import 'package:familee_dental/features/inventory/controller/categories_controller.dart';
import 'package:familee_dental/features/inventory/controller/expired_supply_controller.dart';
import 'package:familee_dental/features/inventory/pages/archive_supply_page.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/widgets/notification_badge_button.dart';
import 'package:shimmer/shimmer.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/features/auth/services/auth_service.dart';

class Inventory extends StatefulWidget {
  const Inventory({super.key});

  @override
  State<Inventory> createState() => _InventoryState();
}

class _InventoryState extends State<Inventory> {
  int selectedCategory = 0;
  String? _highlightSupplyName; // for deep-link from notifications
  bool _deepLinkHandled = false;
  bool _expiringFilterApplied = false;
  // summary filter removed

  final TextEditingController searchController = TextEditingController();
  String searchText = '';

  String? selectedSort = "Expiry Date (Soonest First)";

  // Filter state
  Map<String, dynamic> currentFilters = {};

  // Use the controller for all logic
  final InventoryController controller = InventoryController();
  final FilterController filterController = FilterController();
  final CategoriesController categoriesController = CategoriesController();
  final ExpiredSupplyController expiredController = ExpiredSupplyController();

  // ─── Real-time State ─────────────────────────────────────────────────────
  Key _categoriesStreamKey = UniqueKey();
  Key _inventoryStreamKey = UniqueKey();

  // Add ScrollController for Choice Chips
  final ScrollController _chipsScrollController = ScrollController();

  // Map to store GlobalKeys for each chip
  final Map<int, GlobalKey> _chipKeys = {};

  // Method to refresh the categories stream
  void _refreshCategoriesStream() {
    setState(() {
      _categoriesStreamKey = UniqueKey();
    });
  }

  // Method to refresh the inventory stream
  void _refreshInventoryStream() {
    setState(() {
      _inventoryStreamKey = UniqueKey();
    });
  }

  // Method to refresh both streams
  void _refreshAllStreams() {
    setState(() {
      _categoriesStreamKey = UniqueKey();
      _inventoryStreamKey = UniqueKey();
    });
  }

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => InventoryFilterModal(
        onApply: (filters) {
          setState(() {
            currentFilters = filters;
            // Reset the expiring filter flag when filters are manually applied
            _expiringFilterApplied = false;
          });
        },
        currentFilters: currentFilters,
      ),
    );
  }

  void _showSortModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => InventorySortModal(
        selected: selectedSort,
        onSelect: (sort) {
          setState(() {
            selectedSort = sort;
          });
        },
      ),
    );
  }

  // Method to scroll to selected chip using GlobalKey for precise positioning
  void _scrollToSelectedChip(int index, List<String> categories) {
    if (index >= 0 &&
        index < categories.length &&
        _chipsScrollController.hasClients) {
      final key = _chipKeys[index];
      if (key?.currentContext != null) {
        final RenderBox renderBox =
            key!.currentContext!.findRenderObject() as RenderBox;
        final position = renderBox.localToGlobal(Offset.zero);
        final scrollPosition = _chipsScrollController.position.pixels +
            position.dx -
            16; // 16px padding from left

        _chipsScrollController.animateTo(
          scrollPosition.clamp(
              0.0, _chipsScrollController.position.maxScrollExtent),
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        // Fallback to estimated positioning if GlobalKey is not available
        double estimatedChipWidth = 140.0;
        double scrollPosition = index * estimatedChipWidth;
        double maxScroll = _chipsScrollController.position.maxScrollExtent;
        scrollPosition = scrollPosition.clamp(0.0, maxScroll);

        _chipsScrollController.animateTo(
          scrollPosition,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize default categories and migrate existing data
    _initializeData();
    // Best-effort cleanup of zero-stock duplicates when there are stocked batches
    controller.cleanupZeroStockDuplicates();
    // Convert expired supplies to placeholders
    _convertExpiredToPlaceholders();

    // Handle route arguments after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleRouteArguments();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Capture deep-link arg once
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      if (_highlightSupplyName == null &&
          args['highlightSupplyName'] is String) {
        _highlightSupplyName = (args['highlightSupplyName'] as String).trim();
      }
    }
    // Convert expired supplies to placeholders when page becomes visible
    _convertExpiredToPlaceholders();
  }

  void _handleRouteArguments() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      // Handle expiring filter from dashboard
      if (args['filter'] == 'expiring') {
        _applyExpiringFilter();
        _expiringFilterApplied = true;
      }
    } else {
      // No arguments - reset the expiring filter flag and clear filters
      _expiringFilterApplied = false;
      if (currentFilters['expiry'] != null) {
        setState(() {
          currentFilters.remove('expiry');
        });
      }
    }
  }

  Future<void> _initializeData() async {
    await categoriesController.initializeDefaultCategories();
    await filterController.migrateExistingBrandsAndSuppliers();
  }

  void _convertExpiredToPlaceholders() async {
    try {
      await expiredController.convertExpiredToPlaceholders();
    } catch (e) {
      // Handle error silently for now
    }
  }

  void _applyExpiringFilter() {
    // Set the expiry filter to show only expiring items
    setState(() {
      currentFilters['expiry'] = ['Expiring'];
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _chipsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return WillPopScope(
      onWillPop: () async {
        // Navigate back to Dashboard when back button is pressed
        // Use popUntil to go back to existing Dashboard instead of creating a new one
        Navigator.popUntil(
            context, (route) => route.settings.name == '/dashboard');
        return false; // Prevent default back behavior
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: MediaQuery.of(context).size.width >= 900
              ? false
              : true, // Remove back button on desktop
          title: Text(
            "Inventory",
            style:
                AppFonts.sfProStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: theme.appBarTheme.backgroundColor,
          toolbarHeight: 70,
          iconTheme: theme.appBarTheme.iconTheme,
          elevation: theme.appBarTheme.elevation,
          shadowColor: theme.appBarTheme.shadowColor,
          actions: [
            const NotificationBadgeButton(),
          ],
        ),
        drawer:
            MediaQuery.of(context).size.width >= 900 ? null : const MyDrawer(),
        body: MediaQuery.of(context).size.width >= 900
            ? _buildWithNavigationRail(theme, scheme)
            : SafeArea(
                child: RefreshIndicator(
                  onRefresh: () async {
                    // Refresh the streams to reload data from Supabase
                    _refreshAllStreams();
                    // Convert expired supplies to placeholders
                    _convertExpiredToPlaceholders();
                    // Wait for the inventory stream to emit at least one event
                    // This ensures the RefreshIndicator shows its animation
                    await controller
                        .getGroupedSuppliesStream(archived: false)
                        .first;
                  },
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search Bar + filter/sort
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search...',
                                    hintStyle: AppFonts.sfProStyle(
                                      fontSize: 16,
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.6),
                                    ),
                                    prefixIcon: Icon(Icons.search,
                                        color: theme.iconTheme.color),
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
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 0, horizontal: 16),
                                    filled: true,
                                    fillColor: scheme.surface,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      searchText = value;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 48,
                                width: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    backgroundColor: currentFilters.isNotEmpty
                                        ? const Color(0xFF4E38D4)
                                        : scheme.surface,
                                    foregroundColor: currentFilters.isNotEmpty
                                        ? Colors.white
                                        : theme.textTheme.bodyMedium?.color,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 1,
                                  ),
                                  onPressed: () => _showFilterModal(context),
                                  child: Icon(Icons.filter_alt_outlined),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                height: 48,
                                width: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    backgroundColor: scheme.surface,
                                    foregroundColor:
                                        theme.textTheme.bodyMedium?.color,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 1,
                                  ),
                                  onPressed: () => _showSortModal(context),
                                  child: Icon(Icons.sort_by_alpha),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          StreamBuilder<List<String>>(
                            key: _categoriesStreamKey,
                            stream: categoriesController.getCategoriesStream(),
                            builder: (context, snapshot) {
                              final currentCategories = snapshot.data ?? [];
                              final List<String> categoriesWithAll = [
                                'All Supplies',
                                ...currentCategories
                              ];

                              // Show skeleton loader for categories
                              if (snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  currentCategories.isEmpty) {
                                final isDark = Theme.of(context).brightness ==
                                    Brightness.dark;
                                final baseColor = isDark
                                    ? Colors.grey[800]!
                                    : Colors.grey[300]!;
                                final highlightColor = isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[100]!;

                                return SizedBox(
                                  height: 50,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: 5,
                                    separatorBuilder: (_, __) =>
                                        SizedBox(width: 8),
                                    itemBuilder: (_, __) => Shimmer.fromColors(
                                      baseColor: baseColor,
                                      highlightColor: highlightColor,
                                      child: Container(
                                        width: 120,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // Show last known data even if there's an error
                              if (snapshot.hasError &&
                                  currentCategories.isEmpty) {
                                return SizedBox(
                                  height: 50,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        ChoiceChip(
                                          label: Text('All Supplies'),
                                          selected: selectedCategory == 0,
                                          showCheckmark: false,
                                          selectedColor:
                                              const Color(0xFF4E38D4),
                                          backgroundColor: scheme.surface,
                                          labelStyle: TextStyle(
                                            color: selectedCategory == 0
                                                ? Colors.white
                                                : theme.textTheme.bodyMedium
                                                    ?.color,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          shape: StadiumBorder(
                                            side: BorderSide(
                                              color: selectedCategory == 0
                                                  ? const Color(0xFF4E38D4)
                                                  : theme.dividerColor,
                                            ),
                                          ),
                                          onSelected: (_) {
                                            setState(() {
                                              selectedCategory = 0;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              // Auto-scroll to selected chip when categories are loaded
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (selectedCategory <
                                        categoriesWithAll.length &&
                                    _chipsScrollController.hasClients) {
                                  _scrollToSelectedChip(
                                      selectedCategory, categoriesWithAll);
                                }
                              });

                              // Clear old keys if categories changed
                              if (_chipKeys.length !=
                                  categoriesWithAll.length) {
                                _chipKeys.clear();
                              }

                              return SingleChildScrollView(
                                controller: _chipsScrollController,
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: List.generate(
                                      categoriesWithAll.length, (index) {
                                    final isSelected =
                                        selectedCategory == index;
                                    // Ensure we have a GlobalKey for this index
                                    if (!_chipKeys.containsKey(index)) {
                                      _chipKeys[index] = GlobalKey();
                                    }
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: ChoiceChip(
                                        key: _chipKeys[index],
                                        label: Text(categoriesWithAll[index]),
                                        selected: isSelected,
                                        showCheckmark: false,
                                        selectedColor: const Color(0xFF4E38D4),
                                        backgroundColor: scheme.surface,
                                        labelStyle: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : theme
                                                  .textTheme.bodyMedium?.color,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        shape: StadiumBorder(
                                          side: BorderSide(
                                            color: isSelected
                                                ? const Color(0xFF4E38D4)
                                                : theme.dividerColor,
                                          ),
                                        ),
                                        onSelected: (selected) {
                                          setState(() {
                                            selectedCategory = index;
                                          });
                                          // Scroll to the selected chip
                                          _scrollToSelectedChip(
                                              index, categoriesWithAll);
                                        },
                                      ),
                                    );
                                  }),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // Supabase-powered, category-filtered, search-filtered, responsive grid
                          Expanded(
                            child: StreamBuilder<List<String>>(
                              key: _categoriesStreamKey,
                              stream:
                                  categoriesController.getCategoriesStream(),
                              builder: (context, categorySnapshot) {
                                final currentCategories =
                                    categorySnapshot.data ?? [];
                                final categoriesWithAll = [
                                  'All Supplies',
                                  ...currentCategories
                                ];
                                final selectedCategoryName = (selectedCategory ==
                                        0)
                                    ? "" // empty means no category filter -> show all
                                    : (selectedCategory <
                                            categoriesWithAll.length
                                        ? categoriesWithAll[selectedCategory]
                                        : "");

                                return StreamBuilder<
                                    List<GroupedInventoryItem>>(
                                  key: _inventoryStreamKey,
                                  stream: controller.getGroupedSuppliesStream(
                                      archived: false),
                                  builder: (context, snapshot) {
                                    final hasData = snapshot.hasData &&
                                        snapshot.data!.isNotEmpty;

                                    // Show skeleton loader only on first load
                                    if (snapshot.connectionState ==
                                            ConnectionState.waiting &&
                                        !hasData) {
                                      final isDark =
                                          Theme.of(context).brightness ==
                                              Brightness.dark;
                                      final baseColor = isDark
                                          ? Colors.grey[800]!
                                          : Colors.grey[300]!;
                                      final highlightColor = isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[100]!;

                                      return LayoutBuilder(
                                        builder: (context, constraints) {
                                          return GridView.builder(
                                            physics:
                                                NeverScrollableScrollPhysics(),
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: constraints
                                                          .maxWidth >
                                                      800
                                                  ? 4
                                                  : constraints.maxWidth > 600
                                                      ? 3
                                                      : 2,
                                              mainAxisSpacing: 8,
                                              crossAxisSpacing: 8,
                                              childAspectRatio:
                                                  constraints.maxWidth < 400
                                                      ? 0.7
                                                      : 0.85,
                                            ),
                                            itemCount: 8,
                                            itemBuilder: (context, index) {
                                              return Shimmer.fromColors(
                                                baseColor: baseColor,
                                                highlightColor: highlightColor,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      );
                                    }

                                    // Show subtle error banner but keep showing data if available
                                    if (snapshot.hasError) {
                                      // If we have data, show it with error banner
                                      // If no data, show empty state with retry option
                                      if (!hasData) {
                                        return Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.cloud_off_outlined,
                                                  size: 64, color: Colors.grey),
                                              SizedBox(height: 16),
                                              Text(
                                                'Connection Issue',
                                                style: TextStyle(
                                                  color: theme.textTheme
                                                      .bodyMedium?.color,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'Pull down to refresh',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    }

                                    if (!snapshot.hasData ||
                                        snapshot.data!.isEmpty) {
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.inventory_2_outlined,
                                                size: 64, color: Colors.grey),
                                            SizedBox(height: 16),
                                            Text(
                                              'No supplies found',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Add your first supply using the + button',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    // Use controller to filter and sort grouped items
                                    final sortedItems =
                                        controller.filterAndSortGroupedItems(
                                      items: snapshot.data!,
                                      selectedCategory: selectedCategoryName,
                                      searchText: searchText,
                                      selectedSort: selectedSort,
                                      filters: currentFilters,
                                    );

                                    // Filter out expired items from main inventory - they should only appear in Expired Supply page
                                    // But keep non-expired batches even if other batches of the same product are expired
                                    final visibleItems =
                                        sortedItems.where((item) {
                                      return item.getStatus() != "Expired";
                                    }).toList();

                                    // Handle deep-link to specific supply once, after frame
                                    if (!_deepLinkHandled &&
                                        _highlightSupplyName != null &&
                                        _highlightSupplyName!.isNotEmpty) {
                                      GroupedInventoryItem? target;
                                      for (final g in sortedItems) {
                                        if (g.mainItem.name.toLowerCase() ==
                                            _highlightSupplyName!
                                                .toLowerCase()) {
                                          target = g;
                                          break;
                                        }
                                      }
                                      if (target != null) {
                                        _deepLinkHandled = true;
                                        final t = target;
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          // Allow access to all items, including out-of-stock placeholders
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  InventoryViewSupplyPage(
                                                      item: t.mainItem),
                                            ),
                                          );
                                        });
                                      }
                                    }

                                    return LayoutBuilder(
                                      builder: (context, constraints) {
                                        // Since cards now show expiry dates for expiring/expired items regardless of filters,
                                        // use a more conservative aspect ratio to accommodate the extra height
                                        double aspectRatio =
                                            constraints.maxWidth < 400
                                                ? 0.7
                                                : 0.85;
                                        return GridView.builder(
                                            physics:
                                                AlwaysScrollableScrollPhysics(),
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: constraints
                                                          .maxWidth >
                                                      800
                                                  ? 4
                                                  : constraints.maxWidth > 600
                                                      ? 3
                                                      : 2,
                                              mainAxisSpacing: 8,
                                              crossAxisSpacing: 8,
                                              childAspectRatio: aspectRatio,
                                            ),
                                            itemCount: visibleItems.length,
                                            itemBuilder: (context, index) {
                                              final groupedItem =
                                                  visibleItems[index];
                                              return GestureDetector(
                                                onTap: () {
                                                  // Allow navigation for all items, including out-of-stock placeholders
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          InventoryViewSupplyPage(
                                                              item: groupedItem
                                                                  .mainItem),
                                                    ),
                                                  );
                                                },
                                                child: InventoryItemCard(
                                                  item: groupedItem.mainItem,
                                                  status:
                                                      groupedItem.getStatus(),
                                                  currentSort: selectedSort,
                                                  overrideStock:
                                                      groupedItem.totalStock,
                                                ),
                                              );
                                            });
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
        floatingActionButton: InventoryFAB(
          onAddSupply: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddSupplyPage(),
              ),
            );
            // Refresh inventory stream when returning from add page
            if (result == true || result == 'added') {
              _refreshInventoryStream();
            }
          },
          onArchivedSupply: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ArchiveSupplyPage(),
              ),
            );
            // Refresh inventory stream when returning from archive page
            if (result == true || result == 'unarchived') {
              _refreshInventoryStream();
            }
          },
          onExpiredSupply: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ExpiredSupplyPage(),
              ),
            );
            // Refresh inventory stream when returning from expired page
            if (result == true || result == 'disposed') {
              _refreshInventoryStream();
            }
          },
          onAddCategory: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddCategoryPage(),
              ),
            );
            // Refresh categories stream when returning from add page
            if (result == true || result == 'added') {
              _refreshCategoriesStream();
            }
          },
          onEditCategory: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditCategoriesPage(),
              ),
            );
            // Refresh categories stream when returning from edit page
            if (result == true || result == 'updated' || result == 'deleted') {
              _refreshCategoriesStream();
            }
          },
        ),
      ),
    );
  }

  // Info banner intentionally removed for Inventory

  Widget _buildWithNavigationRail(ThemeData theme, ColorScheme scheme) {
    final userRoleProvider = UserRoleProvider();
    final canAccessActivityLog = userRoleProvider.canAccessActivityLog();

    return Row(
      children: [
        NavigationRail(
          minWidth: 150,
          selectedIndex: 1, // Inventory is at index 1
          labelType: NavigationRailLabelType.all,
          useIndicator: true,
          backgroundColor: theme.scaffoldBackgroundColor,
          selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
          selectedLabelTextStyle: AppFonts.sfProStyle(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
          unselectedLabelTextStyle: AppFonts.sfProStyle(
            fontWeight: FontWeight.w500,
            color: theme.textTheme.bodyMedium?.color,
          ),
          leading: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset(
                      'assets/images/logo/logo_101.png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          color: Colors.blue,
                          child: const Icon(
                            Icons.medical_services,
                            color: Colors.white,
                            size: 30,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'FamiLee Dental',
                  style: AppFonts.sfProStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ],
            ),
          ),
          destinations: [
            const NavigationRailDestination(
              icon: Icon(Icons.dashboard),
              label: Text('Dashboard'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.inventory),
              label: Text('Inventory'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.shopping_cart),
              label: Text('Purchase Order'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.playlist_remove),
              label: Text('Stock Deduction'),
            ),
            if (canAccessActivityLog)
              const NavigationRailDestination(
                icon: Icon(Icons.history),
                label: Text('Activity Logs'),
              ),
            const NavigationRailDestination(
              icon: Icon(Icons.settings),
              label: Text('Settings'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.logout),
              label: Text('Logout'),
            ),
          ],
          onDestinationSelected: (index) async {
            if (index == 0) {
              Navigator.pushNamed(context, '/dashboard');
            } else if (index == 1) {
              // Already on Inventory
            } else if (index == 2) {
              Navigator.pushNamed(context, '/purchase-order');
            } else if (index == 3) {
              Navigator.pushNamed(context, '/stock-deduction');
            } else if (canAccessActivityLog && index == 4) {
              Navigator.pushNamed(context, '/activity-log');
            } else if (index == (canAccessActivityLog ? 5 : 4)) {
              Navigator.pushNamed(context, '/settings');
            } else if (index == (canAccessActivityLog ? 6 : 5)) {
              await _handleLogout();
            }
          },
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                _refreshAllStreams();
                _convertExpiredToPlaceholders();
                await controller
                    .getGroupedSuppliesStream(archived: false)
                    .first;
              },
              child: ResponsiveContainer(
                maxWidth: 1200,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
                    vertical: 12.0,
                  ),
                  child: _buildInventoryContent(theme, scheme),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await _showLogoutDialog(context);
    if (shouldLogout == true) {
      final authService = AuthService();
      await authService.logout();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<bool> _showLogoutDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                  minWidth: 350,
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: Colors.red,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Are you sure you want to logout?',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Yes',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                              'No',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w500,
                                color: theme.textTheme.bodyMedium?.color,
                                fontSize: 16,
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
          },
        ) ??
        false;
  }

  Widget _buildInventoryContent(ThemeData theme, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar + filter/sort
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: AppFonts.sfProStyle(
                    fontSize: 16,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                  prefixIcon: Icon(Icons.search, color: theme.iconTheme.color),
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
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  filled: true,
                  fillColor: scheme.surface,
                ),
                onChanged: (value) {
                  setState(() {
                    searchText = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              width: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: currentFilters.isNotEmpty
                      ? const Color(0xFF4E38D4)
                      : scheme.surface,
                  foregroundColor: currentFilters.isNotEmpty
                      ? Colors.white
                      : theme.textTheme.bodyMedium?.color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 1,
                ),
                onPressed: () => _showFilterModal(context),
                child: const Icon(Icons.filter_alt_outlined),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 48,
              width: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: scheme.surface,
                  foregroundColor: theme.textTheme.bodyMedium?.color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 1,
                ),
                onPressed: () => _showSortModal(context),
                child: const Icon(Icons.sort_by_alpha),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Rest of inventory content from original Column continues here unchanged...
        _buildCategoryChips(theme, scheme),
        const SizedBox(height: 16),
        Expanded(child: _buildInventoryGrid(theme, scheme)),
      ],
    );
  }

  Widget _buildCategoryChips(ThemeData theme, ColorScheme scheme) {
    return StreamBuilder<List<String>>(
      key: _categoriesStreamKey,
      stream: categoriesController.getCategoriesStream(),
      builder: (context, snapshot) {
        final currentCategories = snapshot.data ?? [];
        final List<String> categoriesWithAll = [
          'All Supplies',
          ...currentCategories
        ];

        if (snapshot.connectionState == ConnectionState.waiting &&
            currentCategories.isEmpty) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
          final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

          return SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, __) => Shimmer.fromColors(
                baseColor: baseColor,
                highlightColor: highlightColor,
                child: Container(
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError && currentCategories.isEmpty) {
          return SizedBox(
            height: 50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Supplies'),
                    selected: selectedCategory == 0,
                    showCheckmark: false,
                    selectedColor: const Color(0xFF4E38D4),
                    backgroundColor: scheme.surface,
                    labelStyle: TextStyle(
                      color: selectedCategory == 0
                          ? Colors.white
                          : theme.textTheme.bodyMedium?.color,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: selectedCategory == 0
                            ? const Color(0xFF4E38D4)
                            : theme.dividerColor,
                      ),
                    ),
                    onSelected: (_) {
                      setState(() {
                        selectedCategory = 0;
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (selectedCategory < categoriesWithAll.length &&
              _chipsScrollController.hasClients) {
            _scrollToSelectedChip(selectedCategory, categoriesWithAll);
          }
        });

        if (_chipKeys.length != categoriesWithAll.length) {
          _chipKeys.clear();
        }

        return SingleChildScrollView(
          controller: _chipsScrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(categoriesWithAll.length, (index) {
              final isSelected = selectedCategory == index;
              if (!_chipKeys.containsKey(index)) {
                _chipKeys[index] = GlobalKey();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  key: _chipKeys[index],
                  label: Text(categoriesWithAll[index]),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: const Color(0xFF4E38D4),
                  backgroundColor: scheme.surface,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : theme.textTheme.bodyMedium?.color,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF4E38D4)
                          : theme.dividerColor,
                    ),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      selectedCategory = index;
                    });
                    _scrollToSelectedChip(index, categoriesWithAll);
                  },
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildInventoryGrid(ThemeData theme, ColorScheme scheme) {
    return StreamBuilder<List<String>>(
      key: _categoriesStreamKey,
      stream: categoriesController.getCategoriesStream(),
      builder: (context, categorySnapshot) {
        final currentCategories = categorySnapshot.data ?? [];
        final categoriesWithAll = ['All Supplies', ...currentCategories];
        final selectedCategoryName = (selectedCategory == 0)
            ? ""
            : (selectedCategory < categoriesWithAll.length
                ? categoriesWithAll[selectedCategory]
                : "");

        return StreamBuilder<List<GroupedInventoryItem>>(
          key: _inventoryStreamKey,
          stream: controller.getGroupedSuppliesStream(archived: false),
          builder: (context, snapshot) {
            final hasData = snapshot.hasData && snapshot.data!.isNotEmpty;

            if (snapshot.connectionState == ConnectionState.waiting &&
                !hasData) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
              final highlightColor =
                  isDark ? Colors.grey[700]! : Colors.grey[100]!;

              return LayoutBuilder(
                builder: (context, constraints) {
                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: constraints.maxWidth > 800
                          ? 4
                          : constraints.maxWidth > 600
                              ? 3
                              : 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: constraints.maxWidth < 400 ? 0.7 : 0.85,
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
              if (!hasData) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Connection Issue',
                        style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pull down to refresh',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No supplies found',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your first supply using the + button',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            final sortedItems = controller.filterAndSortGroupedItems(
              items: snapshot.data!,
              selectedCategory: selectedCategoryName,
              searchText: searchText,
              selectedSort: selectedSort,
              filters: currentFilters,
            );

            final visibleItems = sortedItems.where((item) {
              return item.getStatus() != "Expired";
            }).toList();

            if (!_deepLinkHandled &&
                _highlightSupplyName != null &&
                _highlightSupplyName!.isNotEmpty) {
              GroupedInventoryItem? target;
              for (final g in sortedItems) {
                if (g.mainItem.name.toLowerCase() ==
                    _highlightSupplyName!.toLowerCase()) {
                  target = g;
                  break;
                }
              }
              if (target != null) {
                _deepLinkHandled = true;
                final t = target;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          InventoryViewSupplyPage(item: t.mainItem),
                    ),
                  );
                });
              }
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                double aspectRatio = constraints.maxWidth < 400 ? 0.7 : 0.85;
                return GridView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: constraints.maxWidth > 800
                        ? 4
                        : constraints.maxWidth > 600
                            ? 3
                            : 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: aspectRatio,
                  ),
                  itemCount: visibleItems.length,
                  itemBuilder: (context, index) {
                    final groupedItem = visibleItems[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InventoryViewSupplyPage(
                                item: groupedItem.mainItem),
                          ),
                        );
                      },
                      child: InventoryItemCard(
                        item: groupedItem.mainItem,
                        status: groupedItem.getStatus(),
                        currentSort: selectedSort,
                        overrideStock: groupedItem.totalStock,
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
