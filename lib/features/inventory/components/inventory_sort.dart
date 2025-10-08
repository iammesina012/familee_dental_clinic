import 'package:flutter/material.dart';

class InventorySortModal extends StatelessWidget {
  final String? selected;
  final void Function(String) onSelect;
  const InventorySortModal({super.key, this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortOptions = [
      "Expiry Date (Soonest First)",
      "Expiry Date (Latest First)",
      "Name (A → Z)",
      "Name (Z → A)",
      "Quantity (Low → High)",
      "Quantity (High → Low)",
    ];
    final sortDescriptions = [
      "Earliest expiry date first, then later, no expiry last",
      "Farthest expiry date first, no expiry last",
      "Alphabetical by item name (ascending)",
      "Alphabetical by item name (descending)",
      "Smallest stock first",
      "Largest stock first",
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.70, // Increased to show more options
      minChildSize: 0.50, // Increased minimum size
      maxChildSize: 0.70, // Increased maximum size
      builder: (context, scrollController) {
        return Material(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              // Handle bar for dragging
              Container(
                margin: EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 8),
                child: Text(
                  "Sort By",
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold, fontSize: 19),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: sortOptions.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 0, color: theme.dividerColor),
                  itemBuilder: (context, i) {
                    final isActive = selected == sortOptions[i];
                    return ListTile(
                      title: Text(
                        sortOptions[i],
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? const Color(0xFF4E38D4)
                              : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      subtitle: Text(
                        sortDescriptions[i],
                        style:
                            theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                      ),
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
