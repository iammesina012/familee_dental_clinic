import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final Color? color;

  const DashboardCard({
    super.key,
    required this.title,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: Colors.black26,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 75,
            decoration: BoxDecoration(
              color: color ?? Colors.grey[300],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: 170,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
