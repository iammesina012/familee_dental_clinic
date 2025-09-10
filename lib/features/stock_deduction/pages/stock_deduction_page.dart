import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:projects/shared/drawer.dart';
import 'package:projects/shared/themes/font.dart';
import 'package:projects/features/stock_deduction/controller/stock_deduction_controller.dart';
import 'package:projects/features/inventory/controller/inventory_controller.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';
import 'package:projects/features/activity_log/controller/sd_activity_controller.dart';

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
      _deductions[index]['deductQty'] = next > maxStock ? maxStock : next;
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
    if (overlay == null) return;

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
      final currentInventory = await _inventoryController
          .getGroupedSuppliesStream(archived: false)
          .first;

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
              // Use current inventory data
              _deductions.add({
                'docId': currentItem.mainItem.id,
                'name': currentItem.mainItem.name,
                'brand': currentItem.mainItem.brand,
                'imageUrl': currentItem.mainItem.imageUrl,
                'expiry': currentItem.mainItem.expiry,
                'noExpiry': currentItem.mainItem.noExpiry,
                'stock': currentItem.totalStock,
                'deductQty': currentItem.totalStock > 0 ? 1 : 0,
              });
            } else {
              // Fallback to preset data if item not found in current inventory
              final stock = supply['stock'] as int? ?? 0;
              _deductions.add({
                ...supply,
                'deductQty': stock > 0 ? 1 : 0,
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
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 12, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppFonts.sfProStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
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
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 12, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppFonts.sfProStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
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
          return true;
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF9EFF2),
          appBar: AppBar(
            title: Text(
              'Quick Deduction',
              style: AppFonts.sfProStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
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
                    Navigator.pushNamed(context, '/notifications');
                  },
                ),
              ),
            ],
          ),
          drawer: MyDrawer(
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
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
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
                        color: const Color(0xFFE8D5E8),
                        borderRadius: BorderRadius.circular(12),
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
                                      margin: const EdgeInsets.only(bottom: 12),
                                      color: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 16),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                              minHeight: 84),
                                          child: Row(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  item['imageUrl'] ?? '',
                                                  width: 48,
                                                  height: 48,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      Container(
                                                    width: 48,
                                                    height: 48,
                                                    color: Colors.grey[200],
                                                    child: const Icon(
                                                        Icons.inventory,
                                                        color: Colors.grey),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      item['name'] ?? '',
                                                      style:
                                                          AppFonts.sfProStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    _expiryChip('Expiry: ' +
                                                        _formatExpiry(
                                                            item['expiry'],
                                                            item['noExpiry']
                                                                as bool?)),
                                                    const SizedBox(height: 6),
                                                    _stockChip('Stock: ' +
                                                        ((_deductions[index]
                                                                    ['stock'] ??
                                                                0) as int)
                                                            .toString()),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    onPressed: () =>
                                                        _decrementQty(index),
                                                    icon: const Icon(Icons
                                                        .remove_circle_outline),
                                                  ),
                                                  Text(
                                                    (_deductions[index]
                                                                ['deductQty']
                                                            as int)
                                                        .toString(),
                                                    style: AppFonts.sfProStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  IconButton(
                                                    onPressed: () =>
                                                        _incrementQty(index),
                                                    icon: const Icon(Icons
                                                        .add_circle_outline),
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
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.shopping_basket_outlined,
              size: 60,
              color: Color(0xFF8B5A8B),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Supplies Added Yet',
            style: AppFonts.sfProStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8B5A8B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add supplies',
            style: AppFonts.sfProStyle(
              fontSize: 14,
              color: const Color(0xFF8B5A8B).withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
