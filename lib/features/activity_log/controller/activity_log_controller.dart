import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class ActivityLogController extends ChangeNotifier {
  // Private variables
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'All Categories';
  String _searchQuery = '';

  // Supabase instance
  final SupabaseClient _supabase = Supabase.instance.client;

  // Real-time activities from Supabase
  List<Map<String, dynamic>> _allActivities = [];
  RealtimeChannel? _realtimeChannel;

  // Current user's role (cached)
  String _currentUserRole = 'staff';

  // Loading state
  bool _isLoading = true;

  // Cache previously fetched activities by date key (yyyy-mm-dd)
  final Map<String, List<Map<String, dynamic>>> _cachedActivitiesByDate = {};
  static const int _maxCachedDates = 7;

  // Getters
  DateTime get selectedDate => _selectedDate;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  List<Map<String, dynamic>> get allActivities => _allActivities;
  bool get isLoading => _isLoading;

  // Filtered activities based on current filters
  List<Map<String, dynamic>> get filteredActivities {
    List<Map<String, dynamic>> filtered = _allActivities;

    // Apply role-based filtering first
    filtered = _applyRoleBasedFiltering(filtered);

    // Filter by category
    if (_selectedCategory != 'All Categories') {
      filtered = filtered
          .where((activity) => activity['category'] == _selectedCategory)
          .toList();
    }

    // Filter by search query (improved semantics)
    if (_searchQuery.isNotEmpty) {
      final String query = _searchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        filtered = filtered.where((activity) {
          final String user =
              (activity['userName'] ?? '').toString().toLowerCase();
          final String desc =
              (activity['description'] ?? '').toString().toLowerCase();
          final String category =
              (activity['category'] ?? '').toString().toLowerCase();
          final String action =
              (activity['action'] ?? '').toString().toLowerCase();

          // Tokenize to support word-start matches
          List<String> tokenize(String s) => s
              .split(RegExp(r'[^a-z0-9]+'))
              .where((t) => t.isNotEmpty)
              .toList();

          final userTokens = tokenize(user);
          final descTokens = tokenize(desc);
          final catTokens = tokenize(category);
          final actionTokens = tokenize(action);

          final bool wordStartMatch = [
            ...userTokens,
            ...descTokens,
            ...catTokens,
            ...actionTokens,
          ].any((t) => t.startsWith(query));

          if (query.length <= 2) {
            // Very short queries (1-2 chars): match only at word starts
            return wordStartMatch;
          }

          // Longer queries (3+): allow substring matches as well
          final bool substringMatch = user.contains(query) ||
              desc.contains(query) ||
              category.contains(query) ||
              action.contains(query);
          return wordStartMatch || substringMatch;
        }).toList();
      }
    }

    // Filter by selected date
    filtered = filtered.where((activity) {
      final activityDate = activity['date'] as DateTime;
      return activityDate.year == _selectedDate.year &&
          activityDate.month == _selectedDate.month &&
          activityDate.day == _selectedDate.day;
    }).toList();

    // Sort by date and time (most recent first)
    filtered.sort((a, b) {
      final dateA = a['date'] as DateTime;
      final dateB = b['date'] as DateTime;
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  // Constructor - start listening to Supabase
  ActivityLogController() {
    _loadCurrentUserRole();
    _startListeningToActivities();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // Start listening to activities from Supabase
  void _startListeningToActivities() {
    unawaited(_subscribeToSelectedDate());
  }

  Future<void> _subscribeToSelectedDate() async {
    try {
      final targetDate = _selectedDate;
      final cached = _getCachedActivities(targetDate);

      if (cached != null) {
        _allActivities = cached;
        _isLoading = false;
      } else {
        _allActivities = [];
        _isLoading = true;
      }
      notifyListeners();

      final range = _buildUtcRangeForDate(targetDate);

      await _fetchActivitiesForRange(range, cacheDate: targetDate);

      if (_isSameDay(_selectedDate, targetDate)) {
        _attachRealtimeChannel(range);
      }
    } catch (e) {
      print('Error starting activity stream: $e');
    }
  }

  // Manual refresh method for pull-to-refresh
  Future<void> refreshActivities() async {
    try {
      // Reload current user role first
      await _loadCurrentUserRole();
      final targetDate = _selectedDate;
      final range = _buildUtcRangeForDate(targetDate);
      await _fetchActivitiesForRange(range,
          resetLoading: true, cacheDate: targetDate);
    } catch (e) {
      print('Error refreshing activities: $e');
    }
  }

  // Apply role-based filtering to activities
  List<Map<String, dynamic>> _applyRoleBasedFiltering(
      List<Map<String, dynamic>> activities) {
    try {
      final User? currentUser = _supabase.auth.currentUser;
      if (currentUser == null) return []; // No user logged in, return empty

      // Get current user's role
      final String currentUserRole = _getCurrentUserRole();

      // Filter based on role hierarchy
      switch (currentUserRole.toLowerCase()) {
        case 'owner':
          // Owner can see all activities (Owner, Admin, Staff)
          return activities;
        case 'admin':
          // Admin can see Admin and Staff activities (NOT Owner activities)
          final filtered = activities.where((activity) {
            final String activityUserRole = _getActivityUserRole(activity);
            final String lowerRole = activityUserRole.toLowerCase();
            final bool shouldShow =
                lowerRole == 'admin' || lowerRole == 'staff';
            return shouldShow;
          }).toList();
          return filtered;
        case 'staff':
          // Staff cannot see any activities
          return [];
        default:
          // Unknown role, return empty for security
          return [];
      }
    } catch (e) {
      print('Error applying role-based filtering: $e');
      return []; // Return empty for security on error
    }
  }

  // Load current user's role
  Future<void> _loadCurrentUserRole() async {
    try {
      final User? currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        _currentUserRole = 'staff';
        return;
      }

      final response = await _supabase
          .from('user_roles')
          .select('role')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (response != null && response['role'] != null) {
        _currentUserRole = response['role'] as String;
      } else {
        _currentUserRole = 'staff'; // Default fallback
      }
    } catch (e) {
      print('Error loading current user role: $e');
      _currentUserRole = 'staff'; // Default to most restrictive on error
    }
  }

  // Get current user's role (cached)
  String _getCurrentUserRole() {
    return _currentUserRole;
  }

  // Get the role of the user who performed the activity
  String _getActivityUserRole(Map<String, dynamic> activity) {
    // Use the stored user_role field
    final String userRole = (activity['user_role'] ?? 'staff').toString();
    return userRole.toLowerCase();
  }

  // Methods to update filters
  void updateSelectedDate(DateTime date) {
    final bool changed = !_isSameDay(_selectedDate, date);
    _selectedDate = date;
    notifyListeners();
    if (changed) {
      unawaited(_subscribeToSelectedDate());
    }
  }

  void updateSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Map<String, DateTime> _buildUtcRangeForDate(DateTime date) {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return {'start': start, 'end': end};
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  List<Map<String, dynamic>>? _getCachedActivities(DateTime date) {
    final cached = _cachedActivitiesByDate[_dateKey(date)];
    if (cached == null) return null;
    return cached
        .map((activity) => Map<String, dynamic>.from(activity))
        .toList(growable: false);
  }

  bool hasCachedDataFor(DateTime date) {
    final cached = _cachedActivitiesByDate[_dateKey(date)];
    return cached != null && cached.isNotEmpty;
  }

  void _cacheActivitiesForDate(
      DateTime date, List<Map<String, dynamic>> activities) {
    final key = _dateKey(date);
    final cachedList = activities
        .map((activity) => Map<String, dynamic>.from(activity))
        .toList(growable: false);
    _cachedActivitiesByDate[key] = cachedList;

    if (_cachedActivitiesByDate.length > _maxCachedDates) {
      final keys = _cachedActivitiesByDate.keys.toList()
        ..sort(); // oldest first
      while (keys.length > _maxCachedDates) {
        final removeKey = keys.removeAt(0);
        _cachedActivitiesByDate.remove(removeKey);
      }
    }
  }

  Future<void> _fetchActivitiesForRange(Map<String, DateTime> range,
      {bool resetLoading = false, DateTime? cacheDate}) async {
    try {
      if (resetLoading) {
        _isLoading = true;
        notifyListeners();
      }

      final response = await _supabase
          .from('activity_logs')
          .select('*')
          .gte('created_at', range['start']!.toIso8601String())
          .lt('created_at', range['end']!.toIso8601String())
          .limit(250)
          .order('created_at', ascending: false);

      final List<dynamic> rows = response as List<dynamic>;
      _allActivities = rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map(_mapRowToActivity)
          .toList(growable: false);

      if (cacheDate != null) {
        _cacheActivitiesForDate(cacheDate, _allActivities);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error fetching activities: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void _attachRealtimeChannel(Map<String, DateTime> range) {
    try {
      _realtimeChannel?.unsubscribe();
      final startIso = range['start']!;
      final endIso = range['end']!;

      _realtimeChannel = _supabase.channel(
          'activity_logs_${startIso.toIso8601String()}_${endIso.toIso8601String()}');

      _realtimeChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'activity_logs',
            callback: (payload) => _handleRealtimePayload(
                payload, range, PostgresChangeEvent.insert),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'activity_logs',
            callback: (payload) => _handleRealtimePayload(
                payload, range, PostgresChangeEvent.update),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'activity_logs',
            callback: (payload) => _handleRealtimePayload(
                payload, range, PostgresChangeEvent.delete),
          )
          .subscribe();
    } catch (e) {
      print('Error attaching realtime channel: $e');
    }
  }

  void _handleRealtimePayload(PostgresChangePayload payload,
      Map<String, DateTime> range, PostgresChangeEvent eventType) {
    try {
      final Map<String, dynamic>? record =
          eventType == PostgresChangeEvent.delete
              ? payload.oldRecord as Map<String, dynamic>?
              : payload.newRecord as Map<String, dynamic>?;
      if (record == null) return;

      final DateTime? createdAt = _extractCreatedAt(record);
      if (createdAt == null) return;
      final start = range['start']!;
      final end = range['end']!;
      if (createdAt.isBefore(start) || !createdAt.isBefore(end)) {
        return;
      }

      if (eventType == PostgresChangeEvent.delete) {
        final id = record['id'];
        if (id != null) {
          _allActivities.removeWhere((activity) => activity['id'] == id);
          _cacheActivitiesForDate(_selectedDate, _allActivities);
          notifyListeners();
        }
        return;
      }

      _addOrUpdateActivity(record);
    } catch (e) {
      print('Error handling realtime payload: $e');
    }
  }

  DateTime? _extractCreatedAt(Map<String, dynamic> record) {
    final createdAtRaw = record['created_at']?.toString();
    if (createdAtRaw == null) return null;
    return DateTime.tryParse(createdAtRaw);
  }

  void _addOrUpdateActivity(Map<String, dynamic> record) {
    if (record.isEmpty) return;
    final mapped = _mapRowToActivity(record);
    final id = mapped['id'];
    if (id == null) return;

    final index = _allActivities.indexWhere((activity) => activity['id'] == id);
    if (index >= 0) {
      _allActivities[index] = mapped;
    } else {
      _allActivities.insert(0, mapped);
    }
    _allActivities.sort((a, b) {
      final dateA = a['date'] as DateTime;
      final dateB = b['date'] as DateTime;
      return dateB.compareTo(dateA);
    });
    notifyListeners();
    _cacheActivitiesForDate(_selectedDate, _allActivities);
  }

  Map<String, dynamic> _mapRowToActivity(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'userName': row['user_name'] ?? 'Unknown User',
      'description': row['description'] ?? '',
      'date': row['date'] != null
          ? DateTime.parse(row['date'] as String)
          : DateTime.now(),
      'time': row['time'] ?? '',
      'category': row['category'] ?? '',
      'action': row['action'] ?? '',
      'user_role': row['user_role'] ?? 'staff',
      'metadata': row['metadata'] ?? {},
    };
  }

  // Method to add new activity (for future use)
  Future<void> addActivity({
    required String userName,
    required String description,
    required DateTime date,
    required String time,
    required String category,
  }) async {
    // This method is kept for backward compatibility
    // New activities should use ActivityLoggerService.logActivity() instead
    // Intentionally left blank; activities are logged via dedicated controllers
  }

  // Method to fetch activities from database (for future use)
  Future<void> fetchActivities() async {
    // Activities are automatically fetched via Supabase stream
    // This method is kept for backward compatibility
  }

  // Method to delete activity from Supabase
  Future<void> deleteActivity(String activityId) async {
    try {
      // Delete from Supabase
      await _supabase.from('activity_logs').delete().eq('id', activityId);

      // The stream will automatically update the UI
      // success
    } catch (e) {
      // Swallow errors to avoid noisy logs; surface to UI if needed
    }
  }

  // Method to get activities by category (for analytics)
  List<Map<String, dynamic>> getActivitiesByCategory(String category) {
    return _allActivities
        .where((activity) => activity['category'] == category)
        .toList();
  }

  // Method to get activities count by date range
  int getActivitiesCountByDateRange(DateTime startDate, DateTime endDate) {
    return _allActivities.where((activity) {
      final activityDate = activity['date'] as DateTime;
      return activityDate
              .isAfter(startDate.subtract(const Duration(days: 1))) &&
          activityDate.isBefore(endDate.add(const Duration(days: 1)));
    }).length;
  }

  // Method to format date for display
  String formatDateForDisplay(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  // ===== Presentation helpers (moved from UI to keep page UI-only) =====

  // Format top description text for list items
  String formatListDescription(String description) {
    if (description.contains('Deducted')) {
      final parts = description.split(' - ');
      if (parts.length >= 2) {
        final actionPart = parts[0];
        final cleanAction = actionPart
            .replaceAll(RegExp(r'Deducted \\d+ '), 'Deducted ')
            .replaceAll(RegExp(r' \\([^)]+\\)'), '');
        return cleanAction;
      }
    }
    return description;
  }

  // For preset_edited, compute the display description line
  String formatPresetEditedDescription(String originalName, String newName) {
    final oldName = (originalName).trim();
    final nowName = (newName).trim();
    final changed = oldName.toLowerCase() != nowName.toLowerCase();
    return changed
        ? 'Edited Preset: ' + oldName + ' → ' + nowName
        : 'Edited Preset: ' + nowName;
  }

  // Map metadata key to display label
  String mapMetadataKeyToLabel(String key) {
    switch (key) {
      case 'poCode':
        return 'PO Code';
      case 'poName':
        return 'PO Name';
      case 'supplyName':
        return 'Supply Name';
      case 'quantity':
        return 'Quantity';
      case 'reason':
        return 'Reason';
      case 'changeType':
        return 'Change Type';
      case 'details':
        return 'Details';
      case 'addedSupplies':
        return 'Added Supplies';
      case 'removedSupplies':
        return 'Removed Supplies';
      default:
        if (key.isEmpty) return key;
        return key[0].toUpperCase() + key.substring(1);
    }
  }

  // Format currency with peso sign
  String formatPeso(dynamic amount) {
    if (amount is num) return '₱' + amount.toStringAsFixed(2);
    final parsed = double.tryParse((amount ?? '').toString());
    return parsed != null ? '₱' + parsed.toStringAsFixed(2) : '₱0.00';
  }

  // Normalize date string to YYYY/MM/DD
  String formatDateString(String raw) {
    return raw.replaceAll('-', '/');
  }

  // Build ordered metadata rows as label/value pairs for UI rendering
  List<Map<String, String>> computeMetadataRows(
    Map<String, dynamic> metadata, {
    String? action,
    String? category,
  }) {
    final List<Map<String, String>> rows = [];

    // Helper: add row
    void addRow(String label, String value) {
      rows.add({'label': label, 'value': value});
    }

    // Helper: add divider
    void addDivider() {
      rows.add({'label': '__DIVIDER__', 'value': ''});
    }

    // Handle Settings category - profile_edited
    if (category == 'Settings' && action == 'profile_edited') {
      if (metadata.containsKey('changes')) {
        final changes = metadata['changes'] as Map<String, dynamic>;
        // Add each change that occurred
        changes.forEach((key, value) {
          addRow(key, value.toString());
        });
      }
      return rows;
    }

    // Handle Settings category - password_changed
    if (category == 'Settings' && action == 'password_changed') {
      // No additional details for privacy reasons
      return rows;
    }

    // Determine if we have supplies array
    final bool hasSuppliesArray = metadata['supplies'] is List &&
        (metadata['supplies'] as List).isNotEmpty;

    // Determine category context
    final bool isPurchaseOrder = (category == 'Purchase Order') ||
        metadata.containsKey('poCode') ||
        metadata.containsKey('poName');

    // Handle supplies array path (per-supply blocks)
    if (hasSuppliesArray) {
      // For preset edits, show Added/Removed Supplies only if non-empty
      if (metadata.containsKey('addedSupplies')) {
        final List<dynamic> added = (metadata['addedSupplies'] as List?) ?? [];
        if (added.isNotEmpty) {
          addRow('Added Supplies', added.join(', '));
        }
      }
      if (metadata.containsKey('removedSupplies')) {
        final List<dynamic> removed =
            (metadata['removedSupplies'] as List?) ?? [];
        if (removed.isNotEmpty) {
          addRow('Removed Supplies', removed.join(', '));
        }
      }
      if (rows.isNotEmpty) {
        addDivider();
      }

      final List suppliesList = metadata['supplies'] as List;
      for (int i = 0; i < suppliesList.length; i++) {
        final s = suppliesList[i] as Map<String, dynamic>;

        // Gather per-supply field changes keyed as "Label::SupplyName"
        final Map<String, dynamic> changesByLabel = {};
        if (metadata['fieldChanges'] is Map<String, dynamic>) {
          final Map<String, dynamic> fc =
              metadata['fieldChanges'] as Map<String, dynamic>;
          final supplyNameKey = (s['supplyName'] ?? '').toString();
          for (final e in fc.entries) {
            if (e.key.endsWith('::' + supplyNameKey)) {
              final parts = e.key.split('::');
              final label = parts.isNotEmpty ? parts.first : 'Changed';
              changesByLabel[label] = e.value;
            }
          }
        }

        addRow('Supply Name', (s['supplyName'] ?? 'N/A').toString());

        if (changesByLabel.containsKey('Brand Name')) {
          final ch = changesByLabel['Brand Name'] as Map<String, dynamic>;
          addRow(
              'Brand Name',
              '${ch['previous']?.toString() ?? 'N/A'} → '
                  '${ch['new']?.toString() ?? 'N/A'}');
        } else {
          addRow(
              'Brand Name', (s['brandName'] ?? s['brand'] ?? 'N/A').toString());
        }

        if (changesByLabel.containsKey('Supplier Name')) {
          final ch = changesByLabel['Supplier Name'] as Map<String, dynamic>;
          addRow(
              'Supplier Name',
              '${ch['previous']?.toString() ?? 'N/A'} → '
                  '${ch['new']?.toString() ?? 'N/A'}');
        } else {
          addRow('Supplier Name',
              (s['supplierName'] ?? s['supplier'] ?? 'N/A').toString());
        }

        // The following fields are PO-specific. Only show for Purchase Order.
        if (isPurchaseOrder) {
          // Quantity
          if (changesByLabel.containsKey('Quantity')) {
            final ch = changesByLabel['Quantity'] as Map<String, dynamic>;
            addRow(
                'Quantity',
                '${ch['previous']?.toString() ?? 'N/A'} → '
                    '${ch['new']?.toString() ?? 'N/A'}');
          } else if (s.containsKey('quantity')) {
            addRow('Quantity', (s['quantity'] ?? 0).toString());
          }

          // Cost
          if (changesByLabel.containsKey('Cost')) {
            final ch = changesByLabel['Cost'] as Map<String, dynamic>;
            final prev = ch['previous']?.toString() ?? '0';
            final curr = ch['new']?.toString() ?? '0';
            final prevFmt = formatPeso(double.tryParse(prev) ?? 0);
            final currFmt = formatPeso(double.tryParse(curr) ?? 0);
            addRow('Cost', prevFmt + ' → ' + currFmt);
          } else if (s.containsKey('cost')) {
            addRow('Cost', formatPeso(s['cost'] ?? 0));
          }

          // Expiry Date(s)
          if (changesByLabel.containsKey('Expiry Date')) {
            final ch = changesByLabel['Expiry Date'] as Map<String, dynamic>;
            final prev = formatDateString(ch['previous']?.toString() ?? '');
            final curr = formatDateString(ch['new']?.toString() ?? '');
            addRow('Expiry Date', prev + ' → ' + curr);
          } else if (s.containsKey('expiryBatches') ||
              s.containsKey('expiryDate')) {
            final List<dynamic> batches = (s['expiryBatches'] as List?) ?? [];
            if (batches.isNotEmpty) {
              for (final b in batches) {
                final raw = (b['expiryDate'] ?? 'No expiry date').toString();
                addRow('Expiry Date', formatDateString(raw));
              }
            } else {
              final raw = (s['expiryDate'] ?? 'No expiry date').toString();
              addRow('Expiry Date', formatDateString(raw));
            }
          }
        }

        if (i < suppliesList.length - 1) {
          addDivider();
        }
      }

      return rows;
    }

    // Single-supply/legacy path: order fields
    final List<MapEntry<String, String>> orderedEntries = [];
    if (metadata.containsKey('supplyName')) {
      orderedEntries.add(const MapEntry('supplyName', 'Supply Name'));
    }
    if (metadata.containsKey('itemName')) {
      orderedEntries.add(const MapEntry('itemName', 'Supply Name'));
    }
    if (metadata.containsKey('category')) {
      orderedEntries.add(const MapEntry('category', 'Category'));
    }
    if (metadata.containsKey('stock')) {
      orderedEntries.add(const MapEntry('stock', 'Stock'));
    }
    if (metadata.containsKey('unit')) {
      orderedEntries.add(const MapEntry('unit', 'Unit'));
    }
    if (metadata.containsKey('cost')) {
      orderedEntries.add(const MapEntry('cost', 'Cost'));
    }
    if (metadata.containsKey('brand')) {
      orderedEntries.add(const MapEntry('brand', 'Brand Name'));
    }
    if (metadata.containsKey('supplier')) {
      orderedEntries.add(const MapEntry('supplier', 'Supplier Name'));
    }

    // Add PO specific fields when no supplies array
    if (metadata.containsKey('brandName')) {
      orderedEntries.add(const MapEntry('brandName', 'Brand Name'));
    }
    if (metadata.containsKey('supplierName')) {
      orderedEntries.add(const MapEntry('supplierName', 'Supplier Name'));
    }
    if (metadata.containsKey('quantity')) {
      orderedEntries.add(const MapEntry('quantity', 'Quantity'));
    }
    if (metadata.containsKey('subtotal')) {
      orderedEntries.add(const MapEntry('subtotal', 'Total'));
    }

    // Expiry keys
    final hasBatches = metadata.containsKey('expiryBatches') &&
        (metadata['expiryBatches'] is List) &&
        ((metadata['expiryBatches'] as List).isNotEmpty);
    if (hasBatches) {
      orderedEntries.add(const MapEntry('expiryBatches', 'Expiry Date'));
    } else if (metadata.containsKey('expiryDate')) {
      orderedEntries.add(const MapEntry('expiryDate', 'Expiry Date'));
    }

    // Add remaining metadata (excluding internal preset keys and duplicates)
    for (final entry in metadata.entries) {
      final lowerKey = entry.key.toString().toLowerCase();
      final isDuplicateSpecial =
          lowerKey == 'expirybatches' || lowerKey == 'expirydate';
      final already = orderedEntries.any((e) => e.key == entry.key);
      final isInternalPresetKey = entry.key == 'presetName' ||
          entry.key == 'originalPresetName' ||
          entry.key == 'suppliesCount' ||
          entry.key == 'originalSuppliesCount' ||
          entry.key == 'fieldChanges';
      if (!already && !isDuplicateSpecial && !isInternalPresetKey) {
        orderedEntries
            .add(MapEntry(entry.key, mapMetadataKeyToLabel(entry.key)));
      }
    }

    // Inline diff mapping helper
    String mapToFieldChangeKey(String k) {
      switch (k) {
        case 'itemName':
          return 'Name';
        case 'category':
          return 'Category';
        case 'stock':
          return 'Stock';
        case 'unit':
          return 'Unit';
        case 'cost':
          return 'Cost';
        case 'brand':
          return 'Brand';
        case 'supplier':
          return 'Supplier';
        case 'expiryDate':
          return 'Expiry Date';
        default:
          if (k.isEmpty) return k;
          return k[0].toUpperCase() + k.substring(1);
      }
    }

    // Build rows
    for (final entry in orderedEntries) {
      String value;

      if (entry.key == 'expiryDate') {
        value = (metadata['expiryDate']?.toString() ?? 'No expiry date');
        value = formatDateString(value);
      } else if (entry.key == 'subtotal') {
        value = formatPeso(metadata[entry.key]);
      } else if (entry.key == 'expiryBatches') {
        final List<dynamic> batches =
            (metadata['expiryBatches'] as List?) ?? [];
        if (batches.isEmpty) {
          final raw = metadata['expiryDate']?.toString() ?? 'No expiry date';
          addRow('Expiry Date', formatDateString(raw));
          continue;
        } else {
          for (final b in batches) {
            final raw = (b['expiryDate'] ?? 'No expiry date').toString();
            final date = formatDateString(raw);
            addRow('Expiry Date', date);
          }
          continue;
        }
      } else if (entry.key == 'addedSupplies') {
        final List<dynamic> addedSupplies =
            (metadata['addedSupplies'] as List?) ?? [];
        if (addedSupplies.isEmpty) {
          continue;
        }
        value = addedSupplies.join(', ');
      } else if (entry.key == 'removedSupplies') {
        final List<dynamic> removedSupplies =
            (metadata['removedSupplies'] as List?) ?? [];
        if (removedSupplies.isEmpty) {
          continue;
        }
        value = removedSupplies.join(', ');
      } else {
        value = metadata[entry.key]?.toString() ?? 'N/A';
        if (entry.key == 'cost') {
          value = formatPeso(metadata[entry.key]);
        }
      }

      // Inline diffs if available
      if (metadata.containsKey('fieldChanges') &&
          metadata['fieldChanges'] is Map<String, dynamic>) {
        final Map<String, dynamic> fieldChanges =
            metadata['fieldChanges'] as Map<String, dynamic>;
        final String fcKey = mapToFieldChangeKey(entry.key);
        if (fieldChanges.containsKey(fcKey)) {
          final changes = fieldChanges[fcKey] as Map<String, dynamic>;
          String previous = changes['previous']?.toString() ?? 'N/A';
          String newValue = changes['new']?.toString() ?? 'N/A';
          if (fcKey == 'Expiry Date') {
            previous = formatDateString(previous);
            newValue = formatDateString(newValue);
          } else if (fcKey == 'Cost') {
            final prevNum = double.tryParse(previous);
            final newNum = double.tryParse(newValue);
            previous = prevNum != null ? formatPeso(prevNum) : previous;
            newValue = newNum != null ? formatPeso(newNum) : newValue;
          }
          value = '$previous → $newValue';
        }
      }

      addRow(entry.value, value);
    }

    return rows;
  }
}
