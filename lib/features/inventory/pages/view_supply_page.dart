import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marquee/marquee.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/inventory/components/inventory_other_supply_batches.dart';
import 'package:familee_dental/features/inventory/pages/edit_supply_page.dart';
import 'package:familee_dental/features/inventory/controller/view_supply_controller.dart';
import 'package:familee_dental/features/inventory/controller/inventory_controller.dart';
import 'package:familee_dental/features/inventory/pages/archive_supply_page.dart';
import 'package:familee_dental/features/inventory/pages/expired_view_supply_page.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/services/connectivity_service.dart';
import 'package:familee_dental/shared/widgets/connection_error_dialog.dart';

class InventoryViewSupplyPage extends StatefulWidget {
  final InventoryItem item;
  final bool skipAutoRedirect; // when navigating from Other Supply Batches
  final bool
      hideOtherExpirySection; // hide Other Supply Batches section (e.g., from Expired page)
  const InventoryViewSupplyPage(
      {super.key,
      required this.item,
      this.skipAutoRedirect = false,
      this.hideOtherExpirySection = false});

  @override
  State<InventoryViewSupplyPage> createState() =>
      _InventoryViewSupplyPageState();
}

class _InventoryViewSupplyPageState extends State<InventoryViewSupplyPage> {
  // Add a key to force rebuild when needed
  Key _streamKey = UniqueKey();

  // Track whether we're viewing overview or batch details
  InventoryItem?
      _selectedBatch; // null = overview mode, not null = batch details mode

  // Method to refresh the stream
  void _refreshStream() {
    setState(() {
      _streamKey = UniqueKey();
    });
  }

  // Method to show batch details
  void _showBatchDetails(InventoryItem batch) {
    setState(() {
      _selectedBatch = batch;
    });
  }

  // Method to return to overview
  void _returnToOverview() {
    setState(() {
      _selectedBatch = null;
    });
  }

  // Calculate total stock from batch data
  int _calculateTotals(List<Map<String, dynamic>> batches) {
    int totalStock = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final batch in batches) {
      final stock = (batch['stock'] ?? 0) as int;

      // Only count non-expired batches
      final expiryStr = batch['expiry']?.toString();
      bool isExpired = false;

      if (expiryStr != null && expiryStr.isNotEmpty) {
        final expiryDate = DateTime.tryParse(expiryStr.replaceAll('/', '-'));
        if (expiryDate != null) {
          final dateOnly =
              DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
          isExpired =
              dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today);
        }
      }

