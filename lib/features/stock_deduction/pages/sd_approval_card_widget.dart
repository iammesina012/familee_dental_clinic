import 'package:flutter/material.dart';
import 'package:familee_dental/shared/themes/font.dart';

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
    final supplies = approval['supplies'] as List<dynamic>? ?? [];
    final patientName = approval['patientName'] ?? '';
    final age = approval['age'] ?? '';
    final sex = approval['sex'] ??
        approval['gender'] ??
        ''; // Use sex first, fallback to gender
    final conditions = approval['conditions'] ?? '';
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
                            presetName,
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

                  // Patient Information Section
                  if (patientName.isNotEmpty ||
                      age.isNotEmpty ||
                      sex.isNotEmpty ||
                      conditions.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 18,
                          color: const Color(0xFF00D4AA),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Patient Information',
                          style: AppFonts.sfProStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey[800]!.withOpacity(0.5)
                            : const Color(0xFF00D4AA).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.grey[700]!.withOpacity(0.3)
                              : const Color(0xFF00D4AA).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Row 1: Patient Name | Sex
                          Row(
                            children: [
                              if (patientName.isNotEmpty)
                                Expanded(
                                  child: _buildModernInfoRow(
                                    Icons.badge_outlined,
                                    'Patient Name',
                                    patientName,
                                    theme,
                                    isDark,
                                  ),
                                ),
                              if (patientName.isNotEmpty && sex.isNotEmpty)
                                const SizedBox(width: 16),
                              if (sex.isNotEmpty)
                                Expanded(
                                  child: _buildModernInfoRow(
                                    Icons.people_outline_rounded,
                                    'Sex',
                                    sex,
                                    theme,
                                    isDark,
                                  ),
                                ),
                            ],
                          ),
                          // Row 2: Age | Conditions
                          if ((age.isNotEmpty || conditions.isNotEmpty) &&
                              (patientName.isNotEmpty || sex.isNotEmpty))
                            const SizedBox(height: 12),
                          Row(
                            children: [
                              if (age.isNotEmpty)
                                Expanded(
                                  child: _buildModernInfoRow(
                                    Icons.calendar_today_outlined,
                                    'Age',
                                    age,
                                    theme,
                                    isDark,
                                  ),
                                ),
                              if (age.isNotEmpty && conditions.isNotEmpty)
                                const SizedBox(width: 16),
                              if (conditions.isNotEmpty)
                                Expanded(
                                  child: _buildModernInfoRow(
                                    Icons.medical_information_outlined,
                                    'Conditions',
                                    conditions,
                                    theme,
                                    isDark,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

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
                                  (supply['name'] ?? 'Unknown Supply') +
                                      (supply['type'] != null &&
                                              supply['type']
                                                  .toString()
                                                  .isNotEmpty
                                          ? '(${supply['type']})'
                                          : ''),
                                  style: AppFonts.sfProStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                // Packaging content/unit only (expiry moved to right side)
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
                          const SizedBox(width: 12),
                          // Expiry and Quantity on the right side
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Expiry text
                              Text(
                                _formatExpiry(supply['expiry'],
                                    supply['noExpiry'] as bool?),
                                style: AppFonts.sfProStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Quantity Badge - Changed to show "x[number]"
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF00D4AA).withOpacity(0.15),
                                      const Color(0xFF00D4AA).withOpacity(0.1),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFF00D4AA)
                                        .withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  'x${quantity.toString()}',
                                  style: AppFonts.sfProStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF00D4AA),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  // Approve/Reject Buttons (only show for pending and if user has permission)
                  if (isPending && canApproveReject) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
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
                                isProcessing ? 'Processing...' : 'Approved',
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
                  ], // Close if (isPending) ...[
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

  // Format expiry date
  String _formatExpiry(dynamic expiry, bool? noExpiry) {
    if (noExpiry == true) return 'No Expiry';
    if (expiry == null || expiry.toString().isEmpty) return 'No Expiry';
    final expiryStr = expiry.toString();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(expiryStr)) {
      return expiryStr.replaceAll('-', '/');
    }
    return expiryStr;
  }

  Widget _buildModernInfoRow(
    IconData icon,
    String label,
    String value,
    ThemeData theme,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF00D4AA),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
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
      ],
    );
  }
}
