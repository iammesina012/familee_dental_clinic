import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familee_dental/features/purchase_order/data/purchase_order.dart';
import 'package:familee_dental/features/purchase_order/controller/po_details_controller.dart';
import 'package:familee_dental/features/purchase_order/controller/po_supabase_controller.dart';
import 'package:familee_dental/features/purchase_order/services/receipt_storage_service.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/activity_log/controller/po_activity_controller.dart';
import 'package:familee_dental/features/notifications/controller/notifications_controller.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/services/connectivity_service.dart';
import 'package:familee_dental/shared/widgets/connection_error_dialog.dart';

class PODetailsPage extends StatefulWidget {
  final PurchaseOrder purchaseOrder;

  const PODetailsPage({Key? key, required this.purchaseOrder})
      : super(key: key);

  @override
  State<PODetailsPage> createState() => _PODetailsPageState();
}

class _ReceiptDetails {
  final String drNumber;
  final String recipient;
  final String remarks;
  final XFile? image;
  _ReceiptDetails(
      {required this.drNumber,
      required this.recipient,
      required this.remarks,
      required this.image});
}

class _PODetailsPageState extends State<PODetailsPage> {
  late PurchaseOrder _purchaseOrder;
  final PODetailsController _controller = PODetailsController();
  final POSupabaseController _poSupabase = POSupabaseController();
  final ReceiptStorageService _receiptStorage = ReceiptStorageService();
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isLoading = false;
  final Map<String, int> _supplierPageIndex = {};
  final Set<String> _expandedSuppliers = {};
  final Map<String, TextEditingController> _remarksControllers = {};
  bool _hasPrecachedReceiptImages = false;

  // Checklist state for tracking which items are checked
  final Map<String, Set<String>> _checkedItems =
      {}; // supplierName -> Set of item keys

  // Helper methods for checklist management
// ignore: unused_element
  void _toggleItemCheck(String supplierName, String itemKey) async {
    setState(() {
      _checkedItems[supplierName] ??= <String>{};
      if (_checkedItems[supplierName]!.contains(itemKey)) {
        _checkedItems[supplierName]!.remove(itemKey);
      } else {
        _checkedItems[supplierName]!.add(itemKey);
      }
    });

    // Check if all items are now checked
    final suppliers =
        _controller.groupSuppliesBySupplier(_purchaseOrder.supplies);
    final items = suppliers[supplierName] ?? [];
    final pendingItems =
        items.where((item) => !_controller.isSupplyReceived(item)).toList();

    if (pendingItems.isNotEmpty) {
      // Generate all possible keys that should be checked (matching UI logic)
      final Set<String> allPossibleKeys = {};
      for (int itemIndex = 0; itemIndex < pendingItems.length; itemIndex++) {
        final item = pendingItems[itemIndex];
        final batches = item['expiryBatches'] as List<dynamic>?;
        if (batches != null && batches.isNotEmpty) {
          // Check if there are any batches with actual expiry dates
          final hasExpiryDates =
              batches.any((b) => _formatExpiry(b['expiryDate']) != null);

          if (hasExpiryDates) {
            // Handle batches with expiry dates
            for (final batch in batches) {
              final String? date = _formatExpiry(batch['expiryDate']);
              final int qty = int.tryParse('${batch['quantity'] ?? 0}') ?? 0;
              if (date != null) {
                final batchKey =
                    '${supplierName}_${item['name']}_${date}_${qty}_${itemIndex}';
                allPossibleKeys.add(batchKey);
              }
            }
          } else {
            // Handle batches with no expiry dates (No expiry supplies with batches)
            final noExpiryKey =
                '${supplierName}_${item['name']}_no_expiry_${itemIndex}';
            allPossibleKeys.add(noExpiryKey);
          }
        } else {
          final single = _formatExpiry(item['expiryDate']);
          if (single != null) {
            final singleKey =
                '${supplierName}_${item['name']}_${single}_${itemIndex}';
            allPossibleKeys.add(singleKey);
          } else {
            final noExpiryKey =
                '${supplierName}_${item['name']}_no_expiry_${itemIndex}';
            allPossibleKeys.add(noExpiryKey);
          }
        }
      }

      final checkedSet = _checkedItems[supplierName] ?? <String>{};

      if (checkedSet.length == allPossibleKeys.length &&
          allPossibleKeys.length > 0) {
        // All items are checked, show confirmation dialog
        final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(
                  'Supplies Received',
                  style: AppFonts.sfProStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Text(
                  'All supplies from $supplierName have been received. Proceed to Receipt Details?',
                  style: AppFonts.sfProStyle(fontSize: 14),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Go Back',
                      style: AppFonts.sfProStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      'Proceed',
                      style: AppFonts.sfProStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00D4AA),
                      ),
                    ),
                  ),
                ],
              ),
            ) ??
            false;

        if (confirm) {
          // Directly proceed to receipt details for manual checkbox checking
          final receiptDetails = await _showReceiptDetailsDialog(supplierName);
          if (receiptDetails == null) return; // user tapped Back

          if (!await _ensureInternetConnection()) {
            return;
          }

          setState(() => _isLoading = true);
          try {
            // Upload receipt image to cloud storage first
            String? receiptImageUrl;
            if (receiptDetails.image != null) {
              receiptImageUrl = await _receiptStorage
                  .uploadReceiptImage(receiptDetails.image!);
              if (receiptImageUrl == null) {
                setState(() => _isLoading = false);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Failed to upload receipt image. Please try again.',
                      style: AppFonts.sfProStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white),
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
                return;
              }
            }

            // Mark supplies as received
            final updatedSupplies =
                List<Map<String, dynamic>>.from(_purchaseOrder.supplies);
            final String nowIso = DateTime.now().toIso8601String();
            for (final item in pendingItems) {
              final idx = updatedSupplies.indexOf(item);
              updatedSupplies[idx] = {
                ...item,
                'status': 'Received',
                'receiptDrNo': receiptDetails.drNumber,
                'receiptRecipient': receiptDetails.recipient,
                'receiptRemarks': receiptDetails.remarks,
                'receiptImagePath':
                    receiptImageUrl, // Now stores cloud URL instead of local path
                'receiptDate': nowIso,
              };
            }

            // Add recipient name to suggestions for future use
            if (receiptDetails.recipient.isNotEmpty) {
              await _controller
                  .addRecipientSuggestion(receiptDetails.recipient);
            }

            // Update the purchase order with received supplies
            final newReceivedCount =
                updatedSupplies.where((s) => s['status'] == 'Received').length;
            String newStatus = _purchaseOrder.status;
            if (newReceivedCount == updatedSupplies.length) {
              newStatus = 'Approval';
            }

            final updatedPO = PurchaseOrder(
              id: _purchaseOrder.id,
              code: _purchaseOrder.code,
              name: _purchaseOrder.name,
              createdAt: _purchaseOrder.createdAt,
              status: newStatus,
              supplies: updatedSupplies,
              receivedCount: newReceivedCount,
            );

            await _poSupabase.updatePOInSupabase(updatedPO);
            setState(() {
              _purchaseOrder = updatedPO;
              // Update checked items state to reflect received supplies
              _checkedItems[supplierName] ??= <String>{};
              for (int itemIndex = 0;
                  itemIndex < pendingItems.length;
                  itemIndex++) {
                final item = pendingItems[itemIndex];
                final batches = item['expiryBatches'] as List<dynamic>?;
                if (batches != null && batches.isNotEmpty) {
                  for (final batch in batches) {
                    final String? date = _formatExpiry(batch['expiryDate']);
                    final int qty =
                        int.tryParse('${batch['quantity'] ?? 0}') ?? 0;
                    if (date != null) {
                      final batchKey =
                          '${supplierName}_${item['name']}_${date}_${qty}_${itemIndex}';
                      _checkedItems[supplierName]!.add(batchKey);
                    }
                  }
                } else {
                  final single = _formatExpiry(item['expiryDate']);
                  if (single != null) {
                    final singleKey =
                        '${supplierName}_${item['name']}_${single}_${itemIndex}';
                    _checkedItems[supplierName]!.add(singleKey);
                  } else {
                    final noExpiryKey =
                        '${supplierName}_${item['name']}_no_expiry_${itemIndex}';
                    _checkedItems[supplierName]!.add(noExpiryKey);
                  }
                }
              }
            });

            // Log activity and send notification if status changed to Approval
            await PoActivityController().logPurchaseOrderReceived(
              poCode: updatedPO.code,
              poName: updatedPO.name,
              supplies: pendingItems,
            );

            if (_purchaseOrder.status != 'Approval' &&
                newStatus == 'Approval') {
              try {
                await NotificationsController()
                    .createPOWaitingApprovalNotification(updatedPO.code);
              } catch (_) {}
            }

            if (!mounted) return;
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Supplies marked as received successfully!',
                  style: AppFonts.sfProStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white),
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );

            // Don't navigate away - stay on the page so user can see the updated status
            // and have the option to approve/reject the PO
          } catch (e) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error marking supplies as received: ${e.toString()}',
                  style: AppFonts.sfProStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white),
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          // User chose to go back, uncheck all items
          setState(() {
            _checkedItems[supplierName]?.clear();
          });
          // Save the updated state
          await _saveChecklistState();
        }
      }
    }

    // Save the updated state to SharedPreferences
    await _saveChecklistState();
  }

  // Save checklist state to SharedPreferences
  Future<void> _saveChecklistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String poId = _purchaseOrder.id;
      final String key = 'po_checklist_$poId';

      // Convert the map to a JSON string
      final Map<String, List<String>> serializableMap = {};
      _checkedItems.forEach((supplier, items) {
        serializableMap[supplier] = items.toList();
      });

      final String jsonString = jsonEncode(serializableMap);
      await prefs.setString(key, jsonString);
    } catch (e) {
      print('Error saving checklist state: $e');
    }
  }

  Future<bool> _ensureInternetConnection() async {
    final hasConnection = await _connectivityService.hasInternetConnection();
    if (!hasConnection && mounted) {
      await showConnectionErrorDialog(context);
    }
    return hasConnection;
  }

  Future<void> _precacheReceiptImages() async {
    if (_hasPrecachedReceiptImages || !mounted) return;

    final Set<String> urls = {};
    for (final supply in _purchaseOrder.supplies) {
      final pathOrUrl =
          (supply['receiptImagePath'] ?? supply['receiptImageUrl'] ?? '')
              .toString()
              .trim();
      if (pathOrUrl.isEmpty) continue;
      if (pathOrUrl.startsWith('http')) {
        urls.add(pathOrUrl);
      }
    }

    for (final url in urls) {
      try {
        await precacheImage(CachedNetworkImageProvider(url), context);
      } catch (_) {
        // Ignore failures, image will attempt to load normally in the UI.
      }
    }

    _hasPrecachedReceiptImages = true;
  }

  Future<void> _prepareInitialData() async {
    try {
      await _poSupabase.preloadFromLocalCache();
    } catch (_) {
      // Ignore errors; caches are optional.
    }

    await _precacheReceiptImages();
  }

  Future<void> _handlePostFrameTasks() async {
    await _prepareInitialData();
    if (!mounted) return;
  }

  // Check if remarks can be edited based on user role and PO status
  bool _canEditRemarks() {
    // Only allow editing in Closed status
    if (_purchaseOrder.status != 'Closed') return false;

    // Owner and Admin can edit remarks in closed section
    // Staff cannot edit remarks in closed section (they can only add during receipt)
    return !UserRoleProvider().isStaff;
  }

  // Check if there are no changes to save (no received supplies)
  bool _hasNoChanges() {
    // If PO is in Open status and no supplies have been received/partially received
    if (_purchaseOrder.status == 'Open') {
      return _purchaseOrder.supplies
          .every((supply) => supply['status'] == 'Pending');
    }

    // For other statuses, allow saving if there are changes
    return false;
  }

  bool _hasReceiptDetails() {
    // Check if any supply has receipt details
    return _purchaseOrder.supplies.any((supply) =>
        supply['receiptDrNo'] != null || supply['receiptImagePath'] != null);
  }

  // Get or create a controller for a specific supply
  TextEditingController _getRemarksController(
      String supplierName, int supplyIndex, String initialText) {
    final key = '${supplierName}_${supplyIndex}';
    if (!_remarksControllers.containsKey(key)) {
      _remarksControllers[key] = TextEditingController(text: initialText);
    }
    return _remarksControllers[key]!;
  }

  // Save remarks when user finishes editing
  void _saveRemarks(
      String supplierName, int supplyIndex, String newRemarks) async {
    try {
      // Find the global index of the supply in the entire supplies array
      final suppliers =
          _controller.groupSuppliesBySupplier(_purchaseOrder.supplies);
      final supplierSupplies = suppliers[supplierName] ?? [];

      if (supplyIndex >= supplierSupplies.length) {
        print(
            'Supply index $supplyIndex out of range for supplier $supplierName');
        return;
      }

      final targetSupply = supplierSupplies[supplyIndex];

      // Find the global index of this supply in the entire supplies array
      int globalIndex = -1;
      for (int i = 0; i < _purchaseOrder.supplies.length; i++) {
        if (_purchaseOrder.supplies[i] == targetSupply) {
          globalIndex = i;
          break;
        }
      }

      if (globalIndex == -1) {
        print(
            'Could not find global index for supply in supplier $supplierName at index $supplyIndex');
        return;
      }

      // Update the supply's remarks in the purchase order
      final updatedSupplies =
          List<Map<String, dynamic>>.from(_purchaseOrder.supplies);
      updatedSupplies[globalIndex]['receiptRemarks'] = newRemarks.trim();

      // Create updated PO
      final updatedPO = PurchaseOrder(
        id: _purchaseOrder.id,
        code: _purchaseOrder.code,
        name: _purchaseOrder.name,
        createdAt: _purchaseOrder.createdAt,
        status: _purchaseOrder.status,
        supplies: updatedSupplies,
        receivedCount: _purchaseOrder.receivedCount,
      );

      if (!await _ensureInternetConnection()) {
        return;
      }

      // Save to Supabase
      await _poSupabase.updatePOInSupabase(updatedPO);

      // Update local state
      setState(() {
        _purchaseOrder = updatedPO;
      });
    } catch (e) {
      print('Error saving remarks: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving remarks: ${e.toString()}',
              style: AppFonts.sfProStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Clear checklist state from SharedPreferences
  Future<void> _clearChecklistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String poId = _purchaseOrder.id;
      final key = 'po_checklist_$poId';
      await prefs.remove(key);
    } catch (e) {
      print('Error clearing checklist state: $e');
    }
  }

  // Load checklist state from SharedPreferences
  Future<void> _loadChecklistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String poId = _purchaseOrder.id;
      final String key = 'po_checklist_$poId';

      final String? jsonString = prefs.getString(key);
      if (jsonString != null) {
        final Map<String, dynamic> serializableMap = jsonDecode(jsonString);
        _checkedItems.clear();

        serializableMap.forEach((supplier, items) {
          _checkedItems[supplier] = Set<String>.from(items);
        });
      }
    } catch (e) {
      print('Error loading checklist state: $e');
    }
  }

