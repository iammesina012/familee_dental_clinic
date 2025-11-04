import 'package:flutter/material.dart';
import 'package:familee_dental/shared/drawer.dart';
import 'package:familee_dental/features/dashboard/services/inventory_analytics_service.dart';
import 'package:familee_dental/features/dashboard/services/fast_moving_service.dart';
import 'package:familee_dental/features/inventory/pages/expired_supply_page.dart';
import 'package:familee_dental/shared/widgets/notification_badge_button.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/features/auth/services/auth_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:platform/platform.dart';
import 'dart:io';
import 'dart:async';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final List<Map<String, dynamic>> dashboardCards = [
    {"title": "Low Stock", "color": Colors.yellow[400]},
    {"title": "Out of Stock", "color": Colors.red[400]},
    {"title": "Expiring", "color": Colors.orange[400]},
  ];

  final InventoryAnalyticsService _analyticsService =
      InventoryAnalyticsService();
  final FastMovingService _fastMovingService = FastMovingService();

  String? _userName;
  String? _userRole;
  String _selectedPeriod = 'Quarterly'; // Weekly, Monthly, Quarterly

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Dashboard access logging removed for now
  }

  Future<void> _loadUserData() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser != null) {
        // Try to get user data from user_roles table (same approach as Edit Profile)
        final response = await supabase
            .from('user_roles')
            .select('*')
            .eq('id', currentUser.id)
            .limit(1)
            .maybeSingle();

        if (mounted) {
          setState(() {
            if (response != null &&
                response['name'] != null &&
                response['name'].toString().trim().isNotEmpty) {
              // Use data from user_roles table
              _userName = response['name'].toString().trim();
              _userRole = response['role']?.toString().trim() ?? 'Admin';
            } else {
              // Fallback to auth user data
              final displayName =
                  currentUser.userMetadata?['display_name']?.toString().trim();
              final emailName = currentUser.email?.split('@')[0].trim();
              _userName = displayName ?? emailName ?? 'User';
              _userRole = 'Admin';
            }
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _userName = 'User';
          _userRole = 'Admin';
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WillPopScope(
      onWillPop: () async {
        // Show exit confirmation dialog
        return await _showExitDialog(context);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: theme.brightness == Brightness.dark
            ? const Color(0xFF3A3A3A)
            : const Color(0xFFF5F5F5),
        // Use Drawer for mobile, NavigationRail for tablet/desktop
        drawer:
            MediaQuery.of(context).size.width >= 900 ? null : const MyDrawer(),
        body: MediaQuery.of(context).size.width >= 900
            ? _buildRailLayout(context, theme)
            : _buildDashboardContent(context, theme),
      ),
    );
  }

  Future<bool> _showExitDialog(BuildContext context) async {
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
                    // Icon and Title
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

                    // Title
                    Text(
                      'Exit App',
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
                      'Are you sure you want to exit?',
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

                    // Buttons (Yes first, then No)
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
                            child: Text(
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
        false; // Default to false if dialog is dismissed
  }

  Widget _buildDashboardContent(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: () async {
        // Trigger refresh by rebuilding the widget
        setState(() {});
        // Wait for the main stream to emit at least one event
        // This ensures the RefreshIndicator shows its animation
        await _analyticsService.getSupplyCountsStream().first;
      },
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Welcome Panel (with notification and account)
              _buildWelcomePanel(theme),
              const SizedBox(height: 12),
              // Combined Inventory Check Card with Supply Status Panels
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: EdgeInsets.zero,
                color: isDark
                    ? const Color(0xFF2C2C2C)
                    : theme.colorScheme.surface,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isDark
                        ? const Color(0xFF2C2C2C)
                        : theme.colorScheme.surface,
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with icon, title and analysis link
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.inventory,
                                color: theme.colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Inventory check",
                                style: AppFonts.sfProStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                              const Spacer(),
                              // Export buttons (CSV and PDF)
                              Row(
                                children: [
                                  // CSV Export Button
                                  InkWell(
                                    onTap: () => _handleCSVExport(context),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF107C10), // Excel green
                                            Color(0xFF28A745), // Lighter green
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Text(
                                        "Save as .CSV",
                                        style: AppFonts.sfProStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // PDF Export Button
                                  InkWell(
                                    onTap: () => _handlePDFExport(context),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFFE53E3E), // Adobe red
                                            Color(0xFFFF6B6B), // Lighter red
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Text(
                                        "Save as PDF",
                                        style: AppFonts.sfProStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 32),
                            child: Text(
                              "Summarization of your inventory",
                              style: AppFonts.sfProStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: theme.brightness == Brightness.dark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Supply Status Cards (In Stock, Low Stock, Out of Stock)
                      StreamBuilder<Map<String, int>>(
                        stream: _analyticsService.getSupplyCountsStream(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error loading supply counts',
                                style: AppFonts.sfProStyle(
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                              ),
                            );
                          }

                          final inStock = snapshot.data?['inStock'] ?? 0;
                          final lowStock = snapshot.data?['lowStock'] ?? 0;
                          final outOfStock = snapshot.data?['outOfStock'] ?? 0;

                          return Row(
                            children: [
                              Expanded(
                                child: _buildSupplyStatusCard(
                                  context: context,
                                  theme: theme,
                                  title: 'Total Supplies In Stock',
                                  count: inStock,
                                  gradientColors: [
                                    const Color(0xFFE8F5E9), // Light green
                                    const Color(0xFFC8E6C9), // Lighter green
                                  ],
                                  textColor: const Color(0xFF4CAF50), // Green
                                  iconColor: const Color(0xFF4CAF50),
                                  icon: Icons.inventory_2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSupplyStatusCard(
                                  context: context,
                                  theme: theme,
                                  title: 'Low Stock',
                                  count: lowStock,
                                  gradientColors: [
                                    const Color(0xFFFFF9C4), // Light yellow
                                    const Color(0xFFFFF59D), // Lighter yellow
                                  ],
                                  textColor:
                                      const Color(0xFFF9A825), // More yellow
                                  iconColor: const Color(0xFFFBC02D),
                                  icon: Icons.warning_amber_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSupplyStatusCard(
                                  context: context,
                                  theme: theme,
                                  title: 'Out of Stock',
                                  count: outOfStock,
                                  gradientColors: [
                                    const Color(0xFFF8BBD0), // Darker pink
                                    const Color(0xFFF48FB1), // Medium pink
                                  ],
                                  textColor:
                                      const Color(0xFFE91E63), // Dark pink
                                  iconColor: const Color(0xFFE91E63),
                                  icon: Icons.cancel,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Expired / Expiring mini-cards
                      StreamBuilder<Map<String, int>>(
                        stream: _analyticsService.getExpiryCountsStream(),
                        builder: (context, snapshot) {
                          // Handle errors
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error loading expiry data',
                                style: AppFonts.sfProStyle(
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                              ),
                            );
                          }

                          final expired = snapshot.data != null
                              ? (snapshot.data!['expired'] ?? 0)
                              : 0;
                          final expiring = snapshot.data != null
                              ? (snapshot.data!['expiring'] ?? 0)
                              : 0;

                          return Row(
                            children: [
                              Expanded(
                                child: _buildExpiryCard(
                                  context: context,
                                  count: expired,
                                  label: 'Expired',
                                  icon: Icons.delete_forever,
                                  accentColor: const Color(0xFFD32F2F), // red
                                  gradientColors: [
                                    const Color(0xFFFFCDD2), // Light red
                                    const Color(0xFFFFB3BA), // Lighter red
                                  ],
                                  iconBackgroundColor: const Color(0xFFFFB3BA),
                                  height: 96,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildExpiryCard(
                                  context: context,
                                  count: expiring,
                                  label: 'Expiring',
                                  icon: Icons.timer_outlined,
                                  accentColor:
                                      const Color(0xFFFF6D00), // Deep orange
                                  gradientColors: [
                                    const Color(0xFFFFE0B2), // Lighter orange
                                    const Color(0xFFFFCC80), // Light orange
                                  ],
                                  iconBackgroundColor: const Color(0xFFFFB74D),
                                  height: 96,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Purchase Order Summary Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: EdgeInsets.zero,
                color: isDark
                    ? const Color(0xFF2C2C2C)
                    : theme.colorScheme.surface,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isDark
                        ? const Color(0xFF2C2C2C)
                        : theme.colorScheme.surface,
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with icon, title, and subtitle
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.description,
                                color: Colors.green,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Purchase Order Summary",
                                style: AppFonts.sfProStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 32),
                            child: Text(
                              "Overview of current purchase order statuses",
                              style: AppFonts.sfProStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: theme.brightness == Brightness.dark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Status cards (Open, Partial, Approval, Closed)
                      StreamBuilder<Map<String, int>>(
                        stream:
                            _analyticsService.getPurchaseOrderCountsStream(),
                        builder: (context, snapshot) {
                          // Handle errors
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error loading purchase order data',
                                style: AppFonts.sfProStyle(
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                              ),
                            );
                          }

                          final open = snapshot.data?['Open'] ?? 0;
                          final partial = snapshot.data?['Partial'] ?? 0;
                          final approval = snapshot.data?['Approval'] ?? 0;
                          final closed = snapshot.data?['Closed'] ?? 0;

                          return Row(
                            children: [
                              Expanded(
                                child: _buildPurchaseOrderStatusCard(
                                  context: context,
                                  theme: theme,
                                  title: 'Open',
                                  count: open,
                                  gradientColors: const [
                                    Color(0xFFE8F5E9), // Light green
                                    Color(0xFFC8E6C9), // Lighter green
                                  ],
                                  textColor:
                                      const Color(0xFF2E7D32), // Dark green
                                  iconColor: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPurchaseOrderStatusCard(
                                  context: context,
                                  theme: theme,
                                  title: 'Partial',
                                  count: partial,
                                  gradientColors: const [
                                    Color(0xFFFFECB3), // Light yellow cream
                                    Color(0xFFFFE082), // Medium yellow cream
                                  ],
                                  textColor:
                                      const Color(0xFFFFC107), // Lighter yellow
                                  iconColor:
                                      const Color(0xFFFFEB3B), // Pure yellow
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPurchaseOrderStatusCard(
                                  context: context,
                                  theme: theme,
                                  title: 'Approval',
                                  count: approval,
                                  gradientColors: const [
                                    Color(0xFFFFE0B2), // Light orange
                                    Color(0xFFFFCC80), // Lighter orange
                                  ],
                                  textColor:
                                      const Color(0xFFFF6D00), // Light orange
                                  iconColor: Colors.deepOrange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPurchaseOrderStatusCard(
                                  context: context,
                                  theme: theme,
                                  title: 'Closed',
                                  count: closed,
                                  gradientColors: const [
                                    Color(0xFFFFCDD2), // Light pink/red
                                    Color(0xFFF8BBD0), // Medium pink/red
                                  ],
                                  textColor:
                                      const Color(0xFFC62828), // Dark red
                                  iconColor: Colors.red,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Fast Moving Supply
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: EdgeInsets.zero,
                color: isDark
                    ? const Color(0xFF2C2C2C)
                    : theme.colorScheme.surface,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isDark
                        ? const Color(0xFF2C2C2C)
                        : theme.colorScheme.surface,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with icon, title, and subtitle
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.show_chart,
                                      color: const Color(0xFFFF9800),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Fast Moving Supply',
                                      style: AppFonts.sfProStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                  ],
                                ),
                                // Period dropdown
                                DropdownButton<String>(
                                  value: _selectedPeriod,
                                  isDense: true,
                                  underline:
                                      Container(), // Remove default underline
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: theme.textTheme.bodyMedium?.color,
                                    size: 20,
                                  ),
                                  style: AppFonts.sfProStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                  items: ['Weekly', 'Monthly', 'Quarterly']
                                      .map((String period) {
                                    return DropdownMenuItem<String>(
                                      value: period,
                                      child: Text(period),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _selectedPeriod = newValue;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(
                                height:
                                    4), // Adjust this value to change spacing
                            Padding(
                              padding: const EdgeInsets.only(left: 32),
                              child: Text(
                                "Overview of frequently deducted supplies",
                                style: AppFonts.sfProStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<List<FastMovingItem>>(
                          stream: _fastMovingService.streamTopFastMovingItems(
                            limit: 5,
                            window: _getDurationForPeriod(_selectedPeriod),
                          ),
                          builder: (context, snapshot) {
                            // Handle errors
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Error loading fast moving items',
                                  style: AppFonts.sfProStyle(
                                    fontSize: 16,
                                    color: Colors.red,
                                  ),
                                ),
                              );
                            }

                            // Show skeleton loader on first load
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData) {
                              final baseColor = isDark
                                  ? Colors.grey[800]!
                                  : Colors.grey[300]!;
                              final highlightColor = isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[100]!;

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                  children: List.generate(
                                    3,
                                    (index) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      child: Shimmer.fromColors(
                                        baseColor: baseColor,
                                        highlightColor: highlightColor,
                                        child: Container(
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }

                            // Handle error gracefully - show last known data or empty state
                            final items = snapshot.data ?? [];

                            if (items.isEmpty) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  snapshot.hasError
                                      ? 'Unable to load data. Pull down to refresh.'
                                      : 'No deductions recorded yet.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withOpacity(0.7),
                                  ),
                                ),
                              );
                            }

                            // Find max value for scaling
                            final maxValue = items.isNotEmpty
                                ? items
                                    .map((e) => e.timesDeducted)
                                    .reduce((a, b) => a > b ? a : b)
                                : 1;

                            return _buildBarChart(
                              context: context,
                              theme: theme,
                              items: items,
                              maxValue: maxValue,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Duration _getDurationForPeriod(String period) {
    switch (period) {
      case 'Weekly':
        return const Duration(days: 7);
      case 'Monthly':
        return const Duration(days: 30);
      case 'Quarterly':
        return const Duration(days: 90);
      default:
        return const Duration(days: 90);
    }
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
      color: isDark ? const Color(0xFF2C2C2C) : theme.colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isDark ? const Color(0xFF2C2C2C) : theme.colorScheme.surface,
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row with greeting on left and date/time with icon on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome Back!",
                        style: AppFonts.sfProStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Keep your inventory organized. You're maintaining great stock control!",
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

  Widget _buildSupplyStatusCard({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    required int count,
    required List<Color> gradientColors,
    required Color textColor,
    required Color iconColor,
    required IconData icon,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: EdgeInsets.zero,
      color: isDark ? const Color(0xFF3A3A3A) : theme.colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: isDark
              ? null
              : LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isDark ? const Color(0xFF3A3A3A) : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - Title and Count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.sfProStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.grey.shade400
                          : theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$count',
                    style: AppFonts.sfProStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? textColor : textColor,
                    ),
                  ),
                ],
              ),
            ),
            // Right side - Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseOrderStatusCard({
    required BuildContext context,
    required ThemeData theme,
    required String title,
    required int count,
    required List<Color> gradientColors,
    required Color textColor,
    required Color iconColor,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: EdgeInsets.zero,
      color: isDark ? const Color(0xFF3A3A3A) : theme.colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: isDark
              ? null
              : LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isDark ? const Color(0xFF3A3A3A) : null,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: AppFonts.sfProStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDark ? textColor : textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppFonts.sfProStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.grey.shade400
                    : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart({
    required BuildContext context,
    required ThemeData theme,
    required List<FastMovingItem> items,
    required int maxValue,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final chartColor = const Color(0xFFFF9800); // Orange

    // Calculate rounded max for x-axis labels (rounds up to next multiple of 3)
    // This ensures the chart auto-adjusts when values exceed current max
    // Minimum is 15 to provide space for labels when values are at 12
    // e.g., if maxValue is 12 → roundedMax = 15, if maxValue is 16 → roundedMax = 18
    final calculatedMax = maxValue > 0 ? ((maxValue / 3).ceil() * 3) : 3;
    final roundedMax = calculatedMax < 15 ? 15 : calculatedMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bar chart items
        ...items.map((item) {
          // Calculate bar width to match evenly spaced labels
          // Labels are evenly spaced at positions 0%, 20%, 40%, 60%, 80%, 100%
          final targetLabels = 6;
          final stepSize = 3;
          final startValue = roundedMax - (5 * stepSize);
          final adjustedStart =
              ((startValue / stepSize).round() * stepSize).clamp(0, roundedMax);

          // Generate label values
          final labelValues = List.generate(
            targetLabels,
            (index) => index == targetLabels - 1
                ? roundedMax
                : adjustedStart + (index * stepSize),
          );

          // Calculate bar position based on which labels the value falls between
          double barWidth = 0.0;
          if (item.timesDeducted <= labelValues.first) {
            barWidth = 0.0;
          } else if (item.timesDeducted >= labelValues.last) {
            barWidth = 1.0;
          } else {
            // Find which two labels the value falls between
            for (int i = 0; i < labelValues.length - 1; i++) {
              if (item.timesDeducted >= labelValues[i] &&
                  item.timesDeducted <= labelValues[i + 1]) {
                // Interpolate between the two label positions
                final lowerValue = labelValues[i].toDouble();
                final upperValue = labelValues[i + 1].toDouble();
                final lowerPosition = i / (targetLabels - 1);
                final upperPosition = (i + 1) / (targetLabels - 1);

                if (upperValue > lowerValue) {
                  final ratio = (item.timesDeducted - lowerValue) /
                      (upperValue - lowerValue);
                  barWidth =
                      lowerPosition + (ratio * (upperPosition - lowerPosition));
                } else {
                  barWidth = upperPosition;
                }
                break;
              }
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left side - Y-axis labels (supply name with type)
                SizedBox(
                  width: 150,
                  child: Text(
                    item.type != null && item.type!.isNotEmpty
                        ? '${item.name} (${item.type})'
                        : item.name,
                    style: AppFonts.sfProStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // Middle - Bar chart area
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final barMaxWidth = constraints.maxWidth;
                      final barActualWidth = barMaxWidth * barWidth;

                      return Stack(
                        children: [
                          // Bar
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: barWidth,
                              child: Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  color: chartColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          // Value label at the end of the bar
                          if (barWidth > 0)
                            Positioned(
                              left: barActualWidth + 8,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey.shade800
                                      : Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${item.timesDeducted}',
                                    style: AppFonts.sfProStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 8),
        // X-axis labels - evenly spaced with exactly 6 labels
        Padding(
          padding: const EdgeInsets.only(left: 162),
          child: Builder(
            builder: (context) {
              // Always show exactly 6 labels with step size of 3
              // As max increases, remove lower labels (0 → 3 → 6...)
              final targetLabels = 6;
              final stepSize = 3; // Always use step of 3

              // Calculate starting value: roundedMax - (5 * stepSize)
              // This ensures we have exactly 6 labels ending at roundedMax
              final startValue = roundedMax - (5 * stepSize);
              // Round start to nearest multiple of 3, clamped to >= 0
              final adjustedStart = ((startValue / stepSize).round() * stepSize)
                  .clamp(0, roundedMax);

              // Generate label values
              final labelValues = List.generate(
                targetLabels,
                (index) => index == targetLabels - 1
                    ? roundedMax
                    : adjustedStart + (index * stepSize),
              );

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: labelValues.map((value) {
                  return Text(
                    '$value',
                    style: AppFonts.sfProStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpiryCard({
    required BuildContext context,
    required int count,
    required String label,
    required IconData icon,
    required Color accentColor,
    required List<Color> gradientColors,
    required Color iconBackgroundColor,
    double height = 88,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Use brighter colors for dark mode
    final adjustedAccentColor = isDark
        ? (label == 'Expired'
            ? const Color(0xFFFF6B6B) // Bright red for expired
            : const Color(0xFFFF8C42)) // Deep orange for expiring
        : accentColor;

    return InkWell(
      onTap: () {
        if (label == 'Expired') {
          // Navigate to expired page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ExpiredSupplyPage(),
            ),
          );
        } else if (label == 'Expiring') {
          // Navigate to inventory with expiring filter
          Navigator.pushNamed(context, '/inventory',
              arguments: {'filter': 'expiring'});
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: isDark
              ? null
              : LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isDark ? const Color(0xFF3A3A3A) : null,
        ),
        constraints: BoxConstraints(minHeight: height),
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: AppFonts.sfProStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.grey.shade400
                          : theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$count',
                    style: AppFonts.sfProStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: adjustedAccentColor,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? adjustedAccentColor.withOpacity(0.2)
                    : adjustedAccentColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: adjustedAccentColor,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRailLayout(BuildContext context, ThemeData theme) {
    // Main destinations (top section)
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

    // Use the same role logic as drawer for conditional Activity Log
    final userRoleProvider = UserRoleProvider();
    final canAccessActivityLog = userRoleProvider.canAccessActivityLog();

    // Bottom destinations (Settings and Logout)
    final List<_RailDestination> bottomDestinations = [
      _RailDestination(
          icon: Icons.settings, label: 'Settings', route: '/settings'),
      _RailDestination(icon: Icons.logout, label: 'Logout', route: '/logout'),
    ];

    // Dashboard is selected here
    final int selectedIndex = 0;

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
                        isSelected: i == selectedIndex,
                        onTap: () {
                          final dest = mainDestinations[i];
                          final currentRoute =
                              ModalRoute.of(context)?.settings.name;

                          if (currentRoute != dest.route) {
                            Navigator.pushNamed(context, dest.route);
                          }
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
                        isSelected: false,
                        onTap: () {
                          final currentRoute =
                              ModalRoute.of(context)?.settings.name;
                          if (currentRoute != '/activity-log') {
                            Navigator.pushNamed(context, '/activity-log');
                          }
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
                  onTap: () {
                    final dest = bottomDestinations[i];
                    final currentRoute = ModalRoute.of(context)?.settings.name;

                    // Handle logout separately
                    if (dest.route == '/logout') {
                      _handleLogout(context);
                      return;
                    }

                    if (currentRoute != dest.route) {
                      Navigator.pushNamed(context, dest.route);
                    }
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _buildDashboardContent(context, theme)),
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

  Future<void> _handleLogout(BuildContext context) async {
    final shouldLogout = await _showLogoutDialog(context);
    if (shouldLogout == true) {
      final authService = AuthService();
      await authService.logout();
      // ignore: use_build_context_synchronously
      Navigator.pushReplacementNamed(context, '/login');
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
                    // Icon and Title
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

                    // Buttons (Yes first, then No)
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
                            child: Text(
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
        false; // Default to false if dialog is dismissed
  }

  // CSV Export Handler
  Future<void> _handleCSVExport(BuildContext context) async {
    // Show toast notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Downloading report...',
          style: AppFonts.sfProStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.grey[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      // Collect all dashboard data
      final reportData = await _collectReportData();

      // Generate CSV
      final csvContent = _generateCSV(reportData);

      // Save file
      final filePath = await _saveFile(csvContent, 'csv');
      print('CSV file saved to: $filePath'); // Debug print

      // Show success message with file path
      if (context.mounted) {
        final platform = const LocalPlatform();
        final fileName = filePath.split('/').last.split('\\').last;
        final message = platform.isAndroid
            ? 'Report saved to Downloads'
            : platform.isIOS
                ? 'Report saved (check Files app)'
                : 'Report saved: $fileName';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: AppFonts.sfProStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error saving CSV report: $e'); // Debug print
      print('Stack trace: $stackTrace'); // Debug print
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to generate report: ${e.toString()}',
              style: AppFonts.sfProStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // PDF Export Handler
  Future<void> _handlePDFExport(BuildContext context) async {
    // Show toast notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Downloading report...',
          style: AppFonts.sfProStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.grey[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      // Collect all dashboard data
      final reportData = await _collectReportData();

      // Generate PDF
      final pdfBytes = await _generatePDF(reportData);

      // Save file
      final filePath = await _saveFile(pdfBytes, 'pdf');
      print('PDF file saved to: $filePath'); // Debug print

      // Show success message with file path
      if (context.mounted) {
        final platform = const LocalPlatform();
        final fileName = filePath.split('/').last.split('\\').last;
        final message = platform.isAndroid
            ? 'Report saved to Downloads'
            : platform.isIOS
                ? 'Report saved (check Files app)'
                : 'Report saved: $fileName';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: AppFonts.sfProStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error saving PDF report: $e'); // Debug print
      print('Stack trace: $stackTrace'); // Debug print
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to generate report: ${e.toString()}',
              style: AppFonts.sfProStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Collect all dashboard data
  Future<Map<String, dynamic>> _collectReportData() async {
    final supplyCounts = await _analyticsService.getSupplyCountsStream().first;
    final expiryCounts = await _analyticsService.getExpiryCountsStream().first;
    final poCounts =
        await _analyticsService.getPurchaseOrderCountsStream().first;
    final suppliesByStatus = await _analyticsService.getSuppliesByStatus();
    final purchaseOrdersByStatus =
        await _analyticsService.getPurchaseOrdersByStatus();
    final fastMovingItems = await _fastMovingService
        .streamTopFastMovingItems(
          limit: 5,
          window: _getDurationForPeriod(_selectedPeriod),
        )
        .first;

    return {
      'supplyCounts': supplyCounts,
      'expiryCounts': expiryCounts,
      'poCounts': poCounts,
      'suppliesByStatus': suppliesByStatus,
      'purchaseOrdersByStatus': purchaseOrdersByStatus,
      'fastMovingItems': fastMovingItems,
      'selectedPeriod': _selectedPeriod,
      'generatedAt': DateTime.now(),
    };
  }

  // Generate CSV content
  String _generateCSV(Map<String, dynamic> data) {
    final List<List<dynamic>> rows = [];

    // Header
    rows.add(['Dashboard Report']);
    rows.add(
        ['Generated at: ${_formatDateTime(data['generatedAt'] as DateTime)}']);
    rows.add([]);

    // Supply Counts by Status - Detailed Tables
    final suppliesByStatus =
        data['suppliesByStatus'] as Map<String, List<Map<String, dynamic>>>;
    final statuses = [
      'In Stock',
      'Low Stock',
      'Out of Stock',
      'Expiring',
      'Expired'
    ];

    for (final status in statuses) {
      final supplies = suppliesByStatus[status] ?? [];
      rows.add(['Section: Supply Count - $status']);
      rows.add([
        'Supply Name',
        'Quantity',
        'Packaging Unit',
        'Packaging Content',
        'Brand Name',
        'Supplier Name',
        'Cost',
        'Expiry Date',
      ]);

      if (supplies.isEmpty) {
        rows.add(['No supplies found']);
      } else {
        for (final supply in supplies) {
          rows.add([
            supply['displayName'] ?? supply['name'] ?? '',
            supply['stock'] ?? 0,
            supply['packagingUnit'] ?? '',
            supply['packagingContent'] ?? '',
            supply['brand'] ?? 'N/A',
            supply['supplier'] ?? 'N/A',
            supply['cost'] ?? 0.0,
            supply['expiryDisplay'] ?? 'No expiry',
          ]);
        }
      }
      rows.add([]);
    }

    // Purchase Order Summary by Status - Detailed Tables
    final purchaseOrdersByStatus = data['purchaseOrdersByStatus']
        as Map<String, List<Map<String, dynamic>>>;
    final poStatuses = ['Open', 'Partial', 'Approval', 'Closed'];

    for (final status in poStatuses) {
      final orders = purchaseOrdersByStatus[status] ?? [];
      rows.add(['Section: Purchase Order Summary - $status']);
      rows.add([
        'ID',
        'Supplier Name',
        'Number of Supplies',
        'Expiry Date',
        'Date Created',
        'Date Received',
        'Receipt Number',
        'Recipient Name',
        'Remarks',
      ]);

      if (orders.isEmpty) {
        rows.add(['No purchase orders found']);
      } else {
        for (final order in orders) {
          rows.add([
            order['code'] ?? '',
            order['supplierName'] ?? 'N/A',
            order['suppliesCount'] ?? 0,
            order['expiryDates'] ?? 'N/A',
            order['dateCreated'] ?? 'N/A',
            order['dateReceived'] ?? 'N/A',
            order['receiptNumber'] ?? 'N/A',
            order['recipientName'] ?? 'N/A',
            order['remarks'] ?? 'N/A',
          ]);
        }
      }
      rows.add([]);
    }

    // Fast Moving Supply
    final period = data['selectedPeriod'] as String;
    final periodDays = _getPeriodDays(period);
    rows.add(['Section: Fast Moving Supply ($period - Last $periodDays days)']);
    rows.add(['Supply Name', 'Brand', 'Times Deducted']);
    final fastMovingItems = data['fastMovingItems'] as List<FastMovingItem>;
    for (final item in fastMovingItems) {
      rows.add([
        item.name,
        item.brand,
        item.timesDeducted,
      ]);
    }

    // Convert to CSV string
    return const ListToCsvConverter().convert(rows);
  }

  // Generate PDF
  Future<List<int>> _generatePDF(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    final suppliesByStatus =
        data['suppliesByStatus'] as Map<String, List<Map<String, dynamic>>>;
    final purchaseOrdersByStatus = data['purchaseOrdersByStatus']
        as Map<String, List<Map<String, dynamic>>>;
    final fastMovingItems = data['fastMovingItems'] as List;
    final period = data['selectedPeriod'] as String;
    final periodDays = _getPeriodDays(period);
    final generatedAt = data['generatedAt'] as DateTime;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          final List<pw.Widget> widgets = [];

          // Header
          widgets.add(
            pw.Header(
              level: 0,
              child: pw.Text(
                'Dashboard Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 10));
          widgets.add(
            pw.Text(
              'Generated at: ${_formatDateTime(generatedAt)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          );
          widgets.add(pw.SizedBox(height: 20));

          // Supply Counts by Status - Detailed Tables
          final statuses = [
            'In Stock',
            'Low Stock',
            'Out of Stock',
            'Expiring',
            'Expired'
          ];
          for (final status in statuses) {
            final supplies = suppliesByStatus[status] ?? [];
            widgets.add(
              pw.Text(
                'Supply Count - $status',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 10));

            if (supplies.isEmpty) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('No supplies found'),
                ),
              );
            } else {
              widgets.add(
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.5),
                    1: const pw.FlexColumnWidth(0.8),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.5),
                    5: const pw.FlexColumnWidth(1.5),
                    6: const pw.FlexColumnWidth(1),
                    7: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    // Header row
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Supply Name',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Quantity',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Packaging Unit',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Packaging Content',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Brand Name',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Supplier Name',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Cost',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Expiry Date',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    // Data rows
                    ...supplies.map((supply) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                                supply['displayName'] ?? supply['name'] ?? '',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('${supply['stock'] ?? 0}',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(supply['packagingUnit'] ?? '',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(supply['packagingContent'] ?? '',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(supply['brand'] ?? 'N/A',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(supply['supplier'] ?? 'N/A',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('${supply['cost'] ?? 0.0}',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                                supply['expiryDisplay'] ?? 'No expiry',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              );
            }
            widgets.add(pw.SizedBox(height: 20));
          }

          // Purchase Order Summary by Status - Detailed Tables
          final poStatuses = ['Open', 'Partial', 'Approval', 'Closed'];
          for (final status in poStatuses) {
            final orders = purchaseOrdersByStatus[status] ?? [];
            widgets.add(
              pw.Text(
                'Purchase Order Summary - $status',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 10));

            if (orders.isEmpty) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text('No purchase orders found'),
                ),
              );
            } else {
              widgets.add(
                pw.Table(
                  border: pw.TableBorder.all(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(0.8),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(0.8),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.2),
                    5: const pw.FlexColumnWidth(1.2),
                    6: const pw.FlexColumnWidth(1),
                    7: const pw.FlexColumnWidth(1.2),
                    8: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    // Header row
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('ID',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Supplier Name',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Supplies',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Expiry Date',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Date Created',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Date Received',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Receipt No.',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Recipient',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('Remarks',
                              style: pw.TextStyle(
                                  fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    // Data rows
                    ...orders.map((order) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(order['code'] ?? '',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(order['supplierName'] ?? 'N/A',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('${order['suppliesCount'] ?? 0}',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(order['expiryDates'] ?? 'N/A',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(order['dateCreated'] ?? 'N/A',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(order['dateReceived'] ?? 'N/A',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(order['receiptNumber'] ?? 'N/A',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(order['recipientName'] ?? 'N/A',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(order['remarks'] ?? 'N/A',
                                style: const pw.TextStyle(fontSize: 8)),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              );
            }
            widgets.add(pw.SizedBox(height: 20));
          }

          // Fast Moving Supply Table
          widgets.add(
            pw.Text(
              'Fast Moving Supply ($period - Last $periodDays days)',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 10));
          widgets.add(
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Supply Name'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Brand'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Times Deducted'),
                    ),
                  ],
                ),
                ...fastMovingItems.map((item) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(item.name),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(item.brand),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${item.timesDeducted}'),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          );

          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  // Save file to Downloads
  Future<String> _saveFile(dynamic content, String extension) async {
    final platform = const LocalPlatform();
    final now = DateTime.now();
    final fileName = 'Report_${_formatFileDateTime(now)}.$extension';

    // For Android, save directly to Downloads folder
    if (platform.isAndroid) {
      try {
        // Try to get external storage directory
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          // Get the base path and construct Downloads path
          // External storage path is usually like: /storage/emulated/0/Android/data/com.example.app/files
          // We need to go up to /storage/emulated/0 and then into Download
          String downloadsPath;
          final pathParts = directory.path.split('/');
          if (pathParts.contains('Android')) {
            final androidIndex = pathParts.indexOf('Android');
            downloadsPath =
                pathParts.sublist(0, androidIndex).join('/') + '/Download';
          } else {
            // Fallback: try common Downloads path
            downloadsPath = '/storage/emulated/0/Download';
          }

          final downloadsDir = Directory(downloadsPath);

          // Create directory if it doesn't exist
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }

          final file = File('${downloadsDir.path}/$fileName');

          if (extension == 'csv') {
            await file.writeAsString(content as String);
          } else {
            await file.writeAsBytes(content as List<int>);
          }

          print('File saved to Android Downloads: ${file.path}'); // Debug print
          return file.path;
        }
      } catch (e) {
        print('Error saving to Android Downloads: $e'); // Debug print
        // Fallback to app documents directory
      }

      // Fallback: Save to app's documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      final file = File('${documentsDir.path}/$fileName');

      if (extension == 'csv') {
        await file.writeAsString(content as String);
      } else {
        await file.writeAsBytes(content as List<int>);
      }

      print('File saved to app documents: ${file.path}'); // Debug print
      return file.path;
    } else if (platform.isIOS) {
      // For iOS, use app documents directory (iOS doesn't have user-accessible Downloads)
      final documentsDir = await getApplicationDocumentsDirectory();
      final file = File('${documentsDir.path}/$fileName');

      if (extension == 'csv') {
        await file.writeAsString(content as String);
      } else {
        await file.writeAsBytes(content as List<int>);
      }

      // Try to use share_plus for iOS (optional, can open share sheet)
      try {
        final xFile = XFile(
          file.path,
          name: fileName,
          mimeType: extension == 'csv' ? 'text/csv' : 'application/pdf',
        );
        await Share.shareXFiles([xFile], subject: 'Dashboard Report');
      } catch (e) {
        print(
            'Share not available, file saved to: ${file.path}'); // Debug print
      }

      return file.path;
    } else {
      // For desktop platforms (Windows/macOS/Linux), use Downloads directory
      Directory? directory = await getDownloadsDirectory();

      // Fallback to Documents if Downloads not available
      if (directory == null) {
        directory = await getApplicationDocumentsDirectory();
      }

      final file = File('${directory.path}/$fileName');

      if (extension == 'csv') {
        await file.writeAsString(content as String);
      } else {
        await file.writeAsBytes(content as List<int>);
      }

      print('File written successfully to: ${file.path}'); // Debug print
      print('File exists: ${await file.exists()}'); // Debug print
      print('File size: ${await file.length()} bytes'); // Debug print

      return file.path;
    }
  }

  // Format datetime for display
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  // Format datetime for filename
  String _formatFileDateTime(DateTime dateTime) {
    return '${dateTime.year}${dateTime.month.toString().padLeft(2, '0')}${dateTime.day.toString().padLeft(2, '0')}_${dateTime.hour.toString().padLeft(2, '0')}${dateTime.minute.toString().padLeft(2, '0')}${dateTime.second.toString().padLeft(2, '0')}';
  }

  // Get period days
  int _getPeriodDays(String period) {
    switch (period) {
      case 'Weekly':
        return 7;
      case 'Monthly':
        return 30;
      case 'Quarterly':
        return 90;
      default:
        return 90;
    }
  }
}

class _RailDestination {
  final IconData icon;
  final String label;
  final String route;

  _RailDestination(
      {required this.icon, required this.label, required this.route});
}
