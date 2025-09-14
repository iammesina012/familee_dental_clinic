import 'package:flutter/material.dart';
import 'package:projects/shared/themes/font.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9EFF2),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
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
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        toolbarHeight: 70,
        iconTheme: const IconThemeData(size: 30, color: Colors.black),
        elevation: 5,
        shadowColor: Colors.black54,
      ),
      body: SingleChildScrollView(
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
                },
                activeColor: const Color(0xFF00D4AA),
              ),
            ),
            _buildNotificationCard(),

            const SizedBox(height: 24),

            // Employee Management Section
            _buildSectionHeader("Employee Management"),
            _buildSettingItem(
              icon: Icons.people_outline,
              title: "Employee List",
              subtitle: "Manage employees and roles",
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
              onTap: () {
                // TODO: Navigate to employee list
              },
            ),

            const SizedBox(height: 24),

            // System Section
            _buildSectionHeader("System"),
            _buildSettingItem(
              icon: Icons.backup_outlined,
              title: "Backup & Restore",
              subtitle: "Manage data backup and restore",
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
              onTap: () {
                // TODO: Navigate to backup & restore
              },
            ),

            const SizedBox(height: 32),

            // Standalone Settings
            _buildSettingItem(
              icon: Icons.help_outline,
              title: "App Tutorial",
              subtitle: "Learn how to use the app",
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
              onTap: () {
                // TODO: Navigate to app tutorial
              },
            ),
            _buildSettingItem(
              icon: Icons.support_agent,
              title: "Contact Support",
              subtitle: "Get help and support",
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
              onTap: () {
                // TODO: Navigate to contact support
              },
            ),
            _buildSettingItem(
              icon: Icons.info_outline,
              title: "About",
              subtitle: "App version and information",
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
              onTap: () {
                // TODO: Navigate to about page
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Text(
        title,
        style: AppFonts.sfProStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildNotificationCard() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            leading: const Icon(
              Icons.notifications_outlined,
              color: Colors.black,
              size: 24,
            ),
            title: Text(
              "Notification",
              style: AppFonts.sfProStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
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
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
                Switch(
                  value: _inventoryAlerts,
                  onChanged: (value) {
                    setState(() {
                      _inventoryAlerts = value;
                    });
                  },
                  activeColor: const Color(0xFF00D4AA),
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
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
                Switch(
                  value: _approvalAlerts,
                  onChanged: (value) {
                    setState(() {
                      _approvalAlerts = value;
                    });
                  },
                  activeColor: const Color(0xFF00D4AA),
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
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
          color: Colors.black,
          size: 24,
        ),
        title: title.isNotEmpty
            ? Text(
                title,
                style: AppFonts.sfProStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              )
            : null,
        subtitle: Text(
          subtitle,
          style: AppFonts.sfProStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.grey[600],
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
