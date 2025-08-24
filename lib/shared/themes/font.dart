import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData theme = ThemeData(
      fontFamily: 'SF Pro',
      textTheme: TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.bold),
      ));
}

// Font utility class for easy font management
class AppFonts {
  static const String inter = 'Inter';
  static const String sfPro = 'SF Pro';
  static const String poppins = 'Poppins';

  // Predefined text styles for different fonts
  static TextStyle interStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: inter,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle sfProStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: sfPro,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle poppinsStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: poppins,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}
