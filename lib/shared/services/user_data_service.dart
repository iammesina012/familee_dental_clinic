import 'dart:convert';
import 'package:familee_dental/shared/storage/hive_storage.dart';
import 'package:flutter/foundation.dart';

/// Centralized service for managing user data (name and role) with Hive persistence
///
/// Purpose:
/// - Store user name and role persistently across app restarts
/// - Avoid showing "User" placeholder on app startup
/// - Provide consistent user data across all modules
///
/// Usage: All pages should use this service instead of static variables
class UserDataService {
  static final UserDataService _instance = UserDataService._internal();
  factory UserDataService() => _instance;
  UserDataService._internal();

  // In-memory cache
  String? _cachedUserName;
  String? _cachedUserRole;

  // Getters
  String? get userName => _cachedUserName;
  String? get userRole => _cachedUserRole;

  /// Load user data from Hive for a specific user ID
  /// Call this on app startup when user is logged in
  Future<void> loadFromHive(String userId) async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.userDataBox);
      final userDataStr = box.get('user_data_$userId') as String?;
      if (userDataStr != null) {
        final userData = jsonDecode(userDataStr) as Map<String, dynamic>;
        _cachedUserName = userData['userName'] as String?;
        _cachedUserRole = userData['userRole'] as String?;
        debugPrint(
            'UserDataService: Loaded from Hive - Name: $_cachedUserName, Role: $_cachedUserRole');
      }
    } catch (e) {
      debugPrint('UserDataService: Error loading from Hive: $e');
      // Ignore errors - Hive is best effort
    }
  }

  /// Save user data to Hive for a specific user ID
  /// Call this after successfully fetching from Supabase
  Future<void> saveToHive(String userId, String name, String role) async {
    try {
      _cachedUserName = name;
      _cachedUserRole = role;

      final box = await HiveStorage.openBox(HiveStorage.userDataBox);
      final userData = {
        'userName': name,
        'userRole': role,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      await box.put('user_data_$userId', jsonEncode(userData));
      debugPrint('UserDataService: Saved to Hive - Name: $name, Role: $role');
    } catch (e) {
      debugPrint('UserDataService: Error saving to Hive: $e');
      // Ignore errors - Hive is best effort
    }
  }

  /// Update user data in memory only (without saving to Hive)
  /// Use this when you want to update cache but not persist yet
  void updateCache(String? name, String? role) {
    if (name != null) _cachedUserName = name;
    if (role != null) _cachedUserRole = role;
  }

  /// Clear all user data (call on logout)
  Future<void> clear(String userId) async {
    try {
      _cachedUserName = null;
      _cachedUserRole = null;

      final box = await HiveStorage.openBox(HiveStorage.userDataBox);
      await box.delete('user_data_$userId');
      debugPrint('UserDataService: Cleared user data for $userId');
    } catch (e) {
      debugPrint('UserDataService: Error clearing user data: $e');
      // Ignore errors - Hive is best effort
    }
  }

  /// Clear all user data (for all users - use with caution)
  Future<void> clearAll() async {
    try {
      _cachedUserName = null;
      _cachedUserRole = null;

      final box = await HiveStorage.openBox(HiveStorage.userDataBox);
      await box.clear();
      debugPrint('UserDataService: Cleared all user data');
    } catch (e) {
      debugPrint('UserDataService: Error clearing all user data: $e');
      // Ignore errors - Hive is best effort
    }
  }
}
