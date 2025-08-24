import 'package:flutter/material.dart';

class InventorySortModal extends StatelessWidget {
  final String? selected;
  final void Function(String) onSelect;
  const InventorySortModal({super.key, this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final sortOptions = [
      "Name (A → Z)",
      "Name (Z → A)",
      "Quantity (Low → High)",
      "Quantity (High → Low)",
      "Expiry Date (Soonest First)",
      "Expiry Date (Latest First)",
    ];
    final sortDescriptions = [
      "Alphabetical by item name (ascending)",
      "Alphabetical by item name (descending)",
      "Smallest stock first",
      "Largest stock first",
      "Earliest expiry date first, then later, no expiry last",
      "Farthest expiry date first, no expiry last",
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.70, // Increased to show more options
      minChildSize: 0.50, // Increased minimum size
      maxChildSize: 0.70, // Increased maximum size
      builder: (context, scrollController) {
        return Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              // Handle bar for dragging
              Container(
                margin: EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 8),
                child: Text("Sort By",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: sortOptions.length,
                  separatorBuilder: (_, __) => Divider(height: 0),
                  itemBuilder: (context, i) {
                    final isActive = selected == sortOptions[i];
                    return ListTile(
                      title: Text(
                        sortOptions[i],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isActive ? Color(0xFF4E38D4) : Colors.black87,
                        ),
                      ),
                      subtitle: Text(sortDescriptions[i],
                          style: TextStyle(fontSize: 13)),
                      trailing: isActive
                          ? Icon(Icons.check_circle, color: Color(0xFF4E38D4))
                          : null,
                      onTap: () {
                        onSelect(sortOptions[i]);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
