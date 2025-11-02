import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/stock_deduction/controller/sd_preset_management_controller.dart';
import 'package:familee_dental/features/stock_deduction/controller/sd_approval_controller.dart';
import 'package:familee_dental/features/stock_deduction/pages/sd_edit_preset_page.dart';
import 'package:familee_dental/features/activity_log/controller/sd_activity_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/widgets/notification_badge_button.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceManagementPage extends StatefulWidget {
  const ServiceManagementPage({super.key});

  @override
  State<ServiceManagementPage> createState() => _ServiceManagementPageState();
}

class _ServiceManagementPageState extends State<ServiceManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  final PresetController _presetController = PresetController();
  final SdActivityController _activityController = SdActivityController();
  List<Map<String, dynamic>> _allPresets = [];
  List<Map<String, dynamic>> _filteredPresets = [];
  List<Map<String, dynamic>> _lastKnownPresets = []; // Cache last known data
  Timer? _debounceTimer;
  // Stream key for forcing refresh
  late Stream<List<Map<String, dynamic>>> _presetsStream;
  int _streamKey = 0;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializeStream();
  }

  void _initializeStream() {
    // Show only user-created presets in Service Management
    // Exclude deduction log presets (from_deduction: true) - those belong in Deduction Logs only
    _presetsStream = PresetController().getPresetsStream().map((presets) =>
        presets
            .where((preset) =>
                preset['from_deduction'] != true &&
                preset['fromDeduction'] != true)
            .toList());
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    // Update immediately for real-time search feedback
    _debounceTimer?.cancel();
    if (!mounted) return;
    _filterPresets();
    setState(() {});
  }

  void _filterPresets() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      _filteredPresets = _allPresets;
    } else {
      _filteredPresets = _allPresets.where((preset) {
        final presetName = preset['name']?.toString().toLowerCase() ?? '';

        // Check if the name starts with the search text
        if (presetName.startsWith(query)) {
          return true;
        }

        // Check if any word in the name starts with the search text
        final words = presetName.split(' ');
        for (final word in words) {
          if (word.startsWith(query)) {
            return true;
          }
        }

        return false;
      }).toList();
    }
  }

  // Pull-to-refresh method
  Future<void> _refreshPresets() async {
    // Force stream refresh by recreating it
    _streamKey++;
    _initializeStream();
    setState(() {});

    // Wait for the stream to emit at least one event
    // This ensures the RefreshIndicator shows its animation
    await _presetsStream.first;
  }

  void _createNewPreset() async {
    final result =
        await Navigator.of(context).pushNamed('/stock-deduction/create-preset');
    if (result is Map<String, dynamic>) {
      try {
        await _presetController.savePreset(result);

        // Log the preset creation activity
        final presetName = result['name'] ?? 'Unknown Preset';
        final supplies = (result['supplies'] as List<dynamic>?) ?? [];
        final suppliesList = supplies.cast<Map<String, dynamic>>();
        await _activityController.logPresetCreated(
          presetName: presetName,
          supplies: suppliesList,
        );

        if (!mounted) return;

        // Force refresh the stream to show the new preset immediately
        _refreshPresets();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Preset saved successfully',
              style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF00D4AA),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save preset: $e',
              style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ResponsiveContainer(
      maxWidth: 1100,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // Search bar skeleton
              Shimmer.fromColors(
                baseColor: baseColor,
                highlightColor: highlightColor,
                child: Container(
                  height: 56,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Preset cards skeleton
              Expanded(
                child: ListView.builder(
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      child: Container(
                        height: 120,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Service Management',
          style: AppFonts.sfProStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).appBarTheme.titleTextStyle?.color ??
                  Theme.of(context).textTheme.titleLarge?.color),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
        elevation: Theme.of(context).appBarTheme.elevation ?? 5,
        shadowColor: Theme.of(context).appBarTheme.shadowColor ??
            Theme.of(context).shadowColor,
        actions: [
          const NotificationBadgeButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewPreset,
        backgroundColor: const Color(0xFF00D4AA),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPresets,
        color: const Color(0xFF00D4AA),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          key: ValueKey(_streamKey),
          stream: _presetsStream,
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

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading presets: ${snapshot.error}',
                  style: AppFonts.sfProStyle(fontSize: 16, color: Colors.red),
                ),
              );
            }

            // Update data and cache it when we have valid data
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              _allPresets = snapshot.data!;
              _lastKnownPresets = List.from(snapshot.data!);
            } else if (snapshot.hasData &&
                snapshot.data!.isEmpty &&
                _lastKnownPresets.isEmpty) {
              // Only update to empty if we never had data
              _allPresets = [];
            } else if (!snapshot.hasData && _lastKnownPresets.isNotEmpty) {
              // During refresh, use cached data
              _allPresets = _lastKnownPresets;
            } else {
              _allPresets = snapshot.data ?? [];
            }

            _filterPresets();

            return ResponsiveContainer(
              maxWidth: 1100,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    children: [
                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .shadowColor
                                  .withOpacity(0.08),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                          border: Border.all(
                            color:
                                Theme.of(context).dividerColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search services...',
                            hintStyle: AppFonts.sfProStyle(
                              fontSize: 16,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withOpacity(0.6),
                            ),
                            prefixIcon: Icon(Icons.search,
                                color: Theme.of(context).iconTheme.color),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          style: AppFonts.sfProStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Theme.of(context).colorScheme.surface
                                    : const Color(0xFFE8D5E8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.2)),
                          ),
                          child: _filteredPresets.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _filteredPresets.length,
                                  itemBuilder: (context, index) {
                                    final preset = _filteredPresets[index];
                                    return _buildPresetCard(preset, index);
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF8B5A8B);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey.withOpacity(0.2)
                  : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.bookmark_outline,
              size: 60,
              color: isDark
                  ? Colors.white.withOpacity(0.7)
                  : const Color(0xFF8B5A8B),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchController.text.isEmpty
                ? 'No Presets Created Yet'
                : 'No Presets Found',
            style: AppFonts.sfProStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty
                ? 'Use the + button to create a new preset'
                : 'Try adjusting your search terms',
            style: AppFonts.sfProStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard(Map<String, dynamic> preset, int index) {
    final presetId = preset['id'] ?? index.toString();
    final supplies = preset['supplies'] as List<dynamic>? ?? [];

    return Slidable(
      key: ValueKey('preset-$presetId'),
      closeOnScroll: true,
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => _editPreset(preset),
            backgroundColor: const Color(0xFF00D4AA),
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => _deletePreset(preset),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Remove',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: Theme.of(context).colorScheme.surface,
        elevation: 2,
        shadowColor: Theme.of(context).shadowColor.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.2)),
        ),
        child: InkWell(
          onTap: () {
            _showPresetDetailModal(preset);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.bookmark,
                        color: const Color(0xFF00D4AA),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              preset['name'] ?? 'Unnamed Preset',
                              style: AppFonts.sfProStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${supplies.length} supplies',
                              style: AppFonts.sfProStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).iconTheme.color?.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _editPreset(Map<String, dynamic> preset) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditPresetPage(preset: preset),
      ),
    );

    if (result == true) {
      // Preset was updated successfully
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Preset updated successfully',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF00D4AA),
        ),
      );
    }
  }

  void _deletePreset(Map<String, dynamic> preset) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Delete Preset',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "${preset['name']}"? This action cannot be undone.',
            style: AppFonts.sfProStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style:
                    AppFonts.sfProStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _presetController.deletePreset(preset['id']);
                  // Log deleted preset activity with supplies
                  final List<Map<String, dynamic>> supplies =
                      ((preset['supplies'] as List?) ?? [])
                          .map((e) => e is Map
                              ? Map<String, dynamic>.from(e)
                              : <String, dynamic>{})
                          .where((m) => m.isNotEmpty)
                          .toList();
                  await _activityController.logPresetDeleted(
                    presetName: (preset['name'] ?? '').toString(),
                    supplies: supplies,
                  );
                  if (!mounted) return;
                  Navigator.of(context).pop();

                  // Force refresh the stream to remove the deleted preset immediately
                  _refreshPresets();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Preset deleted successfully',
                        style: AppFonts.sfProStyle(
                            fontSize: 14, color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFF00D4AA),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to delete preset: $e',
                        style: AppFonts.sfProStyle(
                            fontSize: 14, color: Colors.white),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(
                'Delete',
                style: AppFonts.sfProStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPresetDetailModal(Map<String, dynamic> preset) {
    final supplies = List<Map<String, dynamic>>.from(preset['supplies'] ?? []);

    // Create editable copy of supplies with quantities
    final List<Map<String, dynamic>> editableSupplies = supplies.map((supply) {
      return {
        ...supply,
        'quantity': supply['quantity'] ?? 1,
      };
    }).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PresetDetailModal(
        preset: preset,
        supplies: editableSupplies,
      ),
    );
  }
}

