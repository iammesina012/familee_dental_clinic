import 'package:flutter/material.dart';
import 'package:familee_dental/features/settings/controller/employee_list_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'edit_user_page.dart';
import 'add_user_page.dart';
import 'package:shimmer/shimmer.dart';

class EmployeeListPage extends StatefulWidget {
  const EmployeeListPage({super.key});

  @override
  State<EmployeeListPage> createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage> {
  final EmployeeListController _controller = EmployeeListController();
  List<Map<String, dynamic>> _users = [];
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final result = await _controller.loadUsers();

    if (mounted) {
      // Get current user ID to filter out admin from the list
      final currentUser = Supabase.instance.client.auth.currentUser;
      final currentUserId = currentUser?.id;

      // Filter users based on current user's role hierarchy
      List<Map<String, dynamic>> allUsers = result['users'] ?? [];
      final userRoleProvider = UserRoleProvider();
      List<Map<String, dynamic>> filteredUsers = allUsers.where((user) {
        // Always exclude current user
        if (user['uid'] == currentUserId) return false;

        final userRole = user['role'] ?? 'Staff';

        // Owner can see all users (Admin and Staff)
        if (userRoleProvider.isOwner) {
          return true;
        }
        // Admin can only see Staff users
        else if (userRoleProvider.isAdmin) {
          return userRole == 'Staff';
        }
        // Staff cannot see any users (should not have access to this page)
        return false;
      }).toList();

      setState(() {
        _isFirstLoad = false;
        _users = filteredUsers;
      });
    }

    if (!result['success'] && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading users: ${result['error']}')),
      );
    }
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            height: 90,
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
    final userRoleProvider = UserRoleProvider();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color, size: 28),
          onPressed: () {
            Navigator.maybePop(context);
          },
        ),
        title: const Text(
          'Employee List',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'SF Pro',
            color: null,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: theme.appBarTheme.elevation,
        shadowColor: theme.appBarTheme.shadowColor,
      ),
      body: ResponsiveContainer(
        maxWidth: 1100,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Only show Add Employee button if user can manage users
                if (userRoleProvider.canManageUsers()) ...[
                  Row(
                    children: [
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _addUser(),
                        icon: const Icon(Icons.person_add,
                            color: Colors.white, size: 18),
                        label: const Text(
                          'Add Employee',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D4AA),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 1,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.surface
                          : const Color(0xFFE8D5E8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: theme.dividerColor.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: (theme.brightness == Brightness.dark
                                  ? Colors.black
                                  : Colors.black)
                              .withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isFirstLoad
                        ? _buildSkeletonLoader(context)
                        : _users.isEmpty
                            ? RefreshIndicator(
                                onRefresh: _loadUsers,
                                child: SingleChildScrollView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  child: SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.5,
                                    child: Center(
                                      child: Text(
                                        'No employees found',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro',
                                          fontSize: 16,
                                          color:
                                              theme.textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadUsers,
                                child: ListView.builder(
                                  itemCount: _users.length,
                                  itemBuilder: (context, index) {
                                    final user = _users[index];
                                    return _buildUserCard(user, theme);
                                  },
                                ),
                              ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surface
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: (theme.brightness == Brightness.dark
                    ? Colors.black
                    : Colors.black)
                .withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // User Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF00D4AA).withOpacity(0.1),
            child: Text(
              (user['name'] ?? user['displayName'] ?? user['email'] ?? 'U')[0]
                  .toUpperCase(),
              style: const TextStyle(
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF00D4AA),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] ?? user['displayName'] ?? 'Unknown User',
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user['email'] ?? '',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Role Chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getRoleColor(user['role'] ?? 'Staff')
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user['role'] ?? 'Staff',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getRoleColor(user['role'] ?? 'Staff'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (user['isActive'] == true)
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (user['isActive'] == true) ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: (user['isActive'] == true)
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Action Button
          IconButton(
            onPressed: () => _editUser(user),
            icon: const Icon(
              Icons.edit,
              color: Color(0xFF00D4AA),
              size: 24,
            ),
            tooltip: 'Edit Employee',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
          ),
        ],
      ),
    );
  }

  void _editUser(Map<String, dynamic> user) async {
    print(
        'Editing user: ${user['name']} (${user['email']}) - UID: ${user['uid']}');

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditUserPage(user: user),
      ),
    );

    // Refresh the user list if changes were made
    if (result == true) {
      _loadUsers();
    }
  }

  void _addUser() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddUserPage(),
      ),
    );

    // Refresh the user list if a new user was created
    if (result == true) {
      _loadUsers();
    }
  }

  /// Get color for role chip
  Color _getRoleColor(String role) {
    switch (role) {
      case 'Owner':
        return const Color(0xFFFF6B35); // Orange for Owner
      case 'Admin':
        return const Color(0xFF00D4AA); // Teal for Admin
      case 'Staff':
        return Colors.blue; // Blue for Staff
      default:
        return Colors.grey; // Grey for unknown roles
    }
  }
}