      if (!isExpired) {
        totalStock += stock;
      }
    }

    return totalStock;
  }

  // Calculate total baseline from batch data
  // Use the threshold value directly (not summed) since all batches share the same threshold
  int _calculateTotalBaseline(List<Map<String, dynamic>> batches) {
    int totalBaseline = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final batch in batches) {
      final lowStockBaseline = batch['low_stock_baseline'] != null
          ? (batch['low_stock_baseline'] as num).toInt()
          : 0;

      // Only count non-expired batches
      final expiryStr = batch['expiry']?.toString();
      bool isExpired = false;

      if (expiryStr != null && expiryStr.isNotEmpty) {
        final expiryDate = DateTime.tryParse(expiryStr.replaceAll('/', '-'));
        if (expiryDate != null) {
          final dateOnly =
              DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
          isExpired =
              dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today);
        }
      }

      if (!isExpired && lowStockBaseline > 0) {
        totalBaseline = lowStockBaseline;
        break; // All batches have the same threshold, so we can use the first one
      }
    }

    return totalBaseline;
  }

  // Get grouped totals from cache if available
  (int?, int?) _getGroupedTotalsFromCache(InventoryItem item) {
    try {
      final inventoryController = InventoryController();
      final cachedGrouped = inventoryController.getCachedGroupedSupplies();

      if (cachedGrouped != null) {
        // Find the grouped item that matches this item
        for (final grouped in cachedGrouped) {
          if (grouped.mainItem.name == item.name &&
              grouped.mainItem.category == item.category) {
            return (grouped.totalStock, grouped.totalBaseline);
          }
        }
      }
    } catch (e) {
      debugPrint('[VIEW_SUPPLY] Error getting cached grouped data: $e');
    }
    return (null, null);
  }

  @override
  void initState() {
    super.initState();
    debugPrint(
        '[VIEW_SUPPLY] initState called for item: ${widget.item.name} (ID: ${widget.item.id})');
    debugPrint(
        '[VIEW_SUPPLY] Image URL: ${widget.item.imageUrl.isEmpty ? "EMPTY" : widget.item.imageUrl}');
    debugPrint('[VIEW_SUPPLY] initState start time: ${DateTime.now()}');
    _refreshStream();
    debugPrint('[VIEW_SUPPLY] initState completed at: ${DateTime.now()}');
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[VIEW_SUPPLY] build() called for item: ${widget.item.name}');
    final controller = ViewSupplyController();

    return StreamBuilder<InventoryItem?>(
      key: _streamKey,
      stream: controller.supplyStream(widget.item.id),
      builder: (context, snapshot) {
        debugPrint(
            '[VIEW_SUPPLY] StreamBuilder snapshot state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');

        // Always use stream data if available, otherwise use the initial item from widget
        // This ensures we always have data to display and never show loading indicator
        final updatedItem = snapshot.hasData && snapshot.data != null
            ? snapshot.data!
            : widget.item;

        debugPrint(
            '[VIEW_SUPPLY] Using item: ${updatedItem.name}, Image URL: ${updatedItem.imageUrl.isEmpty ? "EMPTY" : updatedItem.imageUrl}');

        // No loading indicator needed since we always have widget.item as fallback
        // If this batch is expired, redirect to Expired View page to keep
        // inventory view free of expired supplies
        if (_isItemExpired(updatedItem) && !widget.skipAutoRedirect) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ExpiredViewSupplyPage(
                  item: updatedItem,
                  skipAutoRedirect: true,
                ),
              ),
            );
          });
          return Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(title: Text("Inventory")),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // If there are other batches with earlier expiry, redirect to earliest
        // Query same name+brand and pick the earliest non-null expiry
        // UI-only re-route; no backend change
        if (widget.skipAutoRedirect) {
          // Even with skipAutoRedirect, we still want grouped status for consistency
          // Query batches to calculate grouped totals
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: () {
              return Supabase.instance.client
                  .from('supplies')
                  .select('*')
                  .eq('name', updatedItem.name)
                  .eq('brand', updatedItem.brand)
                  .eq('type', updatedItem.type ?? '')
                  .timeout(
                const Duration(seconds: 2),
                onTimeout: () {
                  return <Map<String, dynamic>>[];
                },
              );
            }(),
            builder: (context, batchSnap) {
              // Use cached grouped data immediately if available
              final (cachedTotalStock, cachedTotalBaseline) =
                  _getGroupedTotalsFromCache(updatedItem);

              // If we have batch data, use it; otherwise use cache or fallback to individual
              int? totalStock = cachedTotalStock;
              int? totalBaseline = cachedTotalBaseline;

              if (batchSnap.hasData && batchSnap.data!.isNotEmpty) {
                totalStock = _calculateTotals(batchSnap.data!);
                // Calculate totalBaseline from batch data
                totalBaseline = _calculateTotalBaseline(batchSnap.data!);
              }

              final status = controller.getStatus(updatedItem,
                  totalStock: totalStock, totalBaseline: totalBaseline);
              return _buildScaffold(context, controller, updatedItem, status);
            },
          );
        }
        debugPrint('[VIEW_SUPPLY] Starting FutureBuilder for batch query');
        final batchQueryStart = DateTime.now();
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: () {
            debugPrint(
                '[VIEW_SUPPLY] Executing batch query at ${DateTime.now()}');
            // Add timeout to prevent blocking when offline
            return Supabase.instance.client
                .from('supplies')
                .select('*')
                .eq('name', updatedItem.name)
                .eq('brand', updatedItem.brand)
                .eq('type', updatedItem.type ?? '')
                .timeout(
              const Duration(seconds: 2),
              onTimeout: () {
                debugPrint('[VIEW_SUPPLY] Batch query TIMEOUT after 2s');
                return <Map<String, dynamic>>[];
              },
            );
          }(),
          builder: (context, batchSnap) {
            // Show UI immediately while query is running (non-blocking)
            if (batchSnap.connectionState == ConnectionState.waiting) {
              debugPrint(
                  '[VIEW_SUPPLY] Batch query waiting... (${DateTime.now().difference(batchQueryStart).inMilliseconds}ms)');
              // Try to get grouped totals from cache immediately to avoid flash
              final (cachedTotalStock, cachedTotalBaseline) =
                  _getGroupedTotalsFromCache(updatedItem);
              final status = controller.getStatus(updatedItem,
                  totalStock: cachedTotalStock,
                  totalBaseline: cachedTotalBaseline);
              return _buildScaffold(context, controller, updatedItem, status);
            } else if (batchSnap.hasError) {
              debugPrint('[VIEW_SUPPLY] Batch query ERROR: ${batchSnap.error}');
              // Try to get grouped totals from cache on error too
              final (cachedTotalStock, cachedTotalBaseline) =
                  _getGroupedTotalsFromCache(updatedItem);
              final status = controller.getStatus(updatedItem,
                  totalStock: cachedTotalStock,
                  totalBaseline: cachedTotalBaseline);
              return _buildScaffold(context, controller, updatedItem, status);
            } else if (batchSnap.hasData) {
              debugPrint(
                  '[VIEW_SUPPLY] Batch query completed in ${DateTime.now().difference(batchQueryStart).inMilliseconds}ms');
            }

            // If query returned empty (timeout or no data), show UI immediately
            if (batchSnap.hasData && batchSnap.data!.isEmpty) {
              debugPrint(
                  '[VIEW_SUPPLY] Batch query returned empty, showing UI');
              // Try to get grouped totals from cache
              final (cachedTotalStock, cachedTotalBaseline) =
                  _getGroupedTotalsFromCache(updatedItem);
              final status = controller.getStatus(updatedItem,
                  totalStock: cachedTotalStock,
                  totalBaseline: cachedTotalBaseline);
              return _buildScaffold(context, controller, updatedItem, status);
            }

            if (batchSnap.hasData) {
              final rows = batchSnap.data!;
              DateTime? earliest;
              Map<String, dynamic>? earliestRow;
              Map<String, dynamic>? stockRow; // Row with stock > 0
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);

              // First pass: look for earliest expiry with stock > 0
              for (final row in rows) {
                final stock = (row['stock'] ?? 0) as int;
                if (stock > 0) {
                  final expStr = row['expiry']?.toString();
                  if (expStr == null || expStr.isEmpty) {
                    stockRow = row;
                    break; // Prefer no expiry items with stock
                  }
                  final dt = DateTime.tryParse(expStr.replaceAll('/', '-'));
                  if (dt == null) continue;
                  final dateOnly = DateTime(dt.year, dt.month, dt.day);
                  // Skip expired batches
                  if (dateOnly.isBefore(today) ||
                      dateOnly.isAtSameMomentAs(today)) {
                    continue;
                  }
                  // Keep track of earliest expiry with stock
                  if (stockRow == null) {
                    stockRow = row;
                  } else {
                    final existingExpStr = stockRow['expiry']?.toString();
                    if (existingExpStr == null || existingExpStr.isEmpty) {
                      // Current row has expiry, existing doesn't, keep current
                      stockRow = row;
                    } else {
                      final existingDate = DateTime.tryParse(
                          existingExpStr.replaceAll('/', '-'));
                      if (existingDate != null &&
                          dateOnly.isBefore(existingDate)) {
                        stockRow = row;
                      }
                    }
                  }
                }
              }

              // Second pass: if no stock found, look for earliest expiry (existing logic)
              if (stockRow == null) {
                for (final row in rows) {
                  final expStr = row['expiry']?.toString();
                  if (expStr == null || expStr.isEmpty) continue;
                  final dt = DateTime.tryParse(expStr.replaceAll('/', '-'));
                  if (dt == null) continue;
                  final dateOnly = DateTime(dt.year, dt.month, dt.day);
                  // Skip expired batches in Inventory view
                  if (dateOnly.isBefore(today) ||
                      dateOnly.isAtSameMomentAs(today)) {
                    continue;
                  }
                  if (earliest == null || dateOnly.isBefore(earliest)) {
                    earliest = dateOnly;
                    earliestRow = row;
                  }
                }
              }
              final preferredRow = stockRow ?? earliestRow;
              if (preferredRow != null &&
                  preferredRow['id'] != updatedItem.id) {
                // Replace page with preferred batch view (stock first, then earliest expiry)
                // Schedule navigation after current frame to avoid ancestor lookup on deactivated context
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => InventoryViewSupplyPage(
                          item: InventoryItem(
                            id: preferredRow['id'] as String,
                            name: preferredRow['name'] ?? '',
                            imageUrl: preferredRow['image_url'] ?? '',
                            category: preferredRow['category'] ?? '',
                            cost: (preferredRow['cost'] ?? 0).toDouble(),
                            stock: (preferredRow['stock'] ?? 0).toInt(),
                            lowStockBaseline:
                                preferredRow['low_stock_baseline'] != null
                                    ? (preferredRow['low_stock_baseline']
                                            as num)
                                        .toInt()
                                    : null,
                            unit: preferredRow['unit'] ?? '',
                            supplier: preferredRow['supplier'] ?? '',
                            brand: preferredRow['brand'] ?? '',
                            expiry: preferredRow['expiry'],
                            noExpiry: preferredRow['no_expiry'] ?? false,
                            archived: preferredRow['archived'] ?? false,
                            createdAt: preferredRow['created_at'] != null
                                ? DateTime.tryParse(
                                    preferredRow['created_at'] as String)
                                : null,
                          ),
                          skipAutoRedirect: true,
                        ),
                      ),
                    );
                  }
                });
              }
              // Fall back to normal render - prefer immediate type-specific status
              // to avoid briefly showing overall status when switching types.
              final status = controller.getStatus(updatedItem);
              return _buildScaffold(context, controller, updatedItem, status);
            }

            // Fallback case - should never reach here
            final status = controller.getStatus(updatedItem);
            return _buildScaffold(context, controller, updatedItem, status);
          },
        );
      },
    );
  }

  bool _isItemExpired(InventoryItem item) {
    if (item.noExpiry || item.expiry == null || item.expiry!.isEmpty) {
      return false;
    }
    final parsed = DateTime.tryParse(item.expiry!.replaceAll('/', '-'));
    if (parsed == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);
    return dateOnly.isBefore(today) || dateOnly.isAtSameMomentAs(today);
  }

  Widget _buildScaffold(BuildContext context, ViewSupplyController controller,
      InventoryItem updatedItem, String status) {
    // Determine which item to display - batch details or overview
    final displayItem = _selectedBatch ?? updatedItem;
    final isBatchDetailsMode = _selectedBatch != null;

    // When in batch details mode, fetch latest data from stream for accurate individual status
    if (isBatchDetailsMode) {
      // Wrap in StreamBuilder to get latest batch data from database
      return StreamBuilder<InventoryItem?>(
        stream: controller.supplyStream(displayItem.id),
        builder: (context, batchSnapshot) {
          // Use stream data if available, otherwise fall back to _selectedBatch
          final freshBatch = batchSnapshot.hasData && batchSnapshot.data != null
              ? batchSnapshot.data!
              : displayItem;

          // Calculate individual batch status using fresh data (not grouped totals)
          final displayStatus = controller.getStatus(freshBatch);

          return _buildScaffoldBody(context, controller, updatedItem, status,
              freshBatch, displayStatus, isBatchDetailsMode);
        },
      );
    }

    // In overview mode, use the passed status (calculated with grouped totals)
    final displayStatus = status;
    return _buildScaffoldBody(context, controller, updatedItem, status,
        displayItem, displayStatus, isBatchDetailsMode);
  }

  Widget _buildScaffoldBody(
      BuildContext context,
      ViewSupplyController controller,
      InventoryItem updatedItem,
      String status,
      InventoryItem displayItem,
      String displayStatus,
      bool isBatchDetailsMode) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async {
        // If viewing batch details, return to overview instead of popping
        if (isBatchDetailsMode) {
          _returnToOverview();
          return false; // Prevent default back action
        }
        return true; // Allow default back action for overview
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            "Inventory",
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: theme.appBarTheme.backgroundColor,
          toolbarHeight: 70,
          iconTheme: theme.appBarTheme.iconTheme,
          elevation: theme.appBarTheme.elevation,
          shadowColor: theme.appBarTheme.shadowColor,
          actions: [
            // Show different buttons based on archived status
            if (!displayItem.archived) ...[
              // Edit button - Only for Admin users
              if (!UserRoleProvider().isStaff)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.green),
                  tooltip: "Edit",
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditSupplyPage(
                          item: displayItem,
                        ),
                      ),
                    );
                    if (result == true) {
                      // Refresh the stream to get updated data
                      _refreshStream();
                      // Avoid showing a snackbar if the item is now expired,
                      // because this page may immediately redirect to the Expired view
                      try {
                        final response = await Supabase.instance.client
                            .from('supplies')
                            .select('expiry')
                            .eq('id', displayItem.id)
                            .single();
                        final expiryStr = response['expiry']?.toString();
                        bool isExpiredNow = false;
                        if (expiryStr != null && expiryStr.isNotEmpty) {
                          final dt = DateTime.tryParse(expiryStr) ??
                              DateTime.tryParse(expiryStr.replaceAll('/', '-'));
                          if (dt != null) {
                            final today = DateTime.now();
                            final d = DateTime(dt.year, dt.month, dt.day);
                            final t =
                                DateTime(today.year, today.month, today.day);
                            isExpiredNow =
                                d.isBefore(t) || d.isAtSameMomentAs(t);
                          }
                        }
                        if (!isExpiredNow) {
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          if (messenger != null) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Supply updated!')),
                            );
                          }
                        }
                      } catch (_) {
                        // Best-effort only; ignore errors
                      }
                    }
                  },
                ),
              // Archive button - Only for Admin users
              if (!UserRoleProvider().isStaff)
                IconButton(
                  icon: const Icon(Icons.archive, color: Colors.orange),
                  tooltip: "Archive",
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => _buildCustomDialog(
                        context,
                        title: 'Archive Supply',
                        content:
                            'Are you sure you want to archive this supply?',
                        confirmText: 'Archive',
                        confirmColor: Colors.orange,
                        icon: Icons.archive,
                      ),
                    );
                    if (confirmed == true) {
                      // Check connectivity before proceeding
                      final hasConnection =
                          await ConnectivityService().hasInternetConnection();
                      if (!hasConnection) {
                        if (context.mounted) {
                          await showConnectionErrorDialog(context);
                        }
                        return;
                      }

                      try {
                        await controller.archiveSupply(displayItem.id);
                        // Refresh the stream to show updated status
                        _refreshStream();
                        if (!context.mounted) return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => ArchiveSupplyPage(),
                          ),
                        );
                      } catch (e) {
                        // Check if it's a network error
                        final errorString = e.toString().toLowerCase();
                        if (errorString
                            .contains('archive_blocked_stock_remaining')) {
                          if (context.mounted) {
                            await _showArchiveBlockedDialog(context);
                          }
                        } else if (errorString.contains('socketexception') ||
                            errorString.contains('failed host lookup') ||
                            errorString.contains('no address associated') ||
                            errorString.contains('network is unreachable') ||
                            errorString.contains('connection refused') ||
                            errorString.contains('connection timed out')) {
                          if (context.mounted) {
                            await showConnectionErrorDialog(context);
                          }
                        } else {
                          // Other error - show generic error message
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Failed to archive supply: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    }
                  },
                ),
            ] else ...[
              // Unarchive button - Only for Admin users
              if (!UserRoleProvider().isStaff)
                IconButton(
                  icon: const Icon(Icons.unarchive, color: Colors.blue),
                  tooltip: "Unarchive",
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => _buildCustomDialog(
                        context,
                        title: 'Unarchive Supply',
                        content:
                            'Are you sure you want to unarchive this supply?',
                        confirmText: 'Unarchive',
                        confirmColor: Colors.blue,
                        icon: Icons.unarchive,
                      ),
                    );
                    if (confirmed == true) {
                      // Check connectivity before proceeding
                      final hasConnection =
                          await ConnectivityService().hasInternetConnection();
                      if (!hasConnection) {
                        if (context.mounted) {
                          await showConnectionErrorDialog(context);
                        }
                        return;
                      }

                      try {
                        await controller.unarchiveSupply(displayItem.id);
                        // Refresh the stream to show updated status
                        _refreshStream();
                        if (!context.mounted) return;
                        Navigator.of(context).pop(
                            'unarchived'); // Go back to archive page with result
                      } catch (e) {
                        // Check if it's a network error
                        final errorString = e.toString().toLowerCase();
                        if (errorString.contains('socketexception') ||
                            errorString.contains('failed host lookup') ||
                            errorString.contains('no address associated') ||
                            errorString.contains('network is unreachable') ||
                            errorString.contains('connection refused') ||
                            errorString.contains('connection timed out')) {
                          if (context.mounted) {
                            await showConnectionErrorDialog(context);
                          }
                        } else {
                          // Other error - show generic error message
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Failed to unarchive supply: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    }
                  },
                ),
              // Delete button - Only for Admin users
              if (!UserRoleProvider().isStaff)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: "Delete",
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => _buildCustomDialog(
                        context,
                        title: 'Delete Supply',
                        content:
                            'Are you sure you want to delete this supply?\n\nThis action cannot be undone.',
                        confirmText: 'Delete',
                        confirmColor: Colors.red,
                        icon: Icons.delete,
                      ),
                    );
                    if (confirmed == true) {
                      // Check connectivity before proceeding
                      final hasConnection =
                          await ConnectivityService().hasInternetConnection();
                      if (!hasConnection) {
                        if (context.mounted) {
                          await showConnectionErrorDialog(context);
                        }
                        return;
                      }

                      try {
                        await controller.deleteSupply(displayItem.id);
                        if (!context.mounted) return;
                        Navigator.of(context).pop(); // Go back to archive page
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Supply deleted permanently!'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } catch (e) {
                        // Check if it's a network error
                        final errorString = e.toString().toLowerCase();
                        if (errorString.contains('socketexception') ||
                            errorString.contains('failed host lookup') ||
                            errorString.contains('no address associated') ||
                            errorString.contains('network is unreachable') ||
                            errorString.contains('connection refused') ||
                            errorString.contains('connection timed out')) {
                          if (context.mounted) {
                            await showConnectionErrorDialog(context);
                          }
                        } else {
                          // Other error - show generic error message
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Failed to delete supply: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    }
                  },
                ),
            ],
          ],
        ),
        body: ResponsiveContainer(
          maxWidth: 1000,
          child: SafeArea(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    // Refresh the stream to reload data from Supabase
                    _refreshStream();
                    // Wait for the stream to emit at least one event
                    // This ensures the RefreshIndicator shows its animation
                    await controller.supplyStream(displayItem.id).first;
                  },
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          MediaQuery.of(context).size.width < 768 ? 8.0 : 18.0,
                      vertical:
                          MediaQuery.of(context).size.width < 768 ? 8.0 : 16.0,
                    ),
                    child: isBatchDetailsMode
                        ? _buildBatchDetailsView(
                            context, controller, displayItem, displayStatus)
                        : _buildOverviewView(
                            context, controller, updatedItem, displayStatus),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build overview view showing total stock and batches
  Widget _buildOverviewView(
      BuildContext context,
      ViewSupplyController controller,
      InventoryItem updatedItem,
      String status) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client
          .from('supplies')
          .select('*')
          .eq('name', updatedItem.name)
          .eq('brand', updatedItem.brand)
          .eq('type', updatedItem.type ?? '')
          .timeout(const Duration(seconds: 2),
              onTimeout: () => <Map<String, dynamic>>[]),
      builder: (context, batchSnap) {
        int totalStock = 0;
        int? totalBaseline;

        if (batchSnap.hasData && batchSnap.data!.isNotEmpty) {
          totalStock = _calculateTotals(batchSnap.data!);
          totalBaseline = _calculateTotalBaseline(batchSnap.data!);
        } else {
          // Fallback to cache
          final (cachedTotalStock, cachedTotalBaseline) =
              _getGroupedTotalsFromCache(updatedItem);
          totalStock = cachedTotalStock ?? updatedItem.stock;
          totalBaseline = cachedTotalBaseline;
        }

        // Overview status uses total stock vs baseline (grouped logic for overview)
        // Individual batches in "Other Supply Batches" list show their own individual status
        final overallStatus = controller.getStatus(updatedItem,
            totalStock: totalStock, totalBaseline: totalBaseline);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 18),
            // Supply name with type and dropdown
            Stack(
              children: [
                // Centered supply name
                Center(
                  child: Text(
                    updatedItem.type != null && updatedItem.type!.isNotEmpty
                        ? "${updatedItem.name} (${updatedItem.type})"
                        : updatedItem.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Theme.of(context).textTheme.bodyMedium?.color),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              updatedItem.category,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: updatedItem.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: updatedItem.imageUrl,
                        width: 130,
                        height: 130,
                        fit: BoxFit.cover,
                        placeholder: (context, url) {
                          debugPrint(
                              '[IMAGE_VIEW] Loading placeholder for ${updatedItem.name} (URL: $url)');
                          return Container(
                            width: 130,
                            height: 130,
                            color: Theme.of(context)
                                .dividerColor
                                .withOpacity(0.15),
                            child: const Icon(Icons.image,
                                size: 40, color: Colors.grey),
                          );
                        },
                        errorWidget: (context, url, error) {
                          debugPrint(
                              '[IMAGE_VIEW] ERROR loading ${updatedItem.name} (URL: $url, Error: $error)');
                          return Container(
                            width: 130,
                            height: 130,
                            color: Theme.of(context)
                                .dividerColor
                                .withOpacity(0.15),
                            child: const Icon(Icons.image_not_supported,
                                size: 40, color: Colors.grey),
                          );
                        },
                        fadeInDuration: const Duration(milliseconds: 200),
                        fadeOutDuration: const Duration(milliseconds: 100),
                      )
                    : Container(
                        width: 130,
                        height: 130,
                        color: Theme.of(context).dividerColor.withOpacity(0.15),
                        child: const Icon(Icons.image,
                            size: 40, color: Colors.grey),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            // Total Stock display for overview
            Text(
              "Total Stock: $totalStock",
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: controller.getStatusBgColor(overallStatus),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  overallStatus,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: controller.getStatusTextColor(overallStatus),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Divider(
                thickness: 1.2,
                height: 36,
                color: Theme.of(context).dividerColor),
            if (!widget.hideOtherExpirySection) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10.0, top: 2.0),
                  child: Text(
                    "Other Supply Batches",
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
              // Show live supply batches from Supabase; if none, fall back to embedded batches if present
              SupabaseOtherSupplyBatches(
                item: updatedItem,
                onBatchTap: _showBatchDetails,
                excludeCurrentItem:
                    false, // Include all batches in overview mode
              ),
              _EmbeddedExpiryBatchesFallback(item: updatedItem),
            ],
          ],
        );
      },
    );
  }

  // Build batch details view showing all detailed fields
  Widget _buildBatchDetailsView(
      BuildContext context,
      ViewSupplyController controller,
      InventoryItem displayItem,
      String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 18),
        // Supply name with type
        Text(
          displayItem.type != null && displayItem.type!.isNotEmpty
              ? "${displayItem.name} (${displayItem.type})"
              : displayItem.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Theme.of(context).textTheme.bodyMedium?.color),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          displayItem.category,
          style: TextStyle(
            fontSize: 15,
            color:
                Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: displayItem.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: displayItem.imageUrl,
                    width: 130,
                    height: 130,
                    fit: BoxFit.cover,
                    placeholder: (context, url) {
                      debugPrint(
                          '[IMAGE_VIEW] Loading placeholder for ${displayItem.name} (URL: $url)');
                      return Container(
                        width: 130,
                        height: 130,
                        color: Theme.of(context).dividerColor.withOpacity(0.15),
                        child: const Icon(Icons.image,
                            size: 40, color: Colors.grey),
                      );
                    },
                    errorWidget: (context, url, error) {
                      debugPrint(
                          '[IMAGE_VIEW] ERROR loading ${displayItem.name} (URL: $url, Error: $error)');
                      return Container(
                        width: 130,
                        height: 130,
                        color: Theme.of(context).dividerColor.withOpacity(0.15),
                        child: const Icon(Icons.image_not_supported,
                            size: 40, color: Colors.grey),
                      );
                    },
                    fadeInDuration: const Duration(milliseconds: 200),
                    fadeOutDuration: const Duration(milliseconds: 100),
                  )
                : Container(
                    width: 130,
                    height: 130,
                    color: Theme.of(context).dividerColor.withOpacity(0.15),
                    child:
                        const Icon(Icons.image, size: 40, color: Colors.grey),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: controller.getStatusBgColor(status),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: controller.getStatusTextColor(status),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("Stock",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text("${displayItem.stock}",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500, fontSize: 15),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("Packaging Content/Unit",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                      displayItem.packagingContentQuantity != null &&
                              displayItem.packagingContentQuantity! > 0 &&
                              displayItem.packagingContent != null &&
                              displayItem.packagingContent!.isNotEmpty
                          ? "${displayItem.packagingContentQuantity} ${displayItem.packagingContent} per ${displayItem.packagingUnit ?? displayItem.unit}"
                          : displayItem.packagingUnit ?? displayItem.unit,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500, fontSize: 15),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("Cost",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text("₱${displayItem.cost.toStringAsFixed(2)}",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500, fontSize: 15),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("Brand Name",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final textPainter = TextPainter(
                        text: TextSpan(
                          text: displayItem.brand,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        textDirection: TextDirection.ltr,
                      );
                      textPainter.layout();

                      final textWidth = textPainter.width;
                      final containerWidth = constraints.maxWidth;

                      if (textWidth > containerWidth) {
                        // Text is too long, use marquee
                        return SizedBox(
                          height: 20,
                          child: Marquee(
                            text: displayItem.brand,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color),
                            scrollAxis: Axis.horizontal,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            blankSpace: 20.0,
                            velocity: 30.0,
                            pauseAfterRound: const Duration(seconds: 1),
                            startPadding: 10.0,
                            accelerationDuration: const Duration(seconds: 1),
                            accelerationCurve: Curves.linear,
                            decelerationDuration:
                                const Duration(milliseconds: 500),
                            decelerationCurve: Curves.easeOut,
                          ),
                        );
                      } else {
                        // Text fits, use normal text
                        return Text(
                          displayItem.brand,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.w500, fontSize: 15),
                          textAlign: TextAlign.center,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("Expiry",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                    (displayItem.expiry != null &&
                            displayItem.expiry!.isNotEmpty)
                        ? displayItem.expiry!.replaceAll('-', '/')
                        : "No expiry",
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500, fontSize: 15),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("Supplier",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final textPainter = TextPainter(
                        text: TextSpan(
                          text: displayItem.supplier,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        textDirection: TextDirection.ltr,
                      );
                      textPainter.layout();

                      final textWidth = textPainter.width;
                      final containerWidth = constraints.maxWidth;

                      if (textWidth > containerWidth) {
                        // long text = marquee animation
                        return SizedBox(
                          height: 20,
                          child: Marquee(
                            text: displayItem.supplier,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color),
                            scrollAxis: Axis.horizontal,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            blankSpace: 20.0,
                            velocity: 30.0,
                            pauseAfterRound: const Duration(seconds: 1),
                            startPadding: 10.0,
                            accelerationDuration: const Duration(seconds: 1),
                            accelerationCurve: Curves.linear,
                            decelerationDuration:
                                const Duration(milliseconds: 500),
                            decelerationCurve: Curves.easeOut,
                          ),
                        );
                      } else {
                        // short text = no animation
                        return Text(
                          displayItem.supplier,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.w500, fontSize: 15),
                          textAlign: TextAlign.center,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Divider(
            thickness: 1.2, height: 36, color: Theme.of(context).dividerColor),
        if (!widget.hideOtherExpirySection) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10.0, top: 2.0),
              child: Text(
                "Other Supply Batches",
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          // Show live supply batches from Supabase; if none, fall back to embedded batches if present
          SupabaseOtherSupplyBatches(
            item: displayItem,
            onBatchTap: _showBatchDetails,
            excludeCurrentItem:
                true, // Exclude current batch in batch details mode
          ),
          _EmbeddedExpiryBatchesFallback(item: displayItem),
        ],
      ],
    );
  }

  Future<void> _showArchiveBlockedDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 400,
              minWidth: 350,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // X Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Archive Supply Failed',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  'You can only archive this supply when all remaining stock is used or adjusted to zero.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
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
                      'Cancel',
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
          ),
        );
      },
    );
  }

  Widget _buildCustomDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 400,
          minWidth: 350,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon and Title
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: confirmColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: confirmColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              title,
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Content
            Text(
              content,
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

            // Buttons (Confirm first, then Cancel)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      confirmText,
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
                      'Cancel',
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
  }
}

class _EmbeddedExpiryBatchesFallback extends StatelessWidget {
  final InventoryItem item;
  const _EmbeddedExpiryBatchesFallback({required this.item});

  @override
  Widget build(BuildContext context) {
    // Try to read any embedded batches from the item via dynamic properties
    // Since InventoryItem doesn't define them, we rely on the snapshot stream
    // which already provided a fresh updatedItem – we cannot access raw map here.
    // So this fallback is a no-op unless the widget is provided with a complete
    // item map elsewhere. Keeping this as a placeholder for minimal, non-breaking change.
    return const SizedBox.shrink();
  }
}
