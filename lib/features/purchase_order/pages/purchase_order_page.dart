import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:familee_dental/shared/drawer.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/purchase_order/controller/po_list_controller.dart';
import 'package:familee_dental/features/purchase_order/controller/po_supabase_controller.dart';
import 'package:familee_dental/features/purchase_order/data/purchase_order.dart';
import 'dart:async'; // Added for StreamSubscription
import 'package:familee_dental/features/activity_log/controller/po_activity_controller.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/shared/widgets/notification_badge_button.dart';
import 'package:shimmer/shimmer.dart';
import 'package:familee_dental/features/auth/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/shared/services/user_data_service.dart';
import 'package:familee_dental/shared/services/connectivity_service.dart';
import 'package:familee_dental/shared/widgets/connection_error_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:familee_dental/features/inventory/controller/catalog_controller.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/inventory/controller/view_supply_controller.dart';

class PurchaseOrderPage extends StatefulWidget {
  const PurchaseOrderPage({super.key});

  @override
  State<PurchaseOrderPage> createState() => _PurchaseOrderPageState();
}

class _PurchaseOrderPageState extends State<PurchaseOrderPage> {
  final POListController _controller = POListController();
  final POSupabaseController _poSupabaseController = POSupabaseController();
  final ViewSupplyController _viewSupplyController = ViewSupplyController();
  final Set<String> _prefetchedSupplyNames = {};
  DateTime? _closedStartDate;
  DateTime? _closedEndDate;
  // ignore: unused_field
  List<PurchaseOrder> _orders = [];
  List<PurchaseOrder> _closedOrders =
      []; // Separate list for closed POs from Supabase
  List<PurchaseOrder> _approvalOrders = []; // Separate list for approval POs
  List<PurchaseOrder> _openOrders = []; // Separate list for open POs
  List<PurchaseOrder> _partialOrders = []; // Separate list for partial POs
  int activeTabIndex = 0;
  final TextEditingController searchController = TextEditingController();

  String? _userName;
  String? _userRole;
  final _userDataService = UserDataService();
  bool?
      _hasConnection; // Track connectivity status (null = checking, true = online, false = offline)

  // Stream subscriptions for proper disposal
  StreamSubscription<List<PurchaseOrder>>? _openSubscription;
  StreamSubscription<List<PurchaseOrder>>? _partialSubscription;
  StreamSubscription<List<PurchaseOrder>>? _approvalSubscription;
  StreamSubscription<List<PurchaseOrder>>? _closedSubscription;
  StreamSubscription<List<PurchaseOrder>>? _allSubscription;

  // Initial navigation from notifications
  bool _handledInitialArgs = false;
  // removed unused _initialTabIndex
  String? _openPOCode;
  bool _autoOpeningDetails = false; // prevent stacked navigations
  // Info banner removed
  bool _loadedOpen = false;
  bool _loadedPartial = false;
  bool _loadedApproval = false;
  bool _loadedClosed = false;

  Future<void> _load() async {
    try {
      // Check connectivity on refresh
      _checkConnectivity();

      // Load from local storage as backup (kept for potential future use)
      await _controller.getAllPOs();

      // Check current sequence
      await _controller.getCurrentSequence();

      // Load ALL POs from Supabase (real-time)
      _loadAllPOsFromSupabase();

      // Wait for the current tab's stream to emit at least one event
      // This ensures the RefreshIndicator shows its animation
      if (activeTabIndex == 0) {
        await _controller.getOpenPOsStream().first;
      } else if (activeTabIndex == 1) {
        await _controller.getApprovalPOsStream().first;
      } else {
        await _controller.getClosedPOsStream().first;
      }
    } catch (e) {
      // Don't show error UI in async operations to avoid context issues
      // The error is logged for debugging purposes
    }
  }

  void _loadAllPOsFromSupabase() {
    try {
      // Load Open POs
      _openSubscription = _controller.getOpenPOsStream().listen(
        (openPOs) {
          if (mounted) {
            setState(() {
              _openOrders = openPOs;
              _loadedOpen = true;
            });
            _resolveSmartRedirect();
          }
        },
        onError: (error) {
          // Don't use ScaffoldMessenger in stream error handlers
          // The error will be handled gracefully without showing UI
        },
      );

      // Load Partial POs
      _partialSubscription = _controller.getPartialPOsStream().listen(
        (partialPOs) {
          if (mounted) {
            setState(() {
              _partialOrders = partialPOs;
              _loadedPartial = true;
            });
            _resolveSmartRedirect();
          }
        },
        onError: (error) {
          // Don't use ScaffoldMessenger in stream error handlers
          // The error will be handled gracefully without showing UI
        },
      );

      // Load Approval POs
      _approvalSubscription = _controller.getApprovalPOsStream().listen(
        (approvalPOs) {
          if (mounted) {
            setState(() {
              _approvalOrders = approvalPOs;
              _loadedApproval = true;
            });
            _resolveSmartRedirect();
          }
        },
        onError: (error) {
          // Don't use ScaffoldMessenger in stream error handlers
          // The error will be handled gracefully without showing UI
        },
      );

      // Load Closed POs
      _closedSubscription = _controller.getClosedPOsStream().listen(
        (closedPOs) {
          if (mounted) {
            setState(() {
              _closedOrders = closedPOs;
              _loadedClosed = true;
            });
            _resolveSmartRedirect();
          }
        },
        onError: (error) {
          // Don't use ScaffoldMessenger in stream error handlers
          // The error will be handled gracefully without showing UI
        },
      );

      // Load all POs for backup and other operations
      _allSubscription = _controller.getAllPOsStream().listen(
        (allPOs) {
          if (mounted) {
            setState(() {
              _orders = allPOs;
            });
          }
        },
        onError: (error) {
          // Don't use ScaffoldMessenger in stream error handlers
          // The error will be handled gracefully without showing UI
        },
      );
    } catch (e) {
      // Error handling
    }
  }

