import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
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
  bool _isLoading = false;
  final Map<String, int> _supplierPageIndex = {};
  final Set<String> _expandedSuppliers = {};
  final Map<String, TextEditingController> _remarksControllers = {};

  // Checklist state for tracking which items are checked
  final Map<String, Set<String>> _checkedItems =
      {}; // supplierName -> Set of item keys

  // Helper methods for checklist management
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

  // Check if remarks can be edited based on user role and PO status
  bool _canEditRemarks() {
    // Only allow editing in Closed status
    if (_purchaseOrder.status != 'Closed') return false;

    // Owner and Admin can edit remarks in closed section
    // Staff cannot edit remarks in closed section (they can only add during receipt)
    return !UserRoleProvider().isStaff;
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

  // Handle mark all as received - automatically checks all items and then marks as received
  Future<void> _handleMarkAllReceived() async {
    // Find the first supplier with pending items
    final suppliers =
        _controller.groupSuppliesBySupplier(_purchaseOrder.supplies);
    for (final entry in suppliers.entries) {
      final supplierName = entry.key;
      final items = entry.value;
      final pendingItems =
          items.where((item) => !_controller.isSupplyReceived(item)).toList();

      if (pendingItems.isNotEmpty) {
        // Automatically check all items for this supplier
        setState(() {
          _checkedItems[supplierName] ??= <String>{};

          // Check all expiry batches
          for (int itemIndex = 0;
              itemIndex < pendingItems.length;
              itemIndex++) {
            final item = pendingItems[itemIndex];
            final batches = item['expiryBatches'] as List<dynamic>?;
            if (batches != null && batches.isNotEmpty) {
              for (final batch in batches) {
                final String? date = _formatExpiry(batch['expiryDate']);
                final int qty = int.tryParse('${batch['quantity'] ?? 0}') ?? 0;
                if (date != null) {
                  final batchKey =
                      '${supplierName}_${item['name']}_${date}_${qty}_${itemIndex}';
                  _checkedItems[supplierName]!.add(batchKey);
                }
              }
            } else {
              // Check single expiry date or no expiry
              final single = _formatExpiry(item['expiryDate']);
              if (single != null) {
                final singleKey =
                    '${supplierName}_${item['name']}_${single}_${itemIndex}';
                _checkedItems[supplierName]!.add(singleKey);
              } else {
                // No expiry date
                final noExpiryKey =
                    '${supplierName}_${item['name']}_no_expiry_${itemIndex}';
                _checkedItems[supplierName]!.add(noExpiryKey);
              }
            }
          }
        });

        // Directly proceed with marking as received without confirmation dialog
        await _confirmMarkAllReceived(supplierName, pendingItems);
        return;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    try {
      _purchaseOrder = widget.purchaseOrder;

      // Load saved checklist state
      _loadChecklistState();

      // Show floating alert for closed POs
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.isPOClosed(_purchaseOrder)) {
          _showClosedAlert();
        }
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
    // Compute per-supplier counts for header
    final Map<String, bool> _supplierAllReceivedHeader = {};
    for (final s in _purchaseOrder.supplies) {
      final supplierName = _controller.getSupplierName(s);
      final isReceivedBatch = _controller.isSupplyReceived(s);
      _supplierAllReceivedHeader[supplierName] =
          (_supplierAllReceivedHeader[supplierName] ?? true) && isReceivedBatch;
    }
    final int _uniqueSuppliersHeader = _supplierAllReceivedHeader.length;
    final int _receivedSuppliersHeader =
        _supplierAllReceivedHeader.values.where((v) => v).length;
    return Scaffold(
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
                        "Suppliers",
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
                          '${_receivedSuppliersHeader}/${_uniqueSuppliersHeader}',
                          style: AppFonts.sfProStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
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
                          _controller.canApprovePO(_purchaseOrder))
                        const SizedBox(width: 8),
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
                                  // Group supplies by supplier name
                                  final Map<String, List<Map<String, dynamic>>>
                                      bySupplier = {};
                                  for (final s in _purchaseOrder.supplies) {
                                    final name = _controller.getSupplierName(s);
                                    bySupplier
                                        .putIfAbsent(name, () => [])
                                        .add(s);
                                  }
                                  final entries = bySupplier.entries.toList();

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
                                      final pageController = PageController(
                                          initialPage: currentIdx);

                                      return Container(
                                        margin: EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF2A2A2A)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: theme.dividerColor
                                                .withOpacity(0.2),
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
                                                          (allReceived &&
                                                                  supplierDrNo !=
                                                                      null)
                                                              ? '$supplierName (${supplierDrNo})'
                                                              : supplierName,
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
                                                                        : Icons
                                                                            .schedule,
                                                                    size: 14,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 6),
                                                                  Text(
                                                                    allReceived
                                                                        ? 'Received'
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
                                                                    supplierName)
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
                                                                  supplierName)) {
                                                            _expandedSuppliers
                                                                .remove(
                                                                    supplierName);
                                                          } else {
                                                            _expandedSuppliers
                                                                .add(
                                                                    supplierName);
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
                                                  .contains(supplierName)) ...[
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

                                                // Mark all as received button on top (right aligned)
                                                if (!allReceived &&
                                                    _hasPendingItems())
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
                                                                  'Mark all as received',
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
                                                        ),
                                                      ),
                                                    ],
                                                  ),

                                                // Dot indicators centered
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: List.generate(
                                                      items.length, (i) {
                                                    final active =
                                                        _supplierPageIndex[
                                                                supplierName] ==
                                                            i;
                                                    return Container(
                                                      width: active ? 10 : 8,
                                                      height: active ? 10 : 8,
                                                      margin: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 3),
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: active
                                                            ? theme.colorScheme
                                                                .primary
                                                            : theme.dividerColor
                                                                .withOpacity(
                                                                    0.6),
                                                      ),
                                                    );
                                                  }),
                                                ),

                                                if (allReceived &&
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
                                                        if (allReceived &&
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
                                                        if (allReceived &&
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
                // LEFT column — give it more space
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEnhancedDetailRow(
                        'Supply',
                        _controller.getSupplyName(supply),
                        Icons.shopping_bag,
                      ),
                      const SizedBox(height: 12),
                      _buildEnhancedDetailRow(
                        'Brand',
                        _controller.getBrandName(supply),
                        Icons.branding_watermark,
                      ),

                      // Expiry dates
                      ...(() {
                        final batches =
                            supply['expiryBatches'] as List<dynamic>?;
                        if (batches != null && batches.isNotEmpty) {
                          // Check if there are any batches with actual expiry dates
                          final hasExpiryDates = batches.any(
                              (b) => _formatExpiry(b['expiryDate']) != null);

                          if (!hasExpiryDates) {
                            // No expiry dates - show no expiry checkbox for batches
                            final noKey = '__no_expiry_';
                            final supplyStatus =
                                supply['status']?.toString().toLowerCase();
                            final isReceivedBatch =
                                supplyStatus == 'received' ||
                                    _controller.isSupplyReceived(supply);
                            final isChecked =
                                _isItemChecked(supplierName, noKey) ||
                                    isReceivedBatch;

                            // Calculate total quantity from all batches
                            int totalQty = 0;
                            for (final batch in batches) {
                              totalQty +=
                                  int.tryParse('${batch['quantity'] ?? 0}') ??
                                      0;
                            }
                            // If no quantity in batches, use supply quantity
                            if (totalQty == 0) {
                              totalQty =
                                  int.tryParse('${supply['quantity'] ?? 0}') ??
                                      0;
                            }

                            return <Widget>[
                              const SizedBox(height: 12),
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
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () =>
                                    _toggleItemCheck(supplierName, noKey),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isReceivedBatch
                                        ? const Color(0xFF00D4AA)
                                        : (isChecked
                                            ? const Color(0xFF00D4AA)
                                            : Colors.transparent),
                                    border: Border.all(
                                      color: isReceivedBatch
                                          ? const Color(0xFF00D4AA)
                                          : (isChecked
                                              ? const Color(0xFF00D4AA)
                                              : Colors.white.withOpacity(0.3)),
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: _controller
                                                  .isSupplyReceived(supply)
                                              ? Colors.white
                                              : (isChecked
                                                  ? Colors.white
                                                  : Colors.transparent),
                                          border: Border.all(
                                            color: _controller
                                                    .isSupplyReceived(supply)
                                                ? const Color(0xFF00D4AA)
                                                : (isChecked
                                                    ? Colors.white
                                                    : Colors.white
                                                        .withOpacity(0.6)),
                                            width: 1.5,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                        child: (isChecked ||
                                                _controller
                                                    .isSupplyReceived(supply))
                                            ? Icon(
                                                Icons.check,
                                                size: 10,
                                                color: _controller
                                                        .isSupplyReceived(
                                                            supply)
                                                    ? const Color(0xFF00D4AA)
                                                    : const Color(0xFF00D4AA),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'No expiry  •  Qty: ${supply['quantity'] ?? 0}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: false,
                                          style: AppFonts.sfProStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: _controller
                                                    .isSupplyReceived(supply)
                                                ? Colors.white
                                                : (isChecked
                                                    ? Colors.white
                                                    : Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.color),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Add remarks display if available and supply is received
                              ...(() {
                                final remarks =
                                    supply['receiptRemarks']?.toString().trim();
                                final supplyStatus =
                                    supply['status']?.toString().toLowerCase();
                                final isReceived = supplyStatus == 'received' ||
                                    _controller.isSupplyReceived(supply);
                                if (remarks != null &&
                                    remarks.isNotEmpty &&
                                    isReceived) {
                                  final canEdit = _canEditRemarks();
                                  return <Widget>[
                                    const SizedBox(height: 12),
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
                                    canEdit
                                        ? TextField(
                                            controller: _getRemarksController(
                                                supplierName,
                                                supplyIndex ?? 0,
                                                remarks),
                                            maxLines: null,
                                            style: AppFonts.sfProStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color,
                                            ),
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: Theme.of(context)
                                                  .colorScheme
                                                  .surface
                                                  .withOpacity(0.1),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outline
                                                      .withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outline
                                                      .withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  width: 2,
                                                ),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                            ),
                                            onSubmitted: (value) {
                                              // Save when user presses done/enter on keyboard
                                              _saveRemarks(supplierName,
                                                  supplyIndex ?? 0, value);
                                            },
                                            onTapOutside: (event) {
                                              // Save when user taps outside the field
                                              final controller =
                                                  _getRemarksController(
                                                      supplierName,
                                                      supplyIndex ?? 0,
                                                      remarks);
                                              _saveRemarks(
                                                  supplierName,
                                                  supplyIndex ?? 0,
                                                  controller.text);
                                            },
                                          )
                                        : Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surface
                                                  .withOpacity(0.1),
                                              border: Border.all(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outline
                                                    .withOpacity(0.3),
                                                width: 1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              remarks,
                                              style: AppFonts.sfProStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color,
                                              ),
                                            ),
                                          ),
                                  ];
                                }
                                return <Widget>[];
                              })(),
                            ];
                          }

                          return <Widget>[
                            const SizedBox(height: 12),
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
                            const SizedBox(height: 4),
                            ...batches.map((b) {
                              final String? date =
                                  _formatExpiry(b['expiryDate']);
                              final int qty =
                                  int.tryParse('${b['quantity'] ?? 0}') ?? 0;
                              if (date == null) return const SizedBox.shrink();

                              final batchKey =
                                  '${supplierName}_${supply['name']}_${date}_${qty}_${supplyIndex ?? 0}';
                              // Check if supply is received - try multiple ways to determine this
                              final supplyStatus =
                                  supply['status']?.toString().toLowerCase();
                              final isReceivedBatchBatch =
                                  supplyStatus == 'received' ||
                                      _controller.isSupplyReceived(supply);

                              // Always show as checked if supply is received, regardless of manual checkbox state
                              final isChecked = isReceivedBatchBatch ||
                                  _isItemChecked(supplierName, batchKey);

                              final row = Row(
                                children: [
                                  // square “checkbox”
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: _controller
                                              .isSupplyReceived(supply)
                                          ? Colors
                                              .white // White background for received supplies checkbox
                                          : (isChecked
                                              ? Colors.white
                                              : Colors.transparent),
                                      border: Border.all(
                                        color: _controller
                                                .isSupplyReceived(supply)
                                            ? const Color(
                                                0xFF00D4AA) // Green border for received supplies
                                            : (isChecked
                                                ? Colors.white
                                                : Colors.white
                                                    .withOpacity(0.6)),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: (isChecked ||
                                            _controller
                                                .isSupplyReceived(supply))
                                        ? Icon(
                                            Icons.check,
                                            size: 10,
                                            color: _controller
                                                    .isSupplyReceived(supply)
                                                ? const Color(
                                                    0xFF00D4AA) // Green checkmark for received supplies (visible on white background)
                                                : const Color(
                                                    0xFF00D4AA), // Green checkmark for manually checked
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  // 👇 prevent overflow
                                  Expanded(
                                    child: Text(
                                      '$date  •  Qty: $qty',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: AppFonts.sfProStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: _controller
                                                .isSupplyReceived(supply)
                                            ? Colors
                                                .white // White text for received supplies
                                            : (isChecked
                                                ? Colors.white
                                                : Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color),
                                      ),
                                    ),
                                  ),
                                ],
                              );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: GestureDetector(
                                  onTap: () =>
                                      _toggleItemCheck(supplierName, batchKey),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _controller
                                              .isSupplyReceived(supply)
                                          ? const Color(
                                              0xFF00D4AA) // Green background for received supplies
                                          : (isChecked
                                              ? const Color(0xFF00D4AA)
                                              : Colors.transparent),
                                      border: Border.all(
                                        color: _controller
                                                .isSupplyReceived(supply)
                                            ? const Color(
                                                0xFF00D4AA) // Green border for received supplies
                                            : (isChecked
                                                ? const Color(0xFF00D4AA)
                                                : Colors.white
                                                    .withOpacity(0.3)),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: row,
                                  ),
                                ),
                              );
                            }).toList(),
                            // Add remarks display if available and supply is received
                            ...(() {
                              final remarks =
                                  supply['receiptRemarks']?.toString().trim();
                              final supplyStatus =
                                  supply['status']?.toString().toLowerCase();
                              final isReceived = supplyStatus == 'received' ||
                                  _controller.isSupplyReceived(supply);
                              if (remarks != null &&
                                  remarks.isNotEmpty &&
                                  isReceived) {
                                final canEdit = _canEditRemarks();
                                return <Widget>[
                                  const SizedBox(height: 12),
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
                                  canEdit
                                      ? TextField(
                                          controller: _getRemarksController(
                                              supplierName,
                                              supplyIndex ?? 0,
                                              remarks),
                                          maxLines: null,
                                          style: AppFonts.sfProStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.color,
                                          ),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: Theme.of(context)
                                                .colorScheme
                                                .surface
                                                .withOpacity(0.1),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outline
                                                    .withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outline
                                                    .withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                width: 2,
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8),
                                          ),
                                          onSubmitted: (value) {
                                            // Save when user presses done/enter on keyboard
                                            _saveRemarks(supplierName,
                                                supplyIndex ?? 0, value);
                                          },
                                          onTapOutside: (event) {
                                            // Save when user taps outside the field
                                            final controller =
                                                _getRemarksController(
                                                    supplierName,
                                                    supplyIndex ?? 0,
                                                    remarks);
                                            _saveRemarks(
                                                supplierName,
                                                supplyIndex ?? 0,
                                                controller.text);
                                          },
                                        )
                                      : Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surface
                                                .withOpacity(0.1),
                                            border: Border.all(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outline
                                                  .withOpacity(0.3),
                                              width: 1,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            remarks,
                                            style: AppFonts.sfProStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color,
                                            ),
                                          ),
                                        ),
                                ];
                              }
                              return <Widget>[];
                            })(),
                          ];
                        }

                        final single = _formatExpiry(supply['expiryDate']);
                        if (single != null) {
                          final singleKey =
                              '${supplierName}_${supply['name']}_${single}_${supplyIndex ?? 0}';
                          // Check if supply is received - try multiple ways to determine this
                          final supplyStatus =
                              supply['status']?.toString().toLowerCase();
                          final isReceivedBatch = supplyStatus == 'received' ||
                              _controller.isSupplyReceived(supply);

                          final isChecked =
                              _isItemChecked(supplierName, singleKey) ||
                                  isReceivedBatch;

                          Widget row(String text) => Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: _controller
                                              .isSupplyReceived(supply)
                                          ? Colors
                                              .white // White background for received supplies checkbox
                                          : (isChecked
                                              ? Colors.white
                                              : Colors.transparent),
                                      border: Border.all(
                                        color: _controller
                                                .isSupplyReceived(supply)
                                            ? const Color(
                                                0xFF00D4AA) // Green border for received supplies
                                            : (isChecked
                                                ? Colors.white
                                                : Colors.white
                                                    .withOpacity(0.6)),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: (isChecked ||
                                            _controller
                                                .isSupplyReceived(supply))
                                        ? Icon(
                                            Icons.check,
                                            size: 10,
                                            color: _controller
                                                    .isSupplyReceived(supply)
                                                ? const Color(
                                                    0xFF00D4AA) // Green checkmark for received supplies (visible on white background)
                                                : const Color(
                                                    0xFF00D4AA), // Green checkmark for manually checked
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      text,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: AppFonts.sfProStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: _controller
                                                .isSupplyReceived(supply)
                                            ? Colors
                                                .white // White text for received supplies
                                            : (isChecked
                                                ? Colors.white
                                                : Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color),
                                      ),
                                    ),
                                  ),
                                ],
                              );

                          return <Widget>[
                            const SizedBox(height: 12),
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
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () =>
                                  _toggleItemCheck(supplierName, singleKey),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isReceivedBatch
                                      ? const Color(
                                          0xFF00D4AA) // Green background for received supplies
                                      : (isChecked
                                          ? const Color(0xFF00D4AA)
                                          : Colors.transparent),
                                  border: Border.all(
                                    color: isReceivedBatch
                                        ? const Color(
                                            0xFF00D4AA) // Green border for received supplies
                                        : (isChecked
                                            ? const Color(0xFF00D4AA)
                                            : Colors.white.withOpacity(0.3)),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: row(single),
                              ),
                            ),
                          ];
                        }

                        // No expiry case
                        final noKey =
                            '${supplierName}_${supply['name']}_no_expiry_${supplyIndex ?? 0}';
                        // Check if supply is received - try multiple ways to determine this
                        final supplyStatus =
                            supply['status']?.toString().toLowerCase();
                        final isReceivedBatch = supplyStatus == 'received' ||
                            _controller.isSupplyReceived(supply);

                        final isChecked = _isItemChecked(supplierName, noKey) ||
                            isReceivedBatch;

                        return <Widget>[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _toggleItemCheck(supplierName, noKey),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isReceivedBatch
                                    ? const Color(0xFF00D4AA)
                                    : (isChecked
                                        ? const Color(0xFF00D4AA)
                                        : Colors.transparent),
                                border: Border.all(
                                  color: isReceivedBatch
                                      ? const Color(0xFF00D4AA)
                                      : (isChecked
                                          ? const Color(0xFF00D4AA)
                                          : Colors.white.withOpacity(0.3)),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: _controller
                                              .isSupplyReceived(supply)
                                          ? Colors
                                              .white // White background for received supplies checkbox
                                          : (isChecked
                                              ? Colors.white
                                              : Colors.transparent),
                                      border: Border.all(
                                        color: _controller
                                                .isSupplyReceived(supply)
                                            ? const Color(
                                                0xFF00D4AA) // Green border for received supplies
                                            : (isChecked
                                                ? Colors.white
                                                : Colors.white
                                                    .withOpacity(0.6)),
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: (isChecked ||
                                            _controller
                                                .isSupplyReceived(supply))
                                        ? Icon(
                                            Icons.check,
                                            size: 10,
                                            color: _controller
                                                    .isSupplyReceived(supply)
                                                ? const Color(
                                                    0xFF00D4AA) // Green checkmark for received supplies (visible on white background)
                                                : const Color(
                                                    0xFF00D4AA), // Green checkmark for manually checked
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No expiry  •  Qty: ${supply['quantity'] ?? 0}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: AppFonts.sfProStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: _controller
                                                .isSupplyReceived(supply)
                                            ? Colors
                                                .white // White text for received supplies
                                            : (isChecked
                                                ? Colors.white
                                                : Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Add remarks display if available and supply is received
                          ...(() {
                            final remarks =
                                supply['receiptRemarks']?.toString().trim();
                            final supplyStatus =
                                supply['status']?.toString().toLowerCase();
                            final isReceived = supplyStatus == 'received' ||
                                _controller.isSupplyReceived(supply);
                            if (remarks != null &&
                                remarks.isNotEmpty &&
                                isReceived) {
                              final canEdit = _canEditRemarks();
                              return <Widget>[
                                const SizedBox(height: 12),
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
                                canEdit
                                    ? TextField(
                                        controller: _getRemarksController(
                                            supplierName,
                                            supplyIndex ?? 0,
                                            remarks),
                                        maxLines: null,
                                        style: AppFonts.sfProStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color,
                                        ),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Theme.of(context)
                                              .colorScheme
                                              .surface
                                              .withOpacity(0.1),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outline
                                                  .withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outline
                                                  .withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              width: 2,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 8),
                                        ),
                                        onSubmitted: (value) {
                                          // Save when user presses done/enter on keyboard
                                          _saveRemarks(supplierName,
                                              supplyIndex ?? 0, value);
                                        },
                                        onTapOutside: (event) {
                                          // Save when user taps outside the field
                                          final controller =
                                              _getRemarksController(
                                                  supplierName,
                                                  supplyIndex ?? 0,
                                                  remarks);
                                          _saveRemarks(
                                              supplierName,
                                              supplyIndex ?? 0,
                                              controller.text);
                                        },
                                      )
                                    : Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface
                                              .withOpacity(0.1),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline
                                                .withOpacity(0.3),
                                            width: 1,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          remarks,
                                          style: AppFonts.sfProStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.color,
                                          ),
                                        ),
                                      ),
                              ];
                            }
                            return <Widget>[];
                          })(),
                        ];
                      })(),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // RIGHT column
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEnhancedDetailRow(
                        'Quantity & Unit',
                        '${supply['quantity'] ?? 0} ${supply['unit'] ?? 'Box'}',
                        Icons.inventory,
                      ),
                      const SizedBox(height: 12),
                      _buildEnhancedDetailRow(
                        'Subtotal',
                        '₱${_controller.calculateSupplySubtotal(supply).toStringAsFixed(2)}',
                        Icons.attach_money,
                      ),
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
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Reject this Purchase Order?',
              style: AppFonts.sfProStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'This will move the PO back to Open so it can be edited. Continue?',
              style: AppFonts.sfProStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel',
                    style: AppFonts.sfProStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Reject',
                    style: AppFonts.sfProStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

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
  Future<_ReceiptDetails?> _showReceiptDetailsDialog(
      String supplierName) async {
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
                      : 500),
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
                      SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Receipt No.',
                                style: AppFonts.sfProStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: drController,
                              decoration: InputDecoration(
                                hintText: 'Enter receipt number',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                errorText: drError,
                              ),
                              onChanged: (_) => setLocal(() => drError = null),
                            ),
                            const SizedBox(height: 12),
                            Text('Recipient Name',
                                style: AppFonts.sfProStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Autocomplete<String>(
                              fieldViewBuilder: (context, textEditingController,
                                  focusNode, onFieldSubmitted) {
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
                                    fontSize: 13, fontWeight: FontWeight.w600)),
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
                                    fontSize: 13, fontWeight: FontWeight.w600)),
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
                            onPressed: () async {
                              final dr = drController.text.trim();
                              final rec = recipientController.text.trim();
                              bool ok = true;

                              // Check for duplicate receipt number
                              if (dr.isNotEmpty) {
                                final isDuplicate = await _controller
                                    .isReceiptNumberDuplicate(dr);
                                if (isDuplicate) {
                                  drError = 'Receipt number already exists';
                                  ok = false;
                                }
                              }

                              if (dr.isEmpty || !drPattern.hasMatch(dr)) {
                                drError = 'Please enter alphanumeric only';
                                ok = false;
                              }
                              if (rec.isEmpty ||
                                  !recipientPattern.hasMatch(rec)) {
                                recipientError = 'Please enter letters only';
                                ok = false;
                              }
                              if (pickedImage == null) {
                                imageError = 'Please attach a receipt image';
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
                                              fontWeight: FontWeight.bold)),
                                      content: Text(
                                          'Do you want to save these receipt details?',
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
                                          child: Text('Save',
                                              style: AppFonts.sfProStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      const Color(0xFF00D4AA))),
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
                            child: Text('Save',
                                style: AppFonts.sfProStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF00D4AA))),
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
      // Cloud URL - use Image.network
      return Image.network(
        pathOrUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
                SizedBox(height: 8),
                Text(
                  'Loading receipt...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 48, color: Colors.grey[600]),
                SizedBox(height: 8),
                Text(
                  'Unable to load receipt',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Check your internet connection',
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

  void _showClosedAlert() {
    // Show the alert as an overlay that doesn't block interactions
    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _AnimatedClosedAlert(
        onDismiss: () {
          overlayEntry?.remove();
        },
      ),
    );

    Overlay.of(context).insert(overlayEntry);
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

class _AnimatedClosedAlert extends StatefulWidget {
  final VoidCallback onDismiss;

  const _AnimatedClosedAlert({
    required this.onDismiss,
  });

  @override
  State<_AnimatedClosedAlert> createState() => _AnimatedClosedAlertState();
}

class _AnimatedClosedAlertState extends State<_AnimatedClosedAlert>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Slide animation controller
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Fade animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Slide animation from top
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -2.0), // Start above the screen
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.bounceOut,
    ));

    // Fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _slideController.forward();
    _fadeController.forward();

    // Auto fade out after 4 seconds
    Future.delayed(const Duration(milliseconds: 4000), () {
      if (mounted) {
        _fadeOut();
      }
    });
  }

  void _fadeOut() async {
    await _fadeController.reverse();
    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            constraints: const BoxConstraints(
                maxWidth: 350, minHeight: 80, maxHeight: 120),
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
                  color: Theme.of(context).shadowColor.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Error Icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Text Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Purchase Order Closed',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This purchase order is already closed and cannot be modified.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: Colors.white,
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Close Button
                    GestureDetector(
                      onTap: _fadeOut,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
