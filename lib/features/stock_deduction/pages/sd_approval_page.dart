import 'dart:async';
import 'package:flutter/material.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/stock_deduction/controller/sd_approval_controller.dart';
import 'package:familee_dental/features/stock_deduction/controller/stock_deduction_controller.dart';
import 'package:familee_dental/features/stock_deduction/controller/sd_preset_management_controller.dart';
import 'package:familee_dental/features/inventory/controller/inventory_controller.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/stock_deduction/pages/sd_approval_card_widget.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/widgets/notification_badge_button.dart';
import 'package:shimmer/shimmer.dart';

class ApprovalPage extends StatefulWidget {
  const ApprovalPage({super.key});

  @override
  State<ApprovalPage> createState() => _ApprovalPageState();
}

class _ApprovalPageState extends State<ApprovalPage> {
  final ApprovalController _approvalController = ApprovalController();
  final StockDeductionController _deductionController =
      StockDeductionController();
  final InventoryController _inventoryController = InventoryController();
  final PresetController _presetController = PresetController();
  List<Map<String, dynamic>> _allApprovals = [];
  List<Map<String, dynamic>> _lastKnownApprovals = [];
  late Stream<List<Map<String, dynamic>>> _approvalsStream;
  int _streamKey = 0;
  bool _isFirstLoad = true;
  final Set<String> _expandedCardIds = {};

  @override
  void initState() {
    super.initState();
    _initializeStream();
  }

  void _initializeStream() {
    _approvalsStream = ApprovalController().getApprovalsStream();
  }

  // Pull-to-refresh method
  Future<void> _refreshApprovals() async {
    _streamKey++;
    _initializeStream();
    setState(() {});

    await _approvalsStream.first;
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
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      child: Container(
                        height: 200,
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
          'Approval',
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
      body: RefreshIndicator(
        onRefresh: _refreshApprovals,
        color: const Color(0xFF00D4AA),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          key: ValueKey(_streamKey),
          stream: _approvalsStream,
          builder: (context, snapshot) {
            if (_isFirstLoad && !snapshot.hasData) {
              return _buildSkeletonLoader(context);
            }

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
                  'Error loading approvals: ${snapshot.error}',
                  style: AppFonts.sfProStyle(fontSize: 16, color: Colors.red),
                ),
              );
            }

            // Filter to show only pending approvals
            List<Map<String, dynamic>> allData = [];
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              allData = snapshot.data!;
            } else if (!snapshot.hasData && _lastKnownApprovals.isNotEmpty) {
              allData = _lastKnownApprovals;
            } else {
              allData = snapshot.data ?? [];
            }

            // Filter out approved and rejected approvals - only show pending
            _allApprovals = allData.where((approval) {
              final status = approval['status'] ?? 'pending';
              return status == 'pending';
            }).toList();

