import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:projects/shared/drawer.dart';
import 'package:projects/shared/themes/font.dart';
import 'package:projects/features/purchase_order/controller/po_list_controller.dart';
import 'package:projects/features/purchase_order/data/purchase_order.dart';
import 'dart:async'; // Added for StreamSubscription
import 'package:projects/features/activity_log/controller/po_activity_controller.dart';

class PurchaseOrderPage extends StatefulWidget {
  const PurchaseOrderPage({super.key});

  @override
  State<PurchaseOrderPage> createState() => _PurchaseOrderPageState();
}

class _PurchaseOrderPageState extends State<PurchaseOrderPage> {
  final POListController _controller = POListController();
  List<PurchaseOrder> _orders = [];
  List<PurchaseOrder> _closedOrders =
      []; // Separate list for closed POs from Firebase
  List<PurchaseOrder> _approvalOrders = []; // Separate list for approval POs
  List<PurchaseOrder> _openOrders = []; // Separate list for open POs
  int activeTabIndex = 0;
  final TextEditingController searchController = TextEditingController();

  // Stream subscriptions for proper disposal
  StreamSubscription<List<PurchaseOrder>>? _openSubscription;
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
  bool _loadedApproval = false;
  bool _loadedClosed = false;

  Future<void> _load() async {
    try {
      // Load from local storage as backup (kept for potential future use)
      await _controller.getAllPOs();

      // Check current sequence
      await _controller.getCurrentSequence();

      // Load ALL POs from Firebase (real-time)
      _loadAllPOsFromFirebase();
    } catch (e) {
      // Don't show error UI in async operations to avoid context issues
      // The error is logged for debugging purposes
    }
  }

