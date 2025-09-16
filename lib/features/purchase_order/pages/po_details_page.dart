import 'package:flutter/material.dart';
import '../data/purchase_order.dart';
import '../controller/po_details_controller.dart';
import '../controller/po_firebase_controller.dart';
import '../../../shared/themes/font.dart';
import 'package:projects/features/activity_log/controller/po_activity_controller.dart';
import 'package:projects/features/notifications/controller/notifications_controller.dart';

class PODetailsPage extends StatefulWidget {
  final PurchaseOrder purchaseOrder;

  const PODetailsPage({Key? key, required this.purchaseOrder})
      : super(key: key);

  @override
  State<PODetailsPage> createState() => _PODetailsPageState();
}

class _PODetailsPageState extends State<PODetailsPage> {
  late PurchaseOrder _purchaseOrder;
  final PODetailsController _controller = PODetailsController();
  final POFirebaseController _poFirebase = POFirebaseController();
  bool _isLoading = false;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
        elevation: 5,
        shadowColor: theme.shadowColor,
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
              // Purchase Name Section (Read-only)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.08),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ],
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.shopping_cart,
                                color: theme.colorScheme.primary,
                                size: MediaQuery.of(context).size.width * 0.05,
                              ),
                            ),
                            SizedBox(width: 12),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.5),
                              child: Text(
                                _purchaseOrder.name,
                                style: AppFonts.sfProStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // Approve button positioned beside the purchase name
                        Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (_controller.canRejectPO(_purchaseOrder))
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.orange,
                                      Colors.deepOrange,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _confirmReject,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          height: 14,
                                          width: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : Text(
                                          'Reject',
                                          style: AppFonts.sfProStyle(
                                            fontSize: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.035,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            if (_controller.canApprovePO(_purchaseOrder))
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF00D4AA),
                                      Color(0xFF00B894),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF00D4AA).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: (_isLoading ||
                                          !_controller
                                              .canApprovePO(_purchaseOrder))
                                      ? null
                                      : _approvePurchaseOrder,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          height: 14,
                                          width: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : Text(
                                          'Approve',
                                          style: AppFonts.sfProStyle(
                                            fontSize: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.035,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 16),

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
                            // Header
                            Container(
                              margin: EdgeInsets.all(16),
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark
                                    ? const Color(0xFF1F1F23)
                                    : scheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.shadowColor.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
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
                                      Container(
                                        padding: EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.inventory_2,
                                          color: theme.colorScheme.primary,
                                          size: 20,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        "Supplies (${_purchaseOrder.supplies.length})",
                                        style: AppFonts.sfProStyle(
                                          fontSize: 18,
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
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: theme.colorScheme.primary
                                            .withOpacity(0.25),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          color: theme.brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : theme.colorScheme.primary,
                                          size: 14,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          '${_purchaseOrder.receivedCount}/${_purchaseOrder.supplies.length}',
                                          style: AppFonts.sfProStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: theme.brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // List
                            Expanded(
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _purchaseOrder.supplies.length,
                                itemBuilder: (context, index) {
                                  final supply = _purchaseOrder.supplies[index];
                                  return _buildSupplyCard(supply, index);
                                },
                              ),
                            ),
                            // Total Cost Section
                            Container(
                              margin: EdgeInsets.all(16),
                              padding: EdgeInsets.all(20),
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
                                borderRadius: BorderRadius.circular(16),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Cost:',
                                    style: AppFonts.sfProStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.white
                                          : const Color(0xFF8B5A8B),
                                    ),
                                  ),
                                  Text(
                                    '₱${_controller.calculateTotalCost(_purchaseOrder).toStringAsFixed(2)}',
                                    style: AppFonts.sfProStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.white
                                          : const Color(0xFF8B5A8B),
                                    ),
                                  ),
                                ],
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

  Widget _buildSupplyCard(Map<String, dynamic> supply, int index) {
    final isReceived = _controller.isSupplyReceived(supply);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1F1F23)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _controller.isPOClosed(_purchaseOrder) || isReceived
            ? null
            : () => _confirmMarkReceived(supply, index),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with supply name and status
              Row(
                children: [
                  // Supply icon
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isReceived
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isReceived ? Icons.inventory_2 : Icons.pending_actions,
                      color: isReceived ? Colors.green : Colors.orange,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),

                  // Supply name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _controller.getSupplyName(supply),
                          style: AppFonts.sfProStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                        SizedBox(height: 4),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isReceived
                                  ? [Colors.green, Colors.green.shade600]
                                  : [Colors.orange, Colors.orange.shade600],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isReceived ? Colors.green : Colors.orange)
                                        .withOpacity(0.3),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isReceived
                                    ? Icons.check_circle
                                    : Icons.schedule,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 6),
                              Text(
                                isReceived ? 'Received' : 'Pending',
                                style: AppFonts.sfProStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // Supply details in a styled container
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1F1F23)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    _buildEnhancedDetailRow(
                        'Brand',
                        _controller.getBrandName(supply),
                        Icons.branding_watermark),
                    SizedBox(height: 12),
                    _buildEnhancedDetailRow('Supplier',
                        _controller.getSupplierName(supply), Icons.business),
                    SizedBox(height: 12),
                    _buildEnhancedDetailRow('Quantity',
                        '${supply['quantity'] ?? 0}', Icons.inventory),
                    SizedBox(height: 12),
                    _buildEnhancedDetailRow(
                        'Subtotal',
                        '₱${_controller.calculateSupplySubtotal(supply).toStringAsFixed(2)}',
                        Icons.attach_money),

                    // Show expiry date(s)
                    ...(() {
                      final batches = supply['expiryBatches'] as List<dynamic>?;
                      if (batches != null && batches.isNotEmpty) {
                        return <Widget>[
                          const SizedBox(height: 12),
                          ...batches.map((b) {
                            final String? date = _formatExpiry(b['expiryDate']);
                            final int qty =
                                int.tryParse('${b['quantity'] ?? 0}') ?? 0;
                            if (date == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _buildEnhancedDetailRow('Expiry Date',
                                  '$date  •  Qty: $qty', Icons.event),
                            );
                          }).toList(),
                        ];
                      }
                      final single = _formatExpiry(supply['expiryDate']);
                      if (single != null) {
                        return <Widget>[
                          const SizedBox(height: 12),
                          _buildEnhancedDetailRow(
                              'Expiry Date', single, Icons.event),
                        ];
                      }
                      return <Widget>[];
                    })(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // _buildDetailRow was unused and removed

  Widget _buildEnhancedDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF00D4AA).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: const Color(0xFF00D4AA),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppFonts.sfProStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withOpacity(0.8),
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: AppFonts.sfProStyle(
                  fontSize: 14,
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

  // Deprecated dialog (not used). Keeping implementation removed to avoid warnings.
  /* void _showReceiveDialog(Map<String, dynamic> supply, int index) {
    DateTime? selectedDate;
    bool noExpiry = false;
    final TextEditingController dateController = TextEditingController();

    // Check if supply is already received and has expiry date
    final isAlreadyReceived = supply['status'] == 'Received';
    final existingExpiryDate = supply['expiryDate'];

    // Initialize values based on existing data
    if (isAlreadyReceived && existingExpiryDate != null) {
      if (existingExpiryDate == 'No expiry') {
        noExpiry = true;
      } else {
        // Parse existing date if it's in YYYY-MM-DD format
        try {
          final parts = existingExpiryDate.split('-');
          if (parts.length == 3) {
            selectedDate = DateTime(
              int.parse(parts[0]), // year
              int.parse(parts[1]), // month
              int.parse(parts[2]), // day
            );
            dateController.text = existingExpiryDate;
          }
        } catch (e) {
          // If parsing fails, just use the string as is
          dateController.text = existingExpiryDate;
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.grey[50]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with icon and title
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isAlreadyReceived
                              ? [Color(0xFF8B5A8B), Color(0xFF7B4A7B)]
                              : [Color(0xFF00D4AA), Color(0xFF00B894)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isAlreadyReceived
                                  ? Icons.edit
                                  : Icons.check_circle_outline,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isAlreadyReceived
                                  ? 'Edit Expiry Date'
                                  : 'Mark as Received',
                              style: AppFonts.sfProStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24),

                    // Supply name and status
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2,
                                color: isAlreadyReceived
                                    ? Color(0xFF8B5A8B)
                                    : Color(0xFF00D4AA),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _controller.getSupplyName(supply),
                                  style: AppFonts.sfProStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (isAlreadyReceived) ...[
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Text(
                                'Currently Received',
                                style: AppFonts.sfProStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // Checkbox for no expiry
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: noExpiry
                                  ? Color(0xFF00D4AA)
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Checkbox(
                              value: noExpiry,
                              onChanged: (value) {
                                setDialogState(() {
                                  noExpiry = value ?? false;
                                  if (noExpiry) {
                                    selectedDate = null;
                                    dateController.clear();
                                  }
                                });
                              },
                              activeColor: Color(0xFF00D4AA),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No expiry date',
                              style: AppFonts.sfProStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (!noExpiry) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.event,
                                  color: Color(0xFF00D4AA),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Expiry Date:',
                                  style: AppFonts.sfProStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            TextField(
                              controller: dateController,
                              readOnly: true,
                              decoration: InputDecoration(
                                hintText: 'Select expiry date',
                                hintStyle: AppFonts.sfProStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Color(0xFF00D4AA), width: 2),
                                ),
                                suffixIcon: Container(
                                  margin: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF00D4AA),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: Icon(Icons.calendar_today,
                                        color: Colors.white, size: 20),
                                    onPressed: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now()
                                            .add(Duration(days: 365 * 10)),
                                      );
                                      if (date != null) {
                                        setDialogState(() {
                                          selectedDate = date;
                                          dateController.text =
                                              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: AppFonts.sfProStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: (noExpiry || selectedDate != null)
                                    ? [Color(0xFF00D4AA), Color(0xFF00B894)]
                                    : [Colors.grey[300]!, Colors.grey[400]!],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: (noExpiry || selectedDate != null)
                                  ? [
                                      BoxShadow(
                                        color:
                                            Color(0xFF00D4AA).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ElevatedButton(
                              onPressed: (noExpiry || selectedDate != null)
                                  ? () => _markAsReceived(
                                      supply, index, selectedDate, noExpiry)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                isAlreadyReceived ? 'Update' : 'Received',
                                style: AppFonts.sfProStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
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
      },
    );
  } */

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

      await _poFirebase.updatePOInFirebase(updatedPO);

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