class _PresetDetailModal extends StatefulWidget {
  final Map<String, dynamic> preset;
  final List<Map<String, dynamic>> supplies;

  const _PresetDetailModal({
    required this.preset,
    required this.supplies,
  });

  @override
  State<_PresetDetailModal> createState() => _PresetDetailModalState();
}

class _PresetDetailModalState extends State<_PresetDetailModal> {
  late List<Map<String, dynamic>> _editableSupplies;
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _conditionsController = TextEditingController();
  String? _selectedSex; // Changed from Gender to Sex
  final SupabaseClient _supabase = Supabase.instance.client;

  // Validation error messages
  String? _patientNameError;
  String? _ageError;
  String? _sexError;
  String? _conditionsError;

  // Map to store inventory stock for each supply
  Map<String, int> _inventoryStock = {};

  @override
  void initState() {
    super.initState();
    _editableSupplies = List.from(widget.supplies);
    // Ensure all supplies have a quantity field initialized
    for (var supply in _editableSupplies) {
      if (supply['quantity'] == null) {
        supply['quantity'] = 0;
      }
    }

    // Load saved patient information from preset
    final preset = widget.preset;
    if (preset['patient_name'] != null &&
        preset['patient_name'].toString().isNotEmpty) {
      _patientNameController.text = preset['patient_name'].toString();
    }
    if (preset['age'] != null && preset['age'].toString().isNotEmpty) {
      _ageController.text = preset['age'].toString();
    }
    if (preset['gender'] != null && preset['gender'].toString().isNotEmpty) {
      _selectedSex = preset['gender'].toString();
    }
    if (preset['conditions'] != null &&
        preset['conditions'].toString().isNotEmpty) {
      _conditionsController.text = preset['conditions'].toString();
    }

    _fetchInventoryStock();
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _ageController.dispose();
    _conditionsController.dispose();
    super.dispose();
  }