  // removed unused _filteredOrders helper

  // Apply search filter to a provided list (used by StreamBuilder)
  List<PurchaseOrder> _applySearchFilter(List<PurchaseOrder> baseList) {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return baseList;
    return baseList.where((po) {
      final bool matchesBasic = po.code.toLowerCase().contains(query) ||
          po.name.toLowerCase().contains(query);
      if (matchesBasic) return true;
      try {
        // Also search delivery receipt numbers saved on supplies
        final supplies = po.supplies as List<dynamic>?;
        if (supplies == null) return false;
        for (final s in supplies) {
          if (s is Map) {
            final dr = (s['receiptDrNo'] ?? s['drNo'] ?? s['dr_number'])
                ?.toString()
                .toLowerCase();
            if (dr != null && dr.contains(query)) return true;
          }
        }
      } catch (_) {}
      return false;
    }).toList();
  }

  DateTime _dateOnly(DateTime source) =>
      DateTime(source.year, source.month, source.day);

  bool _isWithinClosedDateRange(DateTime date) {
    if (_closedStartDate == null && _closedEndDate == null) return true;
    final target = _dateOnly(date);
    if (_closedStartDate != null &&
        target.isBefore(_dateOnly(_closedStartDate!))) {
      return false;
    }
    if (_closedEndDate != null && target.isAfter(_dateOnly(_closedEndDate!))) {
      return false;
    }
    return true;
  }

  Future<void> _pickClosedStartDate() async {
    final now = DateTime.now();
    final initialDate =
        _closedStartDate ?? _closedEndDate ?? DateTime(now.year, now.month, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );

    if (picked != null && mounted) {
      setState(() {
        _closedStartDate = _dateOnly(picked);
        if (_closedEndDate != null &&
            _closedEndDate!.isBefore(_closedStartDate!)) {
          _closedEndDate = _closedStartDate;
        }
      });
    }
  }

  Future<void> _pickClosedEndDate() async {
    final now = DateTime.now();
    final initialDate =
        _closedEndDate ?? _closedStartDate ?? DateTime(now.year, now.month, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );

    if (picked != null && mounted) {
      setState(() {
        _closedEndDate = _dateOnly(picked);
        if (_closedStartDate != null &&
            _closedStartDate!.isAfter(_closedEndDate!)) {
          _closedStartDate = _closedEndDate;
        }
      });
    }
  }

  void _clearClosedDateRange() {
    if (_closedStartDate == null && _closedEndDate == null) return;
    setState(() {
      _closedStartDate = null;
      _closedEndDate = null;
    });
  }

