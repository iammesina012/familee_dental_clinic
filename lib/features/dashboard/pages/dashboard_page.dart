import 'package:flutter/material.dart';
import 'package:familee_dental/shared/drawer.dart';
import 'package:familee_dental/features/dashboard/services/inventory_analytics_service.dart';
import 'package:familee_dental/features/dashboard/services/fast_moving_service.dart';
import 'package:familee_dental/features/inventory/pages/expired_supply_page.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/widgets/notification_badge_button.dart';
import 'package:shimmer/shimmer.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  final List<Map<String, dynamic>> dashboardCards = [
    {"title": "Low Stock", "color": Colors.yellow[400]},
    {"title": "Out of Stock", "color": Colors.red[400]},
    {"title": "Expiring", "color": Colors.orange[400]},
  ];

  final InventoryAnalyticsService _analyticsService =
      InventoryAnalyticsService();
  final FastMovingService _fastMovingService = FastMovingService();

  AnimationController? _inventoryCardController;
  Animation<double>? _animation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    // Dashboard access logging removed for now
  }

  void _initializeAnimation() {
    _inventoryCardController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
          parent: _inventoryCardController!, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _inventoryCardController?.forward();
      }
    });
  }

  @override
  void dispose() {
    _inventoryCardController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Dashboard",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: theme.appBarTheme.elevation,
        shadowColor: theme.appBarTheme.shadowColor,
        actions: [
          const NotificationBadgeButton(),
        ],
      ),
      drawer: const MyDrawer(),
      body: _buildDashboardContent(theme),
    );
  }

  Widget _buildDashboardContent(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: () async {
        // Trigger refresh by rebuilding the widget
        setState(() {});
        // Wait for the main stream to emit at least one event
        // This ensures the RefreshIndicator shows its animation
        await _analyticsService.getInventoryStatsStream().first;
      },
      child: ResponsiveContainer(
        maxWidth: 1000,
        child: Padding(
          padding: EdgeInsets.all(
              MediaQuery.of(context).size.width < 768 ? 8.0 : 16.0),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Inventory Check Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: EdgeInsets.zero,
                color: theme.colorScheme.surface,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with title and analysis link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Inventory check",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/inventory');
                            },
                            child: Row(
                              children: [
                                Text(
                                  "View",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 12,
                                  color: theme.iconTheme.color,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Separate Percentage Rectangles with Animation
                      StreamBuilder<Map<String, dynamic>>(
                        stream: _analyticsService.getInventoryStatsStream(),
                        builder: (context, snapshot) {
                          // Only show loading state on first load, not on refresh
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
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
                                      height: 32,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          final stats = snapshot.data ??
                              {
                                'inStockPercentage': 0,
                                'lowStockPercentage': 0,
                                'outOfStockPercentage': 0,
                              };

                          final inStockPercentage =
                              stats['inStockPercentage'] as int;
                          final lowStockPercentage =
                              stats['lowStockPercentage'] as int;
                          final outOfStockPercentage =
                              stats['outOfStockPercentage'] as int;

                          // Cache width calculations outside of AnimatedBuilder
                          // Use LayoutBuilder to get the actual available width
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final totalWidth = constraints.maxWidth;
                              final gapCount = (inStockPercentage > 0 &&
                                          lowStockPercentage > 0
                                      ? 1
                                      : 0) +
                                  (lowStockPercentage > 0 &&
                                          outOfStockPercentage > 0
                                      ? 1
                                      : 0);
                              final availableWidth =
                                  totalWidth - (4.0 * gapCount);
                              final totalPercentage = inStockPercentage +
                                  lowStockPercentage +
                                  outOfStockPercentage;
                              final scaleFactor = totalPercentage > 0
                                  ? 100.0 / totalPercentage
                                  : 1.0;

                              return AnimatedBuilder(
                                animation: _animation ??
                                    const AlwaysStoppedAnimation(0.5),
                                builder: (context, child) {
                                  final currentMultiplier =
                                      _animation?.value ?? 0.5;

                                  return Row(
                                    children: [
                                      // In Stock Rectangle (Green)
                                      if (inStockPercentage > 0)
                                        Builder(
                                          builder: (context) {
                                            final barWidth = availableWidth *
                                                (inStockPercentage *
                                                    scaleFactor /
                                                    100) *
                                                currentMultiplier;
                                            // final isNarrow = barWidth < 50;
                                            // final isVeryNarrow = barWidth < 30;

                                            return AnimatedContainer(
                                              duration:
                                                  Duration(milliseconds: 200),
                                              width: barWidth,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Color(0xFF1ACB5D),
                                                    Color(0xFF99D711)
                                                  ],
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                ),
                                              ),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Padding(
                                                  padding:
                                                      EdgeInsets.only(left: 4),
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 4,
                                                            vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.3),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                      border: Border.all(
                                                        color: Colors.black
                                                            .withOpacity(0.4),
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      "${(inStockPercentage * currentMultiplier).round()}%",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      if (inStockPercentage > 0 &&
                                          lowStockPercentage > 0)
                                        const SizedBox(width: 4),
                                      // Low Stock Rectangle (Orange)
                                      if (lowStockPercentage > 0)
                                        Builder(
                                          builder: (context) {
                                            final barWidth = availableWidth *
                                                (lowStockPercentage *
                                                    scaleFactor /
                                                    100) *
                                                currentMultiplier;
                                            // final isNarrow = barWidth < 50;
                                            // final isVeryNarrow = barWidth < 30;

                                            return AnimatedContainer(
                                              duration:
                                                  Duration(milliseconds: 200),
                                              width: barWidth,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Color(0xFFDEA805),
                                                    Color(0xFFF77436)
                                                  ],
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                ),
                                              ),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Padding(
                                                  padding:
                                                      EdgeInsets.only(left: 4),
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 4,
                                                            vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.3),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                      border: Border.all(
                                                        color: Colors.black
                                                            .withOpacity(0.4),
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      "${(lowStockPercentage * currentMultiplier).round()}%",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      if (lowStockPercentage > 0 &&
                                          outOfStockPercentage > 0)
                                        const SizedBox(width: 4),
                                      // Out of Stock Rectangle (Red)
                                      if (outOfStockPercentage > 0)
                                        Builder(
                                          builder: (context) {
                                            final barWidth = availableWidth *
                                                (outOfStockPercentage *
                                                    scaleFactor /
                                                    100) *
                                                currentMultiplier;
                                            // final isNarrow = barWidth < 50;
                                            // final isVeryNarrow = barWidth < 30;

                                            return AnimatedContainer(
                                              duration:
                                                  Duration(milliseconds: 200),
                                              width: barWidth,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Color(0xFFE44B4D),
                                                    Color(0xFFE02180)
                                                  ],
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                ),
                                              ),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Padding(
                                                  padding:
                                                      EdgeInsets.only(left: 4),
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 4,
                                                            vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.3),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                      border: Border.all(
                                                        color: Colors.black
                                                            .withOpacity(0.4),
                                                        width: 0.5,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      "${(outOfStockPercentage * currentMultiplier).round()}%",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 9,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Legend
                      Row(
                        children: [
                          // In Stock Legend
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF1ACB5D),
                                      Color(0xFF99D711),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "In stock",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: theme.textTheme.bodyMedium?.color,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Low Stock Legend
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFDEA805),
                                      Color(0xFFF77436),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Low stock",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: theme.textTheme.bodyMedium?.color,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Out of Stock Legend
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFE44B4D),
                                      Color(0xFFE02180),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Out of stock",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: theme.textTheme.bodyMedium?.color,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Expired / Expiring mini-cards
              StreamBuilder<Map<String, int>>(
                stream: _analyticsService.getExpiryCountsStream(),
                builder: (context, snapshot) {
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
                          icon: Icons.warning_amber_rounded,
                          accentColor: Colors.red,
                          height: 96,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildExpiryCard(
                          context: context,
                          count: expiring,
                          label: 'Expiring',
                          icon: Icons.timer_outlined,
                          accentColor: Colors.orange,
                          height: 96,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 12),

              // Fast Moving Supply
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: EdgeInsets.zero,
                color: theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fast Moving Supply',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                          Text(
                            'Last 3 months',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 4),
                      StreamBuilder<List<FastMovingItem>>(
                        stream: _fastMovingService.streamTopFastMovingItems(
                          limit: 5,
                          window: const Duration(days: 90),
                        ),
                        builder: (context, snapshot) {
                          // Show skeleton loader on first load
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final baseColor =
                                isDark ? Colors.grey[800]! : Colors.grey[300]!;
                            final highlightColor =
                                isDark ? Colors.grey[700]! : Colors.grey[100]!;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                children: List.generate(
                                  3,
                                  (index) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 6),
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
                              padding: const EdgeInsets.symmetric(vertical: 12),
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

                          return Column(
                            children: [
                              for (int i = 0; i < items.length; i++)
                                _FastMovingRow(index: i + 1, item: items[i]),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpiryCard({
    required BuildContext context,
    required int count,
    required String label,
    required IconData icon,
    required Color accentColor,
    double height = 88,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
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
          constraints: BoxConstraints(minHeight: height),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FastMovingRow extends StatelessWidget {
  final int index;
  final FastMovingItem item;
  const _FastMovingRow({required this.index, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Index
          SizedBox(
            width: 24,
            child: Text(
              '$index.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
          // Name and brand
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                if (item.brand.isNotEmpty)
                  Text(
                    item.brand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
              ],
            ),
          ),
          // Times deducted pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'x${item.timesDeducted}',
              style: const TextStyle(
                color: Color(0xFFFB8C00),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
