import 'package:flutter/material.dart';

class ResponsiveLayout {
  static const double tabletBreakpoint = 768;
  static const double desktopBreakpoint = 1024;

  // Device type checks
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < tabletBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint &&
      MediaQuery.of(context).size.width < desktopBreakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  // Get responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 20);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 60);
    } else {
      return const EdgeInsets.symmetric(horizontal: 120);
    }
  }

  // Get responsive max width for content
  static double getMaxContentWidth(BuildContext context) {
    if (isMobile(context)) {
      return double.infinity;
    } else if (isTablet(context)) {
      return 600;
    } else {
      return 800;
    }
  }

  // Get responsive font sizes
  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    if (isMobile(context)) return mobile;
    if (isTablet(context)) return tablet;
    return desktop;
  }
}
