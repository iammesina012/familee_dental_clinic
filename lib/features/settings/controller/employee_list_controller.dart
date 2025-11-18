import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/shared/storage/hive_storage.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// EmployeeListController
///
/// Purpose: Encapsulate all backend/data operations related to Employee Management.
/// - Supabase reads and writes for user data
/// - User creation, deletion, and modification
/// - User role management
///
/// The UI page should use this controller for data access and mutations,
/// keeping all non-UI logic out of the widget layer.
class EmployeeListController {
  final SupabaseClient _supabase = Supabase.instance.client;

  // In-memory cache for employees (persists across widget rebuilds)
  List<Map<String, dynamic>>? _cachedUsers;

  // ===== HIVE PERSISTENT CACHE HELPERS =====

  /// Load users from Hive cache
  Future<List<Map<String, dynamic>>?> _loadUsersFromHive() async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.employeeListBox);
      final usersStr = box.get('employees') as String?;

      if (usersStr != null) {
        final jsonList = jsonDecode(usersStr) as List<dynamic>;
        return jsonList
            .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading employees from Hive: $e');
    }
    return null;
  }

  /// Save users to Hive cache
  Future<void> _saveUsersToHive(List<Map<String, dynamic>> users) async {
    try {
      final box = await HiveStorage.openBox(HiveStorage.employeeListBox);
      final jsonList = users
          .map((user) => {
                'uid': user['uid'],
                'email': user['email'],
                'displayName': user['displayName'],
                'name': user['name'],
                'username': user['username'],
                'role': user['role'],
                'isActive': user['isActive'],
                'createdAt': user['createdAt'],
                'updatedAt': user['updatedAt'],
              })
          .toList();
      await box.put('employees', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving employees to Hive: $e');
    }
  }

  /// Get all users as a realtime stream
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    // Note: We need to ensure admin exists first, but we can't await in a stream
    // So we'll do the transformation in the map
    return _supabase
        .from('user_roles')
        .stream(primaryKey: ['id']).map((response) {
      List<Map<String, dynamic>> users = [];

      for (var userData in response) {
        final user = {
          'uid': userData['id'] ?? '',
          'email': userData['email'] ?? '',
          'displayName': userData['name'] ?? 'User',
          'name': userData['name'] ?? 'User',
          'username': userData['username'] ?? '',
          'role': userData['role'] ?? 'Staff',
          'isActive': userData['is_active'] ?? true,
          'createdAt': userData['created_at'],
          'updatedAt': userData['updated_at'],
        };
        users.add(user);
      }

      // Sort: Owner first, then Admin, then Staff, then by name A-Z
      users.sort((a, b) {
        final aRole = a['role'] ?? 'Staff';
        final bRole = b['role'] ?? 'Staff';

        // Role hierarchy: Owner > Admin > Staff
        final roleOrder = {'Owner': 0, 'Admin': 1, 'Staff': 2};
        final aRoleOrder = roleOrder[aRole] ?? 2;
        final bRoleOrder = roleOrder[bRole] ?? 2;

        if (aRoleOrder != bRoleOrder) {
          return aRoleOrder.compareTo(bRoleOrder);
        }

        // If same role, sort by name A-Z
        final aName = (a['name'] ?? '').toString().toLowerCase();
        final bName = (b['name'] ?? '').toString().toLowerCase();
        return aName.compareTo(bName);
      });

      return users;
    });
  }

  /// Get all Supabase users (legacy - kept for backwards compatibility)
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      // 1. Check in-memory cache first
      if (_cachedUsers == null) {
        // 2. If in-memory cache is null, load from Hive
        final hiveData = await _loadUsersFromHive();
        if (hiveData != null && hiveData.isNotEmpty) {
          _cachedUsers = hiveData; // Populate in-memory cache
        }
      }

      // 3. Try to fetch from Supabase (if online)
      try {
        // Ensure admin user exists in Supabase
        await _ensureAdminUserExists();

        // Get all users from Supabase user_roles table (active and inactive)
        final response = await _supabase.from('user_roles').select('*');

        List<Map<String, dynamic>> users = [];

        for (var userData in response) {
          final user = {
            'uid': userData['id'] ?? '',
            'email': userData['email'] ?? '',
            'displayName': userData['name'] ?? 'User',
            'name': userData['name'] ?? 'User',
            'username': userData['username'] ?? '',
            'role': userData['role'] ?? 'Staff',
            'isActive': userData['is_active'] ?? true,
            'createdAt': userData['created_at'],
            'updatedAt': userData['updated_at'],
          };
          users.add(user);
        }

        // Sort: Owner first, then Admin, then Staff, then by name A-Z
        users.sort((a, b) {
          final aRole = a['role'] ?? 'Staff';
          final bRole = b['role'] ?? 'Staff';

          // Role hierarchy: Owner > Admin > Staff
          final roleOrder = {'Owner': 0, 'Admin': 1, 'Staff': 2};
          final aRoleOrder = roleOrder[aRole] ?? 2;
          final bRoleOrder = roleOrder[bRole] ?? 2;

          if (aRoleOrder != bRoleOrder) {
            return aRoleOrder.compareTo(bRoleOrder);
          }

          // If same role, sort by name A-Z
          final aName = (a['name'] ?? '').toString().toLowerCase();
          final bName = (b['name'] ?? '').toString().toLowerCase();
          return aName.compareTo(bName);
        });

        // Save to both caches
        _cachedUsers = users; // Update in-memory cache
        await _saveUsersToHive(users); // Save to Hive

        return users;
      } catch (e) {
        // If Supabase fetch fails (e.g., offline), use cached data
        print('Error fetching users from Supabase: $e');
        if (_cachedUsers != null && _cachedUsers!.isNotEmpty) {
          return _cachedUsers!;
        }
        return [];
      }
    } catch (e) {
      print('Error getting users: $e');
      // Return cached data if available
      if (_cachedUsers != null) {
        return _cachedUsers!;
      }
      return [];
    }
  }

  /// Ensure admin user exists in Supabase
  Future<void> _ensureAdminUserExists() async {
    try {
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return;

      final response = await _supabase
          .from('user_roles')
          .select('id')
          .eq('id', currentUser.id)
          .limit(1);

      if (response.isEmpty) {
        // Create admin user record in Supabase
        await _supabase.from('user_roles').insert({
          'id': currentUser.id,
          'name': 'Michael William Mesina',
          'username': 'iammesina012',
          'email': currentUser.email,
          'role': 'Admin',
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('Error ensuring admin user exists: $e');
    }
  }

  /// Load users with error handling
  Future<Map<String, dynamic>> loadUsers() async {
    try {
      final users = await getUsers();
      return {
        'success': true,
        'users': users,
        'error': null,
      };
    } catch (e) {
      // Try to return cached data on error
      if (_cachedUsers != null) {
        return {
          'success': true,
          'users': _cachedUsers!,
          'error': null,
        };
      }
      return {
        'success': false,
        'users': <Map<String, dynamic>>[],
        'error': e.toString(),
      };
    }
  }

  /// Get user role from Supabase (if stored there)
  Future<String> getUserRole(String uid) async {
    try {
      final response = await _supabase
          .from('user_roles')
          .select('role')
          .eq('id', uid)
          .limit(1)
          .single();

      return response['role'] ?? 'Staff';
    } catch (e) {
      print('Error getting user role: $e');
      return 'Staff';
    }
  }

  /// Update user role in Supabase
  Future<bool> updateUserRole(String uid, String role) async {
    try {
      await _supabase.from('user_roles').update({
        'role': role,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid);
      return true;
    } catch (e) {
      print('Error updating user role: $e');
      return false;
    }
  }

  /// Get duplicate users (same email or username)
  Future<List<Map<String, dynamic>>> getDuplicateUsers() async {
    try {
      final users = await getUsers();
      List<Map<String, dynamic>> duplicates = [];

      // Group by email
      Map<String, List<Map<String, dynamic>>> emailGroups = {};
      for (var user in users) {
        String email = user['email'] ?? '';
        if (email.isNotEmpty) {
          emailGroups[email] = emailGroups[email] ?? [];
          emailGroups[email]!.add(user);
        }
      }

      // Find duplicates
      for (var entry in emailGroups.entries) {
        if (entry.value.length > 1) {
          duplicates.addAll(entry.value);
        }
      }

      return duplicates;
    } catch (e) {
      print('Error getting duplicate users: $e');
      return [];
    }
  }
}