  Widget _buildClosedDateFilter(ThemeData theme) {
    final scheme = theme.colorScheme;
    final localizations = MaterialLocalizations.of(context);
    final startLabel = _closedStartDate == null
        ? 'Start date'
        : localizations.formatShortDate(_closedStartDate!);
    final endLabel = _closedEndDate == null
        ? 'End date'
        : localizations.formatShortDate(_closedEndDate!);

    Widget buildPickerTile({
      required String title,
      required String value,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 168,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: AppFonts.sfProStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppFonts.sfProStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              buildPickerTile(
                title: 'From',
                value: startLabel,
                onTap: _pickClosedStartDate,
              ),
              const SizedBox(width: 8),
              buildPickerTile(
                title: 'To',
                value: endLabel,
                onTap: _pickClosedEndDate,
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                width: 40,
                child: Visibility(
                  visible: _closedStartDate != null || _closedEndDate != null,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: true,
                  child: IconButton(
                    tooltip: 'Clear date range',
                    onPressed: _clearClosedDateRange,
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add listener for search functionality
  @override
  void initState() {
    super.initState();
    try {
      // Load user data from Hive first (avoid placeholders)
      _loadUserDataFromHive();

      _load();
      _loadUserData();
      _checkConnectivity();
      searchController.addListener(() {
        setState(() {
          // This will trigger rebuild when search text changes
        });
      });
    } catch (e) {
      // Error handling
    }
  }

  /// Load user data from Hive (no placeholders)
  Future<void> _loadUserDataFromHive() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        await _userDataService.loadFromHive(currentUser.id);
        if (mounted) {
          setState(() {
            _userName = _userDataService.userName;
            _userRole = _userDataService.userRole;
          });
        }
      }
    } catch (e) {
      // Ignore errors - best effort
    }
  }

  Future<void> _checkConnectivity() async {
    final hasConnection = await ConnectivityService().hasInternetConnection();
    if (mounted) {
      setState(() {
        _hasConnection = hasConnection;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser != null) {
        // Try to get user data from user_roles table (same approach as Dashboard)
        final response = await supabase
            .from('user_roles')
            .select('*')
            .eq('id', currentUser.id)
            .limit(1)
            .maybeSingle();

        if (mounted) {
          if (response != null &&
              response['name'] != null &&
              response['name'].toString().trim().isNotEmpty) {
            // Use data from user_roles table
            final name = response['name'].toString().trim();
            final role = response['role']?.toString().trim() ?? 'Admin';

            setState(() {
              _userName = name;
              _userRole = role;
            });

            // Save to Hive for persistence
            await _userDataService.saveToHive(currentUser.id, name, role);
          } else {
            // Fallback to auth user data
            final displayName =
                currentUser.userMetadata?['display_name']?.toString().trim();
            final emailName = currentUser.email?.split('@')[0].trim();
            final name = displayName ?? emailName ?? 'User';
            final role = 'Admin';

            setState(() {
              _userName = name;
              _userRole = role;
            });

            // Save to Hive for persistence
            await _userDataService.saveToHive(currentUser.id, name, role);
          }
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _userName = _userDataService.userName;
          _userRole = _userDataService.userRole;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledInitialArgs) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final int? tab = args['initialTab'] as int?;
      final String? code = args['openPOCode'] as String?;
      if (tab != null) {
        activeTabIndex = tab.clamp(0, 2);
      }
      if (code != null && code.isNotEmpty) {
        _openPOCode = code;
      }
    }
    _handledInitialArgs = true;
  }

  @override
  void dispose() {
    searchController.dispose();
    _openSubscription?.cancel();
    _partialSubscription?.cancel();
    _approvalSubscription?.cancel();
    _closedSubscription?.cancel();
    _allSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    try {
      return Stack(
        children: [
          WillPopScope(
            onWillPop: () async {
              // Navigate back to Dashboard when back button is pressed
              // Use popUntil to go back to existing Dashboard instead of creating a new one
              Navigator.popUntil(
                  context, (route) => route.settings.name == '/dashboard');
              return false; // Prevent default back behavior
            },
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              backgroundColor: theme.brightness == Brightness.dark
                  ? const Color(0xFF3A3A3A)
                  : const Color(0xFFF5F5F5),
              drawer: MediaQuery.of(context).size.width >= 900
                  ? null
                  : const MyDrawer(),
              body: MediaQuery.of(context).size.width >= 900
                  ? _buildRailLayout(context, theme)
                  : _buildPurchaseOrderContent(theme),
            ),
          ),
          // Hidden image cache for Add Supply page (renders off-screen to cache images)
          // Same approach as inventory - images cached when rendered
          _buildHiddenImageCache(),
        ],
      );
    } catch (e) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            "Purchase Order",
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
        ),
        drawer:
            MediaQuery.of(context).size.width >= 900 ? null : const MyDrawer(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: AppFonts.sfProStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Please try again',
                style: AppFonts.sfProStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    // Trigger rebuild
                  });
                },
                icon: Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  'Retry',
                  style: AppFonts.sfProStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00D4AA),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _resolveSmartRedirect() {
    if (_openPOCode == null || _autoOpeningDetails) return;
    // Wait until all streams have delivered at least one snapshot to avoid false "not found"
    if (!(_loadedOpen && _loadedPartial && _loadedApproval && _loadedClosed)) {
      return;
    }
    // Find target PO across current lists to determine actual status
    PurchaseOrder? target;
    for (final p in _openOrders) {
      if (p.code == _openPOCode) {
        target = p;
        break;
      }
    }
    if (target == null) {
      for (final p in _approvalOrders) {
        if (p.code == _openPOCode) {
          target = p;
          break;
        }
      }
    }
    if (target == null) {
      for (final p in _closedOrders) {
        if (p.code == _openPOCode) {
          target = p;
          break;
        }
      }
    }
    if (target == null) {
      // Target PO not found across any list – likely deleted
      final String missingCode = _openPOCode!;
      _openPOCode = null; // clear intent to avoid repeated attempts
      _showNotFoundOverlay(
        title: 'Purchase Order Not Found',
        message: 'This purchase order ($missingCode) no longer exists.',
      );
      return;
    }

    // Switch tab based on latest status
    int nextTab;
    switch (target.status) {
      case 'Approval':
        nextTab = 1;
        break;
      case 'Closed':
        nextTab = 2;
        break;
      default:
        nextTab = 0; // Open
    }
    if (activeTabIndex != nextTab) {
      setState(() {
        activeTabIndex = nextTab;
      });
    }
  }

  void _showNotFoundOverlay({required String title, required String message}) {
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE44B4D),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.error_outline,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.sfProStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.sfProStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        entry?.remove();
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(entry);
    Future.delayed(const Duration(milliseconds: 3500), () {
      entry?.remove();
    });
  }

