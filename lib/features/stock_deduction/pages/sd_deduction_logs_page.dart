import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/stock_deduction/controller/sd_preset_management_controller.dart';
import 'package:familee_dental/features/activity_log/controller/sd_activity_controller.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:shimmer/shimmer.dart';

class DeductionLogsPage extends StatefulWidget {
  const DeductionLogsPage({super.key});

  @override
  State<DeductionLogsPage> createState() => _DeductionLogsPageState();
}

class _DeductionLogsPageState extends State<DeductionLogsPage> {
  final TextEditingController _searchController = TextEditingController();
  final PresetController _presetController = PresetController();
  final SdActivityController _activityController = SdActivityController();
  List<Map<String, dynamic>> _allPresets = [];
  List<Map<String, dynamic>> _filteredPresets = [];
  List<Map<String, dynamic>> _lastKnownPresets = []; // Cache last known data
  Timer? _debounceTimer;
  // Stream key for forcing refresh
  late Stream<List<Map<String, dynamic>>> _presetsStream;
  int _streamKey = 0;
  bool _isFirstLoad = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializeStream();
    // Auto-save purpose and supplies as a preset if they exist
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndSavePurposePreset();
    });
  }

  Future<void> _checkAndSavePurposePreset() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final purpose = args?['purpose'] as String?;
    final remarks = args?['remarks'] as String?;
    final supplies = args?['supplies'] as List<dynamic>?;
    final patientName = args?['patient_name'] as String?;
    final age = args?['age'] as String?;
    final gender = args?['gender'] as String?;
    final conditions = args?['conditions'] as String?;

    if (purpose != null && supplies != null && supplies.isNotEmpty) {
      try {
        // Create preset data with purpose as name
        // Mark it as from deduction log so we can filter it
        final presetData = {
          'name': purpose,
          'supplies': supplies,
          'from_deduction': true, // Mark as created from approved deduction
        };
        if (remarks != null && remarks.isNotEmpty) {
          presetData['remarks'] = remarks;
        }
        // Include patient information if available
        if (patientName != null && patientName.isNotEmpty) {
          presetData['patient_name'] = patientName;
        }
        if (age != null && age.isNotEmpty) {
          presetData['age'] = age;
        }
        if (gender != null && gender.isNotEmpty) {
          presetData['gender'] = gender;
        }
        if (conditions != null && conditions.isNotEmpty) {
          presetData['conditions'] = conditions;
        }

        // Check if a deduction log preset with this name already exists
        // Only update if it's already a deduction log preset (from_deduction == true)
        // Don't update service management presets - create a new record instead
        final existingPreset = await _presetController.getPresetByName(purpose);
        final isExistingDeductionLog = existingPreset != null &&
            (existingPreset['from_deduction'] == true ||
                existingPreset['fromDeduction'] == true);

        if (isExistingDeductionLog) {
          // Update existing deduction log preset instead of creating duplicate
          await _presetController.updatePreset(
              existingPreset['id'], presetData);
        } else {
          // Always create a new preset for deduction logs
          // This ensures service management presets are not overwritten
          await _presetController.savePreset(presetData);

          // Log the preset creation activity (only if newly created)
          final suppliesList = supplies.cast<Map<String, dynamic>>();
          await _activityController.logPresetCreated(
            presetName: purpose,
            supplies: suppliesList,
          );
        }

        // Force refresh the stream to show the updated/new preset immediately
        _refreshPresets();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Deduction saved successfully',
                style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
              ),
              backgroundColor: const Color(0xFF00D4AA),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to save deduction: $e',
                style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _initializeStream() {
    // Only show presets that were created from approved deductions
    _presetsStream = PresetController().getPresetsStream().map((presets) =>
        presets
            .where((preset) =>
                preset['from_deduction'] == true ||
                preset['fromDeduction'] == true)
            .toList());
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    // Update immediately for real-time search feedback
    _debounceTimer?.cancel();
    if (!mounted) return;
    _filterPresets();
    setState(() {});
  }

  void _filterPresets() {
    final query = _searchController.text.toLowerCase().trim();
    List<Map<String, dynamic>> filtered = List.from(_allPresets);

    // Filter by date first
    filtered = filtered.where((preset) {
      final createdAt = preset['created_at']?.toString();
      if (createdAt == null || createdAt.isEmpty) return false;

      try {
        final presetDate = DateTime.parse(createdAt);
        return presetDate.year == _selectedDate.year &&
            presetDate.month == _selectedDate.month &&
            presetDate.day == _selectedDate.day;
      } catch (e) {
        return false;
      }
    }).toList();

    // Then filter by search query
    if (query.isNotEmpty) {
      filtered = filtered.where((preset) {
        final presetName = preset['name']?.toString().toLowerCase() ?? '';

        // Check if the name starts with the search text
        if (presetName.startsWith(query)) {
          return true;
        }

        // Check if any word in the name starts with the search text
        final words = presetName.split(' ');
        for (final word in words) {
          if (word.startsWith(query)) {
            return true;
          }
        }

        return false;
      }).toList();
    }

    _filteredPresets = filtered;
  }

  String _formatDateForDisplay(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$month/$day/$year';
  }

  String _formatTimeForDisplay(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;
    return '$displayHour:$minute $period';
  }

  // Pull-to-refresh method
  Future<void> _refreshPresets() async {
    // Force stream refresh by recreating it
    _streamKey++;
    _initializeStream();
    setState(() {});

    // Wait for the stream to emit at least one event
    // This ensures the RefreshIndicator shows its animation
    await _presetsStream.first;
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ResponsiveContainer(
      maxWidth: 1100,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // Search bar skeleton
              Shimmer.fromColors(
                baseColor: baseColor,
                highlightColor: highlightColor,
                child: Container(
                  height: 56,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Preset cards skeleton
              Expanded(
                child: ListView.builder(
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Shimmer.fromColors(
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                      child: Container(
                        height: 120,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Deduction Logs',
          style: AppFonts.sfProStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).appBarTheme.titleTextStyle?.color ??
                  Theme.of(context).textTheme.titleLarge?.color),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
        elevation: Theme.of(context).appBarTheme.elevation ?? 5,
        shadowColor: Theme.of(context).appBarTheme.shadowColor ??
            Theme.of(context).shadowColor,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPresets,
        color: const Color(0xFF00D4AA),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          key: ValueKey(_streamKey),
          stream: _presetsStream,
          builder: (context, snapshot) {
            // Show skeleton loader only on first load
            if (_isFirstLoad && !snapshot.hasData) {
              return _buildSkeletonLoader(context);
            }

            // Mark first load as complete once we have data
            if (snapshot.hasData && _isFirstLoad) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _isFirstLoad = false;
                  });
                }
              });
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading deduction logs: ${snapshot.error}',
                  style: AppFonts.sfProStyle(fontSize: 16, color: Colors.red),
                ),
              );
            }

            // Update data and cache it when we have valid data
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              _allPresets = snapshot.data!;
              _lastKnownPresets = List.from(snapshot.data!);
            } else if (snapshot.hasData &&
                snapshot.data!.isEmpty &&
                _lastKnownPresets.isEmpty) {
              // Only update to empty if we never had data
              _allPresets = [];
            } else if (!snapshot.hasData && _lastKnownPresets.isNotEmpty) {
              // During refresh, use cached data
              _allPresets = _lastKnownPresets;
            } else {
              _allPresets = snapshot.data ?? [];
            }

            _filterPresets();

            return ResponsiveContainer(
              maxWidth: 1100,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
                    vertical: 12.0,
                  ),
                  child: Column(
                    children: [
                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .shadowColor
                                  .withOpacity(0.08),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                          border: Border.all(
                            color:
                                Theme.of(context).dividerColor.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search deduction logs...',
                            hintStyle: AppFonts.sfProStyle(
                              fontSize: 16,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withOpacity(0.6),
                            ),
                            prefixIcon: Icon(Icons.search,
                                color: Theme.of(context).iconTheme.color),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          style: AppFonts.sfProStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Date picker row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.2),
                              ),
                            ),
                            child: InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null && mounted) {
                                  setState(() {
                                    _selectedDate = picked;
                                  });
                                  _filterPresets();
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Theme.of(context).iconTheme.color,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDateForDisplay(_selectedDate),
                                      style: AppFonts.sfProStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Theme.of(context).colorScheme.surface
                                    : const Color(0xFFE8D5E8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.2)),
                          ),
                          child: _filteredPresets.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _filteredPresets.length,
                                  itemBuilder: (context, index) {
                                    final preset = _filteredPresets[index];
                                    return _buildPresetCard(preset, index);
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF8B5A8B);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey.withOpacity(0.2)
                  : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.history,
              size: 60,
              color: isDark
                  ? Colors.white.withOpacity(0.7)
                  : const Color(0xFF8B5A8B),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchController.text.isEmpty
                ? 'No Deduction Logs Yet'
                : 'No Logs Found',
            style: AppFonts.sfProStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty
                ? 'Deductions will appear here after you deduct supplies'
                : 'Try adjusting your search terms',
            style: AppFonts.sfProStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard(Map<String, dynamic> preset, int index) {
    final supplies = preset['supplies'] as List<dynamic>? ?? [];
    final presetId = preset['id']?.toString() ?? '';
    final isStaff = UserRoleProvider().isStaff;

    // Parse time from created_at
    String? timeDisplay;
    try {
      final createdAt = preset['created_at']?.toString();
      if (createdAt != null && createdAt.isNotEmpty) {
        final date = DateTime.parse(createdAt);
        timeDisplay = _formatTimeForDisplay(date);
      }
    } catch (e) {
      // If parsing fails, timeDisplay will remain null
    }

    // Card content
    final cardContent = Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      shadowColor: Theme.of(context).shadowColor.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: () {
          _showPresetDetailModal(preset);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.history,
                      color: const Color(0xFF00D4AA),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preset['name'] ?? 'Unnamed Deduction',
                            style: AppFonts.sfProStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${supplies.length} ${supplies.length == 1 ? 'supply' : 'supplies'}',
                            style: AppFonts.sfProStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.color
                                  ?.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (timeDisplay != null) ...[
                Text(
                  timeDisplay,
                  style: AppFonts.sfProStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.color
                        ?.withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).iconTheme.color?.withOpacity(0.8),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );

    // Return slidable if not staff, otherwise just the card
    if (isStaff) {
      return cardContent;
    }

    return Slidable(
      key: ValueKey('deduction-log-$presetId-$index'),
      closeOnScroll: true,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => _deleteDeductionLog(preset),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Remove',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: cardContent,
    );
  }

  Future<void> _deleteDeductionLog(Map<String, dynamic> preset) async {
    final presetName = preset['name']?.toString() ?? 'this deduction log';
    final presetId = preset['id']?.toString();

    if (presetId == null || presetId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot delete: Invalid preset ID',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Remove Deduction Log',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to remove "$presetName"? This action cannot be undone.',
            style: AppFonts.sfProStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style:
                    AppFonts.sfProStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(
                'Remove',
                style: AppFonts.sfProStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      // Delete the preset from database
      await _presetController.deletePreset(presetId);

      // Log the deletion activity
      await _activityController.logPresetDeleted(
        presetName: presetName,
        supplies: List<Map<String, dynamic>>.from(preset['supplies'] ?? []),
      );

      if (!mounted) return;

      // Refresh the stream to update the list
      _refreshPresets();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deduction log removed successfully',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF00D4AA),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to remove deduction log: $e',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showPresetDetailModal(Map<String, dynamic> preset) {
    showDialog(
      context: context,
      builder: (context) => _PresetDetailModal(preset: preset),
    );
  }
}

class _PresetDetailModal extends StatelessWidget {
  final Map<String, dynamic> preset;

  const _PresetDetailModal({required this.preset});

  String _formatExpiry(dynamic expiry, bool? noExpiry) {
    if (noExpiry == true) return 'No Expiry';
    if (expiry == null || expiry.toString().isEmpty) return 'No Expiry';
    final expiryStr = expiry.toString();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(expiryStr)) {
      return expiryStr.replaceAll('-', '/');
    }
    return expiryStr;
  }

  String _buildPackagingString(Map<String, dynamic> supply) {
    final packagingContentQuantity = supply['packagingContentQuantity'];
    final packagingContent = supply['packagingContent'];
    final packagingUnit = supply['packagingUnit'];

    if (packagingContent != null &&
        packagingContent.toString().isNotEmpty &&
        packagingUnit != null &&
        packagingUnit.toString().isNotEmpty) {
      // Format: "10mL per Bottle"
      return '${packagingContentQuantity ?? ''} ${packagingContent} per $packagingUnit';
    } else if (packagingUnit != null && packagingUnit.toString().isNotEmpty) {
      // Format: "pieces" (just the unit)
      return packagingUnit.toString();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final supplies = preset['supplies'] as List<dynamic>? ?? [];
    final patientName = preset['patient_name']?.toString() ?? '';
    final age = preset['age']?.toString() ?? '';
    final gender = preset['gender']?.toString() ?? '';
    final conditions = preset['conditions']?.toString() ?? '';
    final hasPatientInfo = patientName.isNotEmpty ||
        age.isNotEmpty ||
        gender.isNotEmpty ||
        conditions.isNotEmpty;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with service name and icon
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4AA).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00D4AA).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.bookmark_rounded,
                      color: Color(0xFF00D4AA),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      preset['name'] ?? 'Deduction Details',
                      style: AppFonts.sfProStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient Information Section
                    if (hasPatientInfo) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 18,
                            color: const Color(0xFF00D4AA),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Patient Information',
                            style: AppFonts.sfProStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]!.withOpacity(0.5)
                              : const Color(0xFF00D4AA).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[700]!.withOpacity(0.3)
                                    : const Color(0xFF00D4AA).withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Row 1: Patient Name | Gender
                            Row(
                              children: [
                                if (patientName.isNotEmpty)
                                  Expanded(
                                    child: _buildModernInfoRow(
                                      context,
                                      Icons.badge_outlined,
                                      'Patient Name',
                                      patientName,
                                    ),
                                  ),
                                if (patientName.isNotEmpty && gender.isNotEmpty)
                                  const SizedBox(width: 16),
                                if (gender.isNotEmpty)
                                  Expanded(
                                    child: _buildModernInfoRow(
                                      context,
                                      Icons.people_outline_rounded,
                                      'Sex',
                                      gender,
                                    ),
                                  ),
                              ],
                            ),
                            // Row 2: Age | Conditions
                            if ((age.isNotEmpty || conditions.isNotEmpty) &&
                                (patientName.isNotEmpty || gender.isNotEmpty))
                              const SizedBox(height: 12),
                            Row(
                              children: [
                                if (age.isNotEmpty)
                                  Expanded(
                                    child: _buildModernInfoRow(
                                      context,
                                      Icons.calendar_today_outlined,
                                      'Age',
                                      age,
                                    ),
                                  ),
                                if (age.isNotEmpty && conditions.isNotEmpty)
                                  const SizedBox(width: 16),
                                if (conditions.isNotEmpty)
                                  Expanded(
                                    child: _buildModernInfoRow(
                                      context,
                                      Icons.medical_information_outlined,
                                      'Conditions',
                                      conditions,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // Supplies Section
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 18,
                          color: const Color(0xFF00D4AA),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Supplies Deducted',
                          style: AppFonts.sfProStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (supplies.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No supplies in this deduction',
                          style: AppFonts.sfProStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.color
                                ?.withOpacity(0.8),
                          ),
                        ),
                      )
                    else
                      ...supplies.asMap().entries.map((entry) {
                        final supply = entry.value as Map<String, dynamic>;
                        return _buildSupplyCard(context, supply, entry.key + 1);
                      }).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF00D4AA),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppFonts.sfProStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppFonts.sfProStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupplyCard(
      BuildContext context, Map<String, dynamic> supply, int index) {
    final theme = Theme.of(context);
    final deductQty = supply['deductQty'] ?? supply['quantity'] ?? 0;
    final imageUrl = supply['imageUrl']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.grey[700]!
              : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          // Supply Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.grey,
                        size: 24,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          // Supply Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Supply name with type in parentheses beside it
                Text(
                  (supply['name'] ?? 'Unknown Supply') +
                      (supply['type'] != null &&
                              supply['type'].toString().isNotEmpty
                          ? ' (${supply['type']})'
                          : ''),
                  style: AppFonts.sfProStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Packaging content/unit below supply name
                Text(
                  _buildPackagingString(supply),
                  style: AppFonts.sfProStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Expiry and Quantity Badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Expiry on the left
              Text(
                _formatExpiry(supply['expiry'], supply['noExpiry'] == true),
                style: AppFonts.sfProStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 8),
              // Quantity Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00D4AA).withOpacity(0.15),
                      const Color(0xFF00D4AA).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF00D4AA).withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  'x${deductQty.toString()}',
                  style: AppFonts.sfProStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00D4AA),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
