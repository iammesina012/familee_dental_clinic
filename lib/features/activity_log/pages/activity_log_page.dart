import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:familee_dental/shared/drawer.dart';
import 'package:familee_dental/features/activity_log/controller/activity_log_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/widgets/notification_badge_button.dart';
import 'package:shimmer/shimmer.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/features/auth/services/auth_service.dart';
import 'package:familee_dental/shared/themes/font.dart';

class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  final TextEditingController _searchController = TextEditingController();
  final ActivityLogController _controller = ActivityLogController();
  // Removed unused per-category controllers from UI page
  int _currentPage = 1;
  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _controller.updateSearchQuery(_searchController.text);
    });
    _controller.addListener(_resetPageOnDataChange);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.removeListener(_resetPageOnDataChange);
    _controller.dispose();
    super.dispose();
  }

  // Format description delegated to controller (UI-only page)
  String _formatDescription(String description) {
    return _controller.formatListDescription(description);
  }

  // Get icon for each category
  Icon _getCategoryIcon(String category) {
    switch (category) {
      case 'Stock Deduction':
        return const Icon(Icons.remove_circle_outline,
            color: Colors.red, size: 20);
      case 'Purchase Order':
        return const Icon(Icons.shopping_cart_outlined,
            color: Colors.blue, size: 20);
      case 'Inventory':
        return const Icon(Icons.inventory_2_outlined,
            color: Colors.green, size: 20);
      case 'Login':
        return const Icon(Icons.login, color: Colors.orange, size: 20);
      case 'Dashboard':
        return const Icon(Icons.dashboard_outlined,
            color: Colors.purple, size: 20);
      case 'Settings':
        return const Icon(Icons.settings, color: Colors.teal, size: 20);
      default:
        return const Icon(Icons.info_outline, color: Colors.grey, size: 20);
    }
  }

  void _resetPageOnDataChange() {
    if (!mounted) return;
    setState(() {
      _currentPage = 1;
    });
  }

  Widget _buildPagination(int totalPages) {
    if (totalPages <= 1) return const SizedBox.shrink();

    const int window = 5; // sliding window size
    int startPage = _currentPage - (window ~/ 2);
    if (startPage < 1) startPage = 1;
    int endPage = startPage + window - 1;
    if (endPage > totalPages) {
      endPage = totalPages;
      startPage = (endPage - window + 1);
      if (startPage < 1) startPage = 1;
    }

    final List<Widget> buttons = [];

    // Previous
    buttons.add(IconButton(
      icon: Icon(Icons.chevron_left,
          color: Theme.of(context).textTheme.bodyLarge?.color, size: 24),
      onPressed: _currentPage > 1
          ? () => setState(() => _currentPage = _currentPage - 1)
          : null,
      tooltip: 'Previous',
    ));

    for (int i = startPage; i <= endPage; i++) {
      final bool selected = _currentPage == i;
      buttons.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: InkWell(
          onTap: () => setState(() => _currentPage = i),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 40,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).primaryColor.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.3)),
            ),
            child: Text(
              i.toString(),
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ),
      ));
    }

    // Next
    buttons.add(IconButton(
      icon: Icon(Icons.chevron_right,
          color: Theme.of(context).textTheme.bodyLarge?.color, size: 24),
      onPressed: _currentPage < totalPages
          ? () => setState(() => _currentPage = _currentPage + 1)
          : null,
      tooltip: 'Next',
    ));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Page ' + _currentPage.toString() + ' of ' + totalPages.toString(),
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: buttons,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(
      BuildContext parentContext, String activityId, String description) {
    showDialog(
      context: parentContext,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 400,
              minWidth: 350,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    size: 40,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Delete Activity',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  'Are you sure you want to delete this activity?',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Activity Preview Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '"$description"',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Delete Button
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextButton(
                          onPressed: () async {
                            // Close the dialog first
                            Navigator.of(context).pop();

                            // Delete the activity
                            await _controller.deleteActivity(activityId);

                            // Show snackbar using the parent context (main page context)
                            if (mounted) {
                              // Use the parent context that was passed to this method
                              ScaffoldMessenger.of(parentContext).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Activity deleted successfully',
                                    style: TextStyle(fontFamily: 'SF Pro'),
                                  ),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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
  }

  // Show activity details dialog
  void _showActivityDetails(
      BuildContext context, Map<String, dynamic> activity) {
    final metadata = activity['metadata'] as Map<String, dynamic>? ?? {};
    final userName = activity['userName'] as String? ?? 'Unknown User';
    final date = activity['date'] as DateTime? ?? DateTime.now();
    final time = activity['time'] as String? ?? '';
    final category = activity['category'] as String? ?? '';
    final description = activity['description'] as String? ?? '';
    final action = activity['action'] as String? ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Theme.of(context).dialogBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600, // Make it wider
              minWidth: 500,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Row(
                    children: [
                      _getCategoryIcon(category),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Activity Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'SF Pro',
                            color:
                                Theme.of(context).textTheme.titleLarge?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Basic Info Section
                          _buildDetailSection(
                            'Basic Information',
                            [
                              _buildDetailRow('Category', category),
                              // Description row: for preset_edited show Old → New only if name actually changed
                              if (action == 'preset_edited')
                                Builder(builder: (_) {
                                  final String oldName =
                                      (metadata['originalPresetName'] ?? '')
                                          .toString();
                                  final String newName =
                                      (metadata['presetName'] ?? '').toString();
                                  final String desc =
                                      _controller.formatPresetEditedDescription(
                                          oldName, newName);
                                  return _buildDetailRow('Description', desc);
                                })
                              else
                                _buildDetailRow('Description', description),
                              // PO Name diff for Edited PO (exclude preset_edited)
                              if (action == 'purchase_order_edited' &&
                                  action != 'preset_edited' &&
                                  metadata['fieldChanges']
                                      is Map<String, dynamic> &&
                                  (metadata['fieldChanges']
                                          as Map<String, dynamic>)
                                      .containsKey('Name'))
                                Builder(builder: (_) {
                                  final change = (metadata['fieldChanges']
                                          as Map<String, dynamic>)['Name']
                                      as Map<String, dynamic>;
                                  final prev =
                                      (change['previous'] ?? '').toString();
                                  final curr = (change['new'] ?? '').toString();
                                  return _buildDetailRow(
                                      'PO Name', '$prev → $curr');
                                }),
                              // Show Fields Modified ONLY for edited Category/Brand/Supplier
                              if (metadata.containsKey('fieldChanges') &&
                                  metadata['fieldChanges']
                                      is Map<String, dynamic> &&
                                  (action == 'category_updated' ||
                                      action == 'brand_updated' ||
                                      action == 'supplier_updated'))
                                _buildFieldChangesRow(metadata['fieldChanges']
                                    as Map<String, dynamic>),
                              _buildDetailRow('User', userName),
                              _buildDetailRow('Date',
                                  _controller.formatDateForDisplay(date)),
                              _buildDetailRow('Time', time),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Metadata Section (if available)
                          // Do NOT show for edited Category/Brand/Supplier (they only show Fields Modified in Basic Info)
                          if (metadata.isNotEmpty &&
                              !(metadata.keys.length == 1 &&
                                  metadata.containsKey('fieldChanges')) &&
                              action != 'category_updated' &&
                              action != 'brand_updated' &&
                              action != 'supplier_updated') ...[
                            _buildDetailSection(
                              'Additional Details',
                              _buildControllerMetadataRows(metadata,
                                  action: action, category: category),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Close Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                          fontFamily: 'SF Pro',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Build detail section with title
  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontFamily: 'SF Pro',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  // Build individual detail row
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width:
                130, // Increased from 100 to 130 to fit "Supplier Name:" on one line
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontFamily: 'SF Pro',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontFamily: 'SF Pro',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build field changes row with before/after values
  Widget _buildFieldChangesRow(Map<String, dynamic> fieldChanges) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              'Fields Modified:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontFamily: 'SF Pro',
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: fieldChanges.entries.map((entry) {
                final changes = entry.value as Map<String, dynamic>;
                final previous = changes['previous']?.toString() ?? 'N/A';
                final newValue = changes['new']?.toString() ?? 'N/A';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '$previous → $newValue',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                      fontFamily: 'SF Pro',
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Build rows using controller-provided data (UI-only)
  List<Widget> _buildControllerMetadataRows(Map<String, dynamic> metadata,
      {String? action, String? category}) {
    final pairs = _controller.computeMetadataRows(metadata,
        action: action, category: category);
    final List<Widget> rows = [];
    for (final p in pairs) {
      if (p['label'] == '__DIVIDER__') {
        rows.add(const Divider(height: 16));
      } else {
        rows.add(_buildDetailRow(p['label'] ?? '', p['value'] ?? ''));
      }
    }
    return rows;
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: MediaQuery.of(context).size.width >= 900
            ? false
            : true, // Remove back button on desktop
        title: Text(
          "Activity Log",
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'SF Pro',
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
      drawer:
          MediaQuery.of(context).size.width >= 900 ? null : const MyDrawer(),
      body: MediaQuery.of(context).size.width >= 900
          ? _buildWithNavigationRail()
          : ResponsiveContainer(
              maxWidth: 1200,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal:
                      MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
                  vertical: 12.0,
                ),
                child: Column(
                  children: [
                    // Search and Filter Bar
                    Row(
                      children: [
                        // Search Bar
                        Expanded(
                          flex: 3,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withOpacity(0.2)),
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                suffixIcon: Icon(Icons.search,
                                    color: Theme.of(context).iconTheme.color),
                                hintStyle: TextStyle(
                                    fontFamily: 'SF Pro',
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withOpacity(0.6)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Category Filter
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withOpacity(0.2)),
                            ),
                            child: ListenableBuilder(
                              listenable: _controller,
                              builder: (context, child) {
                                return DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _controller.selectedCategory,
                                    isExpanded: true,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    items: [
                                      'All Categories',
                                      'Login',
                                      'Inventory',
                                      'Purchase Order',
                                      'Stock Deduction',
                                      'Settings'
                                    ].map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(
                                          value,
                                          style: TextStyle(
                                              fontSize:
                                                  value == 'All Categories'
                                                      ? 13
                                                      : 15,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color,
                                              fontWeight: FontWeight.w500,
                                              fontFamily: 'SF Pro'),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        _controller
                                            .updateSelectedCategory(newValue);
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Recent Activity Section
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).colorScheme.surface
                              : const Color(0xFFE8D5E8),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .shadowColor
                                  .withOpacity(0.08),
                              spreadRadius: 1,
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                              color: Theme.of(context)
                                  .dividerColor
                                  .withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title and Date Picker
                            Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Recent Activity',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color,
                                      fontFamily: 'SF Pro',
                                    ),
                                  ),
                                  ListenableBuilder(
                                    listenable: _controller,
                                    builder: (context, child) {
                                      return Container(
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Theme.of(context)
                                                  .dividerColor
                                                  .withOpacity(0.2)),
                                        ),
                                        child: InkWell(
                                          onTap: () async {
                                            final DateTime? picked =
                                                await showDatePicker(
                                              context: context,
                                              initialDate:
                                                  _controller.selectedDate,
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime.now(),
                                            );
                                            if (picked != null) {
                                              _controller
                                                  .updateSelectedDate(picked);
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.calendar_today,
                                                  size: 16,
                                                  color: Theme.of(context)
                                                      .iconTheme
                                                      .color,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _controller
                                                      .formatDateForDisplay(
                                                          _controller
                                                              .selectedDate),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.color,
                                                    fontWeight: FontWeight.w500,
                                                    fontFamily: 'SF Pro',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            // Activity List
                            Expanded(
                              child: ListenableBuilder(
                                listenable: _controller,
                                builder: (context, child) {
                                  // Show skeleton loader during initial load
                                  if (_controller.isLoading) {
                                    return _buildSkeletonLoader(context);
                                  }

                                  final filteredActivities =
                                      _controller.filteredActivities;

                                  if (filteredActivities.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 120,
                                            height: 120,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                  color: Theme.of(context)
                                                      .dividerColor
                                                      .withOpacity(0.2)),
                                            ),
                                            child: Icon(
                                              Icons.history_outlined,
                                              size: 60,
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors.white
                                                  : const Color(0xFF8B5A8B),
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          Text(
                                            'No Activities Yet',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors.white
                                                  : const Color(0xFF8B5A8B),
                                              fontFamily: 'SF Pro',
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Activities will appear here once you perform actions',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors.white
                                                      .withOpacity(0.7)
                                                  : const Color(0xFF8B5A8B)
                                                      .withOpacity(0.7),
                                              fontFamily: 'SF Pro',
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  // Pagination calculations
                                  final int totalItems =
                                      filteredActivities.length;
                                  final int totalPages =
                                      (totalItems / _itemsPerPage)
                                          .ceil()
                                          .clamp(1, 1000000);
                                  final int startIndex =
                                      (_currentPage - 1) * _itemsPerPage;
                                  final int endIndex =
                                      (startIndex + _itemsPerPage) > totalItems
                                          ? totalItems
                                          : (startIndex + _itemsPerPage);
                                  final pageItems = filteredActivities.sublist(
                                      startIndex, endIndex);

                                  return Column(
                                    children: [
                                      Expanded(
                                        child: RefreshIndicator(
                                          onRefresh: () async {
                                            await _controller
                                                .refreshActivities();
                                          },
                                          child: ListView.builder(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 10),
                                            itemCount: pageItems.length + 1,
                                            itemBuilder: (context, index) {
                                              if (index == pageItems.length) {
                                                return _buildPagination(
                                                    totalPages);
                                              }
                                              final activity = pageItems[index];
                                              // Date formatting handled in details when needed

                                              return Slidable(
                                                endActionPane: ActionPane(
                                                  motion: const ScrollMotion(),
                                                  children: [
                                                    SlidableAction(
                                                      onPressed: (_) =>
                                                          _showDeleteConfirmation(
                                                        context,
                                                        activity['id'],
                                                        _formatDescription(
                                                            activity[
                                                                'description']),
                                                      ),
                                                      backgroundColor:
                                                          Colors.red,
                                                      foregroundColor:
                                                          Colors.white,
                                                      icon: Icons.delete,
                                                      label: 'Delete',
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                        topRight:
                                                            Radius.circular(8),
                                                        bottomRight:
                                                            Radius.circular(8),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: InkWell(
                                                  onTap: () =>
                                                      _showActivityDetails(
                                                          context, activity),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            bottom: 12),
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16),
                                                    height:
                                                        80, // Back to original height
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .surface,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                          color:
                                                              Theme.of(context)
                                                                  .dividerColor
                                                                  .withOpacity(
                                                                      0.2)),
                                                    ),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        // Category icon
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  right: 8,
                                                                  top: 2),
                                                          child: _getCategoryIcon(
                                                              activity[
                                                                  'category']),
                                                        ),
                                                        // Activity description (main text) - more concise and readable
                                                        Expanded(
                                                          child: Text(
                                                            _formatDescription(
                                                                activity[
                                                                    'description']),
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodyMedium
                                                                  ?.color,
                                                              fontFamily:
                                                                  'SF Pro',
                                                            ),
                                                          ),
                                                        ),
                                                        // Time aligned to the right, same level as description
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(top: 2),
                                                          child: Text(
                                                            activity['time'],
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodyMedium
                                                                  ?.color,
                                                              fontFamily:
                                                                  'SF Pro',
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
                                      ),
                                    ],
                                  );
                                },
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

  Widget _buildWithNavigationRail() {
    final theme = Theme.of(context);
    final userRoleProvider = UserRoleProvider();
    final canAccessActivityLog = userRoleProvider.canAccessActivityLog();

    return Row(
      children: [
        NavigationRail(
          minWidth: 150,
          selectedIndex: canAccessActivityLog
              ? 4
              : 0, // Activity Logs is at index 4 if accessible
          labelType: NavigationRailLabelType.all,
          useIndicator: true,
          backgroundColor: theme.scaffoldBackgroundColor,
          selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
          selectedLabelTextStyle: AppFonts.sfProStyle(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
          unselectedLabelTextStyle: AppFonts.sfProStyle(
            fontWeight: FontWeight.w500,
            color: theme.textTheme.bodyMedium?.color,
          ),
          leading: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                const SizedBox(height: 8),
                Text(
                  'FamiLee Dental',
                  style: AppFonts.sfProStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: theme.textTheme.titleMedium?.color,
                  ),
                ),
              ],
            ),
          ),
          destinations: [
            const NavigationRailDestination(
              icon: Icon(Icons.dashboard),
              label: Text('Dashboard'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.inventory),
              label: Text('Inventory'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.shopping_cart),
              label: Text('Purchase Order'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.playlist_remove),
              label: Text('Stock Deduction'),
            ),
            if (canAccessActivityLog)
              const NavigationRailDestination(
                icon: Icon(Icons.history),
                label: Text('Activity Logs'),
              ),
            const NavigationRailDestination(
              icon: Icon(Icons.settings),
              label: Text('Settings'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.logout),
              label: Text('Logout'),
            ),
          ],
          onDestinationSelected: (index) async {
            if (index == 0) {
              Navigator.pushNamed(context, '/dashboard');
            } else if (index == 1) {
              Navigator.pushNamed(context, '/inventory');
            } else if (index == 2) {
              Navigator.pushNamed(context, '/purchase-order');
            } else if (index == 3) {
              Navigator.pushNamed(context, '/stock-deduction');
            } else if (canAccessActivityLog && index == 4) {
              // Already on Activity Logs
            } else if (index == (canAccessActivityLog ? 5 : 4)) {
              Navigator.pushNamed(context, '/settings');
            } else if (index == (canAccessActivityLog ? 6 : 5)) {
              await _handleLogout();
            }
          },
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: ResponsiveContainer(
            maxWidth: 1200,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal:
                    MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
                vertical: 12.0,
              ),
              child: _buildActivityLogContent(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityLogContent() {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Search and Filter Bar
        Row(
          children: [
            // Search Bar
            Expanded(
              flex: 3,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: theme.dividerColor.withOpacity(0.2)),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    suffixIcon:
                        Icon(Icons.search, color: theme.iconTheme.color),
                    hintStyle: TextStyle(
                      fontFamily: 'SF Pro',
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Category Filter
            Expanded(
              flex: 2,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: theme.dividerColor.withOpacity(0.2)),
                ),
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, child) {
                    return DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _controller.selectedCategory,
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        items: [
                          'All Categories',
                          'Login',
                          'Inventory',
                          'Purchase Order',
                          'Stock Deduction',
                          'Settings'
                        ].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: value == 'All Categories' ? 13 : 15,
                                color: theme.textTheme.bodyMedium?.color,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'SF Pro',
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            _controller.updateSelectedCategory(newValue);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Activity Log List
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? theme.colorScheme.surface
                  : const Color(0xFFE8D5E8),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.08),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Date Picker
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyMedium?.color,
                          fontFamily: 'SF Pro',
                        ),
                      ),
                      ListenableBuilder(
                        listenable: _controller,
                        builder: (context, child) {
                          return Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: theme.dividerColor.withOpacity(0.2)),
                            ),
                            child: InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: _controller.selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  _controller.updateSelectedDate(picked);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: theme.iconTheme.color,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _controller.formatDateForDisplay(
                                          _controller.selectedDate),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'SF Pro',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Activity List
                Expanded(
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, child) {
                      if (_controller.isLoading) {
                        return _buildSkeletonLoader(context);
                      }

                      final filteredActivities = _controller.filteredActivities;

                      if (filteredActivities.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.history,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'No activity logs found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontFamily: 'SF Pro',
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Pagination
                      final totalItems = filteredActivities.length;
                      final totalPages =
                          (totalItems / _itemsPerPage).ceil().clamp(1, 1000000);
                      final startIndex = (_currentPage - 1) * _itemsPerPage;
                      final endIndex = (startIndex + _itemsPerPage) > totalItems
                          ? totalItems
                          : (startIndex + _itemsPerPage);
                      final pageItems =
                          filteredActivities.sublist(startIndex, endIndex);

                      return Column(
                        children: [
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: () async {
                                await _controller.refreshActivities();
                              },
                              child: ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: pageItems.length,
                                itemBuilder: (context, index) {
                                  final activity = pageItems[index];
                                  return Slidable(
                                    endActionPane: ActionPane(
                                      motion: const ScrollMotion(),
                                      children: [
                                        SlidableAction(
                                          onPressed: (_) =>
                                              _showDeleteConfirmation(
                                            context,
                                            activity['id'],
                                            _formatDescription(
                                                activity['description']),
                                          ),
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                          icon: Icons.delete,
                                          label: 'Delete',
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(8),
                                            bottomRight: Radius.circular(8),
                                          ),
                                        ),
                                      ],
                                    ),
                                    child: InkWell(
                                      onTap: () => _showActivityDetails(
                                          context, activity),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(16),
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: theme.dividerColor
                                                  .withOpacity(0.2)),
                                        ),
                                        child: Row(
                                          children: [
                                            _getCategoryIcon(
                                                activity['category']),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    _formatDescription(activity[
                                                        'description']),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: theme.textTheme
                                                          .bodyLarge?.color,
                                                      fontFamily: 'SF Pro',
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.person_outline,
                                                        size: 14,
                                                        color: theme.textTheme
                                                            .bodyMedium?.color
                                                            ?.withOpacity(0.7),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Expanded(
                                                        child: Text(
                                                          activity[
                                                                  'userName'] ??
                                                              activity[
                                                                  'user_email'] ??
                                                              'Unknown User',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: theme
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.color
                                                                ?.withOpacity(
                                                                    0.7),
                                                            fontFamily:
                                                                'SF Pro',
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              activity['time'] ?? '',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: theme.brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black,
                                                fontFamily: 'SF Pro',
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
                          ),
                          if (totalPages > 1) _buildPagination(totalPages),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleLogout() async {
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
