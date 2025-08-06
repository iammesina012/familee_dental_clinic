import 'package:flutter/material.dart';
import 'package:projects/shared/drawer_logout.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    String? currentRoute = ModalRoute.of(context)?.settings.name;

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.white),
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
            onTap: () {
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
            onTap: () {
              Navigator.pop(context);
              if (currentRoute != '/inventory') {
                Navigator.pushReplacementNamed(context, '/inventory');
              }
            },
          ),
          _buildDrawerItem(
            icon: Icons.history,
            text: 'Activity Log',
            fontFamily: 'SF Pro',
            selected: currentRoute == '/activity-log',
            onTap: () {
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
            onTap: () {
              Navigator.pop(context);
              if (currentRoute != '/settings') {
                Navigator.pushReplacementNamed(context, '/settings');
              }
            },
          ),
          _buildDrawerItem(
            icon: Icons.logout,
            text: 'Logout',
            fontFamily: 'SF Pro',
            selected: false,
            onTap: () async {
              final shouldLogout = await showLogoutDialog(context);
              if (shouldLogout == true) {
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
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: Colors.black, size: 20),
      title: Text(
        text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
      selected: selected,
      selectedTileColor: Colors.grey[200],
      onTap: onTap,
    );
  }
}
