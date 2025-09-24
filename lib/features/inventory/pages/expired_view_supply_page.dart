import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';
import 'package:projects/features/inventory/components/expired_other_expiry_dates.dart';
import '../controller/expired_view_supply_controller.dart';
import 'package:projects/shared/themes/font.dart';

class ExpiredViewSupplyPage extends StatefulWidget {
  final InventoryItem item;
  final bool skipAutoRedirect; // when navigating from Other Expiry Dates
  const ExpiredViewSupplyPage(
      {super.key, required this.item, this.skipAutoRedirect = false});

  @override
  State<ExpiredViewSupplyPage> createState() => _ExpiredViewSupplyPageState();
}

class _ExpiredViewSupplyPageState extends State<ExpiredViewSupplyPage> {
  // ─── Real-time State ─────────────────────────────────────────────────────
  Key _streamKey = UniqueKey();

  // Method to refresh the stream
  void _refreshStream() {
    setState(() {
      _streamKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ExpiredViewSupplyController();

    return StreamBuilder<InventoryItem?>(
      key: _streamKey,
      stream: controller.supplyStream(widget.item.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: Text("Expired Supply",
                  style: AppFonts.sfProStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.white,
              iconTheme: const IconThemeData(size: 30, color: Colors.black),
            ),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text("Expired Supply",
                  style: AppFonts.sfProStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.white,
              iconTheme: const IconThemeData(size: 30, color: Colors.black),
            ),
            body: Center(child: Text("Item not found.")),
          );
        }
        final updatedItem = snapshot.data!;

        // For expired supplies, we don't need auto-redirect logic
        final status = "Expired"; // Force expired status
        return _buildScaffold(context, controller, updatedItem, status);
      },
    );
  }

  Widget _buildScaffold(
      BuildContext context,
      ExpiredViewSupplyController controller,
      InventoryItem updatedItem,
      String status) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Expired Supply",
          style: AppFonts.sfProStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: theme.appBarTheme.elevation,
        shadowColor: theme.appBarTheme.shadowColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: "Delete",
            onPressed: () => _showDeleteDialog(context, updatedItem),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _refreshStream();
            // Wait a bit for the stream to update
            await Future.delayed(Duration(milliseconds: 500));
          },
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 18),
                    Text(
                      updatedItem.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: theme.textTheme.bodyMedium?.color),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      updatedItem.category,
                      style: TextStyle(
                        fontSize: 15,
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
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
                                color: theme.dividerColor.withOpacity(0.15),
                                child: Icon(Icons.image,
                                    size: 40,
                                    color: theme.iconTheme.color
                                        ?.withOpacity(0.6)),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFF5B2B2B)
                              : const Color(0xFFFFCDD2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Expired",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFFFF8A80)
                                : const Color(0xFFFF4747),
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
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const SizedBox(height: 4),
                              StreamBuilder<int>(
                                stream:
                                    controller.aggregatedExpiredStockForDate(
                                  name: updatedItem.name,
                                  brand: updatedItem.brand,
                                  expiry: updatedItem.expiry,
                                ),
                                builder: (context, stockSnap) {
                                  final total =
                                      stockSnap.data ?? updatedItem.stock;
                                  return Text("$total",
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 15),
                                      textAlign: TextAlign.center);
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
                              Text("Unit",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(updatedItem.unit,
                                  style: theme.textTheme.bodyMedium?.copyWith(
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
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const SizedBox(height: 4),
                              Text("₱${updatedItem.cost.toStringAsFixed(2)}",
                                  style: theme.textTheme.bodyMedium?.copyWith(
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
                                  style: theme.textTheme.bodyMedium?.copyWith(
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
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 15,
                                                color: theme.textTheme
                                                    .bodyMedium?.color),
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
                                      style: theme.textTheme.bodyMedium
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
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(
                                (updatedItem.expiry != null &&
                                        updatedItem.expiry!.isNotEmpty)
                                    ? updatedItem.expiry!.replaceAll('-', '/')
                                    : "No expiry",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500, fontSize: 15),
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
                                  style: theme.textTheme.bodyMedium?.copyWith(
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
                                    // Text is too long, use marquee
                                    return SizedBox(
                                      height: 20,
                                      child: Marquee(
                                        text: updatedItem.supplier,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 15,
                                                color: theme.textTheme
                                                    .bodyMedium?.color),
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
                                      updatedItem.supplier,
                                      style: theme.textTheme.bodyMedium
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
                    const SizedBox(height: 24),
                    Divider(
                        thickness: 1.2, height: 36, color: theme.dividerColor),
                    // Other Expired Batches Section
                    if (!updatedItem.noExpiry &&
                        updatedItem.expiry != null &&
                        updatedItem.expiry!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(bottom: 10.0, top: 2.0),
                        child: Text(
                          "Other Expired Batches",
                          style: AppFonts.sfProStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                      ExpiredOtherExpiryBatches(item: updatedItem),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, InventoryItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _buildCustomDialog(
          context,
          title: 'Delete Supply',
          content:
              'Are you sure you want to permanently delete "${item.name}"?\n\nThis action cannot be undone.',
          confirmText: 'Delete',
          confirmColor: Colors.red,
          icon: Icons.delete,
          item: item,
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
    required InventoryItem item,
  }) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.dialogBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: confirmColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: confirmColor),
            ),
            SizedBox(height: 16),
            Text(
              title,
              style: AppFonts.sfProStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              content,
              style: AppFonts.sfProStyle(
                fontSize: 16,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: AppFonts.sfProStyle(
                        fontSize: 16,
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      // Delete the item first
                      final controller = ExpiredViewSupplyController();
                      try {
                        await controller.deleteSupply(item.id);
                        if (context.mounted) {
                          // Show success message first
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Supply deleted permanently!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          // Small delay to show success message, then navigate back
                          await Future.delayed(Duration(milliseconds: 500));
                          // Navigate back to expired supply page with result
                          Navigator.of(context).pop('deleted');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to delete supply: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: AppFonts.sfProStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