// ignore: unused_element
  bool _isItemChecked(String supplierName, String itemKey) {
    return _checkedItems[supplierName]?.contains(itemKey) ?? false;
  }

  // Check if there are any pending items that can be received
  bool _hasPendingItems() {
    final suppliers =
        _controller.groupSuppliesBySupplier(_purchaseOrder.supplies);
    for (final entry in suppliers.entries) {
      final items = entry.value;
      final pendingItems =
          items.where((item) => !_controller.isSupplyReceived(item)).toList();
      if (pendingItems.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _hasPartiallyReceivedItems(List<Map<String, dynamic>> items) {
    return items.any((item) => item['status'] == 'Partially Received');
  }

  String _getQuantityDisplay(Map<String, dynamic> supply) {
    final totalQuantity = supply['quantity'] ?? 0;
    final unit = supply['packagingUnit'] ?? supply['unit'] ?? 'Box';
    final receivedQuantitiesRaw = supply['receivedQuantities'];

    // Debug: Print what we're getting
    print(
        'Debug: Supply ${supply['name']} - receivedQuantities: $receivedQuantitiesRaw');

    final receivedQuantities =
        receivedQuantitiesRaw != null && receivedQuantitiesRaw is Map
            ? Map<String, int>.from(receivedQuantitiesRaw)
            : null;

    String base;
    if (receivedQuantities != null && receivedQuantities.isNotEmpty) {
      final totalReceived =
          receivedQuantities.values.fold(0, (sum, qty) => sum + qty);
      print(
          'Debug: Total received: $totalReceived, Total quantity: $totalQuantity');
      base = '$totalReceived/$totalQuantity $unit';
    } else {
      base = '$totalQuantity $unit';
    }

    // Append packaging content details if available
    final int contentQty =
        int.tryParse('${supply['packagingContentQuantity'] ?? 0}') ?? 0;
    final String content = (supply['packagingContent'] ?? '').toString();
    final String pkgUnit = (supply['packagingUnit'] ?? unit).toString();
    if (content.isNotEmpty && contentQty > 0) {
      final contentLower = content.toLowerCase();
      final contentLabel = contentQty == 1 && contentLower.endsWith('s')
          ? contentLower.substring(0, contentLower.length - 1)
          : contentLower;
      final unitLabel = pkgUnit.toLowerCase();
      return '$base (${contentQty} $contentLabel per $unitLabel)';
    }

    return base;
  }

  String _getExpiryDisplay(Map<String, dynamic> supply, String expiryText) {
    final receivedQuantitiesRaw = supply['receivedQuantities'];
    final receivedQuantities =
        receivedQuantitiesRaw != null && receivedQuantitiesRaw is Map
            ? Map<String, int>.from(receivedQuantitiesRaw)
            : null;

    // Find the quantity for this specific expiry date from expiryBatches
    int expiryQuantity = 0;
    final batches = supply['expiryBatches'] as List<dynamic>?;
    if (batches != null && batches.isNotEmpty) {
      for (final batch in batches) {
        final batchExpiry = batch['expiryDate']?.toString() ?? '';
        final batchExpiryText = batchExpiry.isEmpty ? 'No expiry' : batchExpiry;
        if (batchExpiryText == expiryText) {
          expiryQuantity = int.tryParse('${batch['quantity'] ?? 0}') ?? 0;
          break;
        }
      }
    }

    if (receivedQuantities != null && receivedQuantities.isNotEmpty) {
      // Find the received quantity for this specific expiry
      final receivedQty = receivedQuantities[expiryText] ?? 0;
      return '$expiryText  •  Qty: $receivedQty/$expiryQuantity';
    }

    return '$expiryText  •  Qty: $expiryQuantity';
  }

  // Handle mark all as received - automatically checks all items and then marks as received
  Future<void> _handleMarkAllReceived() async {
    // Find the first pending supply to mark as received
    final pendingSupplies = _purchaseOrder.supplies
        .where((supply) => !_controller.isSupplyReceived(supply))
        .toList();

    if (pendingSupplies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No pending supplies to receive'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Get the first pending supply (the one that was clicked)
    final targetSupply = pendingSupplies.first;

    // Show confirmation dialog first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Mark as Received',
                  style: AppFonts.sfProStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),

                // Message
                Text(
                  'Are you sure you want to mark this supply as received?',
                  textAlign: TextAlign.center,
                  style: AppFonts.sfProStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Confirm',
                          style: AppFonts.sfProStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : Colors.black,
                          backgroundColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade500
                                  : const Color(0xFFADB4C2),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppFonts.sfProStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
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
    );

    if (confirm != true) return;

    if (!await _ensureInternetConnection()) {
      return;
    }

    // Check if this is the last supply to be marked as received
    final remainingSupplies = _purchaseOrder.supplies
        .where((supply) => !_controller.isSupplyReceived(supply))
        .toList();

    final isLastSupply = remainingSupplies.length == 1 &&
        remainingSupplies.first == targetSupply;

    // Check if receipt details already exist
    bool hasReceiptDetails = _purchaseOrder.supplies.any((supply) =>
        supply['receiptDrNo'] != null || supply['receiptImagePath'] != null);

    // If not the last supply, or if receipt details already exist, skip receipt details dialog
    if (!isLastSupply || hasReceiptDetails) {
      // Mark as received without showing receipt details dialog
      setState(() => _isLoading = true);
      try {
        final updatedSupplies =
            List<Map<String, dynamic>>.from(_purchaseOrder.supplies);
        final String nowIso = DateTime.now().toIso8601String();

        // If this is the last supply and receipt details exist, use existing receipt details
        if (isLastSupply && hasReceiptDetails) {
          // Get existing receipt details from any supply that has them
          Map<String, dynamic>? existingReceiptDetails;
          for (final supply in _purchaseOrder.supplies) {
            if (supply['receiptDrNo'] != null ||
                supply['receiptImagePath'] != null) {
              existingReceiptDetails = {
                'receiptDrNo': supply['receiptDrNo'],
                'receiptRecipient': supply['receiptRecipient'],
                'receiptRemarks': supply['receiptRemarks'],
                'receiptImagePath': supply['receiptImagePath'],
                'receiptDate': supply['receiptDate'],
              };
              break;
            }
          }

          // Mark ALL supplies as received with existing receipt details
          for (int i = 0; i < updatedSupplies.length; i++) {
            updatedSupplies[i] = {
              ...updatedSupplies[i],
              'status': 'Received',
              'receivedAt': nowIso,
              if (existingReceiptDetails != null) ...existingReceiptDetails,
            };
          }
        } else {
          // Not the last supply, just mark this one as received
          final idx = updatedSupplies.indexOf(targetSupply);
          if (idx != -1) {
            updatedSupplies[idx] = {
              ...targetSupply,
              'status': 'Received',
              'receivedAt': nowIso,
            };
          }
        }

        final newReceivedCount =
            updatedSupplies.where((s) => s['status'] == 'Received').length;
        String newStatus = _purchaseOrder.status;
        if (newReceivedCount == updatedSupplies.length) {
          newStatus = 'Approval';
        }

        final updatedPO = PurchaseOrder(
          id: _purchaseOrder.id,
          code: _purchaseOrder.code,
          name: _purchaseOrder.name,
          createdAt: _purchaseOrder.createdAt,
          status: newStatus,
          supplies: updatedSupplies,
          receivedCount: newReceivedCount,
        );

        await _poSupabase.updatePOInSupabase(updatedPO);
        setState(() {
          _purchaseOrder = updatedPO;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Supply marked as received successfully!',
                style: AppFonts.sfProStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return;
    }

    // Show receipt details dialog only for the last supply when receipt details don't exist
    final supplierName = targetSupply['supplierName'] ?? 'Unknown Supplier';
    final receiptDetails = await _showReceiptDetailsDialog(supplierName);
    if (receiptDetails == null) return; // user canceled or went back

    setState(() => _isLoading = true);
    try {
      // Upload receipt image to cloud storage first
      String? receiptImageUrl;
      if (receiptDetails.image != null) {
        receiptImageUrl = await _receiptStorage.uploadReceiptImage(
          receiptDetails.image!,
        );
      }

      // Update the purchase order with received status AND receipt details
      final updatedSupplies =
          List<Map<String, dynamic>>.from(_purchaseOrder.supplies);

      final String nowIso = DateTime.now().toIso8601String();
      // Mark ALL supplies as received with receipt details (this is the last supply)
      for (int i = 0; i < updatedSupplies.length; i++) {
        updatedSupplies[i] = {
          ...updatedSupplies[i],
          'status': 'Received',
          'receivedAt': nowIso,
          'receiptDrNo': receiptDetails.drNumber,
          'receiptRecipient': receiptDetails.recipient,
          'receiptRemarks': receiptDetails.remarks,
          'receiptImagePath': receiptImageUrl,
          'receiptDate': nowIso,
        };
      }

      final newReceivedCount =
          updatedSupplies.where((s) => s['status'] == 'Received').length;
      String newStatus = _purchaseOrder.status;
      if (newReceivedCount == updatedSupplies.length) {
        newStatus = 'Approval';
      }

      final updatedPO = PurchaseOrder(
        id: _purchaseOrder.id,
        code: _purchaseOrder.code,
        name: _purchaseOrder.name,
        createdAt: _purchaseOrder.createdAt,
        status: newStatus,
        supplies: updatedSupplies,
        receivedCount: newReceivedCount,
      );

      await _poSupabase.updatePOInSupabase(updatedPO);

      // Add recipient to suggestions
      if (receiptDetails.recipient.isNotEmpty) {
        await _controller.addRecipientSuggestion(receiptDetails.recipient);
      }

      setState(() {
        _purchaseOrder = updatedPO;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Supply marked as received successfully!',
              style: AppFonts.sfProStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePartialReceive() async {
    print('Debug: _handlePartialReceive called');
    // Show a dialog to select which items to receive
    final pendingSupplies = _purchaseOrder.supplies
        .where((supply) => !_controller.isSupplyReceived(supply))
        .toList();

    // Debug: Print all supplies and their status
    print('Debug: All supplies in PO:');
    for (final supply in _purchaseOrder.supplies) {
      final name = _controller.getSupplyName(supply);
      final status = supply['status'] ?? 'No status';
      final isReceived = _controller.isSupplyReceived(supply);
      print('  - $name: status=$status, isReceived=$isReceived');
    }

    print('Debug: Pending supplies for partial receive:');
    for (final supply in pendingSupplies) {
      final name = _controller.getSupplyName(supply);
      print('  - $name');
    }
    print('Debug: Total pending supplies: ${pendingSupplies.length}');

    if (pendingSupplies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No pending supplies to receive'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Show partial receive dialog
    print('Debug: About to show partial receive dialog');
    await _showPartialReceiveDialog(pendingSupplies);
    print('Debug: Partial receive dialog closed');
  }

  Future<void> _handleSave() async {
    // Show receipt details dialog for saving
    final suppliers =
        _controller.groupSuppliesBySupplier(_purchaseOrder.supplies);
    if (suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No supplies to save'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Get the first supplier for the dialog
    final firstSupplier = suppliers.keys.first;

    // Check if receipt details already exist
    bool hasReceiptDetails = _purchaseOrder.supplies.any((supply) =>
        supply['receiptDrNo'] != null || supply['receiptImagePath'] != null);

    // Pass disableSave flag if receipt details already exist
    final receiptDetails = await _showReceiptDetailsDialog(firstSupplier,
        disableSave: hasReceiptDetails);
    if (receiptDetails == null) return; // user tapped Back

    if (!await _ensureInternetConnection()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Upload receipt image to cloud storage first
      String? receiptImageUrl;
      if (receiptDetails.image != null) {
        receiptImageUrl = await _receiptStorage.uploadReceiptImage(
          receiptDetails.image!,
        );
      }

      // Update the purchase order with receipt details
      final updatedSupplies =
          List<Map<String, dynamic>>.from(_purchaseOrder.supplies);

      final String nowIso = DateTime.now().toIso8601String();
      for (final supply in _purchaseOrder.supplies) {
        final idx = updatedSupplies.indexOf(supply);
        updatedSupplies[idx] = {
          ...supply,
          'receiptDrNo': receiptDetails.drNumber,
          'receiptRecipient': receiptDetails.recipient,
          'receiptRemarks': receiptDetails.remarks,
          'receiptImagePath':
              receiptImageUrl, // Use receiptImagePath like Mark as Received
          'receiptDate': nowIso, // Add receiptDate like Mark as Received
          'savedAt': nowIso,
        };
      }

      // Add recipient to suggestions
      await _controller.addRecipientSuggestion(receiptDetails.recipient);

      // Check if any supplies are received (fully or partially) to determine new status
      // If ANY supplies are received (even partially), move to Approval section
      final hasAnyReceivedSupplies = updatedSupplies.any((supply) =>
          supply['status'] == 'Received' ||
          supply['status'] == 'Partially Received');

      // Update receivedCount like Mark as Received
      final newReceivedCount =
          updatedSupplies.where((s) => s['status'] == 'Received').length;

      final newStatus =
          hasAnyReceivedSupplies ? 'Approval' : _purchaseOrder.status;

      final updatedPO = PurchaseOrder(
        id: _purchaseOrder.id,
        code: _purchaseOrder.code,
        name: _purchaseOrder.name,
        createdAt: _purchaseOrder.createdAt,
        status: newStatus,
        supplies: updatedSupplies,
        receivedCount: newReceivedCount, // Use updated receivedCount
      );

      await _poSupabase.updatePOInSupabase(updatedPO);
      setState(() {
        _purchaseOrder = updatedPO;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Receipt details saved successfully!',
              style: AppFonts.sfProStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPartialReceiveDialog(
      List<Map<String, dynamic>> supplies) async {
    print(
        'Debug: _showPartialReceiveDialog called with ${supplies.length} supplies');
    print('Debug: About to start dialog processing...');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Create a map to group expiry entries by supply
    final Map<String, List<Map<String, dynamic>>> supplyExpiryEntries = {};
    final Map<String, int> quantities = {};
    final Map<String, TextEditingController> quantityControllers = {};

    // Process each supply and group expiry entries by supply
    print('Debug: Processing ${supplies.length} supplies in dialog');
    for (int index = 0; index < supplies.length; index++) {
      final supply = supplies[index];
      final supplyName = _controller.getSupplyName(supply);
      final supplyType = supply['type'] as String? ?? '';
      final batches = supply['expiryBatches'] as List<dynamic>?;

      // Use the actual supplyId from the supply data, but include type to make it unique
      final baseSupplyId = supply['supplyId']?.toString() ??
          supply['id']?.toString() ??
          supply['name']?.toString() ??
          'supply_$index';
      // Include type in supplyId to differentiate supplies with same name but different types
      final supplyId =
          supplyType.isNotEmpty ? '${baseSupplyId}_$supplyType' : baseSupplyId;

      // Debug: Print supply processing info
      print('Debug: Processing supply: $supplyName');
      print('Debug: Supply Type: $supplyType');
      print('Debug: Supply ID: $supplyId');
      print('Debug: Supply data: $supply');
      print('Debug: Has expiryBatches: ${batches != null}');
      print('Debug: Batches count: ${batches?.length ?? 0}');
      print('Debug: supplyId field: ${supply['supplyId']}');
      print('Debug: id field: ${supply['id']}');
      print('Debug: name field: ${supply['name']}');

      supplyExpiryEntries[supplyId] = [];
      print('Debug: Created supplyExpiryEntries for $supplyId');

      if (batches != null && batches.isNotEmpty) {
        // Create entries for each expiry date within this supply
        bool hasValidExpiryDates = false;

        for (final batch in batches) {
          final date = _formatExpiry(batch['expiryDate']);
          final batchQuantity = int.tryParse('${batch['quantity'] ?? 0}') ?? 0;

          if (date != null && batchQuantity > 0) {
            hasValidExpiryDates = true;
            final entryId = '${supplyId}_${date}';

            // Calculate remaining quantity for this expiry batch
            final receivedQuantities =
                supply['receivedQuantities'] as Map<String, dynamic>?;
            final alreadyReceivedForThisExpiry =
                receivedQuantities?[date] as int? ?? 0;
            final remainingQuantity =
                batchQuantity - alreadyReceivedForThisExpiry;

            supplyExpiryEntries[supplyId]!.add({
              'id': entryId,
              'supplyId': supplyId,
              'supplyName': supplyName,
              'supplyType': supplyType,
              'expiryDate': date,
              'maxQuantity': remainingQuantity,
            });

            // Initialize quantity and controller for this entry
            quantities[entryId] = remainingQuantity;
            quantityControllers[entryId] = TextEditingController(
              text: '$remainingQuantity',
            );
          }
        }

        // If no valid expiry dates were found, create a "No expiry" entry
        if (!hasValidExpiryDates) {
          final totalQuantity = int.tryParse('${supply['quantity'] ?? 0}') ?? 0;
          final receivedQuantities =
              supply['receivedQuantities'] as Map<String, dynamic>?;
          final alreadyReceived = receivedQuantities?.values
                  .fold(0, (sum, qty) => sum + (qty as int)) ??
              0;
          final remainingQuantity = totalQuantity - alreadyReceived;

          final entryId = supplyId;
          supplyExpiryEntries[supplyId]!.add({
            'id': entryId,
            'supplyId': supplyId,
            'supplyName': supplyName,
            'supplyType': supplyType,
            'expiryDate': 'No expiry',
            'maxQuantity': remainingQuantity,
          });

          quantities[entryId] = remainingQuantity;
          quantityControllers[entryId] = TextEditingController(
            text: '$remainingQuantity',
          );
        }
      } else {
        // No expiry batches, create single entry
        final totalQuantity = int.tryParse('${supply['quantity'] ?? 0}') ?? 0;
        final receivedQuantities =
            supply['receivedQuantities'] as Map<String, dynamic>?;
        final alreadyReceived = receivedQuantities?.values
                .fold(0, (sum, qty) => sum + (qty as int)) ??
            0;
        final remainingQuantity = totalQuantity - alreadyReceived;

        final entryId = supplyId;
        supplyExpiryEntries[supplyId]!.add({
          'id': entryId,
          'supplyId': supplyId,
          'supplyName': supplyName,
          'supplyType': supplyType,
          'expiryDate': 'No expiry',
          'maxQuantity': remainingQuantity,
        });
        print(
            'Debug: Added entry for $supplyId with remaining qty $remainingQuantity');

        quantities[entryId] = remainingQuantity;
        quantityControllers[entryId] = TextEditingController(
          text: '$remainingQuantity',
        );
      }
    }

    // Debug: Print final supply entries
    print('Debug: Final supplyExpiryEntries:');
    print('Debug: Total supplyExpiryEntries: ${supplyExpiryEntries.length}');
    for (final entry in supplyExpiryEntries.entries) {
      print('  - ${entry.key}: ${entry.value.length} entries');
      for (final expEntry in entry.value) {
        print(
            '    * ${expEntry['supplyName']}: ${expEntry['expiryDate']} (${expEntry['maxQuantity']})');
      }
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints:
                    const BoxConstraints(maxWidth: 500, maxHeight: 600),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Quantity Received',
                          style: AppFonts.sfProStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Supply cards with multiple expiry entries
                            ...supplyExpiryEntries.entries.map((supplyEntry) {
                              final expiryEntries = supplyEntry.value;
                              final supplyName = expiryEntries.isNotEmpty
                                  ? expiryEntries.first['supplyName'] as String
                                  : '';
                              // Get type from the first expiry entry
                              final supplyType = expiryEntries.isNotEmpty
                                  ? expiryEntries.first['supplyType'] as String?
                                  : null;
                              // Format display name with type if available
                              final displayName =
                                  supplyType != null && supplyType.isNotEmpty
                                      ? '$supplyName ($supplyType)'
                                      : supplyName;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF3C3C3C)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Supply name with type
                                    Text(
                                      displayName,
                                      style: AppFonts.sfProStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: theme.textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Multiple quantity and expiry sections
                                    ...expiryEntries.map((entry) {
                                      final entryId = entry['id'] as String;
                                      final expiryDate =
                                          entry['expiryDate'] as String? ??
                                              'No expiry';
                                      final maxQuantity =
                                          entry['maxQuantity'] as int;

                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Row(
                                          children: [
                                            // Quantity section
                                            Flexible(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Quantity',
                                                    style: AppFonts.sfProStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: theme.textTheme
                                                          .bodyMedium?.color,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    height: 36,
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        Container(
                                                          width: 32,
                                                          height: 32,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isDark
                                                                ? const Color(
                                                                    0xFF2C2C2C)
                                                                : Colors.white,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                            border: Border.all(
                                                              color: theme
                                                                  .dividerColor
                                                                  .withOpacity(
                                                                      0.3),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: InkWell(
                                                            onTap: () {
                                                              final currentValue =
                                                                  quantities[
                                                                          entryId] ??
                                                                      1;
                                                              if (currentValue >
                                                                  0) {
                                                                final newValue =
                                                                    currentValue -
                                                                        1;
                                                                quantities[
                                                                        entryId] =
                                                                    newValue;
                                                                quantityControllers[
                                                                            entryId]
                                                                        ?.text =
                                                                    '$newValue';
                                                                setState(() {});
                                                              }
                                                            },
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                            child: Center(
                                                              child: Icon(
                                                                Icons.remove,
                                                                size: 16,
                                                                color: theme
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.color,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Container(
                                                          width: 50,
                                                          height: 32,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isDark
                                                                ? const Color(
                                                                    0xFF2C2C2C)
                                                                : Colors.white,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                            border: Border.all(
                                                              color: theme
                                                                  .dividerColor
                                                                  .withOpacity(
                                                                      0.3),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: Container(
                                                            alignment: Alignment
                                                                .center,
                                                            child:
                                                                TextFormField(
                                                              controller:
                                                                  quantityControllers[
                                                                      entryId],
                                                              textAlign:
                                                                  TextAlign
                                                                      .center,
                                                              keyboardType:
                                                                  TextInputType
                                                                      .number,
                                                              maxLength: 2,
                                                              inputFormatters: [
                                                                FilteringTextInputFormatter
                                                                    .digitsOnly,
                                                                LengthLimitingTextInputFormatter(
                                                                    2),
                                                                _QuantityInputFormatter(
                                                                    maxQuantity),
                                                              ],
                                                              style: AppFonts
                                                                  .sfProStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: theme
                                                                    .textTheme
                                                                    .bodyLarge
                                                                    ?.color,
                                                              ),
                                                              decoration:
                                                                  const InputDecoration(
                                                                border:
                                                                    InputBorder
                                                                        .none,
                                                                contentPadding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                counterText: '',
                                                                isDense: true,
                                                              ),
                                                              onChanged:
                                                                  (value) {
                                                                final cleanValue =
                                                                    value.replaceAll(
                                                                        RegExp(
                                                                            r'[^0-9]'),
                                                                        '');
                                                                if (cleanValue
                                                                    .isEmpty) {
                                                                  quantities[
                                                                      entryId] = 1;
                                                                  return;
                                                                }
                                                                final intValue =
                                                                    int.tryParse(
                                                                            cleanValue) ??
                                                                        1;
                                                                if (intValue <
                                                                    0) {
                                                                  quantities[
                                                                      entryId] = 0;
                                                                } else if (intValue >
                                                                    maxQuantity) {
                                                                  quantities[
                                                                          entryId] =
                                                                      maxQuantity;
                                                                } else {
                                                                  quantities[
                                                                          entryId] =
                                                                      intValue;
                                                                }
                                                              },
                                                              onFieldSubmitted:
                                                                  (value) {
                                                                final cleanValue =
                                                                    value.replaceAll(
                                                                        RegExp(
                                                                            r'[^0-9]'),
                                                                        '');
                                                                if (cleanValue
                                                                    .isEmpty) {
                                                                  quantities[
                                                                      entryId] = 1;
                                                                  return;
                                                                }
                                                                final intValue =
                                                                    int.tryParse(
                                                                            cleanValue) ??
                                                                        1;
                                                                if (intValue <
                                                                    0) {
                                                                  quantities[
                                                                      entryId] = 0;
                                                                } else if (intValue >
                                                                    maxQuantity) {
                                                                  quantities[
                                                                          entryId] =
                                                                      maxQuantity;
                                                                } else {
                                                                  quantities[
                                                                          entryId] =
                                                                      intValue;
                                                                }
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Container(
                                                          width: 32,
                                                          height: 32,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isDark
                                                                ? const Color(
                                                                    0xFF2C2C2C)
                                                                : Colors.white,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                            border: Border.all(
                                                              color: theme
                                                                  .dividerColor
                                                                  .withOpacity(
                                                                      0.3),
                                                              width: 1,
                                                            ),
                                                          ),
                                                          child: InkWell(
                                                            onTap: () {
                                                              final currentValue =
                                                                  quantities[
                                                                          entryId] ??
                                                                      1;
                                                              if (currentValue <
                                                                  maxQuantity) {
                                                                final newValue =
                                                                    currentValue +
                                                                        1;
                                                                quantities[
                                                                        entryId] =
                                                                    newValue;
                                                                quantityControllers[
                                                                            entryId]
                                                                        ?.text =
                                                                    '$newValue';
                                                                setState(() {});
                                                              }
                                                            },
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                            child: Center(
                                                              child: Icon(
                                                                Icons.add,
                                                                size: 16,
                                                                color: theme
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.color,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 80),

                                            // Expiry dates section
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Expiry dates',
                                                    style: AppFonts.sfProStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: theme.textTheme
                                                          .bodyMedium?.color,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    expiryDate,
                                                    style: AppFonts.sfProStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: theme.textTheme
                                                          .bodyMedium?.color,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: Text(
                            'Cancel',
                            style: AppFonts.sfProStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              // Process partial receive for each supply
                              print(
                                  'Debug: Starting partial receive processing');
                              print(
                                  'Debug: supplyExpiryEntries count: ${supplyExpiryEntries.length}');

                              // Group by supply first to avoid overwriting
                              final Map<String, Map<String, int>>
                                  supplyQuantities = {};

                              print(
                                  'Debug: Processing ${supplyExpiryEntries.length} supply entries');
                              for (final supplyEntry
                                  in supplyExpiryEntries.entries) {
                                final supplyId = supplyEntry.key;
                                final expiryEntries = supplyEntry.value;

                                print(
                                    'Debug: Processing supplyId: $supplyId with ${expiryEntries.length} expiry entries');

                                supplyQuantities[supplyId] = {};

                                for (final entry in expiryEntries) {
                                  final entryId = entry['id'] as String;
                                  final receivedQty = quantities[entryId] ?? 0;
                                  final expiryDate =
                                      entry['expiryDate'] as String;

                                  print(
                                      'Debug: Entry $entryId - Qty: $receivedQty, Expiry: $expiryDate');

                                  if (receivedQty > 0) {
                                    supplyQuantities[supplyId]![expiryDate] =
                                        receivedQty;
                                    print(
                                        'Debug: Added to supplyQuantities - Supply $supplyId, Expiry $expiryDate, Qty: $receivedQty');
                                  }
                                }
                              }

                              print(
                                  'Debug: Final supplyQuantities: $supplyQuantities');

                              // Show confirmation dialog before processing
                              final confirmed =
                                  await _showPartialReceiveConfirmation(
                                      context);
                              if (confirmed == true) {
                                if (!await _ensureInternetConnection()) {
                                  return;
                                }
                                // Check if this is the first partial receive (no receipt details yet)
                                bool hasReceiptDetails = _purchaseOrder.supplies
                                    .any((supply) =>
                                        supply['receiptDrNo'] != null ||
                                        supply['receiptImagePath'] != null);

                                // If no receipt details exist yet, show receipt details dialog
                                if (!hasReceiptDetails) {
                                  // Get supplier name for receipt details dialog
                                  final supplierName = _purchaseOrder
                                          .supplies.first['supplierName'] ??
                                      _purchaseOrder
                                          .supplies.first['supplier'] ??
                                      'Supplier';

                                  // Show receipt details dialog
                                  final receiptDetails =
                                      await _showReceiptDetailsDialog(
                                          supplierName);

                                  print(
                                      'Debug: receiptDetails != null: ${receiptDetails != null}, mounted: $mounted');
                                  if (receiptDetails != null && mounted) {
                                    // Upload receipt image to cloud storage
                                    String? receiptImageUrl;
                                    if (receiptDetails.image != null) {
                                      print(
                                          'Debug: Starting receipt image upload...');
                                      try {
                                        receiptImageUrl = await _receiptStorage
                                            .uploadReceiptImage(
                                                receiptDetails.image!);
                                        print(
                                            'Debug: Receipt image upload returned, URL: ${receiptImageUrl != null ? "success" : "null"}');
                                      } catch (e) {
                                        print(
                                            'Debug: Error during receipt upload: $e');
                                        print(
                                            'Debug: Stack trace: ${StackTrace.current}');
                                        receiptImageUrl = null;
                                      }
                                      print(
                                          'Debug: Receipt image upload complete, URL: ${receiptImageUrl != null ? "success" : "null"}');
                                    } else {
                                      print(
                                          'Debug: No receipt image to upload');
                                    }

                                    // Process partial receives and get updated PO
                                    PurchaseOrder updatedPO;
                                    try {
                                      updatedPO = await _controller
                                          .processMultiplePartialReceives(
                                        po: _purchaseOrder,
                                        supplyQuantities: supplyQuantities,
                                      );
                                      print(
                                          'Debug: Partial receives processed successfully, PO status: ${updatedPO.status}');
                                    } catch (e) {
                                      print(
                                          'Debug: Error processing partial receives: $e');
                                      print(
                                          'Debug: Stack trace: ${StackTrace.current}');
                                      // Close dialog on error
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                      rethrow;
                                    }

                                    if (mounted) {
                                      // Update all supplies with receipt details
                                      final updatedSupplies =
                                          List<Map<String, dynamic>>.from(
                                              updatedPO.supplies);
                                      final String nowIso =
                                          DateTime.now().toIso8601String();

                                      for (int i = 0;
                                          i < updatedSupplies.length;
                                          i++) {
                                        // Add receipt details to all supplies
                                        updatedSupplies[i] = {
                                          ...updatedSupplies[i],
                                          'receiptDrNo':
                                              receiptDetails.drNumber,
                                          'receiptRecipient':
                                              receiptDetails.recipient,
                                          'receiptRemarks':
                                              receiptDetails.remarks,
                                          'receiptImagePath': receiptImageUrl,
                                          'receiptDate': nowIso,
                                        };
                                      }

                                      // Add recipient to suggestions
                                      if (receiptDetails.recipient.isNotEmpty) {
                                        await _controller
                                            .addRecipientSuggestion(
                                                receiptDetails.recipient);
                                      }

                                      // Update PO with receipt details, keep status from controller (may be Approval if all received)
                                      final finalPO = PurchaseOrder(
                                        id: updatedPO.id,
                                        code: updatedPO.code,
                                        name: updatedPO.name,
                                        createdAt: updatedPO.createdAt,
                                        status: updatedPO
                                            .status, // Use status from controller
                                        supplies: updatedSupplies,
                                        receivedCount: updatedPO.receivedCount,
                                      );

                                      await _poSupabase
                                          .updatePOInSupabase(finalPO);

                                      // Close the dialog before updating UI
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }

                                      if (mounted) {
                                        print(
                                            'Debug: Final PO status after partial receive: ${finalPO.status}');
                                        print(
                                            'Debug: canApprovePO: ${_controller.canApprovePO(finalPO)}');
                                        print(
                                            'Debug: canRejectPO: ${_controller.canRejectPO(finalPO)}');
                                        setState(() {
                                          _purchaseOrder = finalPO;
                                        });
                                        print(
                                            'Debug: setState called, UI should rebuild...');

                                        final messenger =
                                            ScaffoldMessenger.maybeOf(context);
                                        if (messenger != null) {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Receipt details saved and partial receive completed successfully!'),
                                              backgroundColor: Colors.green,
                                              duration:
                                                  const Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  } else if (mounted) {
                                    // User canceled receipt details dialog, just process partial receive
                                    PurchaseOrder updatedPO;
                                    try {
                                      updatedPO = await _controller
                                          .processMultiplePartialReceives(
                                        po: _purchaseOrder,
                                        supplyQuantities: supplyQuantities,
                                      );
                                    } catch (e) {
                                      // Close dialog on error
                                      if (context.mounted) {
                                        Navigator.of(context).pop();
                                      }
                                      rethrow;
                                    }

                                    // Close the dialog before updating UI
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }

                                    if (mounted) {
                                      setState(() {
                                        _purchaseOrder = updatedPO;
                                      });

                                      final messenger =
                                          ScaffoldMessenger.maybeOf(context);
                                      if (messenger != null) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Partial receive completed successfully!'),
                                            backgroundColor: Colors.green,
                                            duration:
                                                const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                } else {
                                  // Receipt details already exist - skip the dialog, just process partial receive
                                  PurchaseOrder updatedPO;
                                  try {
                                    updatedPO = await _controller
                                        .processMultiplePartialReceives(
                                      po: _purchaseOrder,
                                      supplyQuantities: supplyQuantities,
                                    );
                                  } catch (e) {
                                    // Close dialog on error
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }
                                    rethrow;
                                  }

                                  // Close the dialog before updating UI
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }

                                  if (mounted) {
                                    setState(() {
                                      _purchaseOrder = updatedPO;
                                    });

                                    final messenger =
                                        ScaffoldMessenger.maybeOf(context);
                                    if (messenger != null) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Partial receive completed successfully!'),
                                          backgroundColor: Colors.green,
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
                                }
                              }
                            } catch (e) {
                              // Handle errors with more detailed information
                              print('Error in partial receive: $e');

                              // Add a small delay to ensure context is stable
                              await Future.delayed(
                                  const Duration(milliseconds: 100));

                              if (context.mounted) {
                                try {
                                  Navigator.of(context).pop();
                                } catch (e) {
                                  print('Error closing dialog: $e');
                                }
                              }

                              // Show more specific error message
                              String errorMessage =
                                  'Error processing partial receive';
                              if (e.toString().contains('Supply not found')) {
                                errorMessage =
                                    'Error: Could not find the supply item. Please try refreshing the page.';
                              } else if (e
                                  .toString()
                                  .contains('Failed to process')) {
                                errorMessage =
                                    'Error: Failed to process the partial receive. Please check your input and try again.';
                              } else {
                                errorMessage =
                                    'Error processing partial receive: $e';
                              }

                              if (mounted && context.mounted) {
                                final messenger =
                                    ScaffoldMessenger.maybeOf(context);
                                if (messenger != null) {
                                  try {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(errorMessage),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                  } catch (e) {
                                    print('Error showing SnackBar: $e');
                                  }
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D4AA),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Confirm',
                            style: AppFonts.sfProStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
        );
      },
    );
  }

  // Reload PO data from database after partial receive
// ignore: unused_element
  Future<void> _reloadPOData() async {
    try {
      print('Debug: Reloading PO data...');
      final poController = POSupabaseController();
      final allPOs = await poController.getAll();
      final updatedPO = allPOs.firstWhere(
        (po) => po.id == _purchaseOrder.id,
        orElse: () => _purchaseOrder,
      );

      print('Debug: Reloaded PO supplies:');
      for (int i = 0; i < updatedPO.supplies.length; i++) {
        final supply = updatedPO.supplies[i];
        final name = _controller.getSupplyName(supply);
        final status = supply['status'] ?? 'Unknown';
        final receivedQuantities = supply['receivedQuantities'];
        print(
            '  [$i] $name: Status=$status, ReceivedQuantities=$receivedQuantities');
      }

      _purchaseOrder = updatedPO;
      print('Debug: PO data reloaded successfully');
    } catch (e) {
      print('Error reloading PO data: $e');
    }
  }

  // Show partial receive confirmation dialog
  Future<bool?> _showPartialReceiveConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
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
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: Colors.orange,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Confirm Partial Receive',
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
                'Are you sure you want to process the partial receive for the selected quantities?',
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

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Confirm',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w500,
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
      ),
    );
  }

  // Clear received quantities data (for testing/reset purposes)
// ignore: unused_element
  Future<void> _clearReceivedQuantities() async {
    try {
      final updatedSupplies = <Map<String, dynamic>>[];

      for (final supply in _purchaseOrder.supplies) {
        final updatedSupply = Map<String, dynamic>.from(supply);
        // Remove receivedQuantities and reset status
        updatedSupply.remove('receivedQuantities');
        updatedSupply['status'] = 'Pending';
        updatedSupplies.add(updatedSupply);
      }

      final updatedPO = PurchaseOrder(
        id: _purchaseOrder.id,
        code: _purchaseOrder.code,
        name: _purchaseOrder.name,
        supplies: updatedSupplies,
        status: _purchaseOrder.status,
        createdAt: _purchaseOrder.createdAt,
        receivedCount: _purchaseOrder.receivedCount,
      );

      final poController = POSupabaseController();
      await poController.save(updatedPO);
      _purchaseOrder = updatedPO;
      setState(() {});

      print('Cleared received quantities for all supplies');
    } catch (e) {
      print('Error clearing received quantities: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    try {
      _purchaseOrder = widget.purchaseOrder;

      // Load saved checklist state
      _loadChecklistState();

      // Preload caches and show floating alert for closed POs
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePostFrameTasks();
      });
    } catch (e) {
      // Error handling
    }
  }

  DateTime? _tryParseDate(dynamic raw) {
    try {
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      if (raw is int) {
        // epoch millis
        return DateTime.fromMillisecondsSinceEpoch(raw);
      }
      if (raw is String) {
        return DateTime.tryParse(raw);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _formatYmd(DateTime d) {
    const months = [
      'Jan.',
      'Feb.',
      'Mar.',
      'Apr.',
      'May.',
      'Jun.',
      'Jul.',
      'Aug.',
      'Sep.',
      'Oct.',
      'Nov.',
      'Dec.'
    ];
    final month = months[d.month - 1];
    return '$month ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Compute per-supply counts for header
    final int _uniqueSuppliesHeader = _purchaseOrder.supplies.length;
    final int _receivedSuppliesHeader = _purchaseOrder.supplies
        .where((s) => _controller.isSupplyReceived(s))
        .length;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '${_purchaseOrder.code} - ${_purchaseOrder.name}',
          style: AppFonts.sfProStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.appBarTheme.titleTextStyle?.color ??
                theme.textTheme.titleLarge?.color,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: theme.appBarTheme.elevation ?? 1,
        shadowColor: theme.appBarTheme.shadowColor ??
            theme.shadowColor.withOpacity(0.12),
      ),
      body: ResponsiveContainer(
        maxWidth: 1200,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Suppliers Header
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Text(
                        "Supplies",
                        style: AppFonts.sfProStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_receivedSuppliesHeader}/${_uniqueSuppliesHeader}',
                          style: AppFonts.sfProStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Show Partial Receive and Save buttons only for Open status or POs with partial receives (not Approval)
                      if (_purchaseOrder.status == 'Open' ||
                          _purchaseOrder.status == 'Partially Received' ||
                          (_purchaseOrder.status != 'Approval' &&
                              _purchaseOrder.status != 'Cancelled' &&
                              _purchaseOrder.supplies.any((supply) =>
                                  supply['status'] == 'Partially Received' ||
                                  supply['status'] == 'Pending'))) ...[
                        // Partial Receive button
                        Container(
                          width: 100,
                          height: 40,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed:
                                _isLoading ? null : _handlePartialReceive,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: Text(
                              'Partial Receive',
                              style: AppFonts.sfProStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        // Save button
                        Container(
                          width: 100,
                          height: 40,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            gradient: (_hasNoChanges() || _hasReceiptDetails())
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF00D4AA),
                                      Color(0xFF00B894),
                                    ],
                                  ),
                            color: (_hasNoChanges() || _hasReceiptDetails())
                                ? Colors.grey.withOpacity(0.3)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: (_hasNoChanges() || _hasReceiptDetails())
                                ? null
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF00D4AA)
                                          .withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: ElevatedButton(
                            onPressed: (_isLoading ||
                                    _hasNoChanges() ||
                                    _hasReceiptDetails())
                                ? null
                                : _handleSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  (_hasNoChanges() || _hasReceiptDetails())
                                      ? Colors.grey.withOpacity(0.3)
                                      : Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: Text(
                              'Save',
                              style: AppFonts.sfProStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                      // Approve/Reject buttons - Only for Admin users
                      if (!UserRoleProvider().isStaff &&
                          _controller.canRejectPO(_purchaseOrder))
                        Container(
                          width: MediaQuery.of(context).size.width < 768
                              ? 85
                              : 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.red,
                              Colors.red.shade700,
                            ]),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _confirmReject,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 14,
                                    width: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(
                                    'Reject',
                                    style: AppFonts.sfProStyle(
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                                  768
                                              ? 12
                                              : 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      if (!UserRoleProvider().isStaff &&
                          _controller.canApprovePO(_purchaseOrder)) ...[
                        // Debug: Print Approve button conditions
                        Builder(
                          builder: (context) {
                            print(
                                'Debug: isStaff = ${UserRoleProvider().isStaff}');
                            print(
                                'Debug: canApprovePO = ${_controller.canApprovePO(_purchaseOrder)}');
                            print(
                                'Debug: PO status = ${_purchaseOrder.status}');
                            print(
                                'Debug: receivedCount = ${_purchaseOrder.receivedCount}');
                            print(
                                'Debug: supplies.length = ${_purchaseOrder.supplies.length}');
                            return const SizedBox.shrink();
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (!UserRoleProvider().isStaff &&
                          _controller.canApprovePO(_purchaseOrder))
                        Container(
                          width: MediaQuery.of(context).size.width < 768
                              ? 85
                              : 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Color(0xFF00D4AA),
                              Color(0xFF00B894),
                            ]),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF00D4AA).withOpacity(0.3),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: (_isLoading ||
                                    !_controller.canApprovePO(_purchaseOrder))
                                ? null
                                : _approvePurchaseOrder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 14,
                                    width: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(
                                    'Approve',
                                    style: AppFonts.sfProStyle(
                                      fontSize:
                                          MediaQuery.of(context).size.width <
                                                  768
                                              ? 12
                                              : 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Supplies List Section
                // Supplies List Section
                Expanded(
                  child: _purchaseOrder.supplies.isEmpty
                      ? _buildEmptyState()
                      : Column(
                          children: [
                            // List grouped by Supplier with footer buttons rendered as the last item
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  // Show each supply as its own card (no supplier grouping)
                                  final entries = _purchaseOrder.supplies
                                      .map((s) => MapEntry(
                                            _controller.getSupplierName(s),
                                            <Map<String, dynamic>>[s],
                                          ))
                                      .toList();

                                  // counts handled in app bar header; no per-list counts needed here
                                  return ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: entries.length + 1,
                                    itemBuilder: (context, index) {
                                      if (index == entries.length) {
                                        return const SizedBox.shrink();
                                      }

                                      final entry = entries[index];
                                      final supplierName = entry.key;
                                      final items = entry.value;
                                      // Use per-supply expansion key so each supply gets its own card
                                      final String supplyNameForKey =
                                          _controller
                                              .getSupplyName(items.first);
                                      final String _expansionKey =
                                          '${supplyNameForKey}_$index';

                                      final String? supplierDrNo = items
                                          .map((m) =>
                                              (m['receiptDrNo'] as String?)
                                                  ?.trim())
                                          .firstWhere(
                                              (v) => v != null && v.isNotEmpty,
                                              orElse: () => null);

                                      final String? supplierRecipient = items
                                          .map((m) =>
                                              (m['receiptRecipient'] as String?)
                                                  ?.trim())
                                          .firstWhere(
                                              (v) => v != null && v.isNotEmpty,
                                              orElse: () => null);

                                      final String? supplierImagePath = items
                                          .map((m) =>
                                              (m['receiptImagePath'] as String?)
                                                  ?.trim())
                                          .firstWhere(
                                              (v) => v != null && v.isNotEmpty,
                                              orElse: () => null);

                                      // Debug: Print supplierImagePath
                                      print(
                                          'Debug: supplierImagePath = $supplierImagePath');

                                      final String? supplierReceivedDate = (() {
                                        dynamic raw = items
                                            .map((m) =>
                                                m['receiptDate'] ??
                                                m['receivedAt'] ??
                                                m['received_date'])
                                            .firstWhere((v) => v != null,
                                                orElse: () => null);
                                        final d = _tryParseDate(raw);
                                        return d == null ? null : _formatYmd(d);
                                      })();

                                      // Page index per supplier for indicators
                                      _supplierPageIndex[supplierName] =
                                          _supplierPageIndex[supplierName] ?? 0;
                                      final currentIdx =
                                          _supplierPageIndex[supplierName]!;
                                      final bool allReceived = items.every(
                                          (item) => _controller
                                              .isSupplyReceived(item));

                                      // Debug: Print allReceived
                                      print(
                                          'Debug: allReceived = $allReceived');
                                      final pageController = PageController(
                                          initialPage: currentIdx);

                                      return Container(
                                        margin: EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: theme.brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF2A2A2A)
                                              : const Color(0xFFF9FBFF),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: theme.brightness ==
                                                    Brightness.dark
                                                ? theme.dividerColor
                                                    .withOpacity(0.2)
                                                : const Color(0xFFD0D7E3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          (() {
                                                            final baseName =
                                                                _controller
                                                                    .getSupplyName(
                                                                        items
                                                                            .first);
                                                            final type = (items
                                                                            .first[
                                                                        'type'] ??
                                                                    '')
                                                                .toString();
                                                            final nameWithType =
                                                                type.isNotEmpty
                                                                    ? '$baseName ($type)'
                                                                    : baseName;
                                                            if ((allReceived ||
                                                                    _purchaseOrder
                                                                            .status ==
                                                                        'Approval' ||
                                                                    _purchaseOrder
                                                                            .status ==
                                                                        'Partially Received') &&
                                                                supplierDrNo !=
                                                                    null) {
                                                              return '$nameWithType (${supplierDrNo})';
                                                            }
                                                            return nameWithType;
                                                          })(),
                                                          style: AppFonts
                                                              .sfProStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.color,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 6),
                                                        Wrap(
                                                          spacing: 8,
                                                          runSpacing: 6,
                                                          crossAxisAlignment:
                                                              WrapCrossAlignment
                                                                  .center,
                                                          children: [
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          6),
                                                              decoration:
                                                                  BoxDecoration(
                                                                gradient:
                                                                    LinearGradient(
                                                                  colors:
                                                                      allReceived
                                                                          ? [
                                                                              Colors.green,
                                                                              Colors.green.shade600
                                                                            ]
                                                                          : _hasPartiallyReceivedItems(
                                                                                  items)
                                                                              ? [
                                                                                  Colors.amber,
                                                                                  Colors.amber.shade600
                                                                                ]
                                                                              : _purchaseOrder.status ==
                                                                                      'Cancelled'
                                                                                  ? [
                                                                                      Colors.redAccent,
                                                                                      Colors.red
                                                                                    ]
                                                                                  : [
                                                                                      Colors.orange,
                                                                                      Colors.orange.shade600
                                                                                    ],
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            20),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  Icon(
                                                                    allReceived
                                                                        ? Icons
                                                                            .check_circle
                                                                        : _hasPartiallyReceivedItems(items)
                                                                            ? Icons.inventory_2
                                                                            : _purchaseOrder.status == 'Cancelled'
                                                                                ? Icons.cancel
                                                                                : Icons.schedule,
                                                                    size: 14,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 6),
                                                                  Text(
                                                                    allReceived
                                                                        ? 'Received'
                                                                        : _hasPartiallyReceivedItems(items)
                                                                            ? 'Partially Received'
                                                                            : _purchaseOrder.status == 'Cancelled'
                                                                                ? 'Cancelled'
                                                                                : 'Pending',
                                                                    style: AppFonts
                                                                        .sfProStyle(
                                                                      fontSize:
                                                                          12,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: Colors
                                                                          .white,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        if (allReceived &&
                                                            supplierReceivedDate !=
                                                                null)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 6),
                                                            child: Text(
                                                              'Date Received: ' +
                                                                  supplierReceivedDate,
                                                              style: AppFonts
                                                                  .sfProStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 18),
                                                    child: IconButton(
                                                      icon: Icon(
                                                        _expandedSuppliers
                                                                .contains(
                                                                    _expansionKey)
                                                            ? Icons.expand_less
                                                            : Icons.expand_more,
                                                        color: theme
                                                            .iconTheme.color
                                                            ?.withOpacity(0.8),
                                                      ),
                                                      onPressed: () {
                                                        setState(() {
                                                          if (_expandedSuppliers
                                                              .contains(
                                                                  _expansionKey)) {
                                                            _expandedSuppliers
                                                                .remove(
                                                                    _expansionKey);
                                                          } else {
                                                            _expandedSuppliers.add(
                                                                _expansionKey);
                                                          }
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),

                                              // Expand/collapse content
                                              if (_expandedSuppliers
                                                  .contains(_expansionKey)) ...[
                                                SizedBox(
                                                  height:
                                                      _calculateDynamicHeight(
                                                          items),
                                                  child: PageView.builder(
                                                    controller: pageController,
                                                    onPageChanged: (i) {
                                                      setState(() {
                                                        _supplierPageIndex[
                                                            supplierName] = i;
                                                      });
                                                    },
                                                    itemCount: items.length,
                                                    itemBuilder: (context, i) {
                                                      return _buildSupplyDetailsOnly(
                                                          items[i],
                                                          supplierName,
                                                          supplyIndex: i);
                                                    },
                                                  ),
                                                ),

                                                // Mark all as received button (right aligned)
                                                if (!allReceived &&
                                                    _hasPendingItems() &&
                                                    _purchaseOrder.status !=
                                                        'Approval' &&
                                                    _purchaseOrder.status !=
                                                        'Cancelled')
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      Container(
                                                        width: 140,
                                                        margin: const EdgeInsets
                                                            .only(bottom: 8),
                                                        decoration:
                                                            BoxDecoration(
                                                          gradient:
                                                              const LinearGradient(
                                                            colors: [
                                                              Color(0xFF00D4AA),
                                                              Color(0xFF00B894),
                                                            ],
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: const Color(
                                                                      0xFF00D4AA)
                                                                  .withOpacity(
                                                                      0.3),
                                                              blurRadius: 4,
                                                              offset:
                                                                  const Offset(
                                                                      0, 2),
                                                            ),
                                                          ],
                                                        ),
                                                        child: ElevatedButton(
                                                          onPressed: _isLoading
                                                              ? null
                                                              : _handleMarkAllReceived,
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            backgroundColor:
                                                                Colors
                                                                    .transparent,
                                                            shadowColor: Colors
                                                                .transparent,
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical:
                                                                        6),
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          6),
                                                            ),
                                                          ),
                                                          child: _isLoading
                                                              ? const SizedBox(
                                                                  height: 12,
                                                                  width: 12,
                                                                  child:
                                                                      CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                    valueColor: AlwaysStoppedAnimation<
                                                                            Color>(
                                                                        Colors
                                                                            .white),
                                                                  ),
                                                                )
                                                              : Text(
                                                                  'Mark as received',
                                                                  style: AppFonts
                                                                      .sfProStyle(
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                if ((allReceived ||
                                                        _purchaseOrder.status ==
                                                            'Approval' ||
                                                        _purchaseOrder.status ==
                                                            'Partially Received') &&
                                                    (supplierRecipient !=
                                                            null ||
                                                        supplierImagePath !=
                                                            null))
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 8),
                                                    child: Row(
                                                      children: [
                                                        if ((allReceived ||
                                                                _purchaseOrder
                                                                        .status ==
                                                                    'Approval' ||
                                                                _purchaseOrder
                                                                        .status ==
                                                                    'Partially Received') &&
                                                            supplierRecipient !=
                                                                null)
                                                          Text(
                                                            'Recipient: $supplierRecipient',
                                                            style: AppFonts
                                                                .sfProStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        const Spacer(),
                                                        if ((allReceived ||
                                                                _purchaseOrder
                                                                        .status ==
                                                                    'Approval' ||
                                                                _purchaseOrder
                                                                        .status ==
                                                                    'Partially Received') &&
                                                            supplierImagePath !=
                                                                null)
                                                          TextButton.icon(
                                                            style: TextButton
                                                                .styleFrom(
                                                              padding:
                                                                  EdgeInsets
                                                                      .zero,
                                                              minimumSize:
                                                                  const Size(
                                                                      0, 0),
                                                              tapTargetSize:
                                                                  MaterialTapTargetSize
                                                                      .shrinkWrap,
                                                            ),
                                                            onPressed: () =>
                                                                _showAttachmentImage(
                                                                    supplierImagePath),
                                                            icon: const Icon(
                                                                Icons.image,
                                                                size: 16),
                                                            label: Text(
                                                              'See attachment',
                                                              style: AppFonts
                                                                  .sfProStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),

                                                const SizedBox(height: 14),

                                                Container(
                                                  margin: const EdgeInsets.only(
                                                      top: 0),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withOpacity(0.3),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Total Cost:',
                                                        style:
                                                            AppFonts.sfProStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      Text(
                                                        '₱' +
                                                            items
                                                                .fold<double>(
                                                                    0.0,
                                                                    (sum, it) =>
                                                                        sum +
                                                                        _controller.calculateSupplySubtotal(
                                                                            it))
                                                                .toStringAsFixed(
                                                                    2),
                                                        style:
                                                            AppFonts.sfProStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),

                // Overall Total Cost Section at bottom
                Container(
                  margin: EdgeInsets.only(top: 12),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: theme.brightness == Brightness.dark
                        ? LinearGradient(
                            colors: [
                              Color(0xFF00D4AA).withOpacity(0.25),
                              Color(0xFF00D4AA).withOpacity(0.15),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              Color(0xFF00D4AA).withOpacity(0.10),
                              Color(0xFF00D4AA).withOpacity(0.05),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? Color(0xFF00D4AA).withOpacity(0.45)
                          : Color(0xFF00D4AA).withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.brightness == Brightness.dark
                            ? Color(0xFF00D4AA).withOpacity(0.25)
                            : Color(0xFF00D4AA).withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Overall Total Cost:',
                        style: AppFonts.sfProStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF00D4AA),
                        ),
                      ),
                      Text(
                        '₱${_controller.calculateTotalCost(_purchaseOrder).toStringAsFixed(2)}',
                        style: AppFonts.sfProStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF00D4AA),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(24),
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.08),
              blurRadius: 12,
              offset: Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 60,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No supplies added',
              style: AppFonts.sfProStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Supplies will appear here once added',
              style: AppFonts.sfProStyle(
                fontSize: 16,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedDetailRow(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppFonts.sfProStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color:
                Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: AppFonts.sfProStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }

  // Build details-only content so the PageView slides only details
  Widget _buildSupplyDetailsOnly(
      Map<String, dynamic> supply, String supplierName,
      {int? supplyIndex}) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT column — Brand, Total Quantity, Subtotal
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEnhancedDetailRow(
                        'Brand',
                        _controller.getBrandName(supply),
                        Icons.branding_watermark,
                      ),
                      const SizedBox(height: 12),
                      _buildEnhancedDetailRow(
                        'Total Quantity',
                        _getQuantityDisplay(supply),
                        Icons.inventory,
                      ),
                      const SizedBox(height: 12),
                      _buildEnhancedDetailRow(
                        'Subtotal',
                        '₱${_controller.calculateSupplySubtotal(supply).toStringAsFixed(2)}',
                        Icons.attach_money,
                      ),

                      // Display remarks - allow editing in Closed section even when empty
                      ...(() {
                        final supplyIndex =
                            _purchaseOrder.supplies.indexOf(supply);
                        final remarksController = _getRemarksController(
                          _controller.getSupplierName(supply),
                          supplyIndex,
                          supply['receiptRemarks']?.toString().trim() ?? '',
                        );
                        final canEditRemarks =
                            _purchaseOrder.status == 'Closed' &&
                                _canEditRemarks();
                        final hasRemarks =
                            remarksController.text.trim().isNotEmpty;
                        final shouldShowRemarks = canEditRemarks || hasRemarks;

                        if (!shouldShowRemarks) {
                          return <Widget>[];
                        }

                        return <Widget>[
                          const SizedBox(height: 12),
                          // Multiline field for both Approval and Closed sections
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Remarks',
                                style: AppFonts.sfProStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: double.infinity,
                                constraints: const BoxConstraints(
                                  maxWidth: 450,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 0, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surface
                                      .withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: TextField(
                                  controller: remarksController,
                                  maxLines: 5,
                                  minLines: 1,
                                  enabled: canEditRemarks,
                                  style: AppFonts.sfProStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color ??
                                        Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  onChanged: (value) {
                                    // Only save if in Closed section and user can edit
                                    if (canEditRemarks) {
                                      _saveRemarks(
                                        _controller.getSupplierName(supply),
                                        supplyIndex,
                                        value,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ];
                      })(),

                      // Expiry dates moved to right column
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // RIGHT column — Expiry dates (display only)
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Expiry dates section (display only)
                      ...(() {
                        final batches =
                            supply['expiryBatches'] as List<dynamic>?;
                        if (batches != null && batches.isNotEmpty) {
                          // Check if there are any batches with actual expiry dates
                          final hasExpiryDates = batches.any(
                              (b) => _formatExpiry(b['expiryDate']) != null);

                          if (!hasExpiryDates) {
                            // No expiry dates - show no expiry info
                            return <Widget>[
                              Text(
                                'Expiry Dates',
                                style: AppFonts.sfProStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.withOpacity(0.8),
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 0, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surface
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getExpiryDisplay(supply, 'No expiry'),
                                  textAlign: TextAlign.left,
                                  style: AppFonts.sfProStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color,
                                  ),
                                ),
                              ),
                            ];
                          }

                          return <Widget>[
                            Text(
                              'Expiry Dates',
                              style: AppFonts.sfProStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 2),
                            ...batches.map((b) {
                              final String? date =
                                  _formatExpiry(b['expiryDate']);
                              if (date == null) return const SizedBox.shrink();

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 0, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surface
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _getExpiryDisplay(supply, date),
                                    textAlign: TextAlign.left,
                                    style: AppFonts.sfProStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ];
                        }

                        final single = _formatExpiry(supply['expiryDate']);
                        if (single != null) {
                          return <Widget>[
                            Text(
                              'Expiry Dates',
                              style: AppFonts.sfProStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 0, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surface
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                single,
                                textAlign: TextAlign.left,
                                style: AppFonts.sfProStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color,
                                ),
                              ),
                            ),
                          ];
                        }

                        // No expiry case
                        return <Widget>[
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 0, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'No expiry  •  Qty: ${supply['quantity'] ?? 0}',
                              textAlign: TextAlign.left,
                              style: AppFonts.sfProStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                            ),
                          ),
                        ];
                      })(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Calculate dynamic height based on expiry dates content
  double _calculateDynamicHeight(List<Map<String, dynamic>> items) {
    double baseHeight = 120;
    double maxExtraHeight = 0;

    for (final item in items) {
      final batches = item['expiryBatches'] as List<dynamic>?;
      int checkboxCount = 0;
      bool isNoExpiry = false;

      if (batches != null && batches.isNotEmpty) {
        checkboxCount =
            batches.where((b) => _formatExpiry(b['expiryDate']) != null).length;
        // If batches exist but no expiry dates, it's a no expiry supply
        if (checkboxCount == 0) {
          checkboxCount = 1;
          isNoExpiry = true;
        }
      } else if (_formatExpiry(item['expiryDate']) != null) {
        checkboxCount = 1;
      } else {
        // For items with no expiry, still count 1 checkbox
        checkboxCount = 1;
        isNoExpiry = true;
      }

      double heightForItem;
      if (isNoExpiry) {
        // For no expiry supplies, use more height for the single checkbox
        heightForItem = 20 + (checkboxCount * 40);
      } else {
        // For supplies with expiry dates, use less height per checkbox
        heightForItem = 20 + (checkboxCount * 40);
      }

      // Add height for remarks if present
      final remarks = item['receiptRemarks']?.toString().trim();
      if (remarks != null && remarks.isNotEmpty) {
        // Add height for remarks section: label (16px) + spacing (4px) + container (40px) + spacing (12px)
        heightForItem += 72;
      }

      if (heightForItem > maxExtraHeight) {
        maxExtraHeight = heightForItem;
      }
    }

    return baseHeight + maxExtraHeight;
  }

  // Normalize expiry representation to YYYY/MM/DD; returns null if absent
  String? _formatExpiry(dynamic expiry) {
    if (expiry == null) return null;
    if (expiry is DateTime) {
      return '${expiry.year}/${expiry.month.toString().padLeft(2, '0')}/${expiry.day.toString().padLeft(2, '0')}';
    }
    final raw = expiry.toString().trim();
    if (raw.isEmpty) return null;
    // Accept YYYY-MM-DD or other separators and normalize to '/'
    return raw.replaceAll('-', '/');
  }

  Future<void> _approvePurchaseOrder() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
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
                    // Icon and Title
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4AA).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF00D4AA),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'Approve Purchase Order',
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
                      'This will approve the purchase order and restock the inventory. Continue?',
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

                    // Buttons (Approve first, then Cancel)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00D4AA),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              'Approve',
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
          },
        ) ??
        false;

    if (!confirm) return;

    if (!await _ensureInternetConnection()) {
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _controller.approvePurchaseOrder(_purchaseOrder);
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Purchase Order approved and inventory restocked successfully!',
            style: AppFonts.sfProStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      // Navigate back to Purchase Orders list after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Navigator.of(context).pop({'switchToClosed': true});
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error approving purchase order',
            style: AppFonts.sfProStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmReject() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
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
                    // Icon and Title
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
                      'Reject Purchase Order',
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
                      'This will move the PO back to Open so it can be edited. Continue?',
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

                    // Buttons (Reject first, then Cancel)
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
                            child: Text(
                              'Reject',
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
          },
        ) ??
        false;

    if (!confirm) return;

    if (!await _ensureInternetConnection()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final updated = await _controller.rejectPurchaseOrder(_purchaseOrder);
      setState(() {
        _purchaseOrder = updated;
        _isLoading = false;
        // Clear all checked items and remarks when PO is rejected
        _checkedItems.clear();
        // Clear any cached checklist state
        _clearChecklistState();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Purchase Order moved back to Open.',
            style: AppFonts.sfProStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error rejecting purchase order',
            style: AppFonts.sfProStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

// ignore: unused_element
  Future<void> _confirmMarkAllReceived(
      String supplierName, List<Map<String, dynamic>> items) async {
    final pendingItems =
        items.where((item) => !_controller.isSupplyReceived(item)).toList();
    if (pendingItems.isEmpty) return;

    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Mark All as Received',
                style: AppFonts.sfProStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            content: Text(
                'This will mark all supplies from $supplierName as received.',
                style: AppFonts.sfProStyle(fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel',
                    style: AppFonts.sfProStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Mark All Received',
                    style: AppFonts.sfProStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00D4AA))),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    // Secondary details dialog
    final receiptDetails = await _showReceiptDetailsDialog(supplierName);
    if (receiptDetails == null) return; // user tapped Back

    if (!await _ensureInternetConnection()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Upload receipt image to cloud storage first
      String? receiptImageUrl;
      if (receiptDetails.image != null) {
        receiptImageUrl =
            await _receiptStorage.uploadReceiptImage(receiptDetails.image!);
        if (receiptImageUrl == null) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Failed to upload receipt image. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final updatedSupplies =
          List<Map<String, dynamic>>.from(_purchaseOrder.supplies);
      final String nowIso = DateTime.now().toIso8601String();
      for (final item in pendingItems) {
        final idx = updatedSupplies.indexOf(item);
        updatedSupplies[idx] = {
          ...item,
          'status': 'Received',
          'receiptDrNo': receiptDetails.drNumber,
          'receiptRecipient': receiptDetails.recipient,
          'receiptRemarks': receiptDetails.remarks,
          'receiptImagePath':
              receiptImageUrl, // Now stores cloud URL instead of local path
          'receiptDate': nowIso,
        };
      }

      // Add recipient name to suggestions for future use
      await _controller.addRecipientSuggestion(receiptDetails.recipient);

      final newReceivedCount =
          updatedSupplies.where((s) => s['status'] == 'Received').length;
      String newStatus = _purchaseOrder.status;
      if (newReceivedCount == updatedSupplies.length) {
        newStatus = 'Approval';
      }

      final updatedPO = PurchaseOrder(
        id: _purchaseOrder.id,
        code: _purchaseOrder.code,
        name: _purchaseOrder.name,
        createdAt: _purchaseOrder.createdAt,
        status: newStatus,
        supplies: updatedSupplies,
        receivedCount: newReceivedCount,
      );

      await _poSupabase.updatePOInSupabase(updatedPO);

      await PoActivityController().logPurchaseOrderReceived(
        poCode: updatedPO.code,
        poName: updatedPO.name,
        supplies: pendingItems,
      );

      if (_purchaseOrder.status != 'Approval' && newStatus == 'Approval') {
        try {
          await NotificationsController()
              .createPOWaitingApprovalNotification(updatedPO.code);
        } catch (_) {}
      }

      setState(() {
        _purchaseOrder = updatedPO;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All supplies from $supplierName marked as received!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating supplies'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Secondary dialog to capture receipt details with Back -> returns to previous dialog
  Future<_ReceiptDetails?> _showReceiptDetailsDialog(String supplierName,
      {bool disableSave = false}) async {
    print(
        'DEBUG: _showReceiptDetailsDialog called with disableSave = $disableSave');

    final TextEditingController drController = TextEditingController();
    final TextEditingController recipientController = TextEditingController();
    final TextEditingController remarksController = TextEditingController();
    String? drError;
    String? recipientError;
    String? imageError;
    XFile? pickedImage;
    final ImagePicker picker = ImagePicker();
    final RegExp drPattern = RegExp(r'^[A-Za-z0-9]+$');
    final RegExp recipientPattern = RegExp(r'^[A-Za-z\s]+$');

    final result = await showDialog<_ReceiptDetails>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setLocal) {
          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width < 768
                      ? MediaQuery.of(context).size.width - 24
                      : 500,
                  maxHeight: MediaQuery.of(context).size.height * 0.9),
              child: Material(
                color: Theme.of(context).dialogBackgroundColor,
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Received from $supplierName',
                                style: AppFonts.sfProStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            splashRadius: 20,
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => AlertDialog(
                                      title: Text('Discard changes',
                                          style: AppFonts.sfProStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                      content: Text(
                                          'Go back without saving these receipt details?',
                                          style: AppFonts.sfProStyle(
                                              fontSize: 14)),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: Text('Cancel',
                                              style: AppFonts.sfProStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: Text('Discard',
                                              style: AppFonts.sfProStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      const Color(0xFFEE5A52))),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                              if (confirm) {
                                Navigator.of(context).pop(null);
                              }
                            },
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Receipt No.',
                                  style: AppFonts.sfProStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: drController,
                                decoration: InputDecoration(
                                  hintText: 'Enter receipt number',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  errorText: drError,
                                ),
                                onChanged: (_) =>
                                    setLocal(() => drError = null),
                              ),
                              const SizedBox(height: 12),
                              Text('Recipient Name',
                                  style: AppFonts.sfProStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Autocomplete<String>(
                                fieldViewBuilder: (context,
                                    textEditingController,
                                    focusNode,
                                    onFieldSubmitted) {
                                  // Use the existing recipientController
                                  textEditingController.text =
                                      recipientController.text;
                                  textEditingController.addListener(() {
                                    recipientController.text =
                                        textEditingController.text;
                                  });

                                  return TextField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      hintText: 'Enter recipient name',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      errorText: recipientError,
                                    ),
                                    onChanged: (_) =>
                                        setLocal(() => recipientError = null),
                                  );
                                },
                                optionsBuilder:
                                    (TextEditingValue textEditingValue) async {
                                  if (textEditingValue.text.trim().isEmpty) {
                                    return const Iterable<String>.empty();
                                  }
                                  return await _controller
                                      .getRecipientSuggestions(
                                          textEditingValue.text);
                                },
                                onSelected: (String selection) {
                                  // This is called when a suggestion is selected
                                  // The text field will be automatically updated
                                },
                              ),
                              const SizedBox(height: 12),
                              Text('Remarks',
                                  style: AppFonts.sfProStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: remarksController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'Enter any remarks or notes...',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text('Attach Receipt',
                                  style: AppFonts.sfProStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              if (pickedImage == null)
                                Row(
                                  children: [
                                    // Take Photo Button
                                    Expanded(
                                      child: SizedBox(
                                        height: 80,
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            final img = await picker.pickImage(
                                                source: ImageSource.camera,
                                                imageQuality: 85);
                                            if (img != null)
                                              setLocal(() {
                                                pickedImage = img;
                                                imageError = null;
                                              });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[800],
                                            foregroundColor: Colors.white,
                                            side: const BorderSide(
                                                color: Color(0xFF00D4AA),
                                                width: 1),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.camera_alt_outlined,
                                                color: Color(0xFF00D4AA),
                                                size: 24,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Take Photo',
                                                style: AppFonts.sfProStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Pick Image Button
                                    Expanded(
                                      child: SizedBox(
                                        height: 80,
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            final img = await picker.pickImage(
                                                source: ImageSource.gallery,
                                                imageQuality: 85);
                                            if (img != null)
                                              setLocal(() {
                                                pickedImage = img;
                                                imageError = null;
                                              });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey[800],
                                            foregroundColor: Colors.white,
                                            side: const BorderSide(
                                                color: Color(0xFF00D4AA),
                                                width: 1),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.photo_library_outlined,
                                                color: Color(0xFF00D4AA),
                                                size: 24,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Pick Image',
                                                style: AppFonts.sfProStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Stack(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      height: 220,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.file(
                                          File(pickedImage!.path),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: InkWell(
                                        onTap: () => setLocal(() {
                                          pickedImage = null;
                                        }),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(Icons.close,
                                              color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 6),
                              if (imageError != null)
                                Text(
                                  imageError!,
                                  style: AppFonts.sfProStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => AlertDialog(
                                      title: Text('Discard changes',
                                          style: AppFonts.sfProStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                      content: Text(
                                          'Go back without saving these receipt details?',
                                          style: AppFonts.sfProStyle(
                                              fontSize: 14)),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: Text('Cancel',
                                              style: AppFonts.sfProStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: Text('Discard',
                                              style: AppFonts.sfProStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      const Color(0xFFEE5A52))),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                  false;
                              if (confirm) {
                                Navigator.of(context).pop(null);
                              }
                            },
                            child: Text('Back',
                                style: AppFonts.sfProStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: disableSave
                                ? null
                                : () async {
                                    final dr = drController.text.trim();
                                    final rec = recipientController.text.trim();
                                    bool ok = true;

                                    // Check for duplicate receipt number
                                    if (dr.isNotEmpty) {
                                      final isDuplicate = await _controller
                                          .isReceiptNumberDuplicate(dr);
                                      if (isDuplicate) {
                                        drError =
                                            'Receipt number already exists';
                                        ok = false;
                                      }
                                    }

                                    if (dr.isEmpty || !drPattern.hasMatch(dr)) {
                                      drError =
                                          'Please enter alphanumeric only';
                                      ok = false;
                                    }
                                    if (rec.isEmpty ||
                                        !recipientPattern.hasMatch(rec)) {
                                      recipientError =
                                          'Please enter letters only';
                                      ok = false;
                                    }
                                    if (pickedImage == null) {
                                      imageError =
                                          'Please attach a receipt image';
                                      ok = false;
                                    }
                                    if (!ok) {
                                      setLocal(() {});
                                      return;
                                    }
                                    final confirm = await showDialog<bool>(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => AlertDialog(
                                            title: Text('Save receipt details',
                                                style: AppFonts.sfProStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            content: Text(
                                                'Do you want to save these receipt details?',
                                                style: AppFonts.sfProStyle(
                                                    fontSize: 14)),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(false),
                                                child: Text('Cancel',
                                                    style: AppFonts.sfProStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context)
                                                        .pop(true),
                                                child: Text('Save',
                                                    style: AppFonts.sfProStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: const Color(
                                                            0xFF00D4AA))),
                                              ),
                                            ],
                                          ),
                                        ) ??
                                        false;
                                    if (!confirm) return;
                                    Navigator.of(context).pop(_ReceiptDetails(
                                      drNumber: dr,
                                      recipient: rec,
                                      remarks: remarksController.text.trim(),
                                      image: pickedImage,
                                    ));
                                  },
                            style: TextButton.styleFrom(
                              foregroundColor: disableSave
                                  ? Colors.grey
                                  : const Color(0xFF00D4AA),
                              disabledForegroundColor: Colors.grey,
                            ),
                            child: Opacity(
                              opacity: disableSave ? 0.4 : 1.0,
                              child: Text('Save',
                                  style: AppFonts.sfProStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
    return result;
  }

  void _showAttachmentImage(String pathOrUrl) {
    try {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: _buildReceiptImage(pathOrUrl),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 8,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      _showErrorDialog('Error loading attachment',
          'Unable to open the attachment. Please try again.');
    }
  }

  Widget _buildReceiptImage(String pathOrUrl) {
    // Check if it's a URL (starts with http) or a local file path
    if (pathOrUrl.startsWith('http')) {
      // Cloud URL - use CachedNetworkImage for offline support
      return CachedNetworkImage(
        imageUrl: pathOrUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                'Loading receipt...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        errorWidget: (context, url, error) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 48, color: Colors.grey[600]),
              const SizedBox(height: 8),
              Text(
                'Unable to load receipt',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Check your internet connection',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Local file path - use Image.file with existence check
      final file = File(pathOrUrl);
      if (!file.existsSync()) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 48, color: Colors.grey[600]),
              SizedBox(height: 8),
              Text(
                'Receipt not found',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'File may have been moved or deleted',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }

      return Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 48, color: Colors.grey[600]),
                SizedBox(height: 8),
                Text(
                  'Unable to load image',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'The image file may be corrupted',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Dispose all remarks controllers
    for (final controller in _remarksControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

class _QuantityInputFormatter extends TextInputFormatter {
  final int maxQuantity;

  _QuantityInputFormatter(this.maxQuantity);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only allow digits
    final cleanValue = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanValue.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final intValue = int.tryParse(cleanValue) ?? 0;

    // Allow 0 to maxQuantity (0 means not received, 1+ means received)
    if (intValue > maxQuantity) {
      return TextEditingValue(
        text: '$maxQuantity',
        selection: TextSelection.collapsed(offset: '$maxQuantity'.length),
      );
    }

    return TextEditingValue(
      text: cleanValue,
      selection: TextSelection.collapsed(offset: cleanValue.length),
    );
  }
}
