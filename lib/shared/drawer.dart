import 'package:flutter/material.dart';
import 'package:projects/shared/drawer_logout.dart';
import 'package:projects/features/auth/services/auth_service.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key, this.beforeNavigate});

  final Future<bool> Function()? beforeNavigate;

  @override
  Widget build(BuildContext context) {
    String? currentRoute = ModalRoute.of(context)?.settings.name;

    final theme = Theme.of(context);
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: theme.appBarTheme.backgroundColor),
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
              Navigator.pop(context);
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
              Navigator.pop(context);
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
              Navigator.pop(context);
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
              Navigator.pop(context);
              if (currentRoute != '/stock-deduction') {
                Navigator.pushReplacementNamed(context, '/stock-deduction');
              }
            },
          ),
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
              Navigator.pop(context);
              if (currentRoute != '/activity-log') {
                Navigator.pushReplacementNamed(context, '/activity-log');
              }
            },
          ),
          Spacer(),
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
              Navigator.pop(context);
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
              final shouldLogout = await showLogoutDialog(context);
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
      ),
    );
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
}
