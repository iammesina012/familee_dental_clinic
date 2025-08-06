import 'package:flutter/material.dart';

class FastMovingItemsCard extends StatelessWidget {
  const FastMovingItemsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        height: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Fast Moving Items",
              style: TextStyle(
                fontSize: 20,
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Spacer(),
                Text(
                  "No. of times used:",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
