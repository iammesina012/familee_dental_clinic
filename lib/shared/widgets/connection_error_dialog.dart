import 'package:flutter/material.dart';

/// Connection Error Dialog
///
/// A reusable dialog that shows when the user tries to perform
/// write/modify operations (add, edit, delete, archive) while offline
/// or with weak connection.
///
/// Usage:
/// ```dart
/// if (!await ConnectivityService().hasInternetConnection()) {
///   if (context.mounted) {
///     await showConnectionErrorDialog(context);
///   }
///   return; // Prevent operation from proceeding
/// }
/// ```
Future<void> showConnectionErrorDialog(BuildContext context) async {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 400,
            minWidth: 350,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon and Title
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off,
                  color: Colors.orange,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'No Internet Connection',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Content
              Text(
                'You need an active internet connection to perform this operation. Please check your WiFi or mobile data connection and try again.',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyMedium?.color,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // OK Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
