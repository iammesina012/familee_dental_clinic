import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';
import 'package:projects/features/inventory/components/inventory_other_expiry_dates.dart';
import 'package:projects/features/inventory/pages/edit_supply_page.dart';
import 'package:projects/features/inventory/controller/view_supply_controller.dart';
import 'package:projects/features/inventory/pages/archive_supply_page.dart';
import 'package:projects/features/inventory/pages/expired_view_supply_page.dart';

class InventoryViewSupplyPage extends StatefulWidget {
  final InventoryItem item;
  final bool skipAutoRedirect; // when navigating from Other Expiry Dates
  final bool
      hideOtherExpirySection; // hide Other Expiry Dates section (e.g., from Expired page)
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

  // Method to refresh the stream
  void _refreshStream() {
    setState(() {
      _streamKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ViewSupplyController();

    return StreamBuilder<InventoryItem?>(
      key: _streamKey,
      stream: controller.supplyStream(widget.item.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text("Inventory")),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: Text("Inventory")),
            body: Center(child: Text("Item not found.")),
          );
        }
        final updatedItem = snapshot.data!;
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
              .eq('brand', updatedItem.brand),
          builder: (context, batchSnap) {
            if (batchSnap.hasData) {
              final rows = batchSnap.data!;
              DateTime? earliest;
              Map<String, dynamic>? earliestRow;
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
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
              if (earliestRow != null && earliestRow['id'] != updatedItem.id) {
                // Replace page with earliest batch view
                // Schedule navigation after current frame to avoid ancestor lookup on deactivated context
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => InventoryViewSupplyPage(
                          item: InventoryItem(
                            id: earliestRow!['id'] as String,
                            name: earliestRow['name'] ?? '',
                            imageUrl: earliestRow['image_url'] ?? '',
                            category: earliestRow['category'] ?? '',
                            cost: (earliestRow['cost'] ?? 0).toDouble(),
                            stock: (earliestRow['stock'] ?? 0).toInt(),
                            unit: earliestRow['unit'] ?? '',
                            supplier: earliestRow['supplier'] ?? '',
                            brand: earliestRow['brand'] ?? '',
                            expiry: earliestRow['expiry'],
                            noExpiry: earliestRow['no_expiry'] ?? false,
                            archived: earliestRow['archived'] ?? false,
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
                        final t = DateTime(today.year, today.month, today.day);
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
            IconButton(
              icon: const Icon(Icons.unarchive, color: Colors.blue),
              tooltip: "Unarchive",
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => _buildCustomDialog(
                    context,
                    title: 'Unarchive Supply',
                    content: 'Are you sure you want to unarchive this supply?',
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
                  Navigator.of(context)
                      .pop('unarchived'); // Go back to archive page with result
                }
              },
            ),
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
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                _refreshStream();
                // Wait a bit for the stream to update
                await Future.delayed(Duration(milliseconds: 500));
              },
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 18),
                    Text(
                      updatedItem.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Theme.of(context).textTheme.bodyMedium?.color),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
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
                              Text("Unit",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(updatedItem.unit,
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
                            "Other Expiry Dates",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                      ),
                      // Show live batches from Firestore; if none, fall back to embedded expiryBatches if present
                      SupabaseOtherExpiryBatches(item: updatedItem),
                      _EmbeddedExpiryBatchesFallback(item: updatedItem),
                    ],
                  ],
                ),
              ),
            ),
          ],
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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      backgroundColor: theme.colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: theme.textTheme.titleLarge?.color,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Content
            Text(
              content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    height: 1.4,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Buttons
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
                            color: theme.dividerColor.withOpacity(0.4)),
                      ),
                      foregroundColor: theme.textTheme.bodyMedium?.color,
                    ),
                    child: Text(
                      'Cancel',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.7),
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
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
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
