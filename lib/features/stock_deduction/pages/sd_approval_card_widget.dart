import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:familee_dental/shared/themes/font.dart';

class ApprovalCard extends StatelessWidget {
  final Map<String, dynamic> approval;
  final int index;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const ApprovalCard({
    super.key,
    required this.approval,
    required this.index,
    required this.isExpanded,
    required this.onToggle,
    required this.onDelete,
    required this.onApprove,
    required this.onReject,
  });

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

  @override
  Widget build(BuildContext context) {
    final presetName =
        approval['presetName'] ?? approval['name'] ?? 'Unknown Preset';
    final supplies = approval['supplies'] as List<dynamic>? ?? [];
    final patientName = approval['patientName'] ?? '';
    final age = approval['age'] ?? '';
    final gender = approval['gender'] ?? '';
    final conditions = approval['conditions'] ?? '';
    final status = approval['status'] ?? 'pending';
    final createdAt = approval['created_at'] != null
        ? DateTime.tryParse(approval['created_at'].toString())
        : null;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPending = status == 'pending';
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';

    return Slidable(
      key: ValueKey('approval-${approval['id'] ?? index}'),
      closeOnScroll: true,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Remove',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: Card(
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
                            if (createdAt != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(createdAt),
                                style: AppFonts.sfProStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withOpacity(0.6),
                                ),
                              ),
                            ],
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
                        gender.isNotEmpty ||
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
                            if (patientName.isNotEmpty)
                              _buildModernInfoRow(
                                Icons.badge_outlined,
                                'Patient Name',
                                patientName,
                                theme,
                                isDark,
                              ),
                            if (patientName.isNotEmpty &&
                                (age.isNotEmpty || gender.isNotEmpty))
                              const SizedBox(height: 12),
                            if (age.isNotEmpty || gender.isNotEmpty)
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
                                  if (age.isNotEmpty && gender.isNotEmpty)
                                    const SizedBox(width: 16),
                                  if (gender.isNotEmpty)
                                    Expanded(
                                      child: _buildModernInfoRow(
                                        Icons.people_outline_rounded,
                                        'Gender',
                                        gender,
                                        theme,
                                        isDark,
                                      ),
                                    ),
                                ],
                              ),
                            if ((age.isNotEmpty || gender.isNotEmpty) &&
                                conditions.isNotEmpty)
                              const SizedBox(height: 12),
                            if (conditions.isNotEmpty)
                              _buildModernInfoRow(
                                Icons.medical_information_outlined,
                                'Conditions',
                                conditions,
                                theme,
                                isDark,
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
                          'Supplies',
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
                                    supply['name'] ?? 'Unknown Supply',
                                    style: AppFonts.sfProStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: theme.textTheme.bodyMedium?.color,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (supply['brand'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      supply['brand'],
                                      style: AppFonts.sfProStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: theme.textTheme.bodySmall?.color
                                            ?.withOpacity(0.7),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Quantity Badge - Changed to show "Quantity: [number]"
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
                                  color:
                                      const Color(0xFF00D4AA).withOpacity(0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'Quantity: ${quantity.toString()}',
                                style: AppFonts.sfProStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF00D4AA),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    // Approve/Reject Buttons (only show for pending)
                    if (isPending) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Reject Button
                          ElevatedButton(
                            onPressed: onReject,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
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
                                Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Reject',
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
                            onPressed: onApprove,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
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
                                Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Approved',
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
                  ],
                ], // Close Column children list
              ), // Close Column
            ), // Close Padding
          ), // Close InkWell
        ), // Close Container
      ), // Close Card
    ); // Close Slidable and return statement
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
