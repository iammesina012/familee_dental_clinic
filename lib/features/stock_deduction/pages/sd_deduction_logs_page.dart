import 'dart:async';
import 'package:flutter/material.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/stock_deduction/controller/sd_preset_management_controller.dart';
import 'package:familee_dental/features/activity_log/controller/sd_activity_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/widgets/notification_badge_button.dart';
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
  // Track which preset dropdown is expanded
  String? _expandedPresetId;
  // Stream key for forcing refresh
  late Stream<List<Map<String, dynamic>>> _presetsStream;
  int _streamKey = 0;
  bool _isFirstLoad = true;

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

    if (purpose != null && supplies != null && supplies.isNotEmpty) {
      try {
        // Create preset data with purpose as name
        final presetData = {
          'name': purpose,
          'supplies': supplies,
        };
        if (remarks != null && remarks.isNotEmpty) {
          presetData['remarks'] = remarks;
        }

        // Save the preset
        await _presetController.savePreset(presetData);

        // Log the preset creation activity
        final suppliesList = supplies.cast<Map<String, dynamic>>();
        await _activityController.logPresetCreated(
          presetName: purpose,
          supplies: suppliesList,
        );

        // Force refresh the stream to show the new preset immediately
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
    _presetsStream = PresetController().getPresetsStream();
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
    if (query.isEmpty) {
      _filteredPresets = _allPresets;
    } else {
      _filteredPresets = _allPresets.where((preset) {
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
        actions: [
          const NotificationBadgeButton(),
        ],
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
    final presetId = preset['id'] ?? index.toString();
    final isExpanded = _expandedPresetId == presetId;
    final supplies = preset['supplies'] as List<dynamic>? ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      shadowColor: Theme.of(context).shadowColor.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Main preset info with dropdown button
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedPresetId = null;
                } else {
                  _expandedPresetId = presetId;
                }
              });
            },
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
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
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color,
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
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Theme.of(context).iconTheme.color?.withOpacity(0.8),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          // Dropdown content
          if (isExpanded) ...[
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surface
                    : Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                children: [
                  // Supplies list
                  if (supplies.isNotEmpty) ...[
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: supplies.length,
                        itemBuilder: (context, supplyIndex) {
                          final supply =
                              supplies[supplyIndex] as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    supply['imageUrl'] ?? '',
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 32,
                                      height: 32,
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.inventory,
                                        color: Colors.grey,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    supply['name'] ?? 'Unknown Supply',
                                    style: AppFonts.sfProStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.all(16),
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
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
