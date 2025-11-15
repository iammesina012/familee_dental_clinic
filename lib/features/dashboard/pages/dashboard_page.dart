import 'package:flutter/material.dart';
import 'package:familee_dental/shared/drawer.dart';
import 'package:familee_dental/features/dashboard/services/inventory_analytics_service.dart';
import 'package:familee_dental/features/dashboard/services/fast_moving_service.dart';
import 'package:familee_dental/features/dashboard/services/turnover_rate.dart';
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
import 'package:familee_dental/shared/services/connectivity_service.dart';
import 'package:familee_dental/shared/widgets/connection_error_dialog.dart';
import 'package:familee_dental/shared/services/user_data_service.dart';

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
  final TurnoverRateService _turnoverRateService = TurnoverRateService();

  String? _userName;
  String? _userRole;
  String _selectedPeriod = 'Weekly'; // Weekly, Monthly (for Fast Moving)
  String _selectedUsageSpeedPeriod =
      'Monthly'; // Monthly, Quarterly, Yearly (for Usage Speed)
  bool _isPeriodChanging = false; // Track if period is being changed
  bool?
      _hasConnection; // Track connectivity status (null = checking, true = online, false = offline)
  List<FastMovingItem>?
      _lastFastMovingItems; // Keep last data visible during period change

  final _userDataService = UserDataService();

  @override
  void initState() {
    super.initState();
    // Ensure _selectedPeriod is valid (handle case where it might be "Daily" from previous session)
    if (_selectedPeriod != 'Weekly' && _selectedPeriod != 'Monthly') {
      _selectedPeriod = 'Weekly';
    }
    // Ensure _selectedUsageSpeedPeriod is valid
    if (_selectedUsageSpeedPeriod != 'Monthly' &&
        _selectedUsageSpeedPeriod != 'Quarterly' &&
        _selectedUsageSpeedPeriod != 'Yearly') {
      _selectedUsageSpeedPeriod = 'Monthly';
    }
    // Load user data from Hive first (avoid placeholders)
    _loadUserDataFromHive();
    _loadUserData();
    _checkConnectivity();
    // Dashboard access logging removed for now
  }

  /// Load user data from Hive (no placeholders)
  Future<void> _loadUserDataFromHive() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        await _userDataService.loadFromHive(currentUser.id);
        if (mounted) {
          setState(() {
            _userName = _userDataService.userName;
            _userRole = _userDataService.userRole;
          });
        }
      }
    } catch (e) {
      // Ignore errors - best effort
    }
  }

  Future<void> _checkConnectivity() async {
    final hasConnection = await ConnectivityService().hasInternetConnection();
    if (mounted) {
      setState(() {
        _hasConnection = hasConnection;
      });
      // Pre-population no longer needed - streams auto-load from Hive
    }
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
          if (response != null &&
              response['name'] != null &&
              response['name'].toString().trim().isNotEmpty) {
            // Use data from user_roles table
            final name = response['name'].toString().trim();
            final role = response['role']?.toString().trim() ?? 'Admin';

            setState(() {
              _userName = name;
              _userRole = role;
            });

            // Save to Hive for persistence
            await _userDataService.saveToHive(currentUser.id, name, role);
          } else {
            // Fallback to auth user data
            final displayName =
                currentUser.userMetadata?['display_name']?.toString().trim();
            final emailName = currentUser.email?.split('@')[0].trim();
            final name = displayName ?? emailName ?? 'User';
            final role = 'Admin';

            setState(() {
              _userName = name;
              _userRole = role;
            });

            // Save to Hive for persistence
            await _userDataService.saveToHive(currentUser.id, name, role);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Use cached data from service if available (loaded from Hive)
          _userName = _userDataService.userName;
          _userRole = _userDataService.userRole;
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
                                color: Colors.green,
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
                              // Export buttons (CSV and PDF) visible for Owner only
                              if ((_userRole ?? '').toLowerCase() == 'owner')
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
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF107C10), // Excel green
                                              Color(
                                                  0xFF28A745), // Lighter green
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
                                          borderRadius:
                                              BorderRadius.circular(6),
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
                          // Show skeleton loader only if no data exists (no cached data available)
                          // If cached data exists, it will show immediately instead
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData &&
                              !snapshot.hasError) {
                            final isDark = theme.brightness == Brightness.dark;
                            final baseColor =
                                isDark ? Colors.grey[800]! : Colors.grey[300]!;
                            final highlightColor =
                                isDark ? Colors.grey[700]! : Colors.grey[100]!;

                            return Row(
                              children: [
                                Expanded(
                                  child: Shimmer.fromColors(
                                    baseColor: baseColor,
                                    highlightColor: highlightColor,
                                    child: Container(
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Shimmer.fromColors(
                                    baseColor: baseColor,
                                    highlightColor: highlightColor,
                                    child: Container(
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Shimmer.fromColors(
                                    baseColor: baseColor,
                                    highlightColor: highlightColor,
                                    child: Container(
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          // Use cached data if available, otherwise default to 0
                          final inStock = snapshot.data?['inStock'] ?? 0;
                          final lowStock = snapshot.data?['lowStock'] ?? 0;
                          final outOfStock = snapshot.data?['outOfStock'] ?? 0;

                          return Row(
                            children: [
                              Expanded(
                                child: _buildSupplyStatusCard(
                                  context: context,
                                  theme: theme,
                                  title: 'In Stock',
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
                          // Show skeleton loader only if no data exists (no cached data available)
                          // If cached data exists, it will show immediately instead
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData &&
                              !snapshot.hasError) {
                            final isDark = theme.brightness == Brightness.dark;
                            final baseColor =
                                isDark ? Colors.grey[800]! : Colors.grey[300]!;
                            final highlightColor =
                                isDark ? Colors.grey[700]! : Colors.grey[100]!;

                            return Row(
                              children: [
                                Expanded(
                                  child: Shimmer.fromColors(
                                    baseColor: baseColor,
                                    highlightColor: highlightColor,
                                    child: Container(
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Shimmer.fromColors(
                                    baseColor: baseColor,
                                    highlightColor: highlightColor,
                                    child: Container(
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          // Use cached data if available, otherwise default to 0
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
                                color: Colors.blue,
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
                          // Show skeleton loader only if no data exists (no cached data available)
                          // If cached data exists, it will show immediately instead
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData &&
                              !snapshot.hasError) {
                            final isDark = theme.brightness == Brightness.dark;
                            final baseColor =
                                isDark ? Colors.grey[800]! : Colors.grey[300]!;
                            final highlightColor =
                                isDark ? Colors.grey[700]! : Colors.grey[100]!;

                            return Row(
                              children: [
                                Expanded(
                                  child: Shimmer.fromColors(
                                    baseColor: baseColor,
                                    highlightColor: highlightColor,
                                    child: Container(
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Shimmer.fromColors(
                                    baseColor: baseColor,
                                    highlightColor: highlightColor,
                                    child: Container(
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Shimmer.fromColors(
                                    baseColor: baseColor,
                                    highlightColor: highlightColor,
                                    child: Container(
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Shimmer.fromColors(
                                    baseColor: baseColor,
                                    highlightColor: highlightColor,
                                    child: Container(
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          // Use cached data if available, otherwise default to 0
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
                                      const Color(0xFFFFA000), // Darker yellow
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
                                      color: Colors.amber,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Fast Moving Supply (${_getDateRangeForPeriod(_selectedPeriod)})',
                                      style: AppFonts.sfProStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Info tooltip
                                    Tooltip(
                                      message:
                                          'This shows which items are deducted from stock most often in the selected period. Higher bars mean that supply is used more frequently and may need closer monitoring or reordering.',
                                      child: InkWell(
                                        onTap: () {
                                          // Show info dialog
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              contentPadding:
                                                  const EdgeInsets.fromLTRB(
                                                      24, 20, 24, 16),
                                              title: Text(
                                                'Fast Moving Supply',
                                                style: AppFonts.sfProStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              content: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                        maxWidth: 500),
                                                child: Text(
                                                  'This shows which items are deducted from stock most often in the selected period. Higher bars mean that supply is used more frequently and may need closer monitoring or reordering.',
                                                  style: AppFonts.sfProStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text(
                                                    'Got it',
                                                    style: AppFonts.sfProStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        child: Icon(
                                          Icons.info_outline,
                                          size: 18,
                                          color: theme.brightness ==
                                                  Brightness.dark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Period dropdown
                                DropdownButton<String>(
                                  value: (_selectedPeriod == 'Weekly' ||
                                          _selectedPeriod == 'Monthly')
                                      ? _selectedPeriod
                                      : 'Weekly', // Fallback to Weekly if invalid
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
                                  items: ['Weekly', 'Monthly']
                                      .map((String period) {
                                    return DropdownMenuItem<String>(
                                      value: period,
                                      child: Text(period),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null &&
                                        newValue != _selectedPeriod) {
                                      // Check connectivity when period changes
                                      _checkConnectivity();
                                      setState(() {
                                        _selectedPeriod = newValue;
                                        _isPeriodChanging = true;
                                      });
                                      // Reset loading state after a delay to ensure skeleton is visible (only if online)
                                      Future.delayed(
                                          const Duration(milliseconds: 500),
                                          () {
                                        if (mounted) {
                                          setState(() {
                                            _isPeriodChanging = false;
                                          });
                                        }
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
                          key: ValueKey(
                              _selectedPeriod), // Force rebuild on period change
                          stream: _fastMovingService.streamTopFastMovingItems(
                            limit: 5,
                            window: _getDurationForPeriod(_selectedPeriod),
                          ),
                          builder: (context, snapshot) {
                            // Show skeleton loader only when online AND (period is changing OR waiting for data)
                            // When offline, cached data shows immediately (no skeleton needed)
                            final shouldShowSkeleton =
                                (_hasConnection == true) &&
                                    (_isPeriodChanging ||
                                        (snapshot.connectionState ==
                                                ConnectionState.waiting &&
                                            !snapshot.hasData &&
                                            !snapshot.hasError));

                            if (shouldShowSkeleton) {
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
                                    5,
                                    (index) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      child: Shimmer.fromColors(
                                        baseColor: baseColor,
                                        highlightColor: highlightColor,
                                        child: Container(
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.grey[800]
                                                : Colors.white,
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

                            // Handle gracefully - show cached data or empty state
                            final items = snapshot.data ?? [];

                            // Update last items if we have data
                            if (items.isNotEmpty) {
                              _lastFastMovingItems = items;
                            }

                            // If period is changing or waiting, use last data if available to prevent flashing
                            final displayItems = (items.isEmpty &&
                                    (_isPeriodChanging ||
                                        snapshot.connectionState ==
                                            ConnectionState.waiting) &&
                                    _lastFastMovingItems != null)
                                ? _lastFastMovingItems!
                                : items;

                            // Only show empty state if we have confirmed there's no data
                            // Don't show empty if we're still waiting or have previous data to show
                            if (displayItems.isEmpty &&
                                !_isPeriodChanging &&
                                snapshot.connectionState !=
                                    ConnectionState.waiting) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 48, horizontal: 24),
                                  child: Text(
                                    'No deductions recorded yet.',
                                    style: AppFonts.sfProStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.7),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }

                            // If we're waiting for new data but have old data, show old data
                            // If we're waiting and have no old data, show skeleton (online) or wait (offline)
                            if (displayItems.isEmpty &&
                                (_isPeriodChanging ||
                                    snapshot.connectionState ==
                                        ConnectionState.waiting)) {
                              if (_hasConnection == true) {
                                // Show skeleton when online and waiting
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
                                      5,
                                      (index) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        child: Shimmer.fromColors(
                                          baseColor: baseColor,
                                          highlightColor: highlightColor,
                                          child: Container(
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.grey[800]
                                                  : Colors.white,
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
                              // If offline and no data yet, wait silently for cached data
                              return const SizedBox.shrink();
                            }

                            // Find max value for scaling
                            final maxValue = displayItems.isNotEmpty
                                ? displayItems
                                    .map((e) => e.quantityDeducted)
                                    .reduce((a, b) => a > b ? a : b)
                                : 1;

                            return _buildBarChart(
                              context: context,
                              theme: theme,
                              items: displayItems,
                              maxValue: maxValue,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Usage Speed Card
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
                        // Header with icon, title, subtitle, and info tooltip
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
                                      Icons.trending_up,
                                      color: Colors.blue,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Usage speed (${_getUsageSpeedDateRange(_selectedUsageSpeedPeriod)})',
                                      style: AppFonts.sfProStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Info tooltip
                                    Tooltip(
                                      message:
                                          'This shows how often a supply is used in the selected period. "Fast" means it is used very often, "Normal" means it is used appropriately, "Slow" means it is rarely used and tends to stay longer on the shelf.',
                                      child: InkWell(
                                        onTap: () {
                                          // Show info dialog
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              contentPadding:
                                                  const EdgeInsets.fromLTRB(
                                                      24, 20, 24, 16),
                                              title: Text(
                                                'Usage Speed',
                                                style: AppFonts.sfProStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              content: ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                        maxWidth: 500),
                                                child: Text(
                                                  'This shows how often a supply is used in the selected period. "Fast" means it is used very often, "Normal" means it is used appropriately, "Slow" means it is rarely used and tends to stay longer on the shelf.',
                                                  style: AppFonts.sfProStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text(
                                                    'Got it',
                                                    style: AppFonts.sfProStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        child: Icon(
                                          Icons.info_outline,
                                          size: 18,
                                          color: theme.brightness ==
                                                  Brightness.dark
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Period dropdown
                                DropdownButton<String>(
                                  value: _selectedUsageSpeedPeriod,
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
                                  items: ['Monthly', 'Quarterly', 'Yearly']
                                      .map((String period) {
                                    return DropdownMenuItem<String>(
                                      value: period,
                                      child: Text(period),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null &&
                                        newValue != _selectedUsageSpeedPeriod) {
                                      setState(() {
                                        _selectedUsageSpeedPeriod = newValue;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 32),
                              child: Text(
                                'Shows how often each supply is used in the selected period.',
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
                        FutureBuilder<List<TurnoverItem>>(
                          key: ValueKey(_selectedUsageSpeedPeriod),
                          future: _turnoverRateService
                              .computeTurnoverItems(_selectedUsageSpeedPeriod),
                          builder: (context, snapshot) {
                            // Show skeleton loader only when actively waiting
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
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
                                    5,
                                    (index) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      child: Shimmer.fromColors(
                                        baseColor: baseColor,
                                        highlightColor: highlightColor,
                                        child: Container(
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.grey[800]
                                                : Colors.white,
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

                            // Handle errors
                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 48, horizontal: 24),
                                  child: Text(
                                    'Unable to load usage speed data.',
                                    style: AppFonts.sfProStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.7),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }

                            // Get data (will be empty list if no data or error)
                            final items = snapshot.data ?? [];

                            // Show empty state if no deductions
                            if (items.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 48, horizontal: 24),
                                  child: Text(
                                    'No usage data recorded for this period.',
                                    style: AppFonts.sfProStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.7),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }

                            // Find max value for scaling
                            final maxValue = items.isNotEmpty
                                ? items
                                    .map((e) => e.turnoverRate)
                                    .reduce((a, b) => a > b ? a : b)
                                : 0.5;

                            return _buildTurnoverChart(
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

  // Get fixed date range for period (Monday-Sunday for weekly, first-last day for monthly)
  Map<String, DateTime> _getFixedDateRangeForPeriod(String period) {
    final now = DateTime.now();

    switch (period) {
      case 'Weekly':
        // Get Monday of current week
        final weekday = now.weekday; // 1 = Monday, 7 = Sunday
        final daysFromMonday = weekday - 1;
        final monday = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: daysFromMonday));

        // Get Sunday of current week (6 days after Monday)
        final sunday = monday.add(const Duration(days: 6));

        return {
          'start': monday,
          'end': sunday,
        };
      case 'Monthly':
        // Get first day of current month
        final firstDay = DateTime(now.year, now.month, 1);

        // Get last day of current month
        final lastDay = DateTime(now.year, now.month + 1, 0);

        return {
          'start': firstDay,
          'end': lastDay,
        };
      default:
        // Default to weekly
        final weekday = now.weekday;
        final daysFromMonday = weekday - 1;
        final monday = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: daysFromMonday));
        final sunday = monday.add(const Duration(days: 6));

        return {
          'start': monday,
          'end': sunday,
        };
    }
  }

  Duration _getDurationForPeriod(String period) {
    final dateRange = _getFixedDateRangeForPeriod(period);
    final start = dateRange['start']!;
    final end = dateRange['end']!;
    // Return duration that covers the range (end - start + 1 day to include end date)
    final difference = end.difference(start);
    return Duration(days: difference.inDays + 1);
  }

  /// Get formatted date range for Usage Speed periods (Monthly, Quarterly, Yearly)
  String _getUsageSpeedDateRange(String period) {
    // Use the service to get the date range
    final dateRange = _turnoverRateService.getDateRangeForPeriod(period);
    final startDate = dateRange['start']!;
    final endDate = dateRange['end']!;

    // Format day without leading zero
    String formatDay(int day) => day.toString();
    // Format month as abbreviation with period
    String formatMonth(int month) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return months[month - 1];
    }

    // Format: "Nov 1 - Nov 30, 2025" or "Nov 1 - Dec 15, 2025"
    if (startDate.year == endDate.year && startDate.month == endDate.month) {
      // Same month and year: "Nov 1 - Nov 30, 2025"
      return '${formatMonth(startDate.month)} ${formatDay(startDate.day)} - ${formatMonth(endDate.month)} ${formatDay(endDate.day)}, ${endDate.year}';
    } else if (startDate.year == endDate.year) {
      // Same year, different month: "Nov 1 - Dec 15, 2025"
      return '${formatMonth(startDate.month)} ${formatDay(startDate.day)} - ${formatMonth(endDate.month)} ${formatDay(endDate.day)}, ${endDate.year}';
    } else {
      // Different year: "Nov 1, 2024 - Jan 15, 2025"
      return '${formatMonth(startDate.month)} ${formatDay(startDate.day)}, ${startDate.year} - ${formatMonth(endDate.month)} ${formatDay(endDate.day)}, ${endDate.year}';
    }
  }

  String _getDateRangeForPeriod(String period) {
    final dateRange = _getFixedDateRangeForPeriod(period);
    final startDate = dateRange['start']!;
    final endDate = dateRange['end']!;

    // Format day without leading zero
    String formatDay(int day) => day.toString();
    // Format month as abbreviation
    String formatMonth(int month) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return months[month - 1];
    }

    switch (period) {
      case 'Weekly':
        // Show date range: "Nov 10 - Nov 16, 2025"
        if (startDate.year == endDate.year &&
            startDate.month == endDate.month) {
          // Same month and year
          return '${formatMonth(startDate.month)} ${formatDay(startDate.day)} - ${formatMonth(endDate.month)} ${formatDay(endDate.day)}, ${endDate.year}';
        } else if (startDate.year == endDate.year) {
          // Same year, different month
          return '${formatMonth(startDate.month)} ${formatDay(startDate.day)} - ${formatMonth(endDate.month)} ${formatDay(endDate.day)}, ${endDate.year}';
        } else {
          // Different year
          return '${formatMonth(startDate.month)} ${formatDay(startDate.day)}, ${startDate.year} - ${formatMonth(endDate.month)} ${formatDay(endDate.day)}, ${endDate.year}';
        }
      case 'Monthly':
        // Show date range: "Nov 1 - Nov 30, 2025"
        if (startDate.year == endDate.year &&
            startDate.month == endDate.month) {
          // Same month and year
          return '${formatMonth(startDate.month)} ${formatDay(startDate.day)} - ${formatDay(endDate.day)}, ${endDate.year}';
        } else if (startDate.year == endDate.year) {
          // Same year, different month
          return '${formatMonth(startDate.month)} ${formatDay(startDate.day)} - ${formatMonth(endDate.month)} ${formatDay(endDate.day)}, ${endDate.year}';
        } else {
          // Different year
          return '${formatMonth(startDate.month)} ${formatDay(startDate.day)}, ${startDate.year} - ${formatMonth(endDate.month)} ${formatDay(endDate.day)}, ${endDate.year}';
        }
      default:
        // Default to Weekly format
        if (startDate.year == endDate.year &&
            startDate.month == endDate.month) {
          return '${formatMonth(startDate.month)} ${formatDay(startDate.day)} - ${formatMonth(endDate.month)} ${formatDay(endDate.day)}, ${endDate.year}';
        } else if (startDate.year == endDate.year) {
          return '${formatMonth(startDate.month)} ${formatDay(startDate.day)} - ${formatMonth(endDate.month)} ${formatDay(endDate.day)}, ${endDate.year}';
        } else {
          return '${formatMonth(startDate.month)} ${formatDay(startDate.day)}, ${startDate.year} - ${formatMonth(endDate.month)} ${formatDay(endDate.day)}, ${endDate.year}';
        }
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

    // Calculate rounded max for x-axis labels (rounds up to next multiple of 5)
    // This ensures the chart auto-adjusts when values exceed current max
    // Minimum is 5 to provide space for labels when values are small
    // e.g., if maxValue is 12 → roundedMax = 15, if maxValue is 16 → roundedMax = 20
    final calculatedMax = maxValue > 0 ? ((maxValue / 5).ceil() * 5) : 5;
    final roundedMax = calculatedMax < 5 ? 5 : calculatedMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bar chart items
        ...items.map((item) {
          // Calculate bar width - labels start from 0 and go up to roundedMax in steps of 5
          // Bar width is proportional to the value relative to roundedMax
          final barWidth = roundedMax > 0
              ? (item.quantityDeducted / roundedMax).clamp(0.0, 1.0)
              : 0.0;

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
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFFF9800), // Orange
                                      const Color(0xFFFF6D00), // Deeper orange
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
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
                                    '${item.quantityDeducted}',
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
        // X-axis labels - always start from 0, step by 5, show as many as needed
        Padding(
          padding: const EdgeInsets.only(left: 162),
          child: Builder(
            builder: (context) {
              // Always start from 0, step by 5
              final stepSize = 5;

              // Generate label values: 0, 5, 10, 15, ... up to roundedMax
              final labelValues = <int>[];
              for (int value = 0; value <= roundedMax; value += stepSize) {
                labelValues.add(value);
              }
              // Ensure roundedMax is included even if it's not a multiple of 5
              if (labelValues.isEmpty || labelValues.last < roundedMax) {
                labelValues.add(roundedMax);
              }

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

  Widget _buildTurnoverChart({
    required BuildContext context,
    required ThemeData theme,
    required List<TurnoverItem> items,
    required double maxValue,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    // Calculate rounded max for x-axis labels
    // Always round UP to ensure all values are visible and chart scales properly
    double roundedMax;

    if (maxValue <= 0) {
      roundedMax = 0.5;
    } else if (maxValue <= 0.5) {
      roundedMax = 0.5;
    } else if (maxValue <= 1.0) {
      // Round up to next 0.1
      roundedMax = ((maxValue * 10).ceil() / 10.0);
    } else if (maxValue <= 2.0) {
      // Round up to next 0.2
      roundedMax = ((maxValue * 5).ceil() / 5.0);
    } else if (maxValue <= 5.0) {
      // Round up to next 0.5
      roundedMax = ((maxValue * 2).ceil() / 2.0);
    } else if (maxValue <= 10.0) {
      // Round up to next 1.0
      roundedMax = maxValue.ceil().toDouble();
    } else if (maxValue <= 50.0) {
      // Round up to next 5.0
      roundedMax = ((maxValue / 5.0).ceil() * 5.0);
    } else {
      // Round up to next 10.0
      roundedMax = ((maxValue / 10.0).ceil() * 10.0);
    }

    // Safety check: ensure roundedMax is always >= maxValue (with small buffer)
    if (roundedMax < maxValue) {
      roundedMax = maxValue * 1.1;
    }

    // Add small buffer to ensure bars don't touch the edge
    roundedMax = roundedMax * 1.05;

    // Adjust spacing and bar height based on number of items (more compact when many items)
    final itemCount = items.length;
    final itemSpacing = itemCount > 3 ? 16.0 : 24.0;
    final barHeight = itemCount > 3 ? 28.0 : 32.0;
    final labelFontSize = itemCount > 3 ? 13.0 : 14.0;
    final indicatorFontSize = itemCount > 3 ? 10.0 : 11.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart items
        ...items.map((item) {
          // Calculate bar width - proportional to the value relative to roundedMax
          final barWidth = roundedMax > 0
              ? (item.turnoverRate / roundedMax).clamp(0.0, 1.0)
              : 0.0;

          return Padding(
            padding: EdgeInsets.only(bottom: itemSpacing),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left side - Y-axis labels (supply name with brand)
                SizedBox(
                  width: 150,
                  child: Text(
                    item.brand.isNotEmpty
                        ? '${item.name} (${item.brand})'
                        : item.name,
                    style: AppFonts.sfProStyle(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // Middle - Bar chart area with space for indicator
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final barMaxWidth = constraints.maxWidth;
                      // Reserve space for indicator (approximately 120px for value + label + padding)
                      final indicatorWidth = 120.0;
                      final availableWidth = barMaxWidth - indicatorWidth;
                      final barActualWidth =
                          availableWidth * barWidth.clamp(0.0, 1.0);

                      // Ensure bar doesn't exceed available space
                      final clampedBarWidth =
                          barActualWidth.clamp(0.0, availableWidth);

                      return Stack(
                        clipBehavior:
                            Clip.none, // Allow indicator to overflow if needed
                        children: [
                          // Bar
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: clampedBarWidth,
                              child: Container(
                                height: barHeight,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF2196F3), // Blue
                                      const Color(0xFF1976D2), // Deeper blue
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          // Value label at the end of the bar (always visible)
                          Positioned(
                            left: clampedBarWidth + 8,
                            top: 0,
                            bottom: 0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Numeric value with × symbol
                                Container(
                                  height: barHeight,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    maxWidth: 60,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
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
                                      '${item.turnoverRate.toStringAsFixed(1)}×',
                                      style: AppFonts.sfProStyle(
                                        fontSize: indicatorFontSize,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Speed label (Slow / Normal / Fast)
                                _buildSpeedLabel(
                                  item.turnoverRate,
                                  theme,
                                  isDark,
                                  indicatorFontSize,
                                ),
                              ],
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
        // X-axis labels - dynamically adjust based on data range
        Padding(
          padding: const EdgeInsets.only(left: 162),
          child: Builder(
            builder: (context) {
              // Calculate optimal step size based on roundedMax
              // Aim for 4-6 labels for better readability
              double stepSize;
              int targetLabels =
                  5; // Aim for 5 labels (0, step, 2*step, ..., max)

              // Calculate step size to get approximately targetLabels
              stepSize = roundedMax / (targetLabels - 1);

              // Round step size to nice values for readability
              if (stepSize <= 0.1) {
                stepSize = 0.1;
              } else if (stepSize <= 0.2) {
                stepSize = 0.2;
              } else if (stepSize <= 0.5) {
                stepSize = 0.5;
              } else if (stepSize <= 1.0) {
                stepSize = 1.0;
              } else if (stepSize <= 2.0) {
                stepSize = 2.0;
              } else if (stepSize <= 5.0) {
                stepSize = 5.0;
              } else {
                stepSize = (stepSize / 5.0).ceil() * 5.0; // Round to nearest 5
              }

              // Generate label values: 0, step, 2*step, ... up to roundedMax
              final labelValues = <double>[];
              for (double value = 0;
                  value <= roundedMax + (stepSize * 0.1);
                  value += stepSize) {
                if (value <= roundedMax) {
                  labelValues.add(value);
                }
              }

              // Always include 0 and roundedMax
              if (labelValues.isEmpty) {
                labelValues.add(0.0);
              }
              if (labelValues.last < roundedMax) {
                labelValues.add(roundedMax);
              }

              // Remove duplicates and sort
              final uniqueLabels = labelValues.toSet().toList()..sort();

              // Limit to reasonable number of labels (max 7) to avoid crowding
              final displayLabels = uniqueLabels.length > 7
                  ? [
                      uniqueLabels.first,
                      ...uniqueLabels.skip(1).take(5).toList(),
                      uniqueLabels.last,
                    ]
                  : uniqueLabels;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: displayLabels.map((value) {
                  // Format based on value size
                  String formattedValue;
                  if (value < 0.01) {
                    formattedValue = '0';
                  } else if (value < 1.0) {
                    formattedValue = value.toStringAsFixed(1);
                  } else if (value < 10.0) {
                    formattedValue = value.toStringAsFixed(1);
                  } else {
                    formattedValue = value.toStringAsFixed(0);
                  }

                  return Text(
                    formattedValue,
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

  /// Build speed label (Slow / Normal / Fast) based on turnover rate
  Widget _buildSpeedLabel(
    double turnoverRate,
    ThemeData theme,
    bool isDark,
    double fontSize,
  ) {
    String label;
    Color labelColor;

    if (turnoverRate < 0.5) {
      label = 'Slow';
      labelColor = Colors.orange;
    } else if (turnoverRate <= 1.5) {
      label = 'Normal';
      labelColor = Colors.blue;
    } else {
      label = 'Fast';
      labelColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: labelColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: labelColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: labelColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppFonts.sfProStyle(
              fontSize: fontSize - 1,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
        ],
      ),
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

    return Container(
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

  // Show report selection modal
  Future<Set<String>?> _showReportSelectionDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Set<String> selectedReports = {'All reports'};
    bool allReportsSelected = true;

    return await showDialog<Set<String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                    // Title
                    Text(
                      'Download Report',
                      style: AppFonts.sfProStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Report options
                    _buildReportOption(
                      context: context,
                      theme: theme,
                      isDark: isDark,
                      label: 'All reports',
                      isSelected: allReportsSelected,
                      onTap: () {
                        setState(() {
                          allReportsSelected = true;
                          selectedReports = {'All reports'};
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildReportOption(
                      context: context,
                      theme: theme,
                      isDark: isDark,
                      label: 'Inventory Check',
                      isSelected: !allReportsSelected &&
                          selectedReports.contains('Inventory Check'),
                      isDisabled: allReportsSelected,
                      onTap: () {
                        setState(() {
                          if (allReportsSelected) {
                            // Deselect "All reports" and select this option
                            allReportsSelected = false;
                            selectedReports = {'Inventory Check'};
                          } else {
                            // Toggle this option
                            if (selectedReports.contains('Inventory Check')) {
                              selectedReports.remove('Inventory Check');
                            } else {
                              selectedReports.add('Inventory Check');
                            }
                            selectedReports.remove('All reports');
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildReportOption(
                      context: context,
                      theme: theme,
                      isDark: isDark,
                      label: 'Purchase Order Summary',
                      isSelected: !allReportsSelected &&
                          selectedReports.contains('Purchase Order Summary'),
                      isDisabled: allReportsSelected,
                      onTap: () {
                        setState(() {
                          if (allReportsSelected) {
                            // Deselect "All reports" and select this option
                            allReportsSelected = false;
                            selectedReports = {'Purchase Order Summary'};
                          } else {
                            // Toggle this option
                            if (selectedReports
                                .contains('Purchase Order Summary')) {
                              selectedReports.remove('Purchase Order Summary');
                            } else {
                              selectedReports.add('Purchase Order Summary');
                            }
                            selectedReports.remove('All reports');
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildReportOption(
                      context: context,
                      theme: theme,
                      isDark: isDark,
                      label: 'Fast Moving Supply',
                      isSelected: !allReportsSelected &&
                          selectedReports.contains('Fast Moving Supply'),
                      isDisabled: allReportsSelected,
                      onTap: () {
                        setState(() {
                          if (allReportsSelected) {
                            // Deselect "All reports" and select this option
                            allReportsSelected = false;
                            selectedReports = {'Fast Moving Supply'};
                          } else {
                            // Toggle this option
                            if (selectedReports
                                .contains('Fast Moving Supply')) {
                              selectedReports.remove('Fast Moving Supply');
                            } else {
                              selectedReports.add('Fast Moving Supply');
                            }
                            selectedReports.remove('All reports');
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildReportOption(
                      context: context,
                      theme: theme,
                      isDark: isDark,
                      label: 'Usage Speed',
                      isSelected: !allReportsSelected &&
                          selectedReports.contains('Usage Speed'),
                      isDisabled: allReportsSelected,
                      onTap: () {
                        setState(() {
                          if (allReportsSelected) {
                            // Deselect "All reports" and select this option
                            allReportsSelected = false;
                            selectedReports = {'Usage Speed'};
                          } else {
                            // Toggle this option
                            if (selectedReports.contains('Usage Speed')) {
                              selectedReports.remove('Usage Speed');
                            } else {
                              selectedReports.add('Usage Speed');
                            }
                            selectedReports.remove('All reports');
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(null),
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
                              style: AppFonts.sfProStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (allReportsSelected) {
                                Navigator.of(context).pop({'All reports'});
                              } else if (selectedReports.isNotEmpty) {
                                Navigator.of(context).pop(selectedReports);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF107C10),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              'Confirm',
                              style: AppFonts.sfProStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
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
        );
      },
    );
  }

  Widget _buildReportOption({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return InkWell(
      onTap: onTap, // Always allow tap, let the callback handle the logic
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.grey[800] : Colors.grey[100])
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF107C10)
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDisabled
                      ? (isDark ? Colors.grey[700]! : Colors.grey[400]!)
                      : (isSelected
                          ? const Color(0xFF107C10)
                          : (isDark ? Colors.grey[600]! : Colors.grey[400]!)),
                  width: 2,
                ),
                color:
                    isSelected ? const Color(0xFF107C10) : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppFonts.sfProStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDisabled
                      ? (isDark ? Colors.grey[600] : Colors.grey[400])
                      : theme.textTheme.bodyMedium?.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // CSV Export Handler
  Future<void> _handleCSVExport(BuildContext context) async {
    // Show report selection dialog
    final selectedReports = await _showReportSelectionDialog(context);
    if (selectedReports == null || selectedReports.isEmpty) return;

    // Check connectivity before proceeding
    final hasConnection = await ConnectivityService().hasInternetConnection();
    if (!hasConnection) {
      if (context.mounted) {
        await showConnectionErrorDialog(context);
      }
      return;
    }

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

      // Generate CSV with selected sections
      final csvContent = _generateCSV(reportData, selectedReports);

      // Save file
      final filePath = await _saveFile(csvContent, 'csv');

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
    } catch (e) {
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
    // Show report selection dialog
    final selectedReports = await _showReportSelectionDialog(context);
    if (selectedReports == null || selectedReports.isEmpty) return;

    // Check connectivity before proceeding
    final hasConnection = await ConnectivityService().hasInternetConnection();
    if (!hasConnection) {
      if (context.mounted) {
        await showConnectionErrorDialog(context);
      }
      return;
    }

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

      // Generate PDF with selected sections
      final pdfBytes = await _generatePDF(reportData, selectedReports);

      // Save file
      final filePath = await _saveFile(pdfBytes, 'pdf');

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
    } catch (e) {
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

  // Fetch all supplies deducted within period with purpose and date
  Future<List<Map<String, dynamic>>> _fetchAllDeductionsWithDetails(
      String period) async {
    try {
      final dateRange = _getFixedDateRangeForPeriod(period);
      final startDate = dateRange['start']!;
      final endDate = dateRange['end']!;

      // Set end date to end of day (23:59:59) to include all records from that day
      final endDateWithTime =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

      final supabase = Supabase.instance.client;

      // Fetch all stock deduction logs within the fixed date range
      final logsResponse = await supabase
          .from('stock_deduction_logs')
          .select('id, purpose, supplies, created_at')
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDateWithTime.toIso8601String())
          .order('created_at', ascending: false);

      // Aggregate by supply name + brand (matching dashboard behavior)
      final Map<String, Map<String, dynamic>> aggregates = {};

      for (final log in logsResponse) {
        final purpose = (log['purpose']?.toString() ?? '').trim();
        final createdAtRaw = log['created_at']?.toString();
        DateTime? dateDeducted;
        if (createdAtRaw != null) {
          try {
            dateDeducted = DateTime.parse(createdAtRaw).toLocal();
          } catch (_) {
            // Ignore parse errors
          }
        }

        final supplies = log['supplies'] as List<dynamic>?;
        if (supplies != null) {
          for (final supply in supplies) {
            final supplyMap = supply as Map<String, dynamic>?;
            if (supplyMap != null) {
              final name = (supplyMap['name']?.toString() ?? '').trim();
              final brand = (supplyMap['brand']?.toString() ?? '').trim();
              final quantity =
                  supplyMap['deductQty'] ?? supplyMap['quantity'] ?? 0;
              final quantityInt = quantity is num
                  ? quantity.toInt()
                  : (int.tryParse(quantity.toString()) ?? 0);

              if (name.isNotEmpty) {
                // Create a key for aggregation (name + brand, case-insensitive)
                final key =
                    '${name.toLowerCase().trim()}|${brand.toLowerCase().trim()}';

                if (!aggregates.containsKey(key)) {
                  aggregates[key] = {
                    'name': name,
                    'brand': brand,
                    'purpose': purpose.isEmpty ? 'No Purpose' : purpose,
                    'dateDeducted': dateDeducted,
                    'quantityDeducted': quantityInt,
                  };
                } else {
                  final current = aggregates[key]!;
                  aggregates[key] = {
                    'name': name,
                    'brand': brand,
                    // Keep the most recent purpose and date
                    'purpose': purpose.isEmpty ? current['purpose'] : purpose,
                    'dateDeducted': dateDeducted != null &&
                            (current['dateDeducted'] == null ||
                                dateDeducted.isAfter(
                                    current['dateDeducted'] as DateTime))
                        ? dateDeducted
                        : current['dateDeducted'],
                    'quantityDeducted':
                        (current['quantityDeducted'] as int) + quantityInt,
                  };
                }
              }
            }
          }
        }
      }

      // Convert to list and sort by quantity deducted (descending) to match dashboard
      final List<Map<String, dynamic>> result = aggregates.values.toList();
      result.sort((a, b) => (b['quantityDeducted'] as int)
          .compareTo(a['quantityDeducted'] as int));

      return result;
    } catch (e) {
      return [];
    }
  }

  // Fetch all-time deductions (no date filter)
  Future<List<Map<String, dynamic>>> _fetchAllTimeDeductions() async {
    try {
      final supabase = Supabase.instance.client;

      // Fetch all stock deduction logs (no date filter)
      final logsResponse = await supabase
          .from('stock_deduction_logs')
          .select('id, purpose, supplies, created_at')
          .order('created_at', ascending: false);

      // Aggregate by supply name + brand (matching dashboard behavior)
      final Map<String, Map<String, dynamic>> aggregates = {};

      for (final log in logsResponse) {
        final purpose = (log['purpose']?.toString() ?? '').trim();
        final createdAtRaw = log['created_at']?.toString();
        DateTime? dateDeducted;
        if (createdAtRaw != null) {
          try {
            dateDeducted = DateTime.parse(createdAtRaw).toLocal();
          } catch (_) {
            // Ignore parse errors
          }
        }

        final supplies = log['supplies'] as List<dynamic>?;
        if (supplies != null) {
          for (final supply in supplies) {
            final supplyMap = supply as Map<String, dynamic>?;
            if (supplyMap != null) {
              final name = (supplyMap['name']?.toString() ?? '').trim();
              final brand = (supplyMap['brand']?.toString() ?? '').trim();
              final quantity =
                  supplyMap['deductQty'] ?? supplyMap['quantity'] ?? 0;
              final quantityInt = quantity is num
                  ? quantity.toInt()
                  : (int.tryParse(quantity.toString()) ?? 0);

              if (name.isNotEmpty) {
                // Create a key for aggregation (name + brand, case-insensitive)
                final key =
                    '${name.toLowerCase().trim()}|${brand.toLowerCase().trim()}';

                if (!aggregates.containsKey(key)) {
                  aggregates[key] = {
                    'name': name,
                    'brand': brand,
                    'purpose': purpose.isEmpty ? 'No Purpose' : purpose,
                    'dateDeducted': dateDeducted,
                    'quantityDeducted': quantityInt,
                  };
                } else {
                  final current = aggregates[key]!;
                  aggregates[key] = {
                    'name': name,
                    'brand': brand,
                    // Keep the most recent purpose and date
                    'purpose': purpose.isEmpty ? current['purpose'] : purpose,
                    'dateDeducted': dateDeducted != null &&
                            (current['dateDeducted'] == null ||
                                dateDeducted.isAfter(
                                    current['dateDeducted'] as DateTime))
                        ? dateDeducted
                        : current['dateDeducted'],
                    'quantityDeducted':
                        (current['quantityDeducted'] as int) + quantityInt,
                  };
                }
              }
            }
          }
        }
      }

      // Convert to list and sort by quantity deducted (descending)
      final List<Map<String, dynamic>> result = aggregates.values.toList();
      result.sort((a, b) => (b['quantityDeducted'] as int)
          .compareTo(a['quantityDeducted'] as int));

      return result;
    } catch (e) {
      return [];
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

    // Fetch deductions for weekly, monthly, and all-time periods
    final weeklyDeductions = await _fetchAllDeductionsWithDetails('Weekly');
    final monthlyDeductions = await _fetchAllDeductionsWithDetails('Monthly');
    final allTimeDeductions = await _fetchAllTimeDeductions();

    // Fetch usage speed data for monthly, quarterly, and yearly periods
    final monthlyTurnover =
        await _turnoverRateService.computeTurnoverItems('Monthly');
    final quarterlyTurnover =
        await _turnoverRateService.computeTurnoverItems('Quarterly');
    final yearlyTurnover =
        await _turnoverRateService.computeTurnoverItems('Yearly');

    // Convert usage speed items to serializable format
    final monthlyTurnoverData = monthlyTurnover
        .map((item) => {
              'name': item.name,
              'brand': item.brand,
              'quantityConsumed': item.quantityConsumed,
              'currentStock': item.currentStock,
              'averageStock': item.averageStock,
              'turnoverRate': item.turnoverRate,
            })
        .toList();

    final quarterlyTurnoverData = quarterlyTurnover
        .map((item) => {
              'name': item.name,
              'brand': item.brand,
              'quantityConsumed': item.quantityConsumed,
              'currentStock': item.currentStock,
              'averageStock': item.averageStock,
              'turnoverRate': item.turnoverRate,
            })
        .toList();

    final yearlyTurnoverData = yearlyTurnover
        .map((item) => {
              'name': item.name,
              'brand': item.brand,
              'quantityConsumed': item.quantityConsumed,
              'currentStock': item.currentStock,
              'averageStock': item.averageStock,
              'turnoverRate': item.turnoverRate,
            })
        .toList();

    return {
      'supplyCounts': supplyCounts,
      'expiryCounts': expiryCounts,
      'poCounts': poCounts,
      'suppliesByStatus': suppliesByStatus,
      'purchaseOrdersByStatus': purchaseOrdersByStatus,
      'weeklyDeductions': weeklyDeductions,
      'monthlyDeductions': monthlyDeductions,
      'allTimeDeductions': allTimeDeductions,
      'monthlyTurnover': monthlyTurnoverData,
      'quarterlyTurnover': quarterlyTurnoverData,
      'yearlyTurnover': yearlyTurnoverData,
      'selectedPeriod': _selectedPeriod,
      'generatedAt': DateTime.now(),
    };
  }

  // Generate CSV content
  String _generateCSV(Map<String, dynamic> data, Set<String> selectedReports) {
    final rows = <List<dynamic>>[];
    final includeAll = selectedReports.contains('All reports');
    final includeInventory =
        includeAll || selectedReports.contains('Inventory Check');
    final includePO =
        includeAll || selectedReports.contains('Purchase Order Summary');
    final includeFastMoving =
        includeAll || selectedReports.contains('Fast Moving Supply');
    final includeTurnoverRate =
        includeAll || selectedReports.contains('Turnover Rate');

    // Header
    rows.add(['Dashboard Report']);
    rows.add(
        ['Generated at: ${_formatDateTime(data['generatedAt'] as DateTime)}']);
    rows.add([]);

    // Supply Counts by Status - Detailed Tables
    if (includeInventory) {
      final suppliesByStatus =
          data['suppliesByStatus'] as Map<String, List<Map<String, dynamic>>>;
      final statuses = [
        'In Stock',
        'Low Stock',
        'Out of Stock',
        'Expiring',
        'Expired'
      ];

      rows.add(['Supply Count']);
      rows.add([]);

      for (final status in statuses) {
        final supplies = suppliesByStatus[status] ?? [];
        rows.add([status]);
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
            final costValue = supply['cost'];
            final formattedCost = costValue is num
                ? costValue.toStringAsFixed(2)
                : double.tryParse((costValue ?? '').toString())
                        ?.toStringAsFixed(2) ??
                    '0.00';

            rows.add([
              supply['displayName'] ?? supply['name'] ?? '',
              supply['stock'] ?? 0,
              supply['packagingUnit'] ?? '',
              supply['packagingContent'] ?? '',
              supply['brand'] ?? 'N/A',
              supply['supplier'] ?? 'N/A',
              formattedCost,
              supply['expiryDisplay'] ?? 'No expiry',
            ]);
          }
        }
        rows.add([]);
      }
    }

    // Purchase Order Summary by Status - Detailed Tables
    if (includePO) {
      final purchaseOrdersByStatus = data['purchaseOrdersByStatus']
          as Map<String, List<Map<String, dynamic>>>;
      final poStatuses = ['Open', 'Partial', 'Approval', 'Closed'];

      rows.add(['Purchase Order Summary']);
      rows.add([]);

      for (final status in poStatuses) {
        final orders = purchaseOrdersByStatus[status] ?? [];
        rows.add([status]);
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
            final suppliesCount = order['suppliesCount'];
            final formattedSuppliesCount = suppliesCount is num
                ? suppliesCount.toString()
                : suppliesCount?.toString() ?? '0';

            rows.add([
              order['code'] ?? '',
              order['supplierName'] ?? 'N/A',
              formattedSuppliesCount,
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
    }

    // Fast Moving Supply - Three sections: Weekly, Monthly, All-time
    if (includeFastMoving) {
      rows.add(['Fast Moving Supply']);
      rows.add([]);

      // Weekly Deduction Section
      final weeklyDateRange = _getDateRangeForPeriod('Weekly');
      rows.add(['Weekly Deduction']);
      rows.add(['Period', weeklyDateRange]);
      rows.add([
        'Supply Name',
        'Brand',
        'Purpose',
        'Quantity Deducted',
        'Date Deducted'
      ]);
      final weeklyDeductions = data['weeklyDeductions'] as List<dynamic>;
      if (weeklyDeductions.isEmpty) {
        rows.add(['No deductions found for this period']);
      } else {
        for (final item in weeklyDeductions) {
          final itemMap = item as Map<String, dynamic>;
          final name = itemMap['name']?.toString() ?? '';
          final brand = itemMap['brand']?.toString() ?? '';
          final purpose = itemMap['purpose']?.toString() ?? 'No Purpose';
          final quantityDeducted = itemMap['quantityDeducted'] ?? 0;
          final dateDeducted = itemMap['dateDeducted'] as DateTime?;
          final dateStr = dateDeducted != null
              ? _formatDateTimeWithAMPM(dateDeducted)
              : 'N/A';

          rows.add([
            name,
            brand,
            purpose,
            quantityDeducted.toString(),
            dateStr,
          ]);
        }
      }
      rows.add([]);

      // Monthly Deduction Section
      final monthlyDateRange = _getDateRangeForPeriod('Monthly');
      rows.add(['Monthly Deduction']);
      rows.add(['Period', monthlyDateRange]);
      rows.add([
        'Supply Name',
        'Brand',
        'Purpose',
        'Quantity Deducted',
        'Date Deducted'
      ]);
      final monthlyDeductions = data['monthlyDeductions'] as List<dynamic>;
      if (monthlyDeductions.isEmpty) {
        rows.add(['No deductions found for this period']);
      } else {
        for (final item in monthlyDeductions) {
          final itemMap = item as Map<String, dynamic>;
          final name = itemMap['name']?.toString() ?? '';
          final brand = itemMap['brand']?.toString() ?? '';
          final purpose = itemMap['purpose']?.toString() ?? 'No Purpose';
          final quantityDeducted = itemMap['quantityDeducted'] ?? 0;
          final dateDeducted = itemMap['dateDeducted'] as DateTime?;
          final dateStr = dateDeducted != null
              ? _formatDateTimeWithAMPM(dateDeducted)
              : 'N/A';

          rows.add([
            name,
            brand,
            purpose,
            quantityDeducted.toString(),
            dateStr,
          ]);
        }
      }
      rows.add([]);

      // All-time Deduction Section
      rows.add(['All-time Deduction']);
      rows.add(['Period', 'All time']);
      rows.add([
        'Supply Name',
        'Brand',
        'Purpose',
        'Quantity Deducted',
        'Date Deducted'
      ]);
      final allTimeDeductions = data['allTimeDeductions'] as List<dynamic>;
      if (allTimeDeductions.isEmpty) {
        rows.add(['No deductions found']);
      } else {
        for (final item in allTimeDeductions) {
          final itemMap = item as Map<String, dynamic>;
          final name = itemMap['name']?.toString() ?? '';
          final brand = itemMap['brand']?.toString() ?? '';
          final purpose = itemMap['purpose']?.toString() ?? 'No Purpose';
          final quantityDeducted = itemMap['quantityDeducted'] ?? 0;
          final dateDeducted = itemMap['dateDeducted'] as DateTime?;
          final dateStr = dateDeducted != null
              ? _formatDateTimeWithAMPM(dateDeducted)
              : 'N/A';

          rows.add([
            name,
            brand,
            purpose,
            quantityDeducted.toString(),
            dateStr,
          ]);
        }
      }
    }

    // Usage Speed - Monthly, Quarterly, Yearly sections
    if (includeTurnoverRate) {
      rows.add(['Usage Speed']);
      rows.add([]);

      // Monthly Usage Speed Section
      rows.add(['Monthly Usage Speed']);
      rows.add(['Period', 'Last 30 days']);
      rows.add([
        'Supply Name',
        'Brand',
        'Quantity Consumed',
        'Current Stock',
        'Opening Stock',
        'Average Stock',
        'Usage Speed'
      ]);
      final monthlyTurnover = (data['monthlyTurnover'] as List<dynamic>?) ?? [];
      if (monthlyTurnover.isEmpty) {
        rows.add(['No usage data found for this period']);
      } else {
        for (final item in monthlyTurnover) {
          final itemMap = item as Map<String, dynamic>;
          final name = itemMap['name']?.toString() ?? '';
          final brand = itemMap['brand']?.toString() ?? '';
          final quantityConsumed = (itemMap['quantityConsumed'] ?? 0) as int;
          final currentStock = (itemMap['currentStock'] ?? 0) as int;
          final averageStock = (itemMap['averageStock'] ?? 0.0) as double;
          final turnoverRate = (itemMap['turnoverRate'] ?? 0.0) as double;
          final openingStock = currentStock + quantityConsumed;

          rows.add([
            name,
            brand.isNotEmpty ? brand : 'N/A',
            quantityConsumed.toString(),
            currentStock.toString(),
            openingStock.toString(),
            averageStock.toStringAsFixed(2),
            turnoverRate.toStringAsFixed(2),
          ]);
        }
      }
      rows.add([]);

      // Quarterly Usage Speed Section
      rows.add(['Quarterly Usage Speed']);
      rows.add(['Period', 'Last 3 months']);
      rows.add([
        'Supply Name',
        'Brand',
        'Quantity Consumed',
        'Current Stock',
        'Opening Stock',
        'Average Stock',
        'Usage Speed'
      ]);
      final quarterlyTurnover =
          (data['quarterlyTurnover'] as List<dynamic>?) ?? [];
      if (quarterlyTurnover.isEmpty) {
        rows.add(['No usage data found for this period']);
      } else {
        for (final item in quarterlyTurnover) {
          final itemMap = item as Map<String, dynamic>;
          final name = itemMap['name']?.toString() ?? '';
          final brand = itemMap['brand']?.toString() ?? '';
          final quantityConsumed = (itemMap['quantityConsumed'] ?? 0) as int;
          final currentStock = (itemMap['currentStock'] ?? 0) as int;
          final averageStock = (itemMap['averageStock'] ?? 0.0) as double;
          final turnoverRate = (itemMap['turnoverRate'] ?? 0.0) as double;
          final openingStock = currentStock + quantityConsumed;

          rows.add([
            name,
            brand.isNotEmpty ? brand : 'N/A',
            quantityConsumed.toString(),
            currentStock.toString(),
            openingStock.toString(),
            averageStock.toStringAsFixed(2),
            turnoverRate.toStringAsFixed(2),
          ]);
        }
      }
      rows.add([]);

      // Yearly Usage Speed Section
      rows.add(['Yearly Usage Speed']);
      rows.add(['Period', 'Last 12 months']);
      rows.add([
        'Supply Name',
        'Brand',
        'Quantity Consumed',
        'Current Stock',
        'Opening Stock',
        'Average Stock',
        'Usage Speed'
      ]);
      final yearlyTurnover = (data['yearlyTurnover'] as List<dynamic>?) ?? [];
      if (yearlyTurnover.isEmpty) {
        rows.add(['No usage data found']);
      } else {
        for (final item in yearlyTurnover) {
          final itemMap = item as Map<String, dynamic>;
          final name = itemMap['name']?.toString() ?? '';
          final brand = itemMap['brand']?.toString() ?? '';
          final quantityConsumed = (itemMap['quantityConsumed'] ?? 0) as int;
          final currentStock = (itemMap['currentStock'] ?? 0) as int;
          final averageStock = (itemMap['averageStock'] ?? 0.0) as double;
          final turnoverRate = (itemMap['turnoverRate'] ?? 0.0) as double;
          final openingStock = currentStock + quantityConsumed;

          rows.add([
            name,
            brand.isNotEmpty ? brand : 'N/A',
            quantityConsumed.toString(),
            currentStock.toString(),
            openingStock.toString(),
            averageStock.toStringAsFixed(2),
            turnoverRate.toStringAsFixed(2),
          ]);
        }
      }
    }

    // Convert to CSV string
    return const ListToCsvConverter().convert(rows);
  }

  // Generate PDF
  Future<List<int>> _generatePDF(
      Map<String, dynamic> data, Set<String> selectedReports) async {
    final pdf = pw.Document();
    final includeAll = selectedReports.contains('All reports');
    final includeInventory =
        includeAll || selectedReports.contains('Inventory Check');
    final includePO =
        includeAll || selectedReports.contains('Purchase Order Summary');
    final includeFastMoving =
        includeAll || selectedReports.contains('Fast Moving Supply');
    final includeTurnoverRate =
        includeAll || selectedReports.contains('Turnover Rate');

    final suppliesByStatus =
        data['suppliesByStatus'] as Map<String, List<Map<String, dynamic>>>;
    final purchaseOrdersByStatus = data['purchaseOrdersByStatus']
        as Map<String, List<Map<String, dynamic>>>;
    final weeklyDeductions = data['weeklyDeductions'] as List;
    final monthlyDeductions = data['monthlyDeductions'] as List;
    final allTimeDeductions = data['allTimeDeductions'] as List;
    final monthlyTurnover = (data['monthlyTurnover'] as List<dynamic>?) ?? [];
    final quarterlyTurnover =
        (data['quarterlyTurnover'] as List<dynamic>?) ?? [];
    final yearlyTurnover = (data['yearlyTurnover'] as List<dynamic>?) ?? [];
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
          if (includeInventory) {
            final statuses = [
              'In Stock',
              'Low Stock',
              'Out of Stock',
              'Expiring',
              'Expired'
            ];

            widgets.add(
              pw.Text(
                'Supply Count',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 12));

            for (final status in statuses) {
              final supplies = suppliesByStatus[status] ?? [];
              widgets.add(
                pw.Text(
                  status,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 8));

              if (supplies.isEmpty) {
                widgets.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Text('No supplies found',
                        style: const pw.TextStyle(fontSize: 10)),
                  ),
                );
              } else {
                widgets.add(
                  pw.Table(
                    border: pw.TableBorder.all(width: 0.5),
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
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFEFEFEF),
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Supply Name',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Quantity',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Packaging Unit',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Packaging Content',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Brand Name',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Supplier Name',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Cost',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Expiry Date',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      ...supplies.map((supply) {
                        final costValue = supply['cost'];
                        final formattedCost = costValue is num
                            ? costValue.toStringAsFixed(2)
                            : double.tryParse((costValue ?? '').toString())
                                    ?.toStringAsFixed(2) ??
                                '0.00';

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
                              child: pw.Text(formattedCost,
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
              widgets.add(pw.SizedBox(height: 16));
            }

            widgets.add(pw.SizedBox(height: 24));
          }

          // Purchase Order Summary by Status - Detailed Tables
          if (includePO) {
            final poStatuses = ['Open', 'Partial', 'Approval', 'Closed'];

            widgets.add(
              pw.Text(
                'Purchase Order Summary',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 12));

            for (final status in poStatuses) {
              final orders = purchaseOrdersByStatus[status] ?? [];
              widgets.add(
                pw.Text(
                  status,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 8));

              if (orders.isEmpty) {
                widgets.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Text('No purchase orders found',
                        style: const pw.TextStyle(fontSize: 10)),
                  ),
                );
              } else {
                widgets.add(
                  pw.Table(
                    border: pw.TableBorder.all(width: 0.5),
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
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFEFEFEF),
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('ID',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Supplier Name',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Supplies',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Expiry Date',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Date Created',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Date Received',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Receipt No.',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Recipient',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Remarks',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      ...orders.map((order) {
                        final suppliesCount = order['suppliesCount'];
                        final formattedSuppliesCount = suppliesCount is num
                            ? suppliesCount.toString()
                            : suppliesCount?.toString() ?? '0';

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
                              child: pw.Text(formattedSuppliesCount,
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
              widgets.add(pw.SizedBox(height: 16));
            }

            widgets.add(pw.SizedBox(height: 24));
          }

          // Fast Moving Supply - Three sections: Weekly, Monthly, All-time
          if (includeFastMoving) {
            widgets.add(
              pw.Text(
                'Fast Moving Supply',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 12));

            // Helper function to build deduction table
            void buildDeductionTable(
                String title, String periodLabel, List deductions) {
              widgets.add(
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 8));
              widgets.add(
                pw.Text(
                  'Period: $periodLabel',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 8));

              if (deductions.isEmpty) {
                widgets.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Text('No deductions found for this period',
                        style: const pw.TextStyle(fontSize: 10)),
                  ),
                );
              } else {
                widgets.add(
                  pw.Table(
                    border: pw.TableBorder.all(width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2.5),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FlexColumnWidth(1),
                      4: const pw.FlexColumnWidth(1.5),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFEFEFEF),
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Supply Name',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Brand',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Purpose',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Quantity Deducted',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Date Deducted',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      ...deductions.map((item) {
                        final itemMap = item as Map<String, dynamic>;
                        final name = itemMap['name']?.toString() ?? '';
                        final brand = itemMap['brand']?.toString() ?? '';
                        final purpose =
                            itemMap['purpose']?.toString() ?? 'No Purpose';
                        final quantityDeducted =
                            itemMap['quantityDeducted'] ?? 0;
                        final dateDeducted =
                            itemMap['dateDeducted'] as DateTime?;
                        final dateStr = dateDeducted != null
                            ? _formatDateTimeWithAMPM(dateDeducted)
                            : 'N/A';

                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(name,
                                  style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(brand,
                                  style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(purpose,
                                  style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(quantityDeducted.toString(),
                                  style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(dateStr,
                                  style: const pw.TextStyle(fontSize: 8)),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                );
              }
              widgets.add(pw.SizedBox(height: 24));
            }

            // Weekly Deduction Section
            final weeklyDateRange = _getDateRangeForPeriod('Weekly');
            buildDeductionTable(
                'Weekly Deduction', weeklyDateRange, weeklyDeductions);

            // Monthly Deduction Section
            final monthlyDateRange = _getDateRangeForPeriod('Monthly');
            buildDeductionTable(
                'Monthly Deduction', monthlyDateRange, monthlyDeductions);

            // All-time Deduction Section
            buildDeductionTable(
                'All-time Deduction', 'All time', allTimeDeductions);
          }

          // Usage Speed - Monthly, Quarterly, Yearly sections
          if (includeTurnoverRate) {
            widgets.add(
              pw.Text(
                'Usage Speed',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 12));

            // Helper function to build usage speed table
            void buildUsageSpeedTable(
                String title, String periodLabel, List usageData) {
              widgets.add(
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 8));
              widgets.add(
                pw.Text(
                  'Period: $periodLabel',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 8));

              if (usageData.isEmpty) {
                widgets.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Text('No usage data found for this period',
                        style: const pw.TextStyle(fontSize: 10)),
                  ),
                );
              } else {
                widgets.add(
                  pw.Table(
                    border: pw.TableBorder.all(width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2.5),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(1),
                      3: const pw.FlexColumnWidth(1),
                      4: const pw.FlexColumnWidth(1),
                      5: const pw.FlexColumnWidth(1.2),
                      6: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                          color: PdfColor.fromInt(0xFFEFEFEF),
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Supply Name',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Brand',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Qty Consumed',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Current Stock',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Opening Stock',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Average Stock',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('Usage Speed',
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      ...usageData.map((item) {
                        final itemMap = item as Map<String, dynamic>;
                        final name = itemMap['name']?.toString() ?? '';
                        final brand = itemMap['brand']?.toString() ?? '';
                        final quantityConsumed =
                            (itemMap['quantityConsumed'] ?? 0) as int;
                        final currentStock =
                            (itemMap['currentStock'] ?? 0) as int;
                        final averageStock =
                            (itemMap['averageStock'] ?? 0.0) as double;
                        final turnoverRate =
                            (itemMap['turnoverRate'] ?? 0.0) as double;
                        final openingStock = currentStock + quantityConsumed;

                        return pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(name,
                                  style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(brand.isNotEmpty ? brand : 'N/A',
                                  style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(quantityConsumed.toString(),
                                  style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(currentStock.toString(),
                                  style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(openingStock.toString(),
                                  style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(averageStock.toStringAsFixed(2),
                                  style: const pw.TextStyle(fontSize: 8)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(turnoverRate.toStringAsFixed(2),
                                  style: const pw.TextStyle(fontSize: 8)),
                            ),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                );
              }
              widgets.add(pw.SizedBox(height: 24));
            }

            // Monthly Usage Speed Section
            buildUsageSpeedTable(
                'Monthly Usage Speed', 'Last 30 days', monthlyTurnover);

            // Quarterly Usage Speed Section
            buildUsageSpeedTable(
                'Quarterly Usage Speed', 'Last 3 months', quarterlyTurnover);

            // Yearly Usage Speed Section
            buildUsageSpeedTable(
                'Yearly Usage Speed', 'Last 12 months', yearlyTurnover);
          }

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

          return file.path;
        }
      } catch (e) {
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
        // Share not available, file saved to app documents
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

      return file.path;
    }
  }

  // Format datetime for display
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  // Format datetime with AM/PM for reports
  String _formatDateTimeWithAMPM(DateTime dateTime) {
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');

    int hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';

    if (hour == 0) {
      hour = 12;
    } else if (hour > 12) {
      hour = hour - 12;
    }

    final hourStr = hour.toString();

    return '$year-$month-$day $hourStr:$minute $period';
  }

  // Format datetime for filename
  String _formatFileDateTime(DateTime dateTime) {
    return '${dateTime.year}${dateTime.month.toString().padLeft(2, '0')}${dateTime.day.toString().padLeft(2, '0')}_${dateTime.hour.toString().padLeft(2, '0')}${dateTime.minute.toString().padLeft(2, '0')}${dateTime.second.toString().padLeft(2, '0')}';
  }
}

class _RailDestination {
  final IconData icon;
  final String label;
  final String route;

  _RailDestination(
      {required this.icon, required this.label, required this.route});
}
