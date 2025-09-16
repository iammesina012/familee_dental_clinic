import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Global theme mode notifier so the app can rebuild when toggled
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    fontFamily: 'SF Pro',
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00D4AA),
      brightness: Brightness.light,
    ).copyWith(
      background: const Color(0xFFF9EFF2),
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFFF9EFF2),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      iconTheme: IconThemeData(color: Colors.black),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      surfaceTintColor: Colors.transparent,
      elevation: 5,
      shadowColor: Colors.black54,
    ),
    drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
    cardTheme: const CardThemeData(
        color: Colors.white, surfaceTintColor: Colors.transparent),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
      bodyMedium: TextStyle(fontWeight: FontWeight.w500, color: Colors.black),
    ),
    iconTheme: const IconThemeData(color: Colors.black),
    dividerColor: Colors.grey,
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'SF Pro',
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00D4AA),
      brightness: Brightness.dark,
    ).copyWith(
      background: const Color(0xFF1F1F23),
      surface: const Color(0xFF2B2B2F),
    ),
    scaffoldBackgroundColor: const Color(0xFF1F1F23),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1F1F23),
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Color(0xFF1F1F23),
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: Colors.black,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: Color(0xFF1F1F23),
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(
        color: Color(0xFF2B2B2F), surfaceTintColor: Colors.transparent),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      bodyMedium: TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    dividerColor: Colors.grey,
  );
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
