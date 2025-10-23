import 'package:flutter/material.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/settings/pages/employee_list_page.dart';
import 'package:familee_dental/features/settings/pages/edit_profile_page.dart';
import 'package:familee_dental/features/settings/controller/settings_controller.dart';
import 'package:familee_dental/features/backup_restore/pages/backup_restore_page.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/features/auth/services/auth_service.dart';
import 'package:familee_dental/shared/drawer.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Settings state
  bool _darkMode = false;
  bool _inventoryAlerts = true;
  bool _approvalAlerts = true;
  final SettingsController _settingsController = SettingsController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isDark = await _settingsController.getDarkMode();
    final inv = await _settingsController.getInventoryAlertsEnabled();
    final appr = await _settingsController.getApprovalAlertsEnabled();
    if (mounted) {
      setState(() {
        _darkMode = isDark;
        _inventoryAlerts = inv;
        _approvalAlerts = appr;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final userRoleProvider = UserRoleProvider();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: MediaQuery.of(context).size.width >= 900
            ? false
            : true, // Remove back button on desktop
        leading: MediaQuery.of(context).size.width >= 900
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back,
                    color: theme.iconTheme.color, size: 28),
                onPressed: () {
                  Navigator.maybePop(context);
                },
              ),
        title: const Text(
          "Settings",
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
      drawer:
          MediaQuery.of(context).size.width >= 900 ? null : const MyDrawer(),
      body: MediaQuery.of(context).size.width >= 900
          ? _buildWithNavigationRail(theme, scheme, userRoleProvider)
          : ListenableBuilder(
              listenable: userRoleProvider,
              builder: (context, child) {
                final isStaff = userRoleProvider.isStaff;
                final isOwner = userRoleProvider.isOwner;

                return ResponsiveContainer(
                  maxWidth: 1100,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
                      vertical: 12.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // General Section
                        _buildSectionHeader("General"),
                        _buildSettingItem(
                          icon: Icons.palette_outlined,
                          title: "Appearance",
                          subtitle: "Dark Mode",
                          trailing: Switch(
                            value: _darkMode,
                            onChanged: (value) {
                              setState(() {
                                _darkMode = value;
                              });
                              _settingsController.setDarkMode(value);
                              AppTheme.themeMode.value =
                                  value ? ThemeMode.dark : ThemeMode.light;
                            },
                            activeColor: scheme.primary,
                          ),
                        ),
                        _buildNotificationCard(),

                        const SizedBox(height: 24),

                        // Personal Account Section - Available for all users
                        _buildSectionHeader("Personal Account"),

                        _buildSettingItem(
                          icon: Icons.person_3_outlined,
                          title: "Edit Profile",
                          subtitle: "Update your personal details",
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: null,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const EditProfilePage(user: null),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // User Management Section - Only for Owner and Admin users
                        if (!isStaff) ...[
                          _buildSectionHeader("User Management"),

                          _buildSettingItem(
                            icon: Icons.people_outline,
                            title: "Employee List",
                            subtitle: "Manage employees and roles",
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: null,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const EmployeeListPage()),
                              );
                            },
                          ),

                          // Change Password (sub-item)

                          const SizedBox(height: 24),

                          // System Section - Only for Owner users
                          if (isOwner) ...[
                            _buildSectionHeader("System"),
                            _buildSettingItem(
                              icon: Icons.backup_outlined,
                              title: "Backup & Restore",
                              subtitle: "Manage data backup and restore",
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: null,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const BackupRestorePage()),
                                );
                              },
                            ),
                          ],
                        ],

                        const SizedBox(height: 32),

                        // Standalone Settings
                        Divider(
                            height: 1, thickness: 1, color: theme.dividerColor),
                        const SizedBox(height: 20),
                        _buildSettingItem(
                          icon: Icons.help_outline,
                          title: "App Tutorial",
                          subtitle: "Learn how to use the app",
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: null,
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, '/tutorial');
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Text(
        title,
        style: AppFonts.sfProStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: theme.textTheme.bodyMedium?.color,
        ),
      ),
    );
  }

  Widget _buildNotificationCard() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
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
      child: Column(
        children: [
          // Notification header only
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            leading: Icon(
              Icons.notifications_outlined,
              color: theme.iconTheme.color,
              size: 24,
            ),
            title: Text(
              "Notification",
              style: AppFonts.sfProStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
          // Inventory Alerts row
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 4, 32, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Inventory Alerts",
                  style: AppFonts.sfProStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                Switch(
                  value: _inventoryAlerts,
                  onChanged: (value) {
                    setState(() {
                      _inventoryAlerts = value;
                    });
                    _settingsController.setInventoryAlertsEnabled(value);
                  },
                  activeColor: scheme.primary,
                ),
              ],
            ),
          ),
          // Approval Alerts row
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Approval Alerts",
                  style: AppFonts.sfProStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                Switch(
                  value: _approvalAlerts,
                  onChanged: (value) {
                    setState(() {
                      _approvalAlerts = value;
                    });
                    _settingsController.setApprovalAlertsEnabled(value);
                  },
                  activeColor: scheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
    bool isSubItem = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
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
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSubItem ? 32 : 16,
          vertical: 8,
        ),
        leading: Icon(
          icon,
          color: theme.iconTheme.color,
          size: 24,
        ),
        title: title.isNotEmpty
            ? Text(
                title,
                style: AppFonts.sfProStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              )
            : null,
        subtitle: Text(
          subtitle,
          style: AppFonts.sfProStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _buildWithNavigationRail(
      ThemeData theme, ColorScheme scheme, UserRoleProvider userRoleProvider) {
    final canAccessActivityLog = userRoleProvider.canAccessActivityLog();

    return Row(
      children: [
        NavigationRail(
          minWidth: 150,
          selectedIndex: canAccessActivityLog ? 5 : 4, // Settings
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
              Navigator.pushNamed(context, '/activity-log');
            } else if (index == (canAccessActivityLog ? 5 : 4)) {
              // Already on Settings
            } else if (index == (canAccessActivityLog ? 6 : 5)) {
              await _handleLogout();
            }
          },
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: ListenableBuilder(
            listenable: userRoleProvider,
            builder: (context, child) {
              final isStaff = userRoleProvider.isStaff;
              final isOwner = userRoleProvider.isOwner;

              return ResponsiveContainer(
                maxWidth: 1100,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // General Section
                      _buildSectionHeader("General"),
                      _buildSettingItem(
                        icon: Icons.palette_outlined,
                        title: "Appearance",
                        subtitle: "Dark Mode",
                        trailing: Switch(
                          value: _darkMode,
                          onChanged: (value) {
                            setState(() {
                              _darkMode = value;
                            });
                            _settingsController.setDarkMode(value);
                            AppTheme.themeMode.value =
                                value ? ThemeMode.dark : ThemeMode.light;
                          },
                          activeColor: scheme.primary,
                        ),
                      ),
                      _buildNotificationCard(),

                      const SizedBox(height: 24),

                      // Personal Account Section - Available for all users
                      _buildSectionHeader("Personal Account"),

                      _buildSettingItem(
                        icon: Icons.person_3_outlined,
                        title: "Edit Profile",
                        subtitle: "Update your personal details",
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: null,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EditProfilePage(user: null),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // User Management Section - Only for Owner and Admin users
                      if (!isStaff) ...[
                        _buildSectionHeader("User Management"),
                        _buildSettingItem(
                          icon: Icons.people_outline,
                          title: "Employee List",
                          subtitle: "Manage employees and roles",
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: null,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const EmployeeListPage(),
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Data Management Section - Only for Owner
                      if (isOwner) ...[
                        _buildSectionHeader("Data Management"),
                        _buildSettingItem(
                          icon: Icons.backup_outlined,
                          title: "Backup & Restore",
                          subtitle: "Backup and restore your data",
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: null,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BackupRestorePage(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 32),

                        // Standalone Settings
                        Divider(
                            height: 1, thickness: 1, color: theme.dividerColor),
                        const SizedBox(height: 20),
                        _buildSettingItem(
                          icon: Icons.help_outline,
                          title: "App Tutorial",
                          subtitle: "Learn how to use the app",
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: null,
                          ),
                          onTap: () {
                            Navigator.pushNamed(context, '/tutorial');
                          },
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
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
