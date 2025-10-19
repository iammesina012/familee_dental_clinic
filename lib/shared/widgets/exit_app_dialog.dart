import 'package:flutter/material.dart';

/// Exit App Dialog Template
/// 
/// This is a reusable dialog template for exit confirmation.
/// Use this code when implementing exit dialogs on other pages.
/// 
/// Usage:
/// ```dart
/// Future<bool> _showExitDialog(BuildContext context) async {
///   final theme = Theme.of(context);
///   final isDark = theme.brightness == Brightness.dark;
/// 
///   return await showDialog<bool>(
///     context: context,
///     barrierDismissible: false,
///     builder: (context) {
///       return Dialog(
///         shape: RoundedRectangleBorder(
///           borderRadius: BorderRadius.circular(16),
///         ),
///         backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
///         child: Container(
///           constraints: const BoxConstraints(
///             maxWidth: 400,
///             minWidth: 350,
///           ),
///           padding: const EdgeInsets.all(24),
///           child: Column(
///             mainAxisSize: MainAxisSize.min,
///             children: [
///               // Icon and Title
///               Container(
///                 padding: const EdgeInsets.all(16),
///                 decoration: BoxDecoration(
///                   color: Colors.red.withOpacity(0.1),
///                   shape: BoxShape.circle,
///                 ),
///                 child: const Icon(
///                   Icons.logout,
///                   color: Colors.red,
///                   size: 32,
///                 ),
///               ),
///               const SizedBox(height: 16),
/// 
///               // Title
///               Text(
///                 'Exit App',
///                 style: TextStyle(
///                   fontFamily: 'SF Pro',
///                   fontSize: 20,
///                   fontWeight: FontWeight.bold,
///                   color: theme.textTheme.titleLarge?.color,
///                 ),
///                 textAlign: TextAlign.center,
///               ),
///               const SizedBox(height: 12),
/// 
///               // Content
///               Text(
///                 'Are you sure you want to exit?',
///                 style: TextStyle(
///                   fontFamily: 'SF Pro',
///                   fontSize: 16,
///                   fontWeight: FontWeight.w500,
///                   color: theme.textTheme.bodyMedium?.color,
///                   height: 1.4,
///                 ),
///                 textAlign: TextAlign.center,
///               ),
///               const SizedBox(height: 24),
/// 
///               // Buttons (Yes first, then No)
///               Row(
///                 children: [
///                   Expanded(
///                     child: ElevatedButton(
///                       onPressed: () => Navigator.of(context).pop(true),
///                       style: ElevatedButton.styleFrom(
///                         backgroundColor: Colors.red,
///                         foregroundColor: Colors.white,
///                         padding: const EdgeInsets.symmetric(vertical: 12),
///                         shape: RoundedRectangleBorder(
///                           borderRadius: BorderRadius.circular(8),
///                         ),
///                         elevation: 2,
///                       ),
///                       child: Text(
///                         'Yes',
///                         style: TextStyle(
///                           fontFamily: 'SF Pro',
///                           fontWeight: FontWeight.w500,
///                           color: Colors.white,
///                           fontSize: 16,
///                         ),
///                       ),
///                     ),
///                   ),
///                   const SizedBox(width: 12),
///                   Expanded(
///                     child: TextButton(
///                       onPressed: () => Navigator.of(context).pop(false),
///                       style: TextButton.styleFrom(
///                         padding: const EdgeInsets.symmetric(vertical: 12),
///                         shape: RoundedRectangleBorder(
///                           borderRadius: BorderRadius.circular(8),
///                           side: BorderSide(
///                             color: isDark
///                                 ? Colors.grey.shade600
///                                 : Colors.grey.shade300,
///                           ),
///                         ),
///                       ),
///                       child: Text(
///                         'No',
///                         style: TextStyle(
///                           fontFamily: 'SF Pro',
///                           fontWeight: FontWeight.w500,
///                           color: theme.textTheme.bodyMedium?.color,
///                           fontSize: 16,
///                         ),
///                       ),
///                     ),
///                   ),
///                 ],
///               ),
///             ],
///           ),
///         ),
///       );
///     },
///   ) ?? false; // Default to false if dialog is dismissed
/// }
/// ```
/// 
/// WillPopScope Implementation:
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return WillPopScope(
///     onWillPop: () async {
///       // Show exit confirmation dialog
///       return await _showExitDialog(context);
///     },
///     child: Scaffold(
///       // Your page content here
///     ),
///   );
/// }
/// ```