            // Update last known approvals to filtered list
            _lastKnownApprovals = List.from(_allApprovals);

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
                          child: _allApprovals.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _allApprovals.length,
                                  itemBuilder: (context, index) {
                                    final approval = _allApprovals[index];
                                    return ApprovalCard(
                                      approval: approval,
                                      index: index,
                                      isExpanded: _expandedCardIds
                                          .contains(approval['id']?.toString()),
                                      onToggle: () {
                                        setState(() {
                                          final cardId =
                                              approval['id']?.toString();
                                          if (cardId != null) {
                                            if (_expandedCardIds
                                                .contains(cardId)) {
                                              _expandedCardIds.remove(cardId);
                                            } else {
                                              _expandedCardIds.add(cardId);
                                            }
                                          }
                                        });
                                      },
                                      onDelete: () => _deleteApproval(approval),
                                      onApprove: () =>
                                          _approveApproval(approval),
                                      onReject: () => _rejectApproval(approval),
                                    );
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
              Icons.pending_actions,
              size: 60,
              color: isDark
                  ? Colors.white.withOpacity(0.7)
                  : const Color(0xFF8B5A8B),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Pending Approvals',
            style: AppFonts.sfProStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Approvals from Service Management will appear here',
            style: AppFonts.sfProStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    // Ensure we compare in UTC to avoid timezone issues
    final dateUtc = date.toUtc();
    final nowUtc = now.toUtc();

    // Calculate difference - if negative, it means date is in the future (likely timezone issue)
    var difference = nowUtc.difference(dateUtc);

    // If difference is negative (date in future), treat as just now
    if (difference.isNegative) {
      return 'Just now';
    }

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
      }
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  Future<void> _approveApproval(Map<String, dynamic> approval) async {
    final status = approval['status'] ?? 'pending';
    if (status != 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This approval has already been ${status == 'approved' ? 'approved' : 'rejected'}',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Use preset name as purpose (from approval)
    final presetName =
        approval['presetName'] ?? approval['name'] ?? 'Unknown Preset';
    final purpose = presetName;
    final remarks = '';

    try {
      // Get current inventory data to match supplies with docIds
      final supplies = approval['supplies'] as List<dynamic>? ?? [];
      List<GroupedInventoryItem> currentInventory = [];
      try {
        currentInventory = await _inventoryController
            .getGroupedSuppliesStream(archived: false)
            .first;
      } catch (e) {
        print('Error loading current inventory: $e');
      }

      // Convert approval supplies to deduction format
      List<Map<String, dynamic>> deductionsToApply = [];
      for (final supply in supplies) {
        if (supply is Map<String, dynamic>) {
          final supplyName = supply['name']?.toString() ?? '';
          final supplyBrand = supply['brand']?.toString() ?? '';
          final quantity = supply['quantity'] ?? 0;

          if (supplyName.isEmpty || quantity <= 0) continue;

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
            // Block expired items from deduction
            if (currentItem.getStatus() == 'Expired') {
              continue; // Skip expired items
            }

            // Get all batches (earliest expiry first)
            final allBatches = [currentItem.mainItem, ...currentItem.variants];
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
              final int deductQty =
                  quantity > primaryBatch.stock ? primaryBatch.stock : quantity;

              deductionsToApply.add({
                'docId': primaryBatch.id,
                'name': primaryBatch.name,
                'brand': primaryBatch.brand,
                'imageUrl': primaryBatch.imageUrl,
                'expiry': primaryBatch.expiry,
                'noExpiry': primaryBatch.noExpiry,
                'stock': primaryBatch.stock,
                'deductQty': deductQty,
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
        }
      }

      if (deductionsToApply.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No valid supplies to deduct (may be out of stock or expired)',
              style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // Apply stock deductions to inventory
      await _deductionController.applyDeductions(deductionsToApply);

      // Update approval status to approved
      await _approvalController.approveApproval(approval['id']);

      // Immediately remove from local list (optimistic update) so it disappears instantly
      if (mounted) {
        setState(() {
          _allApprovals.removeWhere((a) => a['id'] == approval['id']);
          _lastKnownApprovals.removeWhere((a) => a['id'] == approval['id']);
        });
      }

      // Navigate to Deduction Logs page with purpose and supplies to record it
      final savedDeductions =
          List<Map<String, dynamic>>.from(deductionsToApply);

      if (!mounted) return;

      // Navigate to Deduction Logs
      await Navigator.of(context).pushNamed(
        '/stock-deduction/deduction-logs',
        arguments: {
          'purpose': purpose,
          'remarks': remarks,
          'supplies': savedDeductions,
        },
      );

      // Refresh when returning from Deduction Logs page to ensure list is synced
      if (mounted) {
        _refreshApprovals();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Approval approved and stock deducted successfully',
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
            'Failed to approve: $e',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _rejectApproval(Map<String, dynamic> approval) async {
    final status = approval['status'] ?? 'pending';
    if (status != 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This approval has already been ${status == 'approved' ? 'approved' : 'rejected'}',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Reject Approval',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to reject this approval? This action cannot be undone.',
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(
                'Reject',
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

    if (confirmed != true) return;

    try {
      await _approvalController.rejectApproval(approval['id']);

      // Immediately remove from local list (optimistic update) so it disappears right away
      if (mounted) {
        setState(() {
          _allApprovals.removeWhere((a) => a['id'] == approval['id']);
          _lastKnownApprovals.removeWhere((a) => a['id'] == approval['id']);
        });
      }

      // Refresh the stream to sync with database
      _refreshApprovals();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Approval rejected successfully',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to reject approval: $e',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _deleteApproval(Map<String, dynamic> approval) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Remove Approval',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to remove this approval?',
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
                  await _approvalController.deleteApproval(approval['id']);
                  if (!mounted) return;
                  Navigator.of(context).pop();

                  _refreshApprovals();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Approval removed successfully',
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
                        'Failed to remove approval: $e',
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
                'Remove',
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
}
