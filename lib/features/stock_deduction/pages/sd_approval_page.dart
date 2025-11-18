import 'dart:async';
import 'package:flutter/material.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/stock_deduction/controller/sd_approval_controller.dart';
import 'package:familee_dental/features/stock_deduction/controller/stock_deduction_controller.dart';
import 'package:familee_dental/features/inventory/controller/inventory_controller.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/stock_deduction/pages/sd_approval_card_widget.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/features/activity_log/controller/sd_activity_controller.dart';
import 'package:familee_dental/features/notifications/controller/notifications_controller.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/shared/services/connectivity_service.dart';
import 'package:familee_dental/shared/widgets/connection_error_dialog.dart';

// Helper function to format date for notifications
String _formatDateForNotification(DateTime dateTime) {
  final local = dateTime.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final year = local.year.toString();

  int hour = local.hour;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) {
    hour = 12;
  }
  final hourStr = hour.toString();

  return '$month/$day/$year - $hourStr:$minute $period';
}

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
  List<Map<String, dynamic>> _allApprovals = [];
  List<Map<String, dynamic>> _lastKnownApprovals = [];
  late Stream<List<Map<String, dynamic>>> _approvalsStream;
  int _streamKey = 0;
  bool _isFirstLoad = true;
  final Set<String> _expandedCardIds = {};
  // Blacklist of rejected/approved approval IDs - never show these even if they appear in stream
  final Set<String> _rejectedApprovalIds = <String>{};
  // Track processing approvals to prevent double submissions
  final Set<String> _processingApprovalIds = <String>{};

  @override
  void initState() {
    super.initState();
    // Initialize stream first (will show loading)
    _initializeStream();
    // Pre-loading no longer needed - streams auto-load from Hive
    // _approvalController.preloadPendingApprovals().then((_) {
    //   if (mounted) setState(() {});
    // });
    // Load rejected approvals and rebuild when done
    _loadRejectedApprovals();
  }

  void _initializeStream() {
    _approvalsStream = _approvalController.getApprovalsStream();
  }

  // Load already rejected/approved IDs on init to prevent them from appearing
  // This runs every time the page is initialized (including when navigating back)
  Future<void> _loadRejectedApprovals() async {
    try {
      // Query database directly to get all rejected/approved IDs
      // This ensures we blacklist them even if they somehow appear in the stream
      final supabase = Supabase.instance.client;

      // Query for rejected IDs
      final rejectedIds = await supabase
          .from('stock_deduction_approvals')
          .select('id')
          .eq('status', 'rejected')
          .limit(1000);

      // Query for approved IDs
      final approvedIds = await supabase
          .from('stock_deduction_approvals')
          .select('id')
          .eq('status', 'approved')
          .limit(1000);

      // Combine both results - Supabase always returns a List
      _rejectedApprovalIds.clear(); // Clear first, then add fresh data

      for (final row in rejectedIds) {
        final id = row['id']?.toString();
        if (id != null) {
          _rejectedApprovalIds.add(id);
        }
      }

      for (final row in approvedIds) {
        final id = row['id']?.toString();
        if (id != null) {
          _rejectedApprovalIds.add(id);
        }
      }

      // Trigger a rebuild if needed to apply blacklist
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error loading rejected approvals: $e');
    }
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

            final List<Map<String, dynamic>> cached =
                _approvalController.cachedPendingApprovals;
            final List<Map<String, dynamic>> live =
                snapshot.data ?? const <Map<String, dynamic>>[];
            final bool hasLive = live.isNotEmpty;
            final bool hasCached =
                cached.isNotEmpty || _lastKnownApprovals.isNotEmpty;

            final bool showSkeleton = !snapshot.hasData &&
                (snapshot.connectionState == ConnectionState.waiting ||
                    snapshot.connectionState == ConnectionState.active) &&
                !hasCached;

            if (showSkeleton) {
              return _buildSkeletonLoader(context);
            }

            List<Map<String, dynamic>> candidateList;
            if (hasLive) {
              candidateList = List<Map<String, dynamic>>.from(live);
              _lastKnownApprovals = candidateList;
            } else if (_lastKnownApprovals.isNotEmpty) {
              candidateList =
                  List<Map<String, dynamic>>.from(_lastKnownApprovals);
            } else {
              candidateList = List<Map<String, dynamic>>.from(cached);
              _lastKnownApprovals = candidateList;
            }

            // Filter to show only pending approvals
            List<Map<String, dynamic>> allData = candidateList;

            // Triple-layer protection: blacklist → status check → stream filter
            _allApprovals = allData.where((approval) {
              final approvalId = approval['id']?.toString();
              final status = approval['status'] as String?;

              // LAYER 1: Blacklist check FIRST - absolutely prevent these IDs
              if (approvalId != null &&
                  _rejectedApprovalIds.contains(approvalId)) {
                return false; // Blacklisted - NEVER show
              }

              // LAYER 2: Status check - exclude rejected/approved and add to blacklist
              if (status == 'rejected' || status == 'approved') {
                // Immediately add to blacklist for future protection
                if (approvalId != null) {
                  _rejectedApprovalIds.add(approvalId);
                }
                return false; // Rejected/approved - NEVER show
              }

              // LAYER 3: Only show pending or null status
              return status == 'pending' || status == null;
            }).toList();

            // Update last known approvals to filtered list (only pending)
            // This is used only when snapshot has no data (loading state)
            _lastKnownApprovals = _allApprovals.toList();

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
                                    final approvalId =
                                        approval['id']?.toString();
                                    final isStaff = UserRoleProvider().isStaff;
                                    return ApprovalCard(
                                      approval: approval,
                                      index: index,
                                      isExpanded:
                                          _expandedCardIds.contains(approvalId),
                                      isProcessing: _processingApprovalIds
                                          .contains(approvalId),
                                      canApproveReject: !isStaff,
                                      onToggle: () {
                                        setState(() {
                                          if (approvalId != null) {
                                            if (_expandedCardIds
                                                .contains(approvalId)) {
                                              _expandedCardIds
                                                  .remove(approvalId);
                                            } else {
                                              _expandedCardIds.add(approvalId);
                                            }
                                          }
                                        });
                                      },
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
            'Approvals will appear here',
            style: AppFonts.sfProStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveApproval(Map<String, dynamic> approval) async {
    final approvalId = approval['id']?.toString();

    // Check if already processing
    if (approvalId != null && _processingApprovalIds.contains(approvalId)) {
      return;
    }

    // Check if already approved/rejected
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
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
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Confirm Approval',
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
                  'Are you sure you want to approve?',
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
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
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
    );

    if (confirmed != true) return;

    // Check network connection before proceeding
    final hasConnection = await ConnectivityService().hasInternetConnection();
    if (!hasConnection) {
      if (!mounted) return;
      await showConnectionErrorDialog(context);
      return;
    }

    // Mark as processing
    if (approvalId != null) {
      _processingApprovalIds.add(approvalId);
      setState(() {});
    }

    // Use purpose if available (for direct deductions), otherwise use preset name
    final presetName =
        approval['presetName'] ?? approval['name'] ?? 'Unknown Preset';
    final purpose = approval['purpose']?.toString().isNotEmpty == true
        ? approval['purpose'].toString()
        : presetName;
    final remarks = approval['remarks']?.toString() ?? '';

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
          final supplyDocId = supply['docId']?.toString();
          final supplyName = supply['name']?.toString() ?? '';
          final supplyBrand = supply['brand']?.toString() ?? '';
          final quantity = supply['quantity'] ?? 0;

          if (supplyName.isEmpty || quantity <= 0) continue;

          InventoryItem? targetBatch;

          // Try to find exact batch by docId first (most accurate)
          if (supplyDocId != null && supplyDocId.isNotEmpty) {
            for (final item in currentInventory) {
              // Check main item
              if (item.mainItem.id == supplyDocId && item.mainItem.stock > 0) {
                // Block expired items from deduction
                if (!item.mainItem.noExpiry && item.mainItem.expiry != null) {
                  final expiryDate = DateTime.tryParse(
                      item.mainItem.expiry!.replaceAll('/', '-'));
                  if (expiryDate != null &&
                      expiryDate.isBefore(DateTime.now())) {
                    continue; // Skip expired
                  }
                }
                targetBatch = item.mainItem;
                break;
              }
              // Check variants
              for (final variant in item.variants) {
                if (variant.id == supplyDocId && variant.stock > 0) {
                  // Block expired items from deduction
                  if (!variant.noExpiry && variant.expiry != null) {
                    final expiryDate =
                        DateTime.tryParse(variant.expiry!.replaceAll('/', '-'));
                    if (expiryDate != null &&
                        expiryDate.isBefore(DateTime.now())) {
                      continue; // Skip expired
                    }
                  }
                  targetBatch = variant;
                  break;
                }
              }
              if (targetBatch != null) break;
            }
          }

          // If docId match failed or not available, fall back to name/brand matching
          if (targetBatch == null) {
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

              // Use the earliest expiry batch if docId match failed
              if (validBatches.isNotEmpty) {
                targetBatch = validBatches.first;
              }
            }
          }

          // If we found a target batch, add it to deductions
          if (targetBatch != null) {
            final int deductQty =
                quantity > targetBatch.stock ? targetBatch.stock : quantity;

            deductionsToApply.add({
              'docId': targetBatch.id,
              'name': targetBatch.name,
              'brand': targetBatch.brand,
              'imageUrl': targetBatch.imageUrl,
              'expiry': targetBatch.expiry,
              'noExpiry': targetBatch.noExpiry,
              'stock': targetBatch.stock,
              'deductQty': deductQty,
              // Preserve type and packaging info from original approval supply
              'type': supply['type'],
              'packagingContent': supply['packagingContent'],
              'packagingContentQuantity': supply['packagingContentQuantity'],
              'packagingUnit': supply['packagingUnit'],
              'purpose': supply['purpose'],
            });
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

      // Log approval activity
      final SdActivityController sdActivityController = SdActivityController();
      await sdActivityController.logApprovalApproved(
        purpose: purpose,
        supplies: List<Map<String, dynamic>>.from(supplies),
        remarks: remarks,
      );

      // Create notification for approval
      try {
        final createdAtRaw = approval['created_at'];
        DateTime? createdAt;
        if (createdAtRaw is String) {
          createdAt = DateTime.tryParse(createdAtRaw);
        } else if (createdAtRaw is DateTime) {
          createdAt = createdAtRaw;
        }
        final formattedDate = createdAt != null
            ? _formatDateForNotification(createdAt)
            : _formatDateForNotification(DateTime.now());
        await NotificationsController()
            .createSDApprovedNotification(formattedDate);
      } catch (_) {}

      // Add to blacklist immediately to prevent it from ever appearing again
      final approvalId = approval['id']?.toString();
      if (approvalId != null) {
        _rejectedApprovalIds.add(approvalId);
      }

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
      await Navigator.of(context).pushNamedAndRemoveUntil(
        '/stock-deduction/deduction-logs',
        (route) => route.settings.name == '/stock-deduction',
        arguments: {
          'purpose': purpose,
          'remarks': remarks,
          'supplies': savedDeductions,
          'approval_id': approval['id'],
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

      // Check if it's a network error
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('socketexception') ||
          errorString.contains('failed host lookup') ||
          errorString.contains('no address associated') ||
          errorString.contains('network is unreachable') ||
          errorString.contains('connection refused') ||
          errorString.contains('connection timed out') ||
          errorString.contains('clientexception') ||
          errorString.contains('connection abort') ||
          errorString.contains('software caused connection abort')) {
        await showConnectionErrorDialog(context);
      } else {
        // Other error - show generic error message
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
    } finally {
      // Remove from processing set
      if (approvalId != null && mounted) {
        _processingApprovalIds.remove(approvalId);
        setState(() {});
      }
    }
  }

  Future<void> _rejectApproval(Map<String, dynamic> approval) async {
    final approvalId = approval['id']?.toString();

    // Check if already processing
    if (approvalId != null && _processingApprovalIds.contains(approvalId)) {
      return;
    }

    // Check if already approved/rejected
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
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
                    Icons.close,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Reject Approval',
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
                  'Are you sure you want to reject this approval?',
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
    );

    if (confirmed != true) return;

    // Check network connection before proceeding
    final hasConnection = await ConnectivityService().hasInternetConnection();
    if (!hasConnection) {
      if (!mounted) return;
      await showConnectionErrorDialog(context);
      return;
    }

    // Mark as processing
    if (approvalId != null) {
      _processingApprovalIds.add(approvalId);
      setState(() {});
    }

    try {
      await _approvalController.rejectApproval(approval['id']);

      // Get purpose and remarks for logging
      final presetName =
          approval['presetName'] ?? approval['name'] ?? 'Unknown Preset';
      final purpose = approval['purpose']?.toString().isNotEmpty == true
          ? approval['purpose'].toString()
          : presetName;
      final remarks = approval['remarks']?.toString() ?? '';

      // Log rejection activity
      final SdActivityController sdActivityController = SdActivityController();
      final supplies = approval['supplies'] as List<dynamic>? ?? [];
      await sdActivityController.logApprovalRejected(
        purpose: purpose,
        supplies: List<Map<String, dynamic>>.from(supplies),
        remarks: remarks,
      );

      // Create notification for rejection
      try {
        final createdAtRaw = approval['created_at'];
        DateTime? createdAt;
        if (createdAtRaw is String) {
          createdAt = DateTime.tryParse(createdAtRaw);
        } else if (createdAtRaw is DateTime) {
          createdAt = createdAtRaw;
        }
        final formattedDate = createdAt != null
            ? _formatDateForNotification(createdAt)
            : _formatDateForNotification(DateTime.now());
        await NotificationsController()
            .createSDRejectedNotification(formattedDate);
      } catch (_) {}

      // Add to blacklist immediately to prevent it from ever appearing again
      final approvalId = approval['id']?.toString();
      if (approvalId != null) {
        _rejectedApprovalIds.add(approvalId);
      }

      // Immediately remove from local list (optimistic update) so it disappears right away
      if (mounted) {
        setState(() {
          _allApprovals.removeWhere((a) => a['id'] == approval['id']);
          _lastKnownApprovals.removeWhere((a) => a['id'] == approval['id']);
        });
      }

      // Convert rejected supplies back to deduction format and navigate to stock deduction page
      if (supplies.isNotEmpty) {
        // Get current inventory to get current stock values
        List<GroupedInventoryItem> currentInventory = [];
        try {
          currentInventory = await _inventoryController
              .getGroupedSuppliesStream(archived: false)
              .first;
        } catch (e) {
          print('Error loading current inventory: $e');
        }

        // Convert approval supplies back to deduction format
        List<Map<String, dynamic>> restoredDeductions = [];
        for (final supply in supplies) {
          if (supply is Map<String, dynamic>) {
            final supplyDocId = supply['docId']?.toString();
            final quantity = supply['quantity'] ?? 0;

            if (supplyDocId == null || supplyDocId.isEmpty || quantity <= 0) {
              continue;
            }

            // Find the current batch to get up-to-date stock
            InventoryItem? currentBatch;
            for (final item in currentInventory) {
              if (item.mainItem.id == supplyDocId) {
                currentBatch = item.mainItem;
                break;
              }
              for (final variant in item.variants) {
                if (variant.id == supplyDocId) {
                  currentBatch = variant;
                  break;
                }
              }
              if (currentBatch != null) break;
            }

            // If batch not found or out of stock, skip it
            if (currentBatch == null || currentBatch.stock <= 0) {
              continue;
            }

            // Convert to deduction format
            restoredDeductions.add({
              'docId': supplyDocId,
              'name': supply['name'] ?? '',
              'type': supply['type'],
              'brand': supply['brand'] ?? '',
              'imageUrl': supply['imageUrl'] ?? '',
              'expiry': supply['expiry'],
              'noExpiry': supply['noExpiry'] ?? false,
              'stock': currentBatch.stock,
              'deductQty': quantity, // Restore original quantity
              'purpose': supply['purpose'] ?? null, // Restore original purpose
              'packagingContent': supply['packagingContent'],
              'packagingContentQuantity': supply['packagingContentQuantity'],
              'packagingUnit': supply['packagingUnit'],
              'applyToAll': false,
            });
          }
        }

        // Navigate to stock deduction page with restored items and remarks
        if (restoredDeductions.isNotEmpty && mounted) {
          final remarks = approval['remarks']?.toString() ?? '';
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/stock-deduction',
            (route) =>
                route.settings.name == '/stock-deduction' ||
                route.settings.name == '/dashboard',
            arguments: {
              'restoredDeductions': restoredDeductions,
              'remarks': remarks,
            },
          );
        }
      }

      // Don't reinitialize the stream - let Supabase real-time handle it automatically
      // The stream will receive the update with status='rejected' and the Dart filter will exclude it
      // The blacklist ensures it never reappears even if there's a delay in the update

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

      // Check if it's a network error
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('socketexception') ||
          errorString.contains('failed host lookup') ||
          errorString.contains('no address associated') ||
          errorString.contains('network is unreachable') ||
          errorString.contains('connection refused') ||
          errorString.contains('connection timed out') ||
          errorString.contains('clientexception') ||
          errorString.contains('connection abort') ||
          errorString.contains('software caused connection abort')) {
        await showConnectionErrorDialog(context);
      } else {
        // Other error - show generic error message
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
    } finally {
      // Remove from processing set
      if (approvalId != null && mounted) {
        _processingApprovalIds.remove(approvalId);
        setState(() {});
      }
    }
  }
}
