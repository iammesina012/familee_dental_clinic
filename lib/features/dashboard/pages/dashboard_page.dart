import 'package:flutter/material.dart';
import 'package:projects/shared/drawer.dart';
import 'package:projects/features/dashboard/services/inventory_analytics_service.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF9EFF2),
      appBar: AppBar(
        title: const Text(
          "Dashboard",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        toolbarHeight: 70,
        iconTheme: const IconThemeData(size: 30, color: Colors.black),
        elevation: 5,
        shadowColor: Colors.black54,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.red,
                size: 30,
              ),
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.pushNamed(context, '/notifications');
              },
            ),
          ),
        ],
      ),
      drawer: const MyDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Inventory Check Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              color: Colors.white,
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
                            color: Colors.black,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              "Analysis",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Separate Percentage Rectangles with Animation
                    StreamBuilder<Map<String, dynamic>>(
                      stream: _analyticsService.getInventoryStatsStream(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 32,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: Colors.grey[300],
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.grey[600]!),
                                      ),
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
                        final totalWidth =
                            MediaQuery.of(context).size.width - 80;
                        final gapCount = (inStockPercentage > 0 &&
                                    lowStockPercentage > 0
                                ? 1
                                : 0) +
                            (lowStockPercentage > 0 && outOfStockPercentage > 0
                                ? 1
                                : 0);
                        final availableWidth = totalWidth - (4.0 * gapCount);
                        final totalPercentage = inStockPercentage +
                            lowStockPercentage +
                            outOfStockPercentage;
                        final scaleFactor =
                            totalPercentage > 0 ? 100.0 / totalPercentage : 1.0;

                        return AnimatedBuilder(
                          animation:
                              _animation ?? const AlwaysStoppedAnimation(0.5),
                          builder: (context, child) {
                            final currentMultiplier = _animation?.value ?? 0.5;

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
                                      final isNarrow = barWidth < 50;
                                      final isVeryNarrow = barWidth < 30;

                                      return AnimatedContainer(
                                        duration: Duration(milliseconds: 200),
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
                                            padding: EdgeInsets.only(left: 4),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.3),
                                                borderRadius:
                                                    BorderRadius.circular(4),
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
                                                  fontWeight: FontWeight.bold,
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
                                      final isNarrow = barWidth < 50;
                                      final isVeryNarrow = barWidth < 30;

                                      return AnimatedContainer(
                                        duration: Duration(milliseconds: 200),
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
                                            padding: EdgeInsets.only(left: 4),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.3),
                                                borderRadius:
                                                    BorderRadius.circular(4),
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
                                                  fontWeight: FontWeight.bold,
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
                                      final isNarrow = barWidth < 50;
                                      final isVeryNarrow = barWidth < 30;

                                      return AnimatedContainer(
                                        duration: Duration(milliseconds: 200),
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
                                            padding: EdgeInsets.only(left: 4),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.3),
                                                borderRadius:
                                                    BorderRadius.circular(4),
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
                                                  fontWeight: FontWeight.bold,
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
                                color: Colors.black,
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
                                color: Colors.black,
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
                                color: Colors.black,
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

            const SizedBox(height: 20),

            // COMMENTED OUT EXISTING DESIGN
            /*
            ...dashboardCards.map((card) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: DashboardCard(
                    title: card['title'],
                    color: card['color'],
                  ),
                )),
            const SizedBox(height: 10),
            const FastMovingItemsCard(),
            */
          ],
        ),
      ),
    );
  }
}
