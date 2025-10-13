import 'package:flutter/material.dart';
import 'package:familee_dental/features/auth/services/auth_service.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key, this.beforeNavigate, this.isPersistent = false});

  final Future<bool> Function()? beforeNavigate;
  final bool isPersistent;

  @override
  Widget build(BuildContext context) {
    String? currentRoute = ModalRoute.of(context)?.settings.name;
    final theme = Theme.of(context);
    final userRoleProvider = UserRoleProvider();

    Widget drawerContent = ListenableBuilder(
      listenable: userRoleProvider,
      builder: (context, child) {
        final canAccessActivityLog = userRoleProvider.canAccessActivityLog();

        return Column(
          children: [
            DrawerHeader(
              decoration:
                  BoxDecoration(color: theme.appBarTheme.backgroundColor),
              child: Center(
                child: Image.asset(
                  'assets/images/logo/tita_doc.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            _buildDrawerItem(
              icon: Icons.dashboard,
              text: 'Dashboard',
              fontFamily: 'SF Pro',
              selected: currentRoute == '/dashboard',
              context: context,
              onTap: () async {
                if (beforeNavigate != null) {
                  final ok = await beforeNavigate!();
                  if (!ok) return;
                }
                // Only pop if not persistent (i.e., if it's a modal drawer)
                if (!isPersistent) {
                  Navigator.pop(context);
                }
                if (currentRoute != '/dashboard') {
                  Navigator.pushReplacementNamed(context, '/dashboard');
                }
              },
            ),
            _buildDrawerItem(
              icon: Icons.inventory,
              text: 'Inventory',
              fontFamily: 'SF Pro',
              selected: currentRoute == '/inventory',
              context: context,
              onTap: () async {
                if (beforeNavigate != null) {
                  final ok = await beforeNavigate!();
                  if (!ok) return;
                }
                // Only pop if not persistent (i.e., if it's a modal drawer)
                if (!isPersistent) {
                  Navigator.pop(context);
                }
                if (currentRoute != '/inventory') {
                  Navigator.pushReplacementNamed(context, '/inventory');
                }
              },
            ),
            _buildDrawerItem(
              icon: Icons.shopping_cart,
              text: 'Purchase Order',
              fontFamily: 'SF Pro',
              selected: currentRoute == '/purchase-order',
              context: context,
              onTap: () async {
                if (beforeNavigate != null) {
                  final ok = await beforeNavigate!();
                  if (!ok) return;
                }
                // Only pop if not persistent (i.e., if it's a modal drawer)
                if (!isPersistent) {
                  Navigator.pop(context);
                }
                if (currentRoute != '/purchase-order') {
                  Navigator.pushReplacementNamed(context, '/purchase-order');
                }
              },
            ),
            _buildDrawerItem(
              icon: Icons.playlist_remove,
              text: 'Stock Deduction',
              fontFamily: 'SF Pro',
              selected: currentRoute == '/stock-deduction',
              context: context,
              onTap: () async {
                if (beforeNavigate != null) {
                  final ok = await beforeNavigate!();
                  if (!ok) return;
                }
                // Only pop if not persistent (i.e., if it's a modal drawer)
                if (!isPersistent) {
                  Navigator.pop(context);
                }
                if (currentRoute != '/stock-deduction') {
                  Navigator.pushReplacementNamed(context, '/stock-deduction');
                }
              },
            ),
            // Activity Log - Only show for Admin users
            if (canAccessActivityLog)
              _buildDrawerItem(
                icon: Icons.history,
                text: 'Activity Log',
                fontFamily: 'SF Pro',
                selected: currentRoute == '/activity-log',
                context: context,
                onTap: () async {
                  if (beforeNavigate != null) {
                    final ok = await beforeNavigate!();
                    if (!ok) return;
                  }
                  // Only pop if not persistent (i.e., if it's a modal drawer)
                  if (!isPersistent) {
                    Navigator.pop(context);
                  }
                  if (currentRoute != '/activity-log') {
                    Navigator.pushReplacementNamed(context, '/activity-log');
                  }
                },
              ),
            Spacer(),
            // Settings - Available for both Admin and Staff users
            _buildDrawerItem(
              icon: Icons.settings,
              text: 'Settings',
              fontFamily: 'SF Pro',
              selected: currentRoute == '/settings',
              context: context,
              onTap: () async {
                if (beforeNavigate != null) {
                  final ok = await beforeNavigate!();
                  if (!ok) return;
                }
                // Only pop if not persistent (i.e., if it's a modal drawer)
                if (!isPersistent) {
                  Navigator.pop(context);
                }
                if (currentRoute != '/settings') {
                  // Use push so user can return to the previous page
                  Navigator.pushNamed(context, '/settings');
                }
              },
            ),
            _buildDrawerItem(
              icon: Icons.logout,
              text: 'Logout',
              fontFamily: 'SF Pro',
              selected: false,
              context: context,
              onTap: () async {
                final shouldLogout = await _showLogoutDialog(context);
                if (shouldLogout == true) {
                  final authService = AuthService();
                  await authService.logout();
                  // ignore: use_build_context_synchronously
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
            SizedBox(height: 24),
          ],
        );
      },
    );

    // Determine the appropriate drawer background color based on the theme's brightness
    final drawerBackgroundColor = theme.brightness == Brightness.light
        ? Colors.white
        : theme.scaffoldBackgroundColor;

    // Return either a Drawer (for modal) or the content directly (for persistent)
    if (isPersistent) {
      return Container(
        color: drawerBackgroundColor,
        child: drawerContent,
      );
    } else {
      return Drawer(
        backgroundColor: drawerBackgroundColor,
        child: drawerContent,
      );
    }
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    required String fontFamily,
    required bool selected,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(icon, color: theme.iconTheme.color, size: 20),
      title: Text(
        text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: theme.textTheme.bodyMedium?.color,
        ),
      ),
      selected: selected,
      selectedTileColor: theme.brightness == Brightness.dark
          ? Colors.white10
          : Colors.grey[200],
      onTap: onTap,
    );
  }

  Future<bool?> _showLogoutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildLogoutDialog(context),
    );
  }

  Widget _buildLogoutDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      backgroundColor: theme.dialogBackgroundColor,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: theme.dialogBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon and Title
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout,
                color: Colors.red,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            // Title
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

            // Content
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

            // Buttons
            Row(
              children: [
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
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
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
  }
}