  // Fetch inventory stock for all supplies and update the supply directly
  Future<void> _fetchInventoryStock() async {
    try {
      for (final supply in _editableSupplies) {
        final supplyId = supply['docId'] ?? supply['id'];
        final supplyName = supply['name'] ?? '';
        final supplyType = supply['type'] ?? '';

        if (supplyId != null && supplyId.toString().isNotEmpty) {
          // Query by ID
          final response = await _supabase
              .from('supplies')
              .select('stock')
              .eq('id', supplyId.toString())
              .maybeSingle();

          if (response != null) {
            final stock = (response['stock'] ?? 0) as int;
            _inventoryStock[supplyId.toString()] = stock;
            // Also update the supply directly with stock field
            supply['stock'] = stock;
          }
        } else if (supplyName.isNotEmpty) {
          // Query by name and type
          var query = _supabase
              .from('supplies')
              .select('stock, type')
              .eq('name', supplyName);

          if (supplyType.isNotEmpty) {
            query = query.eq('type', supplyType);
          }

          final response = await query.maybeSingle();

          if (response != null) {
            final stock = (response['stock'] ?? 0) as int;
            final key =
                supplyType.isNotEmpty ? '$supplyName|$supplyType' : supplyName;
            _inventoryStock[key] = stock;
            // Also update the supply directly with stock field
            supply['stock'] = stock;
          }
        }
      }
      if (mounted) setState(() {});
    } catch (e) {
      print('Error fetching inventory stock: $e');
    }
  }

