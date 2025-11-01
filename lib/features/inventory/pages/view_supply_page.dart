import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/inventory/components/inventory_other_supply_batches.dart';
import 'package:familee_dental/features/inventory/pages/edit_supply_page.dart';
import 'package:familee_dental/features/inventory/controller/view_supply_controller.dart';
import 'package:familee_dental/features/inventory/pages/archive_supply_page.dart';
import 'package:familee_dental/features/inventory/pages/expired_view_supply_page.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';

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
  Key _dropdownKey = UniqueKey();

  // Method to refresh the stream
  void _refreshStream() {
    setState(() {
      _streamKey = UniqueKey();
      _dropdownKey = UniqueKey();
    });
  }

  @override
  void initState() {
    super.initState();
    _refreshStream();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ViewSupplyController();

    return StreamBuilder<InventoryItem?>(
      key: _streamKey,
      stream: controller.supplyStream(widget.item.id),
      builder: (context, snapshot) {
        // Handle errors
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading supply details',
              style: AppFonts.sfProStyle(
                fontSize: 16,
                color: Colors.red,
              ),
            ),
          );
        }

        // Always use stream data if available, otherwise use the initial item from widget
        // This ensures we always have data to display and never show loading indicator
        final updatedItem = snapshot.hasData && snapshot.data != null
            ? snapshot.data!
            : widget.item;

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
          final status = controller.getStatus(updatedItem);
          return _buildScaffold(context, controller, updatedItem, status);
        }
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: Supabase.instance.client
              .from('supplies')
              .select('*')
              .eq('name', updatedItem.name)
              .eq('brand', updatedItem.brand)
              .eq('type', updatedItem.type ?? ''),
          builder: (context, batchSnap) {
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
                            unit: preferredRow['unit'] ?? '',
                            supplier: preferredRow['supplier'] ?? '',
                            brand: preferredRow['brand'] ?? '',
                            expiry: preferredRow['expiry'],
                            noExpiry: preferredRow['no_expiry'] ?? false,
                            archived: preferredRow['archived'] ?? false,
                          ),
                          skipAutoRedirect: true,
                        ),
                      ),
                    );
                  }
                });
              }
            }
            // Fall back to normal render
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
    final theme = Theme.of(context);
    return Scaffold(
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
          if (!updatedItem.archived) ...[
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
                        item: updatedItem,
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
                          .eq('id', updatedItem.id)
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
                          isExpiredNow = d.isBefore(t) || d.isAtSameMomentAs(t);
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
                      content: 'Are you sure you want to archive this supply?',
                      confirmText: 'Archive',
                      confirmColor: Colors.orange,
                      icon: Icons.archive,
                    ),
                  );
                  if (confirmed == true) {
                    await controller.archiveSupply(updatedItem.id);
                    // Refresh the stream to show updated status
                    _refreshStream();
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => ArchiveSupplyPage(),
                      ),
                    );
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
                    await controller.unarchiveSupply(updatedItem.id);
                    // Refresh the stream to show updated status
                    _refreshStream();
                    if (!context.mounted) return;
                    Navigator.of(context).pop(
                        'unarchived'); // Go back to archive page with result
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
                    try {
                      await controller.deleteSupply(updatedItem.id);
                      if (!context.mounted) return;
                      Navigator.of(context).pop(); // Go back to archive page
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Supply deleted permanently!'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete supply: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
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
                  await controller.supplyStream(widget.item.id).first;
                },
                child: SingleChildScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        MediaQuery.of(context).size.width < 768 ? 8.0 : 18.0,
                    vertical:
                        MediaQuery.of(context).size.width < 768 ? 8.0 : 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 18),
                      // Supply name with type and dropdown
                      Stack(
                        children: [
                          // Centered supply name
                          Center(
                            child: Text(
                              updatedItem.type != null &&
                                      updatedItem.type!.isNotEmpty
                                  ? "${updatedItem.name} (${updatedItem.type})"
                                  : updatedItem.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Dropdown positioned on the right (only for non-archived items)
                          if (!updatedItem.archived)
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: FutureBuilder<List<String>>(
                                key:
                                    _dropdownKey, // Force refresh when data changes
                                future: _getSupplyTypes(updatedItem.name),
                                builder: (context, snapshot) {
                                  final existingTypes = snapshot.data ?? [];

                                  // If no type exists, show "Add type" button
                                  if (updatedItem.type == null ||
                                      updatedItem.type!.isEmpty) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Theme.of(context).dividerColor,
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () =>
                                              _showAddTypeDialog(updatedItem),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 3,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.add,
                                                  size: 16,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.color,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Add type',
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.color,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  // If type exists, show dropdown
                                  return DropdownButton<String>(
                                    value: updatedItem.type!,
                                    items: [
                                      // Current type
                                      DropdownMenuItem<String>(
                                        value: updatedItem.type!,
                                        child: Text(updatedItem.type!),
                                      ),
                                      // Other existing types
                                      ...existingTypes
                                          .where((type) =>
                                              type != updatedItem.type)
                                          .map((type) =>
                                              DropdownMenuItem<String>(
                                                value: type,
                                                child: Text(type),
                                              )),
                                      // Add new type option
                                      DropdownMenuItem<String>(
                                        value: 'ADD_NEW_TYPE',
                                        child: Row(
                                          children: [
                                            Icon(Icons.add, size: 16),
                                            SizedBox(width: 4),
                                            Text('Add type'),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onChanged: (String? newType) {
                                      if (newType == 'ADD_NEW_TYPE') {
                                        _showAddTypeDialog(updatedItem);
                                      } else if (newType != null &&
                                          newType != updatedItem.type) {
                                        _navigateToSupplyType(
                                            updatedItem.name, newType);
                                      }
                                    },
                                    underline: Container(),
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color,
                                    ),
                                  );
                                },
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
                              ? Image.network(
                                  updatedItem.imageUrl,
                                  width: 130,
                                  height: 130,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 130,
                                  height: 130,
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withOpacity(0.15),
                                  child: const Icon(Icons.image,
                                      size: 40, color: Colors.grey),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                const SizedBox(height: 4),
                                Text("${updatedItem.stock}",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 15),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(
                                    updatedItem.packagingContentQuantity !=
                                                null &&
                                            updatedItem
                                                    .packagingContentQuantity! >
                                                0 &&
                                            updatedItem.packagingContent !=
                                                null &&
                                            updatedItem
                                                .packagingContent!.isNotEmpty
                                        ? "${updatedItem.packagingContentQuantity} ${updatedItem.packagingContent} per ${updatedItem.packagingUnit ?? updatedItem.unit}"
                                        : updatedItem.packagingUnit ??
                                            updatedItem.unit,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 15),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                const SizedBox(height: 4),
                                Text("₱${updatedItem.cost.toStringAsFixed(2)}",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 15),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                const SizedBox(height: 4),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final textPainter = TextPainter(
                                      text: TextSpan(
                                        text: updatedItem.brand,
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
                                          text: updatedItem.brand,
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          blankSpace: 20.0,
                                          velocity: 30.0,
                                          pauseAfterRound:
                                              const Duration(seconds: 1),
                                          startPadding: 10.0,
                                          accelerationDuration:
                                              const Duration(seconds: 1),
                                          accelerationCurve: Curves.linear,
                                          decelerationDuration:
                                              const Duration(milliseconds: 500),
                                          decelerationCurve: Curves.easeOut,
                                        ),
                                      );
                                    } else {
                                      // Text fits, use normal text
                                      return Text(
                                        updatedItem.brand,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 15),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(
                                  (updatedItem.expiry != null &&
                                          updatedItem.expiry!.isNotEmpty)
                                      ? updatedItem.expiry!.replaceAll('-', '/')
                                      : "No expiry",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                const SizedBox(height: 4),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final textPainter = TextPainter(
                                      text: TextSpan(
                                        text: updatedItem.supplier,
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
                                          text: updatedItem.supplier,
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          blankSpace: 20.0,
                                          velocity: 30.0,
                                          pauseAfterRound:
                                              const Duration(seconds: 1),
                                          startPadding: 10.0,
                                          accelerationDuration:
                                              const Duration(seconds: 1),
                                          accelerationCurve: Curves.linear,
                                          decelerationDuration:
                                              const Duration(milliseconds: 500),
                                          decelerationCurve: Curves.easeOut,
                                        ),
                                      );
                                    } else {
                                      // short text = no animation
                                      return Text(
                                        updatedItem.supplier,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 15),
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
                          thickness: 1.2,
                          height: 36,
                          color: Theme.of(context).dividerColor),
                      if (!widget.hideOtherExpirySection) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding:
                                const EdgeInsets.only(bottom: 10.0, top: 2.0),
                            child: Text(
                              "Other Supply Batches",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                            ),
                          ),
                        ),
                        // Show live supply batches from Supabase; if none, fall back to embedded batches if present
                        SupabaseOtherSupplyBatches(item: updatedItem),
                        _EmbeddedExpiryBatchesFallback(item: updatedItem),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

            // Buttons (Cancel first, then Confirm - matching exit dialog pattern)
            Row(
              children: [
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
                const SizedBox(width: 12),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get all types for a supply name
  Future<List<String>> _getSupplyTypes(String supplyName) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('supplies')
          .select('type')
          .eq('name', supplyName)
          .eq('archived', false);

      final types = <String>[];
      for (final row in response) {
        final type = row['type'] as String?;
        if (type != null && type.isNotEmpty && !types.contains(type)) {
          types.add(type);
        }
      }
      return types;
    } catch (e) {
      print('Error getting supply types: $e');
      return [];
    }
  }

  // Helper method to navigate to a specific supply type
  void _navigateToSupplyType(String supplyName, String type) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('supplies')
          .select('*')
          .eq('name', supplyName)
          .eq('type', type)
          .eq('archived', false)
          .limit(1);

      if (response.isNotEmpty) {
        final row = response.first;
        final item = InventoryItem(
          id: row['id'] as String,
          name: row['name'] ?? '',
          type: row['type'],
          imageUrl: row['image_url'] ?? '',
          category: row['category'] ?? '',
          cost: (row['cost'] ?? 0).toDouble(),
          stock: (row['stock'] ?? 0).toInt(),
          unit: row['unit'] ?? '',
          packagingUnit: row['packaging_unit'],
          packagingContent: row['packaging_content'],
          packagingQuantity: row['packaging_quantity'],
          packagingContentQuantity: row['packaging_content_quantity'],
          supplier: row['supplier'] ?? '',
          brand: row['brand'] ?? '',
          expiry: row['expiry'],
          noExpiry: row['no_expiry'] ?? false,
          archived: row['archived'] ?? false,
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => InventoryViewSupplyPage(
              item: item,
              skipAutoRedirect: widget.skipAutoRedirect,
              hideOtherExpirySection: widget.hideOtherExpirySection,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error navigating to supply type: $e');
    }
  }

  // Show dialog to add new type
  void _showAddTypeDialog(InventoryItem currentItem) {
    final typeController = TextEditingController();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        int stockQuantity = 0;
        final stockController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setState) => Scaffold(
            resizeToAvoidBottomInset: true,
            backgroundColor: Colors.transparent,
            body: Center(
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor:
                    isDark ? const Color(0xFF2C2C2C) : Colors.white,
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 400,
                    minWidth: 350,
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.green,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title
                          Text(
                            'Add New Type',
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
                            'Add a new type for "${currentItem.name}"',
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

                          // TextField
                          TextField(
                            controller: typeController,
                            autofocus: true,
                            decoration: InputDecoration(
                              labelText: 'Type Name',
                              hintText: 'e.g., Color, Size, Type, etc.',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Colors.green, width: 2),
                              ),
                              labelStyle: TextStyle(
                                fontFamily: 'SF Pro',
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                              hintStyle: TextStyle(
                                fontFamily: 'SF Pro',
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Stock Quantity Selector
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Stock Quantity',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Enter quantity',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Colors.green, width: 2),
                              ),
                              hintStyle: TextStyle(
                                fontFamily: 'SF Pro',
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                            onChanged: (value) {
                              final parsed = int.tryParse(value);
                              if (parsed != null &&
                                  parsed >= 0 &&
                                  parsed <= 99) {
                                setState(() {
                                  stockQuantity = parsed;
                                });
                              } else if (value.isEmpty) {
                                setState(() {
                                  stockQuantity = 0;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 24),

                          // Buttons (Cancel first, then Add Type - matching logout dialog pattern)
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(
                                          color: Colors.grey, width: 1),
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: theme.textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final newType = typeController.text.trim();
                                    if (newType.isNotEmpty) {
                                      // Show confirmation dialog
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            backgroundColor: isDark
                                                ? const Color(0xFF2C2C2C)
                                                : Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            title: Text(
                                              'Confirm Add Type',
                                              style: TextStyle(
                                                fontFamily: 'SF Pro',
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: theme.textTheme
                                                    .titleLarge?.color,
                                              ),
                                            ),
                                            content: Text(
                                              'Add new type "$newType" with stock quantity $stockQuantity?',
                                              style: TextStyle(
                                                fontFamily: 'SF Pro',
                                                fontSize: 16,
                                                color: theme
                                                    .textTheme.bodyLarge?.color,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(false),
                                                child: Text(
                                                  'Cancel',
                                                  style: TextStyle(
                                                    fontFamily: 'SF Pro',
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: Text(
                                                  'Confirm',
                                                  style: TextStyle(
                                                    fontFamily: 'SF Pro',
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                      if (confirmed == true) {
                                        Navigator.of(context).pop();
                                        await _createNewType(currentItem,
                                            newType, stockQuantity);
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    'Add Type',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Create new supply item with same details but new type
  Future<void> _createNewType(
      InventoryItem currentItem, String newType, int stockQuantity) async {
    try {
      final supabase = Supabase.instance.client;

      // Fetch the most recent type added for this supply name
      final latestSupplyResponse = await supabase
          .from('supplies')
          .select()
          .eq('name', currentItem.name)
          .eq('archived', false)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      // Use the latest supply if available, otherwise fall back to current item
      final sourceItem = latestSupplyResponse != null
          ? InventoryItem(
              id: latestSupplyResponse['id'] as String,
              name: latestSupplyResponse['name'] ?? '',
              type: latestSupplyResponse['type'],
              imageUrl: latestSupplyResponse['image_url'] ?? '',
              category: latestSupplyResponse['category'] ?? '',
              cost: (latestSupplyResponse['cost'] ?? 0).toDouble(),
              stock: (latestSupplyResponse['stock'] ?? 0).toInt(),
              unit: latestSupplyResponse['unit'] ?? '',
              packagingUnit: latestSupplyResponse['packaging_unit'],
              packagingContent: latestSupplyResponse['packaging_content'],
              packagingQuantity: latestSupplyResponse['packaging_quantity'],
              packagingContentQuantity:
                  latestSupplyResponse['packaging_content_quantity'],
              supplier: latestSupplyResponse['supplier'] ?? '',
              brand: latestSupplyResponse['brand'] ?? '',
              expiry: latestSupplyResponse['expiry'],
              noExpiry: latestSupplyResponse['no_expiry'] ?? false,
              archived: latestSupplyResponse['archived'] ?? false,
            )
          : currentItem;

      // Create new supply item with same details but new type
      final newSupplyData = {
        'name': sourceItem.name,
        'type': newType,
        'image_url': sourceItem.imageUrl,
        'category': sourceItem.category,
        'cost': sourceItem.cost,
        'stock': stockQuantity, // Use selected stock quantity
        'unit': sourceItem.unit,
        'packaging_unit': sourceItem.packagingUnit,
        'packaging_quantity': sourceItem.packagingQuantity,
        'packaging_content': sourceItem.packagingContent,
        'packaging_content_quantity': sourceItem.packagingContentQuantity,
        'supplier': sourceItem.supplier,
        'brand': sourceItem.brand,
        'expiry': sourceItem.expiry,
        'no_expiry': sourceItem.noExpiry,
        'archived': false,
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await supabase
          .from('supplies')
          .insert(newSupplyData)
          .select()
          .single();

      // Navigate to the new supply item
      final newItem = InventoryItem(
        id: response['id'] as String,
        name: response['name'] ?? '',
        type: response['type'],
        imageUrl: response['image_url'] ?? '',
        category: response['category'] ?? '',
        cost: (response['cost'] ?? 0).toDouble(),
        stock: (response['stock'] ?? 0).toInt(),
        unit: response['unit'] ?? '',
        packagingUnit: response['packaging_unit'],
        packagingContent: response['packaging_content'],
        packagingQuantity: response['packaging_quantity'],
        packagingContentQuantity: response['packaging_content_quantity'],
        supplier: response['supplier'] ?? '',
        brand: response['brand'] ?? '',
        expiry: response['expiry'],
        noExpiry: response['no_expiry'] ?? false,
        archived: response['archived'] ?? false,
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => InventoryViewSupplyPage(
            item: newItem,
            skipAutoRedirect: widget.skipAutoRedirect,
            hideOtherExpirySection: widget.hideOtherExpirySection,
          ),
        ),
      );

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New type "$newType" added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error creating new type: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add new type: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