  void _loadAllPOsFromFirebase() {
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

  // Add listener for search functionality
  @override
  void initState() {
    super.initState();
    try {
      _load();
      searchController.addListener(() {
        setState(() {
          // This will trigger rebuild when search text changes
        });
      });
    } catch (e) {
      // Error handling
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
    _approvalSubscription?.cancel();
    _closedSubscription?.cancel();
    _allSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text("Purchase Order",
              style: AppFonts.sfProStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.appBarTheme.titleTextStyle?.color ??
                    theme.textTheme.titleLarge?.color,
              )),
          centerTitle: true,
          backgroundColor: theme.appBarTheme.backgroundColor,
          toolbarHeight: 70,
          iconTheme: theme.appBarTheme.iconTheme,
          elevation: theme.appBarTheme.elevation ?? 5,
          shadowColor: theme.appBarTheme.shadowColor ?? theme.shadowColor,
          actions: [
            // Clear all POs button (for testing)
            IconButton(
              icon: const Icon(Icons.clear_all, color: Colors.red, size: 24),
              tooltip: 'Clear All POs (Testing)',
              onPressed: () => _showClearAllDialog(),
            ),
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
        drawer: const MyDrawer(),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Section
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                    border:
                        Border.all(color: theme.dividerColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem(
                          "Open", "${_getSummaryCounts()['Open']}"),
                      _buildSummaryItem(
                          "Approval", "${_getSummaryCounts()['Approval']}"),
                      _buildSummaryItem(
                          "Closed", "${_getSummaryCounts()['Closed']}"),
                    ],
                  ),
                ),
                SizedBox(height: 16),

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
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.6),
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
                    SizedBox(width: 12),
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
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Main Content Area
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.surface
                          : const Color(0xFFE8D5E8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: theme.dividerColor.withOpacity(0.2)),
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
                              SizedBox(width: 12),
                              _buildTab("Approval", activeTabIndex == 1, () {
                                setState(() {
                                  activeTabIndex = 1;
                                });
                              }),
                              SizedBox(width: 12),
                              _buildTab("Closed", activeTabIndex == 2, () {
                                setState(() {
                                  activeTabIndex = 2;
                                });
                              }),
                            ],
                          ),
                        ),

                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _load,
                            child: StreamBuilder<List<PurchaseOrder>>(
                              stream: activeTabIndex == 0
                                  ? _controller.getOpenPOsStream()
                                  : activeTabIndex == 1
                                      ? _controller.getApprovalPOsStream()
                                      : _controller.getClosedPOsStream(),
                              builder: (context, snapshot) {
                                final data =
                                    snapshot.data ?? const <PurchaseOrder>[];
                                final displayed = _applySearchFilter(data);
                                if (snapshot.connectionState ==
                                        ConnectionState.waiting &&
                                    data.isEmpty) {
                                  return Center(
                                      child: CircularProgressIndicator());
                                }
                                if (displayed.isEmpty) {
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            color: theme.brightness ==
                                                    Brightness.dark
                                                ? theme.colorScheme.surface
                                                : scheme.surface
                                                    .withOpacity(0.6),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: theme.brightness ==
                                                      Brightness.dark
                                                  ? theme.dividerColor
                                                      .withOpacity(0.2)
                                                  : theme.dividerColor
                                                      .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.shopping_cart_outlined,
                                            size: 60,
                                            color: theme.brightness ==
                                                    Brightness.dark
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
                                            color: theme.brightness ==
                                                    Brightness.dark
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
                                  itemCount: displayed.length,
                                  separatorBuilder: (_, __) =>
                                      SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final po = displayed[index];
                                    // Auto-open specific PO details if requested
                                    if (_openPOCode != null &&
                                        !_autoOpeningDetails &&
                                        po.code == _openPOCode) {
                                      // Delay navigation until after first frame
                                      _autoOpeningDetails = true;
                                      // capture intent (not used further, just ensures we clear before rebuilds)
                                      _openPOCode =
                                          null; // prevent repeats during rebuilds
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) async {
                                        final result =
                                            await Navigator.pushNamed(
                                          context,
                                          '/po-details',
                                          arguments: {'purchaseOrder': po},
                                        );
                                        // Keep current tab; react to closed redirect if needed
                                        if (result is Map &&
                                            result['switchToClosed'] == true) {
                                          setState(() {
                                            activeTabIndex = 2;
                                          });
                                        }
                                        // Release guard after navigation completes
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
          ),
        ),
      );
    } catch (e) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            "Purchase Order",
            style:
                AppFonts.sfProStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Error loading Purchase Order page',
                style: AppFonts.sfProStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Error: $e',
                style: AppFonts.sfProStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
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
    if (!(_loadedOpen && _loadedApproval && _loadedClosed)) {
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
    return {
      'Open': _openOrders.length,
      'Approval': _approvalOrders.length,
      'Closed': _closedOrders.length,
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
            if (result is Map && result['switchToClosed'] == true) {
              setState(() {
                activeTabIndex = 2; // Closed tab
              });
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

    // Only add slidable functionality for "Open" POs
    if (po.status == 'Open') {
      return Slidable(
        key: Key('slidable-${po.id}'),
        closeOnScroll: true,
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.35,
          children: [
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
            SlidableAction(
              onPressed: (_) async {
                final confirmed = await _showDeleteConfirmation(po);
                if (confirmed) {
                  // PO will be deleted in the confirmation dialog
                }
              },
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
              borderRadius: BorderRadius.circular(12),
            ),
          ],
        ),
        child: cardContent,
      );
    }

    // Return regular card for non-Open POs
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

  Future<bool> _showDeleteConfirmation(PurchaseOrder po) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                'Delete Purchase Order?',
                style: AppFonts.sfProStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Are you sure you want to delete "${po.name}"? This action cannot be undone.',
                style: AppFonts.sfProStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text(
                    'Cancel',
                    style: AppFonts.sfProStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      // Capture PO for logging before deletion
                      final capturedPO = po;
                      // Delete the PO
                      await _controller.deletePO(po.id);
                      Navigator.of(context).pop(true);

                      // Show success message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Purchase Order deleted successfully!',
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
                        // Log activity for removal
                        await PoActivityController().logPurchaseOrderRemoved(
                          poCode: capturedPO.code,
                          poName: capturedPO.name,
                          supplies: capturedPO.supplies,
                        );
                      }
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
                  ),
                  child: Text(
                    'Delete',
                    style: AppFonts.sfProStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Clear All Purchase Orders',
            style: AppFonts.sfProStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'This will permanently delete all purchase orders. This action cannot be undone.',
            style: AppFonts.sfProStyle(
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: AppFonts.sfProStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _controller.clearAllPOs();

                  // Clear local lists immediately
                  setState(() {
                    _openOrders.clear();
                    _approvalOrders.clear();
                    _closedOrders.clear();
                    _orders.clear();
                  });

                  // Reload to ensure everything is in sync
                  await _load();
                } catch (e) {
                  // Error handling - don't use ScaffoldMessenger to avoid context issues
                }
              },
              child: Text(
                'Clear All',
                style: AppFonts.sfProStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
