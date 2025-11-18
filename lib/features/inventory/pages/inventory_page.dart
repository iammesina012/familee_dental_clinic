import 'package:flutter/material.dart';
import 'package:familee_dental/shared/drawer.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/inventory/components/inventory_item_card.dart';
import 'package:familee_dental/features/inventory/components/inventory_fab.dart';
import 'package:familee_dental/features/inventory/components/inventory_filter.dart';
import 'package:familee_dental/features/inventory/components/inventory_sort.dart'; // Your sort modal
import 'package:familee_dental/features/inventory/pages/add_supply_page.dart';
import 'package:familee_dental/features/inventory/pages/view_supply_page.dart';
import 'package:familee_dental/features/inventory/pages/edit_categories_page.dart';
import 'package:familee_dental/features/inventory/controller/inventory_controller.dart';
import 'package:familee_dental/features/inventory/pages/expired_supply_page.dart';
import 'package:familee_dental/features/inventory/controller/filter_controller.dart';
import 'package:familee_dental/features/inventory/controller/categories_controller.dart';
import 'package:familee_dental/features/inventory/controller/expired_supply_controller.dart';
import 'package:familee_dental/features/inventory/pages/archive_supply_page.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/shared/widgets/notification_badge_button.dart';
import 'package:shimmer/shimmer.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/features/auth/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/shared/services/user_data_service.dart';

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

  String? _userName;
  String? _userRole;

  final _userDataService = UserDataService();

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
    // Load user data from Hive first (avoid placeholders)
    _loadUserDataFromHive();

    // Initialize default categories and migrate existing data
    _initializeData();
    // Load user data for appbar
    _loadUserData();
    // Best-effort cleanup of zero-stock duplicates when there are stocked batches
    controller.cleanupZeroStockDuplicates();
    // Convert expired supplies to placeholders
    _convertExpiredToPlaceholders();

    // Handle route arguments after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleRouteArguments();
      // Pre-population no longer needed - streams auto-load from Hive
    });
  }

  /// Load user data from Hive (no placeholders)
  Future<void> _loadUserDataFromHive() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        await _userDataService.loadFromHive(currentUser.id);
        if (mounted) {
          setState(() {
            _userName = _userDataService.userName;
            _userRole = _userDataService.userRole;
          });
        }
      }
    } catch (e) {
      // Ignore errors - best effort
    }
  }

  Future<void> _loadUserData() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser != null) {
        // Try to get user data from user_roles table (same approach as Dashboard)
        final response = await supabase
            .from('user_roles')
            .select('*')
            .eq('id', currentUser.id)
            .limit(1)
            .maybeSingle();

        if (mounted) {
          if (response != null &&
              response['name'] != null &&
              response['name'].toString().trim().isNotEmpty) {
            // Use data from user_roles table
            final name = response['name'].toString().trim();
            final role = response['role']?.toString().trim() ?? 'Admin';

            setState(() {
              _userName = name;
              _userRole = role;
            });

            // Save to Hive for persistence
            await _userDataService.saveToHive(currentUser.id, name, role);
          } else {
            // Fallback to auth user data
            final displayName =
                currentUser.userMetadata?['display_name']?.toString().trim();
            final emailName = currentUser.email?.split('@')[0].trim();
            final name = displayName ?? emailName ?? 'User';
            final role = 'Admin';

            setState(() {
              _userName = name;
              _userRole = role;
            });

            // Save to Hive for persistence
            await _userDataService.saveToHive(currentUser.id, name, role);
          }
        }
      } else {
        // If no current user, use cached data from service if available
        if (mounted) {
          setState(() {
            _userName = _userDataService.userName;
            _userRole = _userDataService.userRole;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          // Use cached data from service if available (loaded from Hive)
          _userName = _userDataService.userName;
          _userRole = _userDataService.userRole;
        });
      }
    }
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

  // Pre-populate all caches when inventory page loads (non-blocking)

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
    return WillPopScope(
      onWillPop: () async {
        // Navigate back to Dashboard when back button is pressed
        // Use popUntil to go back to existing Dashboard instead of creating a new one
        Navigator.popUntil(
            context, (route) => route.settings.name == '/dashboard');
        return false; // Prevent default back behavior
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: theme.brightness == Brightness.dark
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF5F5F5),
        drawer:
            MediaQuery.of(context).size.width >= 900 ? null : const MyDrawer(),
        body: MediaQuery.of(context).size.width >= 900
            ? _buildRailLayout(context, theme)
            : _buildInventoryContent(theme),
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
          onManageCategory: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EditCategoriesPage(),
              ),
            );
            // Refresh categories stream when returning from manage category page
            if (result == true ||
                result == 'updated' ||
                result == 'deleted' ||
                result == 'added') {
              _refreshCategoriesStream();
            }
          },
        ),
      ),
    );
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

  Widget _buildInventoryContent(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh the streams to reload data from Supabase
        _refreshAllStreams();
        // Convert expired supplies to placeholders
        _convertExpiredToPlaceholders();
        // Wait for the inventory stream to emit at least one event
        // This ensures the RefreshIndicator shows its animation
        await controller.getGroupedSuppliesStream(archived: false).first;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Panel (with notification and account)
            _buildWelcomePanel(theme),
            const SizedBox(height: 12),
            // Inventory content body - Expanded to fill remaining space
            Expanded(
              child: _buildInventoryContentBody(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryContentBody(ThemeData theme) {
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
                  fillColor: theme.colorScheme.surface,
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
                      : theme.colorScheme.surface,
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
                  backgroundColor: theme.colorScheme.surface,
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
        _buildCategoryChips(theme, theme.colorScheme),
        const SizedBox(height: 16),
        // Inventory Grid - Expanded to fill remaining space
        Expanded(
          child: _buildInventoryGrid(theme, theme.colorScheme),
        ),
      ],
    );
  }

  Widget _buildCategoryChips(ThemeData theme, ColorScheme scheme) {
    return StreamBuilder<List<String>>(
      key: _categoriesStreamKey,
      stream: categoriesController.getCategoriesStream(),
      builder: (context, snapshot) {
        final currentCategories = snapshot.data ?? [];
        final cachedCategories =
            categoriesController.cachedCategories ?? const <String>[];

        final hasCachedCategories = cachedCategories.isNotEmpty;
        final effectiveCategories = currentCategories.isNotEmpty
            ? currentCategories
            : (hasCachedCategories ? cachedCategories : currentCategories);

        final List<String> categoriesWithAll = [
          'All Supplies',
          ...effectiveCategories
        ];

        if (snapshot.connectionState == ConnectionState.waiting &&
            effectiveCategories.isEmpty &&
            !hasCachedCategories) {
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

        if (snapshot.hasError && effectiveCategories.isEmpty) {
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
        final cachedCategories =
            categoriesController.cachedCategories ?? const <String>[];
        final categoriesWithAll = [
          'All Supplies',
          ...(currentCategories.isNotEmpty
              ? currentCategories
              : (cachedCategories.isNotEmpty ? cachedCategories : []))
        ];
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

            // Show skeleton loader only if no data exists (no cached data available)
            // If cached data exists, it will show immediately instead
            if (snapshot.connectionState == ConnectionState.waiting &&
                !hasData &&
                !snapshot.hasError) {
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

            // On error, if no cached data, show empty state instead of error message
            if (snapshot.hasError && !hasData) {
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
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
                      builder: (context) => InventoryViewSupplyPage(
                        supplyName: t.mainItem.name,
                        supplyCategory: t.mainItem.category,
                        supplyType: t.mainItem.type,
                        supplyBrand: t.mainItem.brand,
                      ),
                    ),
                  );
                });
              }
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                double aspectRatio = constraints.maxWidth < 400 ? 0.65 : 0.75;
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
                        final item = groupedItem.mainItem;
                        debugPrint(
                            '[NAVIGATION] Tapping supply: ${item.name} (ID: ${item.id})');
                        debugPrint(
                            '[NAVIGATION] Image URL: ${item.imageUrl.isEmpty ? "EMPTY" : item.imageUrl}');
                        debugPrint(
                            '[NAVIGATION] Starting navigation at ${DateTime.now()}');

                        final startTime = DateTime.now();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              debugPrint(
                                  '[NAVIGATION] Building ViewSupplyPage for ${item.name} at ${DateTime.now()}');
                              return InventoryViewSupplyPage(
                                supplyName: item.name,
                                supplyCategory: item.category,
                                supplyType: item.type,
                                supplyBrand: item.brand,
                              );
                            },
                          ),
                        ).then((_) {
                          final duration = DateTime.now().difference(startTime);
                          debugPrint(
                              '[NAVIGATION] Returned from ViewSupplyPage after ${duration.inMilliseconds}ms');
                        });
                      },
                      child: InventoryItemCard(
                        item: groupedItem.mainItem,
                        status: groupedItem.getStatus(),
                        currentSort: selectedSort,
                        overrideStock: groupedItem.totalStock,
                        variants: groupedItem.variants,
                        titleOverride: groupedItem.mainItem.type != null &&
                                groupedItem.mainItem.type!.isNotEmpty
                            ? "${groupedItem.mainItem.name} (${groupedItem.mainItem.type})"
                            : null,
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

  Widget _buildWelcomePanel(ThemeData theme) {
    final userName = _userName ?? _userDataService.userName ?? 'User';
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: theme.colorScheme.surface,
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row with greeting on left and account section on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Greeting message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Inventory",
                        style: AppFonts.sfProStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Manage and track your supplies efficiently.",
                        style: AppFonts.sfProStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right side - Notification button and Account section
                Row(
                  children: [
                    // Notification button
                    const NotificationBadgeButton(),
                    const SizedBox(width: 8),
                    // Avatar with first letter
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: AppFonts.sfProStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name and role
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userName,
                          style: AppFonts.sfProStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          _userRole ?? _userDataService.userRole ?? 'Admin',
                          style: AppFonts.sfProStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRailLayout(BuildContext context, ThemeData theme) {
    // Main destinations (top section)
    final List<_RailDestination> mainDestinations = [
      _RailDestination(
          icon: Icons.dashboard, label: 'Dashboard', route: '/dashboard'),
      _RailDestination(
          icon: Icons.inventory, label: 'Inventory', route: '/inventory'),
      _RailDestination(
          icon: Icons.shopping_cart,
          label: 'Purchase Order',
          route: '/purchase-order'),
      _RailDestination(
          icon: Icons.playlist_remove,
          label: 'Stock Deduction',
          route: '/stock-deduction'),
    ];

    // Use the same role logic as drawer for conditional Activity Log
    final userRoleProvider = UserRoleProvider();
    final canAccessActivityLog = userRoleProvider.canAccessActivityLog();

    // Bottom destinations (Settings and Logout)
    final List<_RailDestination> bottomDestinations = [
      _RailDestination(
          icon: Icons.settings, label: 'Settings', route: '/settings'),
      _RailDestination(icon: Icons.logout, label: 'Logout', route: '/logout'),
    ];

    // Inventory is selected here
    final int selectedIndex = 1;

    return Row(
      children: [
        Container(
          width: 220,
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              // Logo and brand
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 35.0, 16.0, 16.0),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
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
                    const SizedBox(width: 15),
                    Flexible(
                      child: Transform.translate(
                        offset: const Offset(0, 8),
                        child: Transform.scale(
                          scale: 2.9,
                          child: theme.brightness == Brightness.dark
                              ? ColorFiltered(
                                  colorFilter: const ColorFilter.matrix([
                                    1.5, 0, 0, 0, 0, // Red channel - brighten
                                    0, 1.5, 0, 0, 0, // Green channel - brighten
                                    0, 0, 1.5, 0, 0, // Blue channel - brighten
                                    0, 0, 0, 1, 0, // Alpha channel - unchanged
                                  ]),
                                  child: Image.asset(
                                    'assets/images/logo/tita_doc_2.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Text(
                                        'FamiLee Dental',
                                        style: AppFonts.sfProStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: theme
                                              .textTheme.titleMedium?.color,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/logo/tita_doc_2.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text(
                                      'FamiLee Dental',
                                      style: AppFonts.sfProStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color:
                                            theme.textTheme.titleMedium?.color,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Navigation items
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // MENU section header
                    _buildSectionHeader(theme, 'MENU'),
                    const SizedBox(height: 8),
                    // MENU items
                    for (int i = 0; i < mainDestinations.length; i++)
                      _buildRailDestinationTile(
                        context: context,
                        theme: theme,
                        destination: mainDestinations[i],
                        isSelected: i == selectedIndex,
                        onTap: () {
                          final dest = mainDestinations[i];
                          final currentRoute =
                              ModalRoute.of(context)?.settings.name;

                          if (currentRoute != dest.route) {
                            Navigator.pushNamed(context, dest.route);
                          }
                        },
                      ),
                    // Activity Logs (if accessible) - part of MENU
                    if (canAccessActivityLog)
                      _buildRailDestinationTile(
                        context: context,
                        theme: theme,
                        destination: _RailDestination(
                          icon: Icons.history,
                          label: 'Activity Logs',
                          route: '/activity-log',
                        ),
                        isSelected: false,
                        onTap: () {
                          final currentRoute =
                              ModalRoute.of(context)?.settings.name;
                          if (currentRoute != '/activity-log') {
                            Navigator.pushNamed(context, '/activity-log');
                          }
                        },
                      ),
                  ],
                ),
              ),
              // GENERAL section at the bottom
              _buildSectionHeader(theme, 'GENERAL'),
              const SizedBox(height: 8),
              // GENERAL items
              for (int i = 0; i < bottomDestinations.length; i++)
                _buildRailDestinationTile(
                  context: context,
                  theme: theme,
                  destination: bottomDestinations[i],
                  isSelected: false,
                  onTap: () {
                    final dest = bottomDestinations[i];
                    final currentRoute = ModalRoute.of(context)?.settings.name;

                    // Handle logout separately
                    if (dest.route == '/logout') {
                      _handleLogout(context);
                      return;
                    }

                    if (currentRoute != dest.route) {
                      Navigator.pushNamed(context, dest.route);
                    }
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: theme.brightness == Brightness.dark
              ? Colors.grey.shade700
              : Colors.grey.shade200,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _refreshAllStreams();
              _convertExpiredToPlaceholders();
              await controller.getGroupedSuppliesStream(archived: false).first;
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Panel (with notification and account)
                  _buildWelcomePanel(theme),
                  const SizedBox(height: 12),
                  // Inventory content - Expanded to fill remaining space
                  Expanded(
                    child: _buildInventoryContentBody(theme),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String label) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: AppFonts.sfProStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildRailDestinationTile({
    required BuildContext context,
    required ThemeData theme,
    required _RailDestination destination,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          // Background with rounded right corners
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    destination.icon,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodyMedium?.color,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      destination.label,
                      style: AppFonts.sfProStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Vertical indicator line on the left
          if (isSelected)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    bottomLeft: Radius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await _showLogoutDialog(context);
    if (shouldLogout == true) {
      final authService = AuthService();
      await authService.logout();
      // ignore: use_build_context_synchronously
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}

class _RailDestination {
  final IconData icon;
  final String label;
  final String route;

  _RailDestination(
      {required this.icon, required this.label, required this.route});
}
