import 'package:flutter/material.dart';
import 'package:projects/shared/themes/font.dart';
import 'package:projects/features/settings/pages/employee_list_page.dart';
import 'package:projects/features/settings/pages/edit_profile_page.dart';
import 'package:projects/features/settings/controller/settings_controller.dart';
import 'package:projects/features/backup_restore/pages/backup_restore_page.dart';
import 'package:projects/shared/providers/user_role_provider.dart';

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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color, size: 28),
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
      body: ListenableBuilder(
        listenable: userRoleProvider,
        builder: (context, child) {
          final isStaff = userRoleProvider.isStaff;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
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

                // User Management Section - Only for Owner and Admin users
                if (!isStaff) ...[
                  _buildSectionHeader("Account Management"),

                  _buildSettingItem(
                    icon: Icons.person_3_outlined,
                    title: "Edit Profile",
                    subtitle: "Update user credentials",
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

                  // System Section - Only for Owner and Admin users
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
                            builder: (_) => const BackupRestorePage()),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 32),

                // Standalone Settings
                Divider(height: 1, thickness: 1, color: theme.dividerColor),
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
                    // TODO: Navigate to app tutorial
                  },
                ),
              ],
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
}
