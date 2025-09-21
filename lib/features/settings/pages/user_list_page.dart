import 'package:flutter/material.dart';
import '../controller/user_list_controller.dart';
import 'edit_user_page.dart';
import 'add_user_page.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final UserListController _controller = UserListController();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    final result = await _controller.loadUsers();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _users = result['users'] ?? [];
      });
    }

    if (!result['success'] && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading users: ${result['error']}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          'User List',
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _addUser(),
                    icon: const Icon(Icons.person_add,
                        color: Colors.white, size: 18),
                    label: const Text(
                      'Add User',
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
                    border:
                        Border.all(color: theme.dividerColor.withOpacity(0.2)),
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
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _users.isEmpty
                          ? Center(
                              child: Text(
                                'No users found',
                                style: TextStyle(
                                  fontFamily: 'SF Pro',
                                  fontSize: 16,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _users.length,
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                return _buildUserCard(user, theme);
                              },
                            ),
                ),
              ),
            ],
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
                        color: (user['role'] == 'Admin')
                            ? const Color(0xFF00D4AA).withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user['role'] ?? 'Staff',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: (user['role'] == 'Admin')
                              ? const Color(0xFF00D4AA)
                              : Colors.blue,
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
            tooltip: 'Edit User',
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

  void _showDuplicateUsers() async {
    final duplicates = await _controller.getDuplicateUsers();

    if (duplicates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No duplicate users found'),
          backgroundColor: Color(0xFF00D4AA),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Users Found'),
        content: Text(
            'Found ${duplicates.length} duplicate users. Check Firebase Console to delete them manually.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