  // Get available stock for a supply
  int _getAvailableStock(Map<String, dynamic> supply) {
    // First, check if the supply has stock field directly
    if (supply['stock'] != null) {
      return (supply['stock'] ?? 0) as int;
    }

    // Otherwise, check the inventory stock map
    final supplyId = supply['docId'] ?? supply['id'];
    final supplyName = supply['name'] ?? '';
    final supplyType = supply['type'] ?? '';

    if (supplyId != null && supplyId.toString().isNotEmpty) {
      return _inventoryStock[supplyId.toString()] ?? 0;
    } else if (supplyName.isNotEmpty) {
      final key =
          supplyType.isNotEmpty ? '$supplyName|$supplyType' : supplyName;
      return _inventoryStock[key] ?? 0;
    }
    return 0;
  }

  // Format expiry date
  String _formatExpiry(dynamic expiry, bool? noExpiry) {
    if (noExpiry == true) return 'No Expiry';
    if (expiry == null || expiry.toString().isEmpty) return 'No Expiry';
    final expiryStr = expiry.toString();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(expiryStr)) {
      return expiryStr.replaceAll('-', '/');
    }
    return expiryStr;
  }

  // Format packaging info
  String _formatPackaging(Map<String, dynamic> supply) {
    final packagingContentQuantity = supply['packagingContentQuantity'];
    final packagingContent = supply['packagingContent'];
    final packagingUnit = supply['packagingUnit'];

    if (packagingContent != null &&
        packagingContent.toString().isNotEmpty &&
        packagingUnit != null &&
        packagingUnit.toString().isNotEmpty) {
      // Format: "10mL per Bottle"
      return '${packagingContentQuantity ?? ''} ${packagingContent} per $packagingUnit';
    } else if (packagingUnit != null && packagingUnit.toString().isNotEmpty) {
      // Format: "pieces" (just the unit)
      return packagingUnit.toString();
    }
    return '';
  }

  // Get quantity unit label with proper pluralization
  String _getQuantityUnitLabel(String? unit, int quantity) {
    if (unit == null || unit.toString().isEmpty) return '';
    final unitStr = unit.toString().trim();

    // If quantity is 1, return singular form
    if (quantity == 1) {
      return unitStr;
    }

    // If the word already ends with 's' (like "Pieces", "Boxes", etc.), it's already plural
    // Just return it as is
    if (unitStr.toLowerCase().endsWith('s')) {
      return unitStr;
    }

    // Handle pluralization for words that don't already end with 's'
    if (unitStr.toLowerCase().endsWith('y')) {
      return '${unitStr.substring(0, unitStr.length - 1)}ies';
    } else if (unitStr.toLowerCase().endsWith('x') ||
        unitStr.toLowerCase().endsWith('ch') ||
        unitStr.toLowerCase().endsWith('sh')) {
      return '${unitStr}es';
    } else {
      return '${unitStr}s';
    }
  }

  void _incrementQty(int index) {
    setState(() {
      final supply = _editableSupplies[index];
      final int current = (supply['quantity'] ?? 0) as int;
      final int availableStock = _getAvailableStock(supply);

      // Limit to available stock (exactly like quick deduction does)
      // Don't allow incrementing beyond available stock
      if (availableStock > 0 && current < availableStock) {
        final int next = current + 1;
        _editableSupplies[index]['quantity'] = next;
      }
      // If availableStock is 0 or current >= availableStock, don't increment
    });
  }

  void _decrementQty(int index) {
    setState(() {
      final current = (_editableSupplies[index]['quantity'] ?? 0) as int;
      if (current > 0) {
        _editableSupplies[index]['quantity'] = current - 1;
      }
    });
  }

  void _addAdditionalSupply() async {
    // Use the add supply page for presets
    final existingDocIds = _editableSupplies
        .map((e) => (e['docId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    final result = await Navigator.of(context).pushNamed(
      '/stock-deduction/add-supply-for-preset',
      arguments: {'existingDocIds': existingDocIds},
    );

    if (result != null) {
      setState(() {
        if (result is Map<String, dynamic>) {
          _editableSupplies.add({
            ...result,
            'quantity': 0, // Changed from 1 to 0 to allow setting to 0
          });
        } else if (result is List) {
          for (final supply in result) {
            if (supply is Map<String, dynamic>) {
              _editableSupplies.add({
                ...supply,
                'quantity': 0, // Changed from 1 to 0 to allow setting to 0
              });
            }
          }
        }
      });
      // Fetch inventory stock for the newly added supplies
      await _fetchInventoryStock();
    }
  }

  void _removeSupply(int index) {
    setState(() {
      _editableSupplies.removeAt(index);
    });
  }

  void _saveAndUsePreset() async {
    // Validate required fields with inline errors
    final patientName = _patientNameController.text.trim();
    final age = _ageController.text.trim();
    final conditions = _conditionsController.text.trim();

    setState(() {
      // Clear previous errors
      _patientNameError = null;
      _ageError = null;
      _sexError = null;
      _conditionsError = null;

      // Validate
      if (patientName.isEmpty) {
        _patientNameError = 'Please enter Patient Name';
      }

      if (age.isEmpty) {
        _ageError = 'Please enter Age';
      }

      if (_selectedSex == null || _selectedSex!.isEmpty) {
        _sexError = 'Please select Sex';
      }

      if (conditions.isEmpty) {
        _conditionsError = 'Please enter Conditions';
      }
    });

    // Return if any validation errors
    if (_patientNameError != null ||
        _ageError != null ||
        _sexError != null ||
        _conditionsError != null) {
      return;
    }

    // Save to approval queue
    try {
      final approvalController = ApprovalController();
      final approvalData = {
        'presetName': widget.preset['name'] ?? 'Unknown Preset',
        'supplies': _editableSupplies,
        'patientName': patientName,
        'age': age,
        'gender': _selectedSex, // Store as gender for backward compatibility
        'sex': _selectedSex, // Also store as sex
        'conditions': conditions,
      };

      await approvalController.saveApproval(approvalData);

      if (!mounted) return;

      Navigator.of(context).pop(); // Close modal
      Navigator.of(context).pop(); // Close Service Management page

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved to Approval',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF00D4AA),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Don't close modal on error - let user see the error and try again
      String errorMessage = 'Failed to save approval';
      if (e.toString().contains('404') || e.toString().contains('Not Found')) {
        errorMessage =
            'Please create the stock_deduction_approvals table in Supabase. The table is missing.';
      } else {
        errorMessage = 'Failed to save approval: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 600,
          maxHeight: 800,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button - Fixed at top
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 12, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.preset['name'] ?? 'Unknown Preset',
                      style: AppFonts.sfProStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: isDark ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Information Fields
                    Text(
                      'Patient Information',
                      style: AppFonts.sfProStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Patient Name
                    TextField(
                      controller: _patientNameController,
                      decoration: InputDecoration(
                        labelText: 'Patient Name *',
                        labelStyle: AppFonts.sfProStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        hintText: 'Required',
                        hintStyle: AppFonts.sfProStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color:
                                isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _patientNameError != null
                                ? Colors.red
                                : (isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[300]!),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _patientNameError != null
                                ? Colors.red
                                : const Color(0xFF00D4AA),
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        errorText: _patientNameError,
                        errorStyle: AppFonts.sfProStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                      style: AppFonts.sfProStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                      onChanged: (_) {
                        if (_patientNameError != null) {
                          setState(() {
                            _patientNameError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Age and Gender Row
                    Row(
                      children: [
                        // Age
                        Expanded(
                          child: TextField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Age *',
                              labelStyle: AppFonts.sfProStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                              hintText: 'Required',
                              hintStyle: AppFonts.sfProStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[400],
                              ),
                              filled: true,
                              fillColor:
                                  isDark ? Colors.grey[800] : Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _ageError != null
                                      ? Colors.red
                                      : (isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[300]!),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _ageError != null
                                      ? Colors.red
                                      : const Color(0xFF00D4AA),
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              errorText: _ageError,
                              errorStyle: AppFonts.sfProStyle(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                            ),
                            style: AppFonts.sfProStyle(
                              fontSize: 16,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A),
                            ),
                            onChanged: (_) {
                              if (_ageError != null) {
                                setState(() {
                                  _ageError = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Sex (changed from Gender)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                value: _selectedSex,
                                decoration: InputDecoration(
                                  labelText: 'Sex *',
                                  labelStyle: AppFonts.sfProStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _sexError != null
                                          ? Colors.red
                                          : (isDark
                                              ? Colors.grey[700]!
                                              : Colors.grey[300]!),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: _sexError != null
                                          ? Colors.red
                                          : const Color(0xFF00D4AA),
                                      width: 2,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.red,
                                      width: 2,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Colors.red,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  errorText: _sexError,
                                  errorStyle: AppFonts.sfProStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                                items: ['Male', 'Female'].map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value,
                                      style: AppFonts.sfProStyle(
                                        fontSize: 16,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedSex = newValue;
                                    if (_sexError != null) {
                                      _sexError = null;
                                    }
                                  });
                                },
                                style: AppFonts.sfProStyle(
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A1A),
                                ),
                                dropdownColor:
                                    isDark ? Colors.grey[800] : Colors.white,
                                icon: Icon(
                                  Icons.arrow_drop_down,
                                  color:
                                      isDark ? Colors.white : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Conditions
                    TextField(
                      controller: _conditionsController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Conditions *',
                        labelStyle: AppFonts.sfProStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        hintText: 'Required',
                        hintStyle: AppFonts.sfProStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color:
                                isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _conditionsError != null
                                ? Colors.red
                                : (isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[300]!),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _conditionsError != null
                                ? Colors.red
                                : const Color(0xFF00D4AA),
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.red,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        errorText: _conditionsError,
                        errorStyle: AppFonts.sfProStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                      style: AppFonts.sfProStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                      onChanged: (_) {
                        if (_conditionsError != null) {
                          setState(() {
                            _conditionsError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Supplies List
                    _editableSupplies.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                'No supplies in this preset',
                                style: AppFonts.sfProStyle(
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _editableSupplies.length,
                            itemBuilder: (context, index) {
                              final supply = _editableSupplies[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Supply Image
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        supply['imageUrl'] ?? '',
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 50,
                                          height: 50,
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.inventory,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Supply Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Supply name with type
                                          Text(
                                            (supply['name'] ??
                                                    'Unknown Supply') +
                                                (supply['type'] != null &&
                                                        supply['type']
                                                            .toString()
                                                            .isNotEmpty
                                                    ? ' (${supply['type']})'
                                                    : ''),
                                            style: AppFonts.sfProStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Packaging info and expiry
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              // Packaging info (left side)
                                              Flexible(
                                                child: Text(
                                                  _formatPackaging(supply),
                                                  style: AppFonts.sfProStyle(
                                                    fontSize: 12,
                                                    color: isDark
                                                        ? Colors.grey[400]
                                                        : Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              // Expiry (right side)
                                              Text(
                                                _formatExpiry(
                                                  supply['expiry'],
                                                  supply['noExpiry'] as bool?,
                                                ),
                                                style: AppFonts.sfProStyle(
                                                  fontSize: 12,
                                                  color: isDark
                                                      ? Colors.grey[400]
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Quantity Controls
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () => _removeSupply(index),
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color: Colors.red[400],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.grey[700]
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.grey[600]!
                                                  : Colors.grey[300]!,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                (_editableSupplies[index]
                                                            ['quantity'] ??
                                                        0)
                                                    .toString(),
                                                style: AppFonts.sfProStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF1A1A1A),
                                                ),
                                              ),
                                              if (supply['packagingUnit'] !=
                                                      null &&
                                                  supply['packagingUnit']
                                                      .toString()
                                                      .isNotEmpty) ...[
                                                const SizedBox(width: 4),
                                                Text(
                                                  _getQuantityUnitLabel(
                                                    supply['packagingUnit'],
                                                    (_editableSupplies[index]
                                                            ['quantity'] ??
                                                        0) as int,
                                                  ),
                                                  style: AppFonts.sfProStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF1A1A1A),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          onPressed: () => _decrementQty(index),
                                          icon: Icon(
                                            Icons.remove_circle_outline,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.grey[700],
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => _incrementQty(index),
                                          icon: Icon(
                                            Icons.add_circle_outline,
                                            color: const Color(0xFF00D4AA),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                    const SizedBox(height: 16),

                    // Add Additional Supply Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _addAdditionalSupply,
                        icon: const Icon(Icons.add),
                        label: Text(
                          'Add Additional Supply',
                          style: AppFonts.sfProStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(
                            color: Color(0xFF00D4AA),
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveAndUsePreset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4AA),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Save',
                          style: AppFonts.sfProStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
