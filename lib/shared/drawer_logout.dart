import 'package:flutter/material.dart';

Future<bool?> showLogoutDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _buildLogoutDialog(context),
  );
}

Widget _buildLogoutDialog(BuildContext context) {
  return Dialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    elevation: 8,
    backgroundColor: Colors.white,
    child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon and Title
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.logout,
              color: Colors.red,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Logout',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Content
          Text(
            'Are you sure you want to logout?',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Logout',
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
        ],
      ),
    ),
  );
}
