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
import 'package:supabase_flutter/supabase_flutter.dart';

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
  // Blacklist of rejected/approved approval IDs - never show these even if they appear in stream
  final Set<String> _rejectedApprovalIds = <String>{};
  // Track processing approvals to prevent double submissions
  final Set<String> _processingApprovalIds = <String>{};

  @override
  void initState() {
    super.initState();
    // Initialize stream first (will show loading)
    _initializeStream();
    // Load rejected approvals and rebuild when done
    _loadRejectedApprovals();
  }

  void _initializeStream() {
    _approvalsStream = ApprovalController().getApprovalsStream();
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
            // CRITICAL: Blacklist check MUST happen FIRST before any processing
            List<Map<String, dynamic>> allData = snapshot.data ?? [];

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
                                    return ApprovalCard(
                                      approval: approval,
                                      index: index,
                                      isExpanded:
                                          _expandedCardIds.contains(approvalId),
                                      isProcessing: _processingApprovalIds
                                          .contains(approvalId),
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

      // Reset the preset in Service Management: clear patient info and reset supply quantities to 0
      try {
        if (presetName != null && presetName.isNotEmpty) {
          // Find the preset by name
          final preset = await _presetController.getPresetByName(presetName);
          if (preset != null) {
            // Get the current supplies and reset all quantities to 0
            final currentSupplies =
                List<Map<String, dynamic>>.from(preset['supplies'] ?? []);
            final resetSupplies = currentSupplies.map((supply) {
              return {
                ...supply,
                'quantity': 0, // Reset quantity to 0
              };
            }).toList();

            // Update the preset: clear patient info and reset supply quantities
            await _presetController.updatePreset(preset['id'], {
              'supplies': resetSupplies,
              'patient_name': '',
              'age': '',
              'gender': '',
              'conditions': '',
            });
          }
        }
      } catch (e) {
        // Log error but don't fail the approval
        print('Error resetting preset: $e');
      }

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

      // Get patient information from approval before we reset it
      final patientName = approval['patientName']?.toString() ?? '';
      final age = approval['age']?.toString() ?? '';
      final gender =
          approval['gender']?.toString() ?? approval['sex']?.toString() ?? '';
      final conditions = approval['conditions']?.toString() ?? '';

      if (!mounted) return;

      // Navigate to Deduction Logs
      await Navigator.of(context).pushNamed(
        '/stock-deduction/deduction-logs',
        arguments: {
          'purpose': purpose,
          'remarks': remarks,
          'supplies': savedDeductions,
          'patient_name': patientName,
          'age': age,
          'gender': gender,
          'conditions': conditions,
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

    // Mark as processing
    if (approvalId != null) {
      _processingApprovalIds.add(approvalId);
      setState(() {});
    }

    try {
      await _approvalController.rejectApproval(approval['id']);

      // Save patient information back to the preset in Service Management
      try {
        final presetName = approval['presetName']?.toString();
        if (presetName != null && presetName.isNotEmpty) {
          // Find the preset by name
          final preset = await _presetController.getPresetByName(presetName);
          if (preset != null) {
            // Get patient information
            final patientName = approval['patientName']?.toString() ?? '';
            final age = approval['age']?.toString() ?? '';
            final gender = approval['gender']?.toString() ??
                approval['sex']?.toString() ??
                '';
            final conditions = approval['conditions']?.toString() ?? '';

            // Get supplies with quantities from approval
            final supplies =
                List<Map<String, dynamic>>.from(approval['supplies'] ?? []);

            // Update the preset with patient information AND supplies with quantities
            await _presetController.updatePreset(preset['id'], {
              'patient_name': patientName,
              'age': age,
              'gender': gender,
              'conditions': conditions,
              'supplies': supplies,
            });
          }
        }
      } catch (e) {
        // Log error but don't fail the rejection
        print('Error saving patient info to preset: $e');
      }

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
    } finally {
      // Remove from processing set
      if (approvalId != null && mounted) {
        _processingApprovalIds.remove(approvalId);
        setState(() {});
      }
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
