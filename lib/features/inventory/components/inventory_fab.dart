import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:projects/shared/providers/user_role_provider.dart';

class InventoryFAB extends StatelessWidget {
  final Function()? onAddSupply;
  final Function()? onArchivedSupply;
  final Function()? onExpiredSupply;
  final Function()? onAddCategory;
  final Function()? onEditCategory;

  const InventoryFAB({
    Key? key,
    this.onAddSupply,
    this.onArchivedSupply,
    this.onExpiredSupply,
    this.onAddCategory,
    this.onEditCategory,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelBg = scheme.surface;
    final labelTextColor = theme.textTheme.bodyMedium?.color;
    final userRoleProvider = UserRoleProvider();
    // final borderColor = theme.dividerColor.withOpacity(0.25);

    return ListenableBuilder(
      listenable: userRoleProvider,
      builder: (context, child) {
        final isStaff = userRoleProvider.isStaff;

        return SpeedDial(
          animatedIcon: AnimatedIcons.menu_close,
          backgroundColor: Color(0xFF4E38D4),
          foregroundColor: Colors.white,
          overlayColor: Colors.black,
          overlayOpacity: 0.2,
          spacing: 16,
          spaceBetweenChildren: 12,
          childMargin: EdgeInsets.only(bottom: 4),
          closeManually: false,
          animationCurve: Curves.elasticInOut,
          animationDuration: Duration(milliseconds: 300),
          onOpen: () {
            // FAB opened
          },
          onClose: () {
            // FAB closed
          },
          children: [
            // Add Supply - Available for all users
            SpeedDialChild(
              child: Icon(Icons.add_box, color: Colors.white),
              backgroundColor: Colors.green,
              label: 'Add Supply',
              labelStyle: TextStyle(
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: labelTextColor,
              ),
              labelBackgroundColor: labelBg,
              labelShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
              onTap: onAddSupply,
            ),

            // Expired Supply (Dispose Expired Items) - Available for all users
            SpeedDialChild(
              child: Icon(Icons.warning, color: Colors.white),
              backgroundColor: Colors.red,
              label: 'Expired Supply',
              labelStyle: TextStyle(
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: labelTextColor,
              ),
              labelBackgroundColor: labelBg,
              labelShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
              onTap: onExpiredSupply,
            ),

            // Archived Supply - Only for Admin users
            if (!isStaff)
              SpeedDialChild(
                child: Icon(Icons.archive, color: Colors.white),
                backgroundColor: Colors.deepPurple,
                label: 'Archived Supply',
                labelStyle: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: labelTextColor,
                ),
                labelBackgroundColor: labelBg,
                labelShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                onTap: onArchivedSupply,
              ),

            // Add Category - Only for Admin users
            if (!isStaff)
              SpeedDialChild(
                child: Icon(Icons.category, color: Colors.white),
                backgroundColor: Colors.orange,
                label: 'Add Category',
                labelStyle: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: labelTextColor,
                ),
                labelBackgroundColor: labelBg,
                labelShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                onTap: onAddCategory,
              ),

            // Edit Category - Only for Admin users
            if (!isStaff)
              SpeedDialChild(
                child: Icon(Icons.edit, color: Colors.white),
                backgroundColor: Colors.blueGrey,
                label: 'Edit Category',
                labelStyle: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: labelTextColor,
                ),
                labelBackgroundColor: labelBg,
                labelShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                onTap: onEditCategory,
              ),
          ],
        );
      },
    );
  }
}
