import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:familee_dental/features/activity_log/controller/activity_log_controller.dart';
import 'package:familee_dental/shared/widgets/notification_badge_button.dart';
import 'package:shimmer/shimmer.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/features/auth/services/auth_service.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  static const int _itemsPerPage = 5;
  String? _userName;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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

  Future<void> _loadUserData() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        // Try to get name and role from user_roles table
        final response = await Supabase.instance.client
            .from('user_roles')
            .select('*')
            .eq('id', currentUser.id)
            .maybeSingle();

        if (response != null) {
          setState(() {
            _userName = response['name']?.toString().trim();
            _userRole = response['role']?.toString().trim();
          });
        }

        // Fallback to metadata or email if not found
        if (_userName == null || _userName!.isEmpty) {
          final displayName =
              currentUser.userMetadata?['display_name']?.toString().trim();
          final emailName = currentUser.email?.split('@')[0].trim();
          setState(() {
            _userName = displayName ?? emailName ?? 'User';
          });
        }

        if (_userRole == null || _userRole!.isEmpty) {
          setState(() {
            _userRole =
                currentUser.userMetadata?['role']?.toString().trim() ?? 'Admin';
          });
        }
      }
    } catch (e) {
      // If error occurs, use fallback
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final emailName = currentUser.email?.split('@')[0].trim();
        setState(() {
          _userName = emailName ?? 'User';
          _userRole = 'Admin';
        });
      }
    }
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
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: () => setState(() => _currentPage = i),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 36,
            height: 32,
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
                fontSize: 13,
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Page ' + _currentPage.toString() + ' of ' + totalPages.toString(),
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 6),
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
            height: 83,
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
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF3A3A3A)
          : const Color(0xFFF5F5F5),
      body: MediaQuery.of(context).size.width >= 900
          ? _buildWithNavigationRail()
          : RefreshIndicator(
              onRefresh: () async {
                await _controller.refreshActivities();
              },
              child: _buildActivityLogContent(),
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
              //rossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Greeting message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Activity Log",
                        style: AppFonts.sfProStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Track and monitor all system activities and user actions.",
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

  Widget _buildWithNavigationRail() {
    final theme = Theme.of(context);
    final userRoleProvider = UserRoleProvider();
    final canAccessActivityLog = userRoleProvider.canAccessActivityLog();

    // Define navigation destinations
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

    final List<_RailDestination> bottomDestinations = [
      _RailDestination(
          icon: Icons.settings, label: 'Settings', route: '/settings'),
      _RailDestination(icon: Icons.logout, label: 'Logout', route: '/logout'),
    ];

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
                        isSelected: false,
                        onTap: () {
                          Navigator.pushNamed(
                              context, mainDestinations[i].route);
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
                        isSelected: true,
                        onTap: () {
                          // Already on Activity Logs
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
                  onTap: () async {
                    final dest = bottomDestinations[i];
                    // Handle logout separately
                    if (dest.route == '/logout') {
                      await _handleLogout();
                      return;
                    }
                    Navigator.pushNamed(context, dest.route);
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
          child: RefreshIndicator(
            onRefresh: () async {
              await _controller.refreshActivities();
            },
            child: _buildActivityLogContent(),
          ),
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

  Widget _buildActivityLogContent() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome Panel (with notification and account)
          _buildWelcomePanel(theme),
          const SizedBox(height: 8),
          // Search, Category, Date
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isNarrow = constraints.maxWidth < 900;
              final double spacing = isNarrow ? 8 : 12;
              final children = <Widget>[
                Expanded(
                  flex: 5,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: theme.dividerColor.withOpacity(0.2)),
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
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: spacing),
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: theme.dividerColor.withOpacity(0.2)),
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
                                    fontSize:
                                        value == 'All Categories' ? 13 : 15,
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
                SizedBox(width: spacing),
                SizedBox(
                  width: 180,
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, child) {
                      return Container(
                        height: 48,
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
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today,
                                    size: 16, color: theme.iconTheme.color),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _controller
                                        .formatDateForDisplay(
                                            _controller.selectedDate)
                                        .toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.textTheme.bodyMedium?.color,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'SF Pro',
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
              ];

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    children[0],
                    SizedBox(height: spacing),
                    children[2],
                    SizedBox(height: spacing),
                    children[4],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              );
            },
          ),
          const SizedBox(height: 12),
          // Activity Log List
          Flexible(
            fit: FlexFit.loose,
            child: Container(
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? theme.colorScheme.surface
                    : const Color(0xFFE8D5E8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Activity List
                  Expanded(
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, child) {
                        if (_controller.isLoading) {
                          return _buildSkeletonLoader(context);
                        }

                        final filteredActivities =
                            _controller.filteredActivities;

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
                        final totalPages = (totalItems / _itemsPerPage)
                            .ceil()
                            .clamp(1, 1000000);
                        final startIndex = (_currentPage - 1) * _itemsPerPage;
                        final endIndex =
                            (startIndex + _itemsPerPage) > totalItems
                                ? totalItems
                                : (startIndex + _itemsPerPage);
                        final pageItems =
                            filteredActivities.sublist(startIndex, endIndex);

                        return ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context)
                              .copyWith(scrollbars: false),
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverPadding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 1, 12, 8),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final activity = pageItems[index];
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: Slidable(
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
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  topRight: Radius.circular(8),
                                                  bottomRight:
                                                      Radius.circular(8),
                                                ),
                                              ),
                                            ],
                                          ),
                                          child: InkWell(
                                            onTap: () => _showActivityDetails(
                                                context, activity),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              height: 90,
                                              decoration: BoxDecoration(
                                                color:
                                                    theme.colorScheme.surface,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: theme.dividerColor
                                                      .withOpacity(0.2),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  _getCategoryIcon(
                                                      activity['category']),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          _formatDescription(
                                                              activity[
                                                                  'description']),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: theme
                                                                .textTheme
                                                                .bodyLarge
                                                                ?.color,
                                                            fontFamily:
                                                                'SF Pro',
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .person_outline,
                                                              size: 14,
                                                              color: theme
                                                                  .textTheme
                                                                  .bodyMedium
                                                                  ?.color
                                                                  ?.withOpacity(
                                                                      0.7),
                                                            ),
                                                            const SizedBox(
                                                                width: 4),
                                                            Expanded(
                                                              child: Text(
                                                                activity[
                                                                        'userName'] ??
                                                                    activity[
                                                                        'user_email'] ??
                                                                    'Unknown User',
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style:
                                                                    TextStyle(
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
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                        ),
                                      );
                                    },
                                    childCount: pageItems.length,
                                  ),
                                ),
                              ),
                              if (totalPages > 1)
                                SliverToBoxAdapter(
                                  child: _buildPagination(totalPages),
                                ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 6),
                              ),
                            ],
                          ),
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

class _RailDestination {
  final IconData icon;
  final String label;
  final String route;

  _RailDestination(
      {required this.icon, required this.label, required this.route});
}
