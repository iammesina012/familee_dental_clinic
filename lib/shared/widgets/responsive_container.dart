import 'package:flutter/material.dart';
import 'package:familee_dental/shared/utils/responsive_layout.dart';

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? ResponsiveLayout.getMaxContentWidth(context),
        ),
        child: Padding(
          padding: padding ?? ResponsiveLayout.getResponsivePadding(context),
          child: child,
        ),
      ),
    );
  }
}
