import 'package:flutter/material.dart';
import 'package:projects/shared/drawer.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';
import 'package:projects/features/inventory/components/inventory_item_card.dart';
import 'package:projects/features/inventory/components/inventory_fab.dart';
import 'package:projects/features/inventory/components/inventory_filter.dart';
import 'package:projects/features/inventory/components/inventory_sort.dart'; // Your sort modal
import 'package:projects/features/inventory/pages/add_supply_page.dart';
import 'package:projects/features/inventory/pages/view_supply_page.dart';
import 'package:projects/features/inventory/pages/add_category_page.dart';
import 'package:projects/features/inventory/pages/edit_categories_page.dart';
import '../controller/inventory_controller.dart';
import '../controller/filter_controller.dart';
import '../controller/categories_controller.dart';
import 'package:projects/features/inventory/pages/archive_supply_page.dart';

class Inventory extends StatefulWidget {
  const Inventory({super.key});

  @override
  State<Inventory> createState() => _InventoryState();
}

class _InventoryState extends State<Inventory> {
  int selectedCategory = 0;

  final TextEditingController searchController = TextEditingController();
  String searchText = '';

  String? selectedSort = "Name (A → Z)";

  // Filter state
  Map<String, dynamic> currentFilters = {};

  // Use the controller for all logic
  final InventoryController controller = InventoryController();
  final FilterController filterController = FilterController();
  final CategoriesController categoriesController = CategoriesController();

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

  @override
  void initState() {
    super.initState();
    // Initialize default categories and migrate existing data
    _initializeData();
  }

  Future<void> _initializeData() async {
    await categoriesController.initializeDefaultCategories();
    await filterController.migrateExistingBrandsAndSuppliers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF9EFF2),
      appBar: AppBar(
        title: const Text(
          "Inventory",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                // Notification logic here
              },
            ),
          ),
        ],
      ),
      drawer: const MyDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                            ? Color(0xFF4E38D4)
                            : Colors.white,
                        foregroundColor: currentFilters.isNotEmpty
                            ? Colors.white
                            : Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
                      ),
                      onPressed: () => _showFilterModal(context),
                      child: Icon(Icons.filter_alt_outlined),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
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
              const SizedBox(height: 12),
              StreamBuilder<List<String>>(
                stream: categoriesController.getCategoriesStream(),
                builder: (context, snapshot) {
                  final currentCategories = snapshot.data ?? [];
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SizedBox(height: 50);
                  }

                  if (snapshot.hasError) {
                    return SizedBox(
                      height: 50,
                      child: Center(
                        child: Text(
                          'Error loading categories',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }

                  if (currentCategories.isEmpty) {
                    return SizedBox(
                      height: 50,
                      child: Center(
                        child: Text(
                          'No categories available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          List.generate(currentCategories.length, (index) {
                        final isSelected = selectedCategory == index;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(currentCategories[index]),
                            selected: isSelected,
                            showCheckmark: false,
                            selectedColor: Color(0xFF4E38D4),
                            backgroundColor: Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: isSelected
                                    ? Color(0xFF4E38D4)
                                    : Colors.grey.shade400,
                              ),
                            ),
                            onSelected: (selected) {
                              setState(() {
                                selectedCategory = index;
                              });
                            },
                          ),
                        );
                      }),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Firestore-powered, category-filtered, search-filtered, responsive grid
              Expanded(
                child: StreamBuilder<List<String>>(
                  stream: categoriesController.getCategoriesStream(),
                  builder: (context, categorySnapshot) {
                    final currentCategories = categorySnapshot.data ?? [];
                    final selectedCategoryName = currentCategories.isNotEmpty &&
                            selectedCategory < currentCategories.length
                        ? currentCategories[selectedCategory]
                        : "";

                    return StreamBuilder<List<GroupedInventoryItem>>(
                      stream:
                          controller.getGroupedSuppliesStream(archived: false),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: SizedBox(),
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
                                  'Error loading inventory',
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

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            double aspectRatio =
                                constraints.maxWidth < 400 ? 0.8 : 0.95;
                            return GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: aspectRatio,
                                ),
                                itemCount: sortedItems.length,
                                itemBuilder: (context, index) {
                                  final groupedItem = sortedItems[index];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              InventoryViewSupplyPage(
                                                  item: groupedItem.mainItem),
                                        ),
                                      );
                                    },
                                    child: InventoryItemCard(
                                      item: groupedItem.mainItem,
                                      status: groupedItem.getStatus(),
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
      floatingActionButton: InventoryFAB(
        onAddSupply: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddSupplyPage(),
            ),
          );
        },
        onArchivedSupply: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ArchiveSupplyPage(),
            ),
          );
        },
        onAddCategory: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddCategoryPage(),
            ),
          );
        },
        onEditCategory: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditCategoriesPage(),
            ),
          );
        },
      ),
    );
  }
}
