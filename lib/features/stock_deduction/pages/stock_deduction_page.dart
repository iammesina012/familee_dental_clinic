import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:familee_dental/shared/drawer.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/stock_deduction/controller/stock_deduction_controller.dart';
import 'package:familee_dental/features/inventory/controller/inventory_controller.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/activity_log/controller/sd_activity_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/widgets/notification_badge_button.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/features/auth/services/auth_service.dart';

class StockDeductionPage extends StatefulWidget {
  const StockDeductionPage({super.key});

  @override
  State<StockDeductionPage> createState() => _StockDeductionPageState();
}

class _StockDeductionPageState extends State<StockDeductionPage> {
  final List<Map<String, dynamic>> _deductions = [];
  final StockDeductionController _controller = StockDeductionController();
  final InventoryController _inventoryController = InventoryController();
  final SdActivityController _activityController = SdActivityController();
  OverlayEntry? _undoOverlayEntry;
  Route? _currentRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _currentRoute = ModalRoute.of(context);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newRoute = ModalRoute.of(context);
    if (_currentRoute != newRoute) {
      _currentRoute = newRoute;
      // Remove undo banner when navigating away from this page
      _removeUndoOverlay();
    }
  }

  @override
  void dispose() {
    _removeUndoOverlay();
    super.dispose();
  }

  void _openAddSupply() async {
    final existingDocIds = _deductions
        .map((e) => (e['docId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
    final result = await Navigator.of(context).pushNamed(
      '/stock-deduction/add-supply',
      arguments: {'existingDocIds': existingDocIds},
    );
    if (result is Map<String, dynamic>) {
      final int stock = (result['stock'] ?? 0) as int;
      if (stock <= 0) {
        await _showOutOfStockDialog(
            result['name']?.toString() ?? 'This supply');
        return;
      }

      final docId = result['docId']?.toString();
      final existsIndex = _deductions.indexWhere((e) => e['docId'] == docId);
      if (existsIndex != -1) {
        // Duplicate found - show dialog
        await _showDuplicateDialog(result['name']?.toString() ?? 'This supply');
        return;
      }

      setState(() {
        _deductions.add({
          ...result,
          'deductQty': stock > 0 ? 1 : 0,
        });
      });
    } else if (result is List) {
      for (final dynamic r in result) {
        if (r is Map<String, dynamic>) {
          final int stock = (r['stock'] ?? 0) as int;
          if (stock <= 0) {
            continue; // skip out of stock in bulk add
          }
          final docId = r['docId']?.toString();
          final existsIndex =
              _deductions.indexWhere((e) => e['docId'] == docId);
          if (existsIndex != -1) {
            // Duplicate found - show dialog
            await _showDuplicateDialog(r['name']?.toString() ?? 'This supply');
            return;
          }
        }
      }

      // If no duplicates found, add all items
      setState(() {
        for (final dynamic r in result) {
          if (r is Map<String, dynamic>) {
            final int stock = (r['stock'] ?? 0) as int;
            if (stock > 0) {
              _deductions.add({
                ...r,
                'deductQty': stock > 0 ? 1 : 0,
              });
            }
          }
        }
      });
    }
  }

  void _incrementQty(int index) {
    setState(() {
      final int current = (_deductions[index]['deductQty'] as int);
      final int maxStock = (_deductions[index]['stock'] ?? 0) as int;
      final int next = current + 1;
      // Limit to both max stock and 99
      final int limit = maxStock < 99 ? maxStock : 99;
      _deductions[index]['deductQty'] = next > limit ? limit : next;
    });
  }

  void _decrementQty(int index) {
    setState(() {
      final current = _deductions[index]['deductQty'] as int;
      if (current > 1) {
        _deductions[index]['deductQty'] = current - 1;
      }
    });
  }

  void _removeDeductionAt(int index) {
    setState(() {
      _deductions.removeAt(index);
    });
  }

  // Intentionally no snackbar/info popups here for duplicates; handled in Add Supply page

  Future<void> _save() async {
    if (_deductions.isEmpty) return;

    // Show confirmation dialog
    final shouldDeduct = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Confirm Deduction',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to deduct ${_deductions.length} ${_deductions.length == 1 ? 'supply' : 'supplies'}?',
            style: AppFonts.sfProStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style:
                    AppFonts.sfProStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4AA)),
              child: Text(
                'Deduct',
                style: AppFonts.sfProStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDeduct != true) return;

    // Store the deductions for potential undo
    final deductionsToApply = List<Map<String, dynamic>>.from(_deductions);

    try {
      await _controller.applyDeductions(deductionsToApply);
      if (!mounted) return;

      _showUndoBanner(deductionsToApply);

      setState(() {
        _deductions.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to deduct stock: $e',
            style: AppFonts.sfProStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _undoDeductions(
      List<Map<String, dynamic>> deductionsToUndo) async {
    try {
      // Always close the banner immediately, even if we're on a different page
      _removeUndoOverlay();

      // Revert by increasing stock back using controller's revert method
      await _controller.revertDeductions(deductionsToUndo);

      // Show success snackbar on this page
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deduction reverted successfully',
              style: AppFonts.sfProStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white),
            ),
            backgroundColor: const Color(0xFF00D4AA),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Ensure banner is closed even on errors
      _removeUndoOverlay();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Failed to revert deduction: $e',
            style: AppFonts.sfProStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  void _showUndoBanner(List<Map<String, dynamic>> deductionsToApply) {
    _removeUndoOverlay();
    final overlay = Overlay.of(context);

    _undoOverlayEntry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          top: MediaQuery.of(ctx).padding.top + 50,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(
                  maxWidth: 360, minHeight: 60, maxHeight: 90),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFEE5A52)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B6B).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.inventory_2_outlined,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${deductionsToApply.length} ${deductionsToApply.length == 1 ? 'supply' : 'supplies'} deducted',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.sfProStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You can undo this action.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.sfProStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _undoDeductions(deductionsToApply),
                      child: Text(
                        'Undo',
                        style: AppFonts.sfProStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _removeUndoOverlay,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_undoOverlayEntry!);

    // Auto-hide after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      _removeUndoOverlay();
    });
  }

  void _removeUndoOverlay() {
    _undoOverlayEntry?.remove();
    _undoOverlayEntry = null;
  }

  void _createPreset() async {
    final result =
        await Navigator.of(context).pushNamed('/stock-deduction/presets');
    if (result is Map<String, dynamic> && result['action'] == 'use_preset') {
      final preset = result['preset'] as Map<String, dynamic>;
      await _loadPresetIntoDeductions(preset);
    }
  }

  Future<void> _loadPresetIntoDeductions(Map<String, dynamic> preset) async {
    try {
      final supplies = preset['supplies'] as List<dynamic>? ?? [];

      // Check if ALL supplies from the preset are already in the current deductions list
      final List<String> existingSupplyNames = _deductions
          .map((e) =>
              '${e['name']?.toString() ?? ''} - ${e['brand']?.toString() ?? ''}')
          .toList();

      final List<String> presetSupplyNames = supplies
          .map((e) =>
              '${e['name']?.toString() ?? ''} - ${e['brand']?.toString() ?? ''}')
          .toList();

      final List<String> duplicates = existingSupplyNames
          .where((name) => presetSupplyNames.contains(name))
          .toList();

      // Only prevent loading if ALL supplies from the preset are already in the list
      if (duplicates.length == presetSupplyNames.length &&
          presetSupplyNames.isNotEmpty) {
        await _showPresetAlreadyLoadedDialog(
            preset['name']?.toString() ?? 'This preset');
        return;
      }

      // Get current inventory data to update stock and expiry information
      // Use inventory controller instead of catalog controller for proper FIFO logic
      List<GroupedInventoryItem> currentInventory = [];
      try {
        currentInventory = await _inventoryController
            .getGroupedSuppliesStream(archived: false)
            .first;
      } catch (e) {
        print('Error loading current inventory: $e');
        // Continue with empty inventory - will handle as missing items
      }

      setState(() {
        _deductions.clear();
        for (final supply in supplies) {
          if (supply is Map<String, dynamic>) {
            final supplyName = supply['name']?.toString() ?? '';
            final supplyBrand = supply['brand']?.toString() ?? '';

            // Find current inventory data for this supply by name and brand
            GroupedInventoryItem? currentItem;
            try {
              currentItem = currentInventory.firstWhere(
                (item) =>
                    item.mainItem.name == supplyName &&
                    item.mainItem.brand == supplyBrand,
              );
            } catch (e) {
              currentItem = null;
            }

            if (currentItem != null) {
              // Block expired items from deduction. Treat them as missing (0 stock, no expiry).
              if (currentItem.getStatus() == 'Expired') {
                _deductions.add({
                  'docId': null,
                  'name': currentItem.mainItem.name,
                  'brand': currentItem.mainItem.brand,
                  'imageUrl': currentItem.mainItem.imageUrl,
                  'expiry': null,
                  'noExpiry': true,
                  'stock': 0,
                  'deductQty': 0,
                });
              } else {
                // Use current inventory data instead of stored preset values
                // For stock deduction, we need to include all batches (earliest expiry first)
                final allBatches = [
                  currentItem.mainItem,
                  ...currentItem.variants
                ];
                final validBatches =
                    allBatches.where((batch) => batch.stock > 0).toList();

                // Sort by expiry (earliest first, no expiry last)
                validBatches.sort((a, b) {
                  if (a.noExpiry && b.noExpiry) return 0;
                  if (a.noExpiry) return 1;
                  if (b.noExpiry) return -1;

                  final aExpiry = a.expiry != null
                      ? DateTime.tryParse(a.expiry!.replaceAll('/', '-'))
                      : null;
                  final bExpiry = b.expiry != null
                      ? DateTime.tryParse(b.expiry!.replaceAll('/', '-'))
                      : null;

                  if (aExpiry == null && bExpiry == null) return 0;
                  if (aExpiry == null) return 1;
                  if (bExpiry == null) return -1;
                  return aExpiry.compareTo(bExpiry);
                });

                // Add the earliest expiry batch with stock as the main deduction item
                if (validBatches.isNotEmpty) {
                  final primaryBatch = validBatches.first;

                  _deductions.add({
                    'docId': primaryBatch.id,
                    'name': primaryBatch.name,
                    'brand': primaryBatch.brand,
                    'imageUrl': primaryBatch.imageUrl,
                    'expiry': primaryBatch.expiry,
                    'noExpiry': primaryBatch.noExpiry,
                    'stock': primaryBatch.stock,
                    'deductQty': primaryBatch.stock > 0 ? 1 : 0,
                    'allBatches': validBatches
                        .map((batch) => {
                              'docId': batch.id,
                              'stock': batch.stock,
                              'expiry': batch.expiry,
                            })
                        .toList(),
                  });
                }
              }
            } else {
              // Not in current inventory (likely expired/removed)
              // Use a safe placeholder so it cannot be deducted
              _deductions.add({
                'docId': null,
                'name': supplyName,
                'brand': supplyBrand,
                'imageUrl': (supply['imageUrl'] ?? '').toString(),
                'expiry': null,
                'noExpiry': true,
                'stock': 0,
                'deductQty': 0,
              });
            }
          }
        }
      });

      // Log preset usage activity
      await _activityController.logPresetUsed(
        presetName: preset['name']?.toString() ?? 'Unknown',
        supplies: supplies.cast<Map<String, dynamic>>(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Preset "${preset['name']}" loaded with ${_deductions.length} supplies',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF00D4AA),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load preset: $e',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _confirmLeave() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Discard changes?',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'You have supplies added. If you leave this page, your list will be cleared.',
            style: AppFonts.sfProStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Stay',
                style:
                    AppFonts.sfProStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(
                'Leave',
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
    return shouldLeave ?? false;
  }

  String _formatExpiry(dynamic expiry, bool? noExpiry) {
    if (noExpiry == true) return 'No Expiry';
    if (expiry == null) return 'No Expiry';
    final String raw = expiry.toString();
    if (raw.isEmpty) return 'No Expiry';
    // Normalize dashes to slashes for consistency
    final dashDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (dashDate.hasMatch(raw)) {
      return raw.replaceAll('-', '/');
    }
    return raw;
  }

  Widget _expiryChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 12,
              color: Theme.of(context).iconTheme.color?.withOpacity(0.8)),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppFonts.sfProStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _stockChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 12,
              color: Theme.of(context).iconTheme.color?.withOpacity(0.8)),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppFonts.sfProStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _showOutOfStockDialog(String supplyName) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Out of stock',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            '"$supplyName" has no available stock to deduct.',
            style: AppFonts.sfProStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: AppFonts.sfProStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDuplicateDialog(String supplyName) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Already added',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            '"$supplyName" is already in your deduction list.',
            style: AppFonts.sfProStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: AppFonts.sfProStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPresetAlreadyLoadedDialog(String presetName) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Preset already loaded',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            '"$presetName" contains supplies that are already in your deduction list.',
            style: AppFonts.sfProStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: AppFonts.sfProStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          if (_deductions.isNotEmpty) {
            return await _confirmLeave();
          }
          // Navigate back to Dashboard when back button is pressed
          // Use popUntil to go back to existing Dashboard instead of creating a new one
          Navigator.popUntil(
              context, (route) => route.settings.name == '/dashboard');
          return false; // Prevent default back behavior
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: MediaQuery.of(context).size.width >= 900
                ? false
                : true, // Remove back button on desktop
            title: Text(
              'Quick Deduction',
              style: AppFonts.sfProStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).appBarTheme.titleTextStyle?.color ??
                    Theme.of(context).textTheme.titleLarge?.color,
              ),
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
          drawer: MediaQuery.of(context).size.width >= 900
              ? null
              : MyDrawer(
                  beforeNavigate: () async {
                    if (_deductions.isNotEmpty) {
                      return await _confirmLeave();
                    }
                    return true;
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: _openAddSupply,
            backgroundColor: const Color(0xFF00D4AA),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: MediaQuery.of(context).size.width >= 900
              ? _buildWithNavigationRail()
              : ResponsiveContainer(
                  maxWidth: 1200,
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width < 768
                            ? 1.0
                            : 16.0,
                        vertical: 12.0,
                      ),
                      child: Column(
                        children: [
                          // Top bar for in-page actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: _createPreset,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00D4AA),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(
                                  'Presets',
                                  style: AppFonts.sfProStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _deductions.isEmpty ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _deductions.isEmpty
                                      ? Colors.grey[400]
                                      : const Color(0xFF00D4AA),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: Text(
                                  'Deduct',
                                  style: AppFonts.sfProStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Theme.of(context).colorScheme.surface
                                    : const Color(0xFFE8D5E8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withOpacity(0.2),
                                ),
                              ),
                              child: _deductions.isEmpty
                                  ? _buildEmptyState()
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(12),
                                      itemCount: _deductions.length,
                                      itemBuilder: (context, index) {
                                        final item = _deductions[index];
                                        return Slidable(
                                            key: ValueKey(
                                                'deduct-${item['docId'] ?? index}'),
                                            closeOnScroll: true,
                                            endActionPane: ActionPane(
                                              motion: const DrawerMotion(),
                                              extentRatio: 0.35,
                                              children: [
                                                SlidableAction(
                                                  onPressed: (_) =>
                                                      _removeDeductionAt(index),
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  icon: Icons.delete,
                                                  label: 'Remove',
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ],
                                            ),
                                            child: Card(
                                              margin: const EdgeInsets.only(
                                                  bottom: 12),
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                              elevation: 2,
                                              shadowColor: Theme.of(context)
                                                  .shadowColor
                                                  .withOpacity(0.15),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  side: BorderSide(
                                                    color: Theme.of(context)
                                                        .dividerColor
                                                        .withOpacity(0.2),
                                                    width: 1,
                                                  )),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 16),
                                                child: ConstrainedBox(
                                                  constraints:
                                                      const BoxConstraints(
                                                          minHeight: 84),
                                                  child: Row(
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        child: Image.network(
                                                          item['imageUrl'] ??
                                                              '',
                                                          width: 48,
                                                          height: 48,
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (_, __, ___) =>
                                                                  Container(
                                                            width: 48,
                                                            height: 48,
                                                            color: Colors
                                                                .grey[200],
                                                            child: const Icon(
                                                                Icons.inventory,
                                                                color: Colors
                                                                    .grey),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 14),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              item['name'] ??
                                                                  '',
                                                              style: AppFonts.sfProStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: Theme.of(
                                                                          context)
                                                                      .textTheme
                                                                      .bodyMedium
                                                                      ?.color),
                                                              maxLines: 2,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                            const SizedBox(
                                                                height: 8),
                                                            _expiryChip('Expiry: ' +
                                                                _formatExpiry(
                                                                    item[
                                                                        'expiry'],
                                                                    item['noExpiry']
                                                                        as bool?)),
                                                            const SizedBox(
                                                                height: 6),
                                                            _stockChip('Stock: ' +
                                                                ((_deductions[index]
                                                                            [
                                                                            'stock'] ??
                                                                        0) as int)
                                                                    .toString()),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          IconButton(
                                                            onPressed: () =>
                                                                _decrementQty(
                                                                    index),
                                                            icon: Icon(
                                                              Icons
                                                                  .remove_circle_outline,
                                                              color: Theme.of(
                                                                      context)
                                                                  .iconTheme
                                                                  .color,
                                                            ),
                                                          ),
                                                          Text(
                                                            (_deductions[index][
                                                                        'deductQty']
                                                                    as int)
                                                                .toString(),
                                                            style: AppFonts.sfProStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Theme.of(
                                                                        context)
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.color),
                                                          ),
                                                          IconButton(
                                                            onPressed: () =>
                                                                _incrementQty(
                                                                    index),
                                                            icon: Icon(
                                                              Icons
                                                                  .add_circle_outline,
                                                              color: Theme.of(
                                                                      context)
                                                                  .iconTheme
                                                                  .color,
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ));
                                      },
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surface
                  : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).dividerColor.withOpacity(0.2)
                    : Colors.transparent,
              ),
            ),
            child: Icon(
              Icons.shopping_basket_outlined,
              size: 60,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF8B5A8B),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Supplies Added Yet',
            style: AppFonts.sfProStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF8B5A8B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add supplies',
            style: AppFonts.sfProStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.7)
                  : const Color(0xFF8B5A8B).withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithNavigationRail() {
    final theme = Theme.of(context);
    final userRoleProvider = UserRoleProvider();
    final canAccessActivityLog = userRoleProvider.canAccessActivityLog();

    return Row(
      children: [
        NavigationRail(
          minWidth: 150,
          selectedIndex: 3, // Stock Deduction is at index 3
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
            // Check if there are unsaved deductions before navigation
            bool canNavigate = true;
            if (_deductions.isNotEmpty) {
              canNavigate = await _confirmLeave();
            }

            if (!canNavigate) return;

            if (index == 0) {
              Navigator.pushNamed(context, '/dashboard');
            } else if (index == 1) {
              Navigator.pushNamed(context, '/inventory');
            } else if (index == 2) {
              Navigator.pushNamed(context, '/purchase-order');
            } else if (index == 3) {
              // Already on Stock Deduction
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
          child: ResponsiveContainer(
            maxWidth: 1200,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal:
                      MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
                  vertical: 12.0,
                ),
                child: _buildStockDeductionContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStockDeductionContent() {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Top bar for in-page actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: _createPreset,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4AA),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Presets',
                style: AppFonts.sfProStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _deductions.isEmpty ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _deductions.isEmpty
                    ? Colors.grey[400]
                    : const Color(0xFF00D4AA),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                'Deduct',
                style: AppFonts.sfProStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? theme.colorScheme.surface
                  : const Color(0xFFE8D5E8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.2),
              ),
            ),
            child: _deductions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _deductions.length,
                    itemBuilder: (context, index) {
                      final item = _deductions[index];
                      return Slidable(
                        key: ValueKey('deduct-${item['docId'] ?? index}'),
                        closeOnScroll: true,
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: 0.35,
                          children: [
                            SlidableAction(
                              onPressed: (_) => _removeDeductionAt(index),
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
                          color: theme.colorScheme.surface,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              item['supply']['name'],
                              style: AppFonts.sfProStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Quantity: ${item['quantity']}',
                                  style: AppFonts.sfProStyle(
                                    fontSize: 14,
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withOpacity(0.7),
                                  ),
                                ),
                                if (item['notes'] != null &&
                                    item['notes'].isNotEmpty)
                                  Text(
                                    'Notes: ${item['notes']}',
                                    style: AppFonts.sfProStyle(
                                      fontSize: 14,
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.7),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeDeductionAt(index),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogout() async {
    // Check for unsaved deductions
    bool canLogout = true;
    if (_deductions.isNotEmpty) {
      canLogout = await _confirmLeave();
    }

    if (!canLogout) return;

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
}