  // Info banner removed

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppFonts.sfProStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        Text(
          label,
          style: AppFonts.sfProStyle(
            fontSize: 14,
            color:
                Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // Calculate summary counts
  Map<String, int> _getSummaryCounts() {
    // Count Closed POs including Cancelled status
    // Use _orders to ensure cancelled POs are included in the count
    final closedCount = _orders
        .where((po) => po.status == 'Closed' || po.status == 'Cancelled')
        .length;

    return {
      'Open': _openOrders.length,
      'Partial': _partialOrders.length,
      'Approval': _approvalOrders.length,
      'Closed': closedCount,
    };
  }

  Widget _buildTab(String text, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: AppFonts.sfProStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isActive
                ? Theme.of(context).textTheme.bodyMedium?.color
                : Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildPOCard(PurchaseOrder po) {
    // Decide status color and label style
    Color statusColor;
    switch (po.status) {
      case 'Closed':
        statusColor = Colors.red;
        break;
      case 'Approval':
        statusColor = Colors.orange;
        break;
      case 'Cancelled':
        statusColor = Colors.redAccent;
        break;
      default:
        statusColor = const Color(0xFF00D4AA);
    }

    // Create the card content
    Widget cardContent = Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          try {
            final result = await Navigator.pushNamed(
              context,
              '/po-details',
              arguments: {'purchaseOrder': po},
            );
            // Refresh the data when returning from PO Details
            if (result is Map) {
              if (result['switchToClosed'] == true) {
                setState(() {
                  activeTabIndex = 2; // Closed tab
                });
              } else if (result['switchToApproval'] == true) {
                setState(() {
                  activeTabIndex = 2; // Approval tab (index 2)
                });
              }
            }
            _load();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error opening PO details: $e',
                  style: AppFonts.sfProStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: left code, right status chip
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${po.code} - ${po.name}',
                      style: AppFonts.sfProStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: statusColor.withOpacity(0.4), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          po.status,
                          style: AppFonts.sfProStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Progress bar based on received supplies
              Container(
                height: 6,
                width: 180,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 6,
                    width: _supplierTotal(po) > 0
                        ? (180 * (_supplierReceived(po) / _supplierTotal(po)))
                        : 0,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB37BE6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Bottom row: left counts, right date + chevron
              Row(
                children: [
                  Text(
                    '${_supplierReceived(po)} of ${_supplierTotal(po)}',
                    style: AppFonts.sfProStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _controller.formatDate(po.createdAt),
                        style: AppFonts.sfProStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right,
                          size: 20,
                          color: Theme.of(context)
                              .iconTheme
                              .color
                              ?.withOpacity(0.6)),
                    ],
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );

    final userRoleProvider = UserRoleProvider();

    // Only add slidable functionality for "Open" POs
    if (po.status == 'Open') {
      final isStaff = userRoleProvider.isStaff;

      if (isStaff) {
        // For staff users: only right slide (Edit), no left slide
        return ClipRect(
          child: Slidable(
            key: Key('slidable-${po.id}'),
            closeOnScroll: true,
            startActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.35,
              children: [
                // Edit action - Available for Staff
                SlidableAction(
                  onPressed: (_) => _editPO(po),
                  backgroundColor: const Color(0xFF00D4AA),
                  foregroundColor: Colors.white,
                  icon: Icons.edit,
                  label: 'Edit',
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            ),
            // No endActionPane for staff - no left slide
            child: cardContent,
          ),
        );
      } else {
        // For admin users: both left and right slides
        return ClipRect(
          child: Slidable(
            key: Key('slidable-${po.id}'),
            closeOnScroll: true,
            startActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.35,
              children: [
                // Edit action - Available for Admin
                SlidableAction(
                  onPressed: (_) => _editPO(po),
                  backgroundColor: const Color(0xFF00D4AA),
                  foregroundColor: Colors.white,
                  icon: Icons.edit,
                  label: 'Edit',
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            ),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.35,
              children: [
                // Delete action - Only for Admin users
                SlidableAction(
                  onPressed: (_) async {
                    final confirmed = await _showDeleteConfirmation(po);
                    if (confirmed) {
                      // PO will be deleted in the confirmation dialog
                    }
                  },
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  icon: Icons.cancel,
                  label: 'Cancel',
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            ),
            child: cardContent,
          ),
        );
      }
    }

    // Return regular card for non-Open/Closed POs or users without permissions
    return cardContent;
  }

  // Supplier-based counts for PO list
  int _supplierTotal(PurchaseOrder po) {
    final Set<String> names = {};
    for (final s in po.supplies) {
      final name = (s['supplierName'] ?? s['supplier'] ?? '').toString();
      names.add(name.trim().toLowerCase());
    }
    return names.length;
  }

  int _supplierReceived(PurchaseOrder po) {
    final Map<String, bool> supplierAllReceived = {};
    for (final s in po.supplies) {
      final name = (s['supplierName'] ?? s['supplier'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final received = (s['status'] == 'Received');
      supplierAllReceived[name] =
          (supplierAllReceived[name] ?? true) && received;
    }
    return supplierAllReceived.values.where((v) => v).length;
  }

  void _editPO(PurchaseOrder po) async {
    final hasConnection = await ConnectivityService().hasInternetConnection();
    if (!hasConnection) {
      await showConnectionErrorDialog(context);
      return;
    }

    // Navigate to Create PO page with existing PO data for editing
    final result = await Navigator.pushNamed(
      context,
      '/create-po',
      arguments: {
        'editingPO': po, // Pass the PO to edit
        'isEditing': true, // Flag to indicate we're editing
      },
    );

    // Refresh the data when returning from Create PO page
    if (result == true) {
      await _load();
    }
  }

  // Hidden widget to cache catalog images when PO page loads (same approach as inventory)
  // This ensures images are cached for Add Supply and Edit Supply pages without needing to visit them first
  Widget _buildHiddenImageCache() {
    final catalogController = CatalogController();

    // Render catalog items and PO supply images off-screen to cache images automatically
    // Same approach as inventory page - render items to trigger CachedNetworkImage caching
    return Positioned(
      left: -9999,
      top: -9999,
      width: 1,
      height: 1,
      child: Opacity(
        opacity: 0,
        child: Stack(
          children: [
            // Cache catalog images (for Add Supply page)
            StreamBuilder<List<GroupedInventoryItem>>(
              stream: catalogController.getAllProductsStream(
                  archived: false, expired: false),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return SizedBox.shrink();
                }

                final products = snapshot.data!;
                // Render first 30 items to cache images (enough to cover most common supplies)
                // This matches inventory behavior where grid items cache images when rendered
                return GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: products.length > 30 ? 30 : products.length,
                  itemBuilder: (context, index) {
                    final item = products[index].mainItem;
                    final supplyName = item.name;
                    if (supplyName.isNotEmpty &&
                        !_prefetchedSupplyNames.contains(supplyName)) {
                      _prefetchedSupplyNames.add(supplyName);
                      // Preload types for this supply name (best-effort)
                      _viewSupplyController.getSupplyTypes(supplyName);
                    }
                    // Use CachedNetworkImage to cache images (same as inventory)
                    // Images are cached automatically when this widget renders
                    return item.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: item.imageUrl,
                            errorWidget: (context, url, error) =>
                                SizedBox.shrink(),
                            placeholder: (context, url) => SizedBox.shrink(),
                          )
                        : SizedBox.shrink();
                  },
                );
              },
            ),
            // Cache images from existing POs (for Edit Supply page)
            StreamBuilder<List<PurchaseOrder>>(
              stream: _controller.getAllPOsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return SizedBox.shrink();
                }

                final pos = snapshot.data!;
                final imageUrls = <String>{};
                final receiptUrls = <String>{};

                // Collect unique image URLs from all POs (for Edit Supply caching)
                for (final po in pos) {
                  for (final supply in po.supplies) {
                    final imageUrl = supply['imageUrl']?.toString() ??
                        supply['image_url']?.toString() ??
                        '';
                    final supplyName = supply['supplyName']?.toString() ??
                        supply['name']?.toString() ??
                        '';
                    if (supplyName.isNotEmpty &&
                        !_prefetchedSupplyNames.contains(supplyName)) {
                      _prefetchedSupplyNames.add(supplyName);
                      _viewSupplyController.getSupplyTypes(supplyName);
                    }
                    if (imageUrl.isNotEmpty) {
                      imageUrls.add(imageUrl);
                    }

                    final receiptUrl = supply['receiptImagePath']?.toString() ??
                        supply['receiptImageUrl']?.toString() ??
                        '';
                    if (receiptUrl.startsWith('http')) {
                      receiptUrls.add(receiptUrl);
                    }
                  }
                }

                // Cache up to 50 unique images from POs (for Edit Supply page)
                final supplyImageWidgets = imageUrls.take(50).map((url) {
                  return CachedNetworkImage(
                    imageUrl: url,
                    errorWidget: (context, url, error) => SizedBox.shrink(),
                    placeholder: (context, url) => SizedBox.shrink(),
                  );
                });

                // Cache up to 30 receipt attachments from closed POs
                final receiptImageWidgets = receiptUrls.take(30).map((url) {
                  return CachedNetworkImage(
                    imageUrl: url,
                    errorWidget: (context, url, error) => SizedBox.shrink(),
                    placeholder: (context, url) => SizedBox.shrink(),
                  );
                });

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...supplyImageWidgets,
                    ...receiptImageWidgets,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(PurchaseOrder po) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return await showDialog<bool>(
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
                        Icons.delete,
                        color: Colors.red,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'Cancel Purchase Order',
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
                      'Are you sure you want to cancel "${po.name}"? This action cannot be undone.',
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

                    // Buttons (Delete first, then Cancel)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              // Check connectivity before proceeding
                              final hasConnection = await ConnectivityService()
                                  .hasInternetConnection();
                              if (!hasConnection) {
                                if (context.mounted) {
                                  Navigator.of(context).pop(false);
                                  await showConnectionErrorDialog(context);
                                }
                                return;
                              }

                              try {
                                // Capture PO for logging before cancellation
                                final capturedPO = po;

                                // Soft cancel the PO instead of hard delete
                                final updatedSupplies = capturedPO.supplies
                                    .map<Map<String, dynamic>>((supply) {
                                  final updated =
                                      Map<String, dynamic>.from(supply);
                                  updated['status'] = 'Cancelled';
                                  return updated;
                                }).toList();

                                final updatedPO = PurchaseOrder(
                                  id: capturedPO.id,
                                  code: capturedPO.code,
                                  name: capturedPO.name,
                                  createdAt: capturedPO.createdAt,
                                  status: 'Cancelled',
                                  supplies: updatedSupplies,
                                  receivedCount: capturedPO.receivedCount,
                                );
                                await _poSupabaseController
                                    .savePOToSupabase(updatedPO);

                                if (mounted) {
                                  Navigator.of(context).pop(true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Purchase Order cancelled successfully!',
                                        style: AppFonts.sfProStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: Color(0xFF00D4AA),
                                      duration: Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );
                                  await PoActivityController()
                                      .logPurchaseOrderRemoved(
                                    poCode: capturedPO.code,
                                    poName: capturedPO.name,
                                    supplies: capturedPO.supplies,
                                  );
                                }
                                _load();
                              } catch (e) {
                                Navigator.of(context).pop(false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error deleting Purchase Order: $e',
                                        style: AppFonts.sfProStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            },
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
                              'Proceed',
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
  }

  Widget _buildPurchaseOrderContent(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Panel (with notification and account)
          _buildWelcomePanel(theme),
          const SizedBox(height: 12),
          // Summary Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem("Open", "${_getSummaryCounts()['Open']}"),
                _buildSummaryItem(
                    "Partial", "${_getSummaryCounts()['Partial']}"),
                _buildSummaryItem(
                    "Approval", "${_getSummaryCounts()['Approval']}"),
                _buildSummaryItem("Closed", "${_getSummaryCounts()['Closed']}"),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Search and Create PO Section
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: (value) {
                    setState(() {
                      // This will trigger rebuild when search text changes
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search PO...',
                    hintStyle: AppFonts.sfProStyle(
                      fontSize: 16,
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                    prefixIcon:
                        Icon(Icons.search, color: theme.iconTheme.color),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    filled: true,
                    fillColor: scheme.surface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final result =
                      await Navigator.pushNamed(context, '/create-po');
                  if (!mounted) return;
                  if (result == true) {
                    await _load();
                  } else {
                    await _load();
                  }
                },
                icon: Icon(Icons.add, color: Colors.white),
                label: Text(
                  'Create PO',
                  style: AppFonts.sfProStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00D4AA),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Main Content Area - Expanded to fill remaining space
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? theme.colorScheme.surface
                    : const Color(0xFFE8D5E8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  // Tabs
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTab("Open", activeTabIndex == 0, () {
                          setState(() {
                            activeTabIndex = 0;
                          });
                        }),
                        const SizedBox(width: 12),
                        _buildTab("Partial", activeTabIndex == 1, () {
                          setState(() {
                            activeTabIndex = 1;
                          });
                        }),
                        const SizedBox(width: 12),
                        _buildTab("Approval", activeTabIndex == 2, () {
                          setState(() {
                            activeTabIndex = 2;
                          });
                        }),
                        const SizedBox(width: 12),
                        _buildTab("Closed", activeTabIndex == 3, () {
                          setState(() {
                            activeTabIndex = 3;
                          });
                        }),
                      ],
                    ),
                  ),
                  if (activeTabIndex == 3) _buildClosedDateFilter(theme),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: StreamBuilder<List<PurchaseOrder>>(
                        stream: activeTabIndex == 0
                            ? _controller.getOpenPOsStream()
                            : activeTabIndex == 1
                                ? _controller.getPartialPOsStream()
                                : activeTabIndex == 2
                                    ? _controller.getApprovalPOsStream()
                                    : _controller.getClosedPOsStream(),
                        builder: (context, snapshot) {
                          final data = snapshot.data ?? const <PurchaseOrder>[];
                          List<PurchaseOrder> displayed =
                              _applySearchFilter(data);
                          if (activeTabIndex == 3 &&
                              (_closedStartDate != null ||
                                  _closedEndDate != null)) {
                            displayed = displayed
                                .where((po) =>
                                    _isWithinClosedDateRange(po.createdAt))
                                .toList();
                          }

                          // Show skeleton loader only when online AND waiting for data
                          // When offline, cached data shows immediately (no skeleton needed)
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              data.isEmpty &&
                              (_hasConnection == true)) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final baseColor =
                                isDark ? Colors.grey[800]! : Colors.grey[300]!;
                            final highlightColor =
                                isDark ? Colors.grey[700]! : Colors.grey[100]!;

                            return ListView.separated(
                              physics: NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.all(12),
                              clipBehavior: Clip.hardEdge,
                              itemCount: 5,
                              separatorBuilder: (_, __) => SizedBox(height: 8),
                              itemBuilder: (_, __) => Shimmer.fromColors(
                                baseColor: baseColor,
                                highlightColor: highlightColor,
                                child: Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            );
                          }

                          // Handle errors gracefully
                          if (snapshot.hasError && data.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cloud_off_outlined,
                                      size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    "Connection Issue",
                                    style: AppFonts.sfProStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    "Pull down to refresh",
                                    style: AppFonts.sfProStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (displayed.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: theme.brightness == Brightness.dark
                                          ? theme.colorScheme.surface
                                          : scheme.surface.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color:
                                            theme.brightness == Brightness.dark
                                                ? theme.dividerColor
                                                    .withOpacity(0.2)
                                                : theme.dividerColor
                                                    .withOpacity(0.3),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.shopping_cart_outlined,
                                      size: 60,
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.white
                                          : const Color(0xFF8B5A8B),
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  Text(
                                    "No Purchase Order Yet",
                                    style: AppFonts.sfProStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.white
                                          : const Color(0xFF8B5A8B),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return ListView.separated(
                            physics: AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.all(12),
                            clipBehavior: Clip.hardEdge,
                            itemCount: displayed.length,
                            separatorBuilder: (_, __) => SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final po = displayed[index];
                              // Auto-open specific PO details if requested
                              if (_openPOCode != null &&
                                  !_autoOpeningDetails &&
                                  po.code == _openPOCode) {
                                _autoOpeningDetails = true;
                                _openPOCode = null;
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) async {
                                  final result = await Navigator.pushNamed(
                                    context,
                                    '/po-details',
                                    arguments: {'purchaseOrder': po},
                                  );
                                  if (result is Map) {
                                    if (result['switchToClosed'] == true) {
                                      setState(() {
                                        activeTabIndex = 2;
                                      });
                                    } else if (result['switchToApproval'] ==
                                        true) {
                                      setState(() {
                                        activeTabIndex = 2;
                                      });
                                    }
                                  }
                                  _autoOpeningDetails = false;
                                });
                              }
                              return _buildPOCard(po);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePanel(ThemeData theme) {
    final userName = _userName ?? 'User';
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: theme.colorScheme.surface,
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row with greeting on left and account section on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Greeting message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Purchase Order",
                        style: AppFonts.sfProStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Manage and track your purchase orders efficiently.",
                        style: AppFonts.sfProStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right side - Notification button and Account section
                Row(
                  children: [
                    // Notification button
                    const NotificationBadgeButton(),
                    const SizedBox(width: 8),
                    // Avatar with first letter
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: AppFonts.sfProStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name and role
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userName,
                          style: AppFonts.sfProStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          _userRole ?? 'Admin',
                          style: AppFonts.sfProStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRailLayout(BuildContext context, ThemeData theme) {
    // Main destinations (top section)
    final List<_RailDestination> mainDestinations = [
      _RailDestination(
          icon: Icons.dashboard, label: 'Dashboard', route: '/dashboard'),
      _RailDestination(
          icon: Icons.inventory, label: 'Inventory', route: '/inventory'),
      _RailDestination(
          icon: Icons.shopping_cart,
          label: 'Purchase Order',
          route: '/purchase-order'),
      _RailDestination(
          icon: Icons.playlist_remove,
          label: 'Stock Deduction',
          route: '/stock-deduction'),
    ];

    // Use the same role logic as drawer for conditional Activity Log
    final userRoleProvider = UserRoleProvider();
    final canAccessActivityLog = userRoleProvider.canAccessActivityLog();

    // Bottom destinations (Settings and Logout)
    final List<_RailDestination> bottomDestinations = [
      _RailDestination(
          icon: Icons.settings, label: 'Settings', route: '/settings'),
      _RailDestination(icon: Icons.logout, label: 'Logout', route: '/logout'),
    ];

    // Purchase Order is selected here
    final int selectedIndex = 2;

    return Row(
      children: [
        Container(
          width: 220,
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              // Logo and brand
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 35.0, 16.0, 16.0),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.asset(
                          'assets/images/logo/logo_101.png',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 60,
                              height: 60,
                              color: Colors.blue,
                              child: const Icon(
                                Icons.medical_services,
                                color: Colors.white,
                                size: 30,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Flexible(
                      child: Transform.translate(
                        offset: const Offset(0, 8),
                        child: Transform.scale(
                          scale: 2.9,
                          child: theme.brightness == Brightness.dark
                              ? ColorFiltered(
                                  colorFilter: const ColorFilter.matrix([
                                    1.5, 0, 0, 0, 0, // Red channel - brighten
                                    0, 1.5, 0, 0, 0, // Green channel - brighten
                                    0, 0, 1.5, 0, 0, // Blue channel - brighten
                                    0, 0, 0, 1, 0, // Alpha channel - unchanged
                                  ]),
                                  child: Image.asset(
                                    'assets/images/logo/tita_doc_2.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Text(
                                        'FamiLee Dental',
                                        style: AppFonts.sfProStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: theme
                                              .textTheme.titleMedium?.color,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/logo/tita_doc_2.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text(
                                      'FamiLee Dental',
                                      style: AppFonts.sfProStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color:
                                            theme.textTheme.titleMedium?.color,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Navigation items
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // MENU section header
                    _buildSectionHeader(theme, 'MENU'),
                    const SizedBox(height: 8),
                    // MENU items
                    for (int i = 0; i < mainDestinations.length; i++)
                      _buildRailDestinationTile(
                        context: context,
                        theme: theme,
                        destination: mainDestinations[i],
                        isSelected: i == selectedIndex,
                        onTap: () {
                          final dest = mainDestinations[i];
                          final currentRoute =
                              ModalRoute.of(context)?.settings.name;

                          if (currentRoute != dest.route) {
                            Navigator.pushNamed(context, dest.route);
                          }
                        },
                      ),
                    // Activity Logs (if accessible) - part of MENU
                    if (canAccessActivityLog)
                      _buildRailDestinationTile(
                        context: context,
                        theme: theme,
                        destination: _RailDestination(
                          icon: Icons.history,
                          label: 'Activity Logs',
                          route: '/activity-log',
                        ),
                        isSelected: false,
                        onTap: () {
                          final currentRoute =
                              ModalRoute.of(context)?.settings.name;
                          if (currentRoute != '/activity-log') {
                            Navigator.pushNamed(context, '/activity-log');
                          }
                        },
                      ),
                  ],
                ),
              ),
              // GENERAL section at the bottom
              _buildSectionHeader(theme, 'GENERAL'),
              const SizedBox(height: 8),
              // GENERAL items
              for (int i = 0; i < bottomDestinations.length; i++)
                _buildRailDestinationTile(
                  context: context,
                  theme: theme,
                  destination: bottomDestinations[i],
                  isSelected: false,
                  onTap: () {
                    final dest = bottomDestinations[i];
                    final currentRoute = ModalRoute.of(context)?.settings.name;

                    // Handle logout separately
                    if (dest.route == '/logout') {
                      _handleLogout(context);
                      return;
                    }

                    if (currentRoute != dest.route) {
                      Navigator.pushNamed(context, dest.route);
                    }
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: theme.brightness == Brightness.dark
              ? Colors.grey.shade700
              : Colors.grey.shade200,
        ),
        Expanded(
          child: _buildPurchaseOrderContent(theme),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String label) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: AppFonts.sfProStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildRailDestinationTile({
    required BuildContext context,
    required ThemeData theme,
    required _RailDestination destination,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          // Background with rounded right corners
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    destination.icon,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodyMedium?.color,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      destination.label,
                      style: AppFonts.sfProStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Vertical indicator line on the left
          if (isSelected)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    bottomLeft: Radius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await _showLogoutDialog(context);
    if (shouldLogout == true) {
      final authService = AuthService();
      await authService.logout();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<bool> _showLogoutDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return await showDialog<bool>(
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
                        Icons.logout,
                        color: Colors.red,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Logout',
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
                      'Are you sure you want to logout?',
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
                              'Yes',
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
                              'No',
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
  }
}

class _RailDestination {
  final IconData icon;
  final String label;
  final String route;

  _RailDestination(
      {required this.icon, required this.label, required this.route});
}
