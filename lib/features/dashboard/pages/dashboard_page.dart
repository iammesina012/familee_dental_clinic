import 'package:flutter/material.dart';
import 'package:projects/shared/drawer.dart';
import 'package:projects/features/dashboard/components/dashboard_card.dart'; // import here
import 'package:projects/features/dashboard/components/dashboard_fmic.dart'; // import here

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
                // Notification logic here
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
            ...dashboardCards.map((card) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: DashboardCard(
                    title: card['title'],
                    color: card['color'],
                  ),
                )),
            const SizedBox(height: 10),
            const FastMovingItemsCard(),
          ],
        ),
      ),
    );
  }
}
