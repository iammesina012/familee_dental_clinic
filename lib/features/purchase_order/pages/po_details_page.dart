import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:familee_dental/features/purchase_order/data/purchase_order.dart';
import 'package:familee_dental/features/purchase_order/controller/po_details_controller.dart';
import 'package:familee_dental/features/purchase_order/controller/po_supabase_controller.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/activity_log/controller/po_activity_controller.dart';
import 'package:familee_dental/features/notifications/controller/notifications_controller.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';

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
  final XFile? image;
  _ReceiptDetails(
      {required this.drNumber, required this.recipient, required this.image});
}

class _PODetailsPageState extends State<PODetailsPage> {
  late PurchaseOrder _purchaseOrder;
  final PODetailsController _controller = PODetailsController();
  final POSupabaseController _poSupabase = POSupabaseController();
  bool _isLoading = false;
  final Map<String, int> _supplierPageIndex = {};
  final Set<String> _expandedSuppliers = {};

  @override
  void initState() {
    super.initState();
    try {
      _purchaseOrder = widget.purchaseOrder;

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
    final scheme = theme.colorScheme;
    // Compute per-supplier counts for header
    final Map<String, bool> _supplierAllReceivedHeader = {};
    for (final s in _purchaseOrder.supplies) {
      final supplierName = _controller.getSupplierName(s);
      final isReceived = _controller.isSupplyReceived(s);
      _supplierAllReceivedHeader[supplierName] =
          (_supplierAllReceivedHeader[supplierName] ?? true) && isReceived;
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
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Moved Total Cost Section to top
              Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: theme.brightness == Brightness.dark
                      ? LinearGradient(
                          colors: [
                            Color(0xFF8B5A8B).withOpacity(0.25),
                            Color(0xFF8B5A8B).withOpacity(0.15),
                          ],
                        )
                      : LinearGradient(
                          colors: [
                            Color(0xFF8B5A8B).withOpacity(0.10),
                            Color(0xFF8B5A8B).withOpacity(0.05),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? Color(0xFF8B5A8B).withOpacity(0.45)
                        : Color(0xFF8B5A8B).withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.brightness == Brightness.dark
                          ? Color(0xFF8B5A8B).withOpacity(0.25)
                          : Color(0xFF8B5A8B).withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Cost:',
                      style: AppFonts.sfProStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.brightness == Brightness.dark
                            ? Colors.white
                            : const Color(0xFF8B5A8B),
                      ),
                    ),
                    Text(
                      '₱${_controller.calculateTotalCost(_purchaseOrder).toStringAsFixed(2)}',
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
              ),

              // Supplies List Section
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: theme.dividerColor.withOpacity(0.2)),
                  ),
                  child: _purchaseOrder.supplies.isEmpty
                      ? _buildEmptyState()
                      : Column(
                          children: [
                            // Header (renamed to Supplier)
                            Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0xFF1F1F23)
                                    : scheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.shadowColor.withOpacity(0.08),
                                    blurRadius: 6,
                                    offset: Offset(0, 1),
                                    spreadRadius: 0,
                                  ),
                                ],
                                border: Border.all(
                                  color: theme.dividerColor.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "Suppliers (${_uniqueSuppliersHeader})",
                                        style: AppFonts.sfProStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: theme.brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : theme
                                                  .textTheme.bodyMedium?.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.25),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.1),
                                          blurRadius: 3,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '${_receivedSuppliersHeader}/${_uniqueSuppliersHeader}',
                                      style: AppFonts.sfProStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            theme.brightness == Brightness.dark
                                                ? Colors.white
                                                : theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // List grouped by Supplier with footer buttons rendered as the last item
                            Expanded(
                              child: Builder(builder: (context) {
                                // Group supplies by supplier name
                                final Map<String, List<Map<String, dynamic>>>
                                    bySupplier = {};
                                for (final s in _purchaseOrder.supplies) {
                                  final name = _controller.getSupplierName(s);
                                  bySupplier.putIfAbsent(name, () => []).add(s);
                                }
                                final entries = bySupplier.entries.toList();

                                // counts handled in app bar header; no per-list counts needed here

                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: entries.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == entries.length) {
                                      return Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            0, 8, 0, 16),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            // Approve/Reject buttons - Only for Admin users
                                            if (!UserRoleProvider().isStaff &&
                                                _controller.canRejectPO(
                                                    _purchaseOrder))
                                              Container(
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      LinearGradient(colors: [
                                                    Colors.orange,
                                                    Colors.deepOrange,
                                                  ]),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.orange
                                                          .withOpacity(0.3),
                                                      blurRadius: 6,
                                                      offset: Offset(0, 3),
                                                    ),
                                                  ],
                                                ),
                                                child: ElevatedButton(
                                                  onPressed: _isLoading
                                                      ? null
                                                      : _confirmReject,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    shadowColor:
                                                        Colors.transparent,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 8),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                  ),
                                                  child: _isLoading
                                                      ? SizedBox(
                                                          height: 14,
                                                          width: 14,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                        Color>(
                                                                    Colors
                                                                        .white),
                                                          ),
                                                        )
                                                      : Text(
                                                          'Reject',
                                                          style: AppFonts
                                                              .sfProStyle(
                                                            fontSize: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width *
                                                                0.032,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            if (!UserRoleProvider().isStaff &&
                                                _controller.canApprovePO(
                                                    _purchaseOrder))
                                              const SizedBox(width: 8),
                                            if (!UserRoleProvider().isStaff &&
                                                _controller.canApprovePO(
                                                    _purchaseOrder))
                                              Container(
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      LinearGradient(colors: [
                                                    Color(0xFF00D4AA),
                                                    Color(0xFF00B894),
                                                  ]),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Color(0xFF00D4AA)
                                                          .withOpacity(0.3),
                                                      blurRadius: 6,
                                                      offset: Offset(0, 3),
                                                    ),
                                                  ],
                                                ),
                                                child: ElevatedButton(
                                                  onPressed: (_isLoading ||
                                                          !_controller
                                                              .canApprovePO(
                                                                  _purchaseOrder))
                                                      ? null
                                                      : _approvePurchaseOrder,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    shadowColor:
                                                        Colors.transparent,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 8),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                  ),
                                                  child: _isLoading
                                                      ? SizedBox(
                                                          height: 14,
                                                          width: 14,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                        Color>(
                                                                    Colors
                                                                        .white),
                                                          ),
                                                        )
                                                      : Text(
                                                          'Approve',
                                                          style: AppFonts
                                                              .sfProStyle(
                                                            fontSize: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width *
                                                                0.032,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
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
                                        (item) =>
                                            _controller.isSupplyReceived(item));
                                    final bool hasPending = items.any((item) =>
                                        !_controller.isSupplyReceived(item));
                                    final bool tappable = !_controller
                                            .isPOClosed(_purchaseOrder) &&
                                        hasPending;
                                    final bool isExpanded = _expandedSuppliers
                                        .contains(supplierName);
                                    final pageController =
                                        PageController(initialPage: currentIdx);

                                    return GestureDetector(
                                      onTap: tappable
                                          ? () => _confirmMarkAllReceived(
                                              supplierName, items)
                                          : null,
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 16),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF1F1F23)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: theme.dividerColor
                                                .withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
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
                                                                          .white),
                                                                  const SizedBox(
                                                                      width: 6),
                                                                  Text(
                                                                    allReceived
                                                                        ? 'Received'
                                                                        : 'Pending',
                                                                    style: AppFonts.sfProStyle(
                                                                        fontSize:
                                                                            12,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        color: Colors
                                                                            .white),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(height: 4),
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
                                                  height: 240,
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
                                                          items[i]);
                                                    },
                                                  ),
                                                ),
                                                // Removed top total cost (now only shown below the indicators)
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
                                                            'Recipient: ${supplierRecipient}',
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
                                                                    supplierImagePath!),
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
                                                    color: theme
                                                        .colorScheme.primary
                                                        .withOpacity(0.06),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    border: Border.all(
                                                      color: theme.dividerColor
                                                          .withOpacity(0.2),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Total Cost',
                                                        style:
                                                            AppFonts.sfProStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: theme.textTheme
                                                              .bodySmall?.color
                                                              ?.withOpacity(
                                                                  0.8),
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
                                                          color: theme
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.color,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }),
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
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Color(0xFF00D4AA).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 14,
            color: const Color(0xFF00D4AA),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
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
              SizedBox(height: 1),
              Text(
                value,
                style: AppFonts.sfProStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Build details-only content so the PageView slides only details
  Widget _buildSupplyDetailsOnly(Map<String, dynamic> supply) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Details content mirrors the inner block of _buildSupplyCard
            _buildEnhancedDetailRow('Supply', _controller.getSupplyName(supply),
                Icons.shopping_bag),
            SizedBox(height: 8),
            _buildEnhancedDetailRow('Brand', _controller.getBrandName(supply),
                Icons.branding_watermark),
            SizedBox(height: 8),
            _buildEnhancedDetailRow(
                'Quantity', '${supply['quantity'] ?? 0}', Icons.inventory),
            SizedBox(height: 8),
            _buildEnhancedDetailRow(
                'Subtotal',
                '₱${_controller.calculateSupplySubtotal(supply).toStringAsFixed(2)}',
                Icons.attach_money),
            ...(() {
              final batches = supply['expiryBatches'] as List<dynamic>?;
              if (batches != null && batches.isNotEmpty) {
                return <Widget>[
                  const SizedBox(height: 8),
                  ...batches.map((b) {
                    final String? date = _formatExpiry(b['expiryDate']);
                    final int qty = int.tryParse('${b['quantity'] ?? 0}') ?? 0;
                    if (date == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _buildEnhancedDetailRow(
                          'Expiry Date', '$date  •  Qty: $qty', Icons.event),
                    );
                  }).toList(),
                ];
              }
              final single = _formatExpiry(supply['expiryDate']);
              if (single != null) {
                return <Widget>[
                  const SizedBox(height: 8),
                  _buildEnhancedDetailRow('Expiry Date', single, Icons.event),
                ];
              }
              return <Widget>[];
            })(),
          ],
        ),
      ),
    );
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

  Future<void> _confirmMarkReceived(
      Map<String, dynamic> supply, int index) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Mark as received?',
                style: AppFonts.sfProStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            content: Text('This will mark the selected supply as received.',
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
                child: Text('Mark Received',
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

    setState(() => _isLoading = true);
    try {
      final updatedSupplies =
          List<Map<String, dynamic>>.from(_purchaseOrder.supplies);
      updatedSupplies[index] = {
        ...supply,
        'status': 'Received',
        // keep existing expiryDate as-is
      };

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

      // Log Received activity (quick path)
      await PoActivityController().logPurchaseOrderReceived(
        poCode: updatedPO.code,
        poName: updatedPO.name,
        supplies: [updatedSupplies[index]],
      );

      // Notify if moved to Approval
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
          content: Text('Supply marked as received!',
              style: AppFonts.sfProStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating supply status',
              style: AppFonts.sfProStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
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
            title: Text('Mark All as Received?',
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
          'receiptImagePath': receiptDetails.image?.path,
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
                  maxWidth: MediaQuery.of(context).size.width - 24),
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
                            Text('Delivery Receipt No.',
                                style: AppFonts.sfProStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: drController,
                              decoration: InputDecoration(
                                hintText: 'Enter DR number',
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
                            TextField(
                              controller: recipientController,
                              decoration: InputDecoration(
                                hintText: 'Enter recipient name',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                errorText: recipientError,
                              ),
                              onChanged: (_) =>
                                  setLocal(() => recipientError = null),
                            ),
                            const SizedBox(height: 12),
                            Text('Attach Receipt',
                                style: AppFonts.sfProStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            if (pickedImage == null)
                              ElevatedButton.icon(
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
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('Pick Image'),
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

  void _showAttachmentImage(String path) {
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
                    child: Image.file(File(path), fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
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
