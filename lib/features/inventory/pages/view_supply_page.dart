import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';
import 'package:projects/features/inventory/components/inventory_other_expiry_dates.dart';
import 'package:projects/features/inventory/pages/edit_supply_page.dart';
import '../controller/view_supply_controller.dart';
import 'package:projects/features/inventory/pages/archive_supply_page.dart';

class InventoryViewSupplyPage extends StatelessWidget {
  final InventoryItem item;
  const InventoryViewSupplyPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final controller = ViewSupplyController();

    return StreamBuilder<InventoryItem?>(
      stream: controller.supplyStream(item.id),
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
        final status = controller.getStatus(updatedItem);
        return Scaffold(
          backgroundColor: const Color(0xFFF9EFF2),
          appBar: AppBar(
            title: const Text(
              "Inventory",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.white,
            toolbarHeight: 70,
            iconTheme: const IconThemeData(size: 30, color: Colors.black),
            elevation: 5,
            shadowColor: Colors.black54,
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Supply updated!')),
                      );
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
                        content:
                            'Are you sure you want to archive this supply?',
                        confirmText: 'Archive',
                        confirmColor: Colors.orange,
                        icon: Icons.archive,
                      ),
                    );
                    if (confirmed == true) {
                      await controller.archiveSupply(updatedItem.id);
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
                        content:
                            'Are you sure you want to unarchive this supply?',
                        confirmText: 'Unarchive',
                        confirmColor: Colors.blue,
                        icon: Icons.unarchive,
                      ),
                    );
                    if (confirmed == true) {
                      await controller.unarchiveSupply(updatedItem.id);
                      if (!context.mounted) return;
                      Navigator.of(context).pop(); // Go back to archive page
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
                SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 18),
                      Text(
                        updatedItem.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        updatedItem.category,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
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
                                  color: Colors.grey[200],
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
                                const Text("Stock",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const SizedBox(height: 4),
                                Text("${updatedItem.stock}",
                                    style: const TextStyle(
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
                                const Text("Unit",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(updatedItem.unit,
                                    style: const TextStyle(
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
                                const Text("Cost",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const SizedBox(height: 4),
                                Text("₱${updatedItem.cost.toStringAsFixed(2)}",
                                    style: const TextStyle(
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
                                const Text("Brand Name",
                                    style: TextStyle(
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
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 15,
                                              color: Colors.black),
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
                                        style: const TextStyle(
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
                                const Text("Expiry",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(
                                  (updatedItem.expiry != null &&
                                          updatedItem.expiry!.isNotEmpty)
                                      ? updatedItem.expiry!
                                      : "No expiry",
                                  style: const TextStyle(
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
                                const Text("Supplier",
                                    style: TextStyle(
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
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 15,
                                              color: Colors.black),
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
                                        style: const TextStyle(
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
                      Divider(thickness: 1.2, height: 36),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding:
                              const EdgeInsets.only(bottom: 10.0, top: 2.0),
                          child: Text(
                            "Other Expiry Dates",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                      ),
                      FirestoreOtherExpiryBatches(item: updatedItem),
                    ],
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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
                    color: Colors.black87,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Content
            Text(
              content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black54,
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
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
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
