import 'package:flutter/material.dart';
import 'package:projects/features/settings/controller/user_list_controller.dart';
import 'package:projects/features/settings/pages/change_password_page.dart';

class ChooseAccountPage extends StatefulWidget {
  const ChooseAccountPage({super.key});

  @override
  State<ChooseAccountPage> createState() => _ChooseAccountPageState();
}

class _ChooseAccountPageState extends State<ChooseAccountPage> {
  final _controller = UserListController();
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
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _users = (result['users'] as List<Map<String, dynamic>>?) ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color, size: 28),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Choose Account',
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
          padding: const EdgeInsets.all(16),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
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
                  child: _users.isEmpty
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
                      : ListView.separated(
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            return Container(
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark
                                    ? theme.colorScheme.surface
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: (theme.brightness == Brightness.dark
                                            ? Colors.black
                                            : Colors.black)
                                        .withOpacity(0.04),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                leading: CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      const Color(0xFF00D4AA).withOpacity(0.1),
                                  child: Text(
                                    (user['name'] ?? user['email'] ?? 'U')
                                        .toString()
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontFamily: 'SF Pro',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF00D4AA),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  user['name'] ?? 'Unknown User',
                                  style: const TextStyle(
                                    fontFamily: 'SF Pro',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: Text(
                                  user['email'] ?? '',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro',
                                    fontSize: 13,
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withOpacity(0.7),
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios,
                                    size: 16),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ChangePasswordPage(user: user),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemCount: _users.length,
                        ),
                ),
        ),
      ),
    );
  }
}
