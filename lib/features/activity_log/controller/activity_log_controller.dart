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
  StreamSubscription? _activitiesSubscription;

  // Getters
  DateTime get selectedDate => _selectedDate;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  List<Map<String, dynamic>> get allActivities => _allActivities;

  // Filtered activities based on current filters
  List<Map<String, dynamic>> get filteredActivities {
    List<Map<String, dynamic>> filtered = _allActivities;

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

  // Constructor - start listening to Firebase
  ActivityLogController() {
    _startListeningToActivities();
  }

  @override
  void dispose() {
    _activitiesSubscription?.cancel();
    super.dispose();
  }

  // Start listening to activities from Supabase
  void _startListeningToActivities() {
    try {
      _activitiesSubscription = _supabase
          .from('activity_logs')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .listen((data) {
            if (data is List<Map<String, dynamic>>) {
              _allActivities = data.map((row) {
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
                  'metadata': row['metadata'] ?? {},
                };
              }).toList();

              notifyListeners();
            }
          });
    } catch (e) {
      print('Error starting activity stream: $e');
    }
  }

  // Methods to update filters
  void updateSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void updateSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
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
    // Activities are automatically fetched via Firebase stream
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
