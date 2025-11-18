import 'package:flutter/material.dart';
import 'package:familee_dental/shared/themes/font.dart';

String _formatApprovalDateTime(DateTime dateTime) {
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

class ApprovalCard extends StatelessWidget {
  final Map<String, dynamic> approval;
  final int index;
  final bool isExpanded;
  final bool isProcessing;
  final bool canApproveReject;
  final VoidCallback onToggle;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const ApprovalCard({
    super.key,
    required this.approval,
    required this.index,
    required this.isExpanded,
    this.isProcessing = false,
    this.canApproveReject = true,
    required this.onToggle,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final presetName =
        approval['presetName'] ?? approval['name'] ?? 'Unknown Preset';
    final createdAtRaw = approval['created_at'];
    DateTime? createdAt;
    if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw);
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    }
    final displayTitle =
        createdAt != null ? _formatApprovalDateTime(createdAt) : presetName;
    final supplies = approval['supplies'] as List<dynamic>? ?? [];
    final status = approval['status'] ?? 'pending';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPending = status == 'pending';
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: theme.colorScheme.surface,
      elevation: 3,
      shadowColor: theme.shadowColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.grey[700]!.withOpacity(0.3)
              : Colors.grey[300]!.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isDark
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.white,
                    Colors.grey[50]!,
                  ],
                ),
        ),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Preset Name, Date, and Expand Icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4AA).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF00D4AA).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.bookmark_rounded,
                        color: Color(0xFF00D4AA),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayTitle,
                            style: AppFonts.sfProStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Supplies Count Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4AA).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00D4AA).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 16,
                            color: const Color(0xFF00D4AA),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${supplies.length} ${supplies.length == 1 ? 'supply' : 'supplies'}',
                            style: AppFonts.sfProStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF00D4AA),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Badge
                    if (isApproved)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Approved',
                              style: AppFonts.sfProStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (isRejected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cancel_outlined,
                              size: 16,
                              color: Colors.red[700],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Rejected',
                              style: AppFonts.sfProStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Expand/Collapse Icon
                    Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: const Color(0xFF00D4AA),
                      size: 28,
                    ),
                  ],
                ),

                // Expanded Content
                if (isExpanded) ...[
                  const SizedBox(height: 20),

                  // Supplies Section
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                        color: const Color(0xFF00D4AA),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Supplies to be deducted',
                        style: AppFonts.sfProStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...supplies.asMap().entries.map((entry) {
                    final supply = entry.value as Map<String, dynamic>;
                    final quantity = supply['quantity'] ?? 0;
                    final purposeRaw =
                        (supply['purpose']?.toString() ?? '').trim();
                    final purposeLabel =
                        purposeRaw.isEmpty ? 'No Purpose' : purposeRaw;
                    return Container(
                      margin: EdgeInsets.only(
                          bottom: entry.key < supplies.length - 1 ? 10 : 0),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.grey[700]!.withOpacity(0.5)
                              : Colors.grey[300]!.withOpacity(0.8),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Supply Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Image.network(
                                supply['imageUrl'] ?? '',
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 56,
                                  height: 56,
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    color: Colors.grey,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Supply Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supply['type'] != null &&
                                          supply['type']
                                              .toString()
                                              .trim()
                                              .isNotEmpty
                                      ? '${supply['name']?.toString() ?? 'Unknown Supply'} (${supply['type']})'
                                      : supply['name']?.toString() ??
                                          'Unknown Supply',
                                  style: AppFonts.sfProStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      _formatExpiryLabel(
                                        supply['expiry'],
                                        supply['noExpiry'] as bool?,
                                      ),
                                      style: AppFonts.sfProStyle(
                                        fontSize: 12,
                                        color: theme.textTheme.bodySmall?.color
                                            ?.withOpacity(0.7),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00D4AA)
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFF00D4AA)
                                              .withOpacity(0.35),
                                        ),
                                      ),
                                      child: Text(
                                        purposeLabel,
                                        style: AppFonts.sfProStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF00A37A),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00D4AA)
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFF00D4AA)
                                              .withOpacity(0.35),
                                        ),
                                      ),
                                      child: Text(
                                        'x$quantity',
                                        style: AppFonts.sfProStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF00A37A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatPackaging(supply),
                                  style: AppFonts.sfProStyle(
                                    fontSize: 12,
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withOpacity(0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Remarks Section (only show if remarks exist)
                  if (approval['remarks'] != null &&
                      approval['remarks'].toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Remarks:',
                        style: AppFonts.sfProStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        approval['remarks'].toString().trim(),
                        style: AppFonts.sfProStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ],

                  // Bottom section with "Deducted by" and Approve/Reject Buttons
                  if (isPending && canApproveReject) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Deducted by section (left side)
                        if (approval['deducted_by_name'] != null &&
                            approval['deducted_by_name']
                                .toString()
                                .trim()
                                .isNotEmpty)
                          Text(
                            'Deducted by ${approval['deducted_by_name'].toString().trim()}',
                            style: AppFonts.sfProStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodySmall?.color
                                  ?.withOpacity(0.7),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        // Buttons (right side)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Reject Button
                            ElevatedButton(
                              onPressed: isProcessing ? null : onReject,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                disabledBackgroundColor:
                                    Colors.red.withOpacity(0.5),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isProcessing)
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isProcessing ? 'Processing...' : 'Reject',
                                    style: AppFonts.sfProStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Approve Button
                            ElevatedButton(
                              onPressed: isProcessing ? null : onApprove,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                disabledBackgroundColor:
                                    Colors.green.withOpacity(0.5),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isProcessing)
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons.check,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isProcessing ? 'Processing...' : 'Approve',
                                    style: AppFonts.sfProStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  // Show "Deducted by" even if buttons are not shown (for approved/rejected)
                  if (!(isPending && canApproveReject) &&
                      approval['deducted_by_name'] != null &&
                      approval['deducted_by_name']
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Deducted by ${approval['deducted_by_name'].toString().trim()}',
                        style: AppFonts.sfProStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.textTheme.bodySmall?.color
                              ?.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ], // Close if (isExpanded) ...[
              ], // Close Column children list
            ), // Close Column
          ), // Close Padding
        ), // Close InkWell
      ), // Close Container
    ); // Close Card and return statement
  }

  // Format packaging info
  String _formatPackaging(Map<String, dynamic> supply) {
    final packagingContentQuantity = supply['packagingContentQuantity'];
    final packagingContent = supply['packagingContent'];
    final packagingUnit = supply['packagingUnit'];

    if (packagingContent != null &&
        packagingContent.toString().isNotEmpty &&
        packagingUnit != null &&
        packagingUnit.toString().isNotEmpty) {
      // Format: "10mL per Bottle"
      return '${packagingContentQuantity ?? ''} ${packagingContent} per $packagingUnit';
    } else if (packagingUnit != null && packagingUnit.toString().isNotEmpty) {
      // Format: "pieces" (just the unit)
      return packagingUnit.toString();
    }
    return '';
  }

  // Format expiry date to MM/DD/YYYY or show No Expiry
  String _formatExpiryLabel(dynamic expiry, bool? noExpiry) {
    if (noExpiry == true) return 'No Expiry';
    if (expiry == null) return 'No Expiry';
    final raw = expiry.toString().trim();
    if (raw.isEmpty) return 'No Expiry';

    DateTime? parsed;
    final normalized = raw.replaceAll('/', '-');
    parsed = DateTime.tryParse(normalized);

    if (parsed != null) {
      final local = parsed.toLocal();
      final month = local.month.toString().padLeft(2, '0');
      final day = local.day.toString().padLeft(2, '0');
      final year = local.year.toString();
      return '$month/$day/$year';
    }

    return raw;
  }
}
