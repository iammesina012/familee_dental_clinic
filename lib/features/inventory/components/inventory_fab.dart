import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class InventoryFAB extends StatelessWidget {
  final Function()? onAddSupply;
  final Function()? onArchivedSupply;
  final Function()? onAddCategory;
  final Function()? onEditCategory;

  const InventoryFAB({
    Key? key,
    this.onAddSupply,
    this.onArchivedSupply,
    this.onAddCategory,
    this.onEditCategory,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SpeedDial(
      animatedIcon: AnimatedIcons.menu_close,
      backgroundColor: Color(0xFF4E38D4),
      foregroundColor: Colors.white,
      overlayColor: Colors.black,
      overlayOpacity: 0.15,
      spacing: 16,
      spaceBetweenChildren: 12,
      childMargin: EdgeInsets.only(bottom: 4),
      children: [
        SpeedDialChild(
          child: Icon(Icons.add_box, color: Colors.white),
          backgroundColor: Colors.green,
          label: 'Add Supply',
          labelStyle: TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: Colors.black,
          ),
          labelBackgroundColor: Colors.white,
          labelShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
          onTap: onAddSupply,
        ),
        SpeedDialChild(
          child: Icon(Icons.archive, color: Colors.white),
          backgroundColor: Colors.deepPurple,
          label: 'Archived Supply',
          labelStyle: TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: Colors.black,
          ),
          labelBackgroundColor: Colors.white,
          labelShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
          onTap: onArchivedSupply,
        ),
        SpeedDialChild(
          child: Icon(Icons.category, color: Colors.white),
          backgroundColor: Colors.orange,
          label: 'Add Category',
          labelStyle: TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: Colors.black,
          ),
          labelBackgroundColor: Colors.white,
          labelShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
          onTap: onAddCategory,
        ),
        SpeedDialChild(
          child: Icon(Icons.edit, color: Colors.white),
          backgroundColor: Colors.blueGrey,
          label: 'Edit Category',
          labelStyle: TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: Colors.black,
          ),
          labelBackgroundColor: Colors.white,
          labelShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
          onTap: onEditCategory,
        ),
      ],
    );
  }
}
