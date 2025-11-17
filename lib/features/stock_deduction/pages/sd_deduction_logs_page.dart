import 'dart:async';
import 'package:flutter/material.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/stock_deduction/controller/sd_logs_controller.dart';
import 'package:familee_dental/features/activity_log/controller/sd_activity_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/services/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shimmer/shimmer.dart';

class DeductionLogsPage extends StatefulWidget {
  const DeductionLogsPage({super.key});

  @override
  State<DeductionLogsPage> createState() => _DeductionLogsPageState();
}

class _DeductionLogsPageState extends State<DeductionLogsPage> {
  final TextEditingController _searchController = TextEditingController();
  final StockDeductionLogsController _logsController =
      StockDeductionLogsController();
  final SdActivityController _activityController = SdActivityController();
  List<Map<String, dynamic>> _allLogs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  List<Map<String, dynamic>> _lastKnownLogs = []; // Cache last known data
  Timer? _debounceTimer;
  final Set<String> _expandedCards = <String>{};
  // Stream key for forcing refresh
  Stream<List<Map<String, dynamic>>> _logsStream =
      const Stream<List<Map<String, dynamic>>>.empty();
  int _streamKey = 0;
  bool _isFirstLoad = true;
  DateTime _selectedDate = DateTime.now();
  int _currentPage = 1;
  static const int _itemsPerPage = 6;
  bool? _hasConnection;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializeStream();
    // Pre-loading no longer needed - streams auto-load from Hive
    // _logsController.preloadLogs().then((_) {
    //   if (mounted) setState(() {});
    // });
    // Auto-save deduction log if navigation provided data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _savePendingLog();
    });
    _initConnectivityWatch();
  }

  Future<void> _savePendingLog() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final purpose = args?['purpose'] as String?;
    final remarks = args?['remarks'] as String?;
    final supplies = args?['supplies'] as List<dynamic>?;
    final approvalId = args?['approval_id'];

    if (purpose != null && supplies != null && supplies.isNotEmpty) {
      try {
        final logData = {
          'purpose': purpose,
          'remarks': remarks,
          'supplies': supplies,
          'approval_id': approvalId,
        };
        await _logsController.saveLog(logData);

        await _activityController.logDeductionLogCreated(
          purpose: purpose,
          supplies: supplies.cast<Map<String, dynamic>>(),
        );

        // Force refresh the stream to show the updated/new log immediately
        _refreshLogs();

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
    _logsStream = _logsController.getLogsStream(selectedDate: _selectedDate);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivityWatch() async {
    try {
      final hasConnection = await ConnectivityService().hasInternetConnection();
      if (mounted) {
        setState(() {
          _hasConnection = hasConnection;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasConnection = null;
        });
      }
    }

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final bool online = results.any((result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet);
      if (mounted) {
        setState(() {
          _hasConnection = online;
        });
      }
    });
  }

  void _onSearchChanged() {
    // Update immediately for real-time search feedback
    _debounceTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _currentPage = 1;
    });
    _filterLogs();
    setState(() {});
  }

  List<Map<String, dynamic>> _logsForSelectedDate(
      List<Map<String, dynamic>> logs, DateTime date) {
    return logs.where((log) {
      final createdAt = log['created_at']?.toString();
      if (createdAt == null || createdAt.isEmpty) return false;
      try {
        final parsed = DateTime.parse(createdAt).toLocal();
        return parsed.year == date.year &&
            parsed.month == date.month &&
            parsed.day == date.day;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  void _filterLogs() {
    final query = _searchController.text.toLowerCase().trim();
    // Controller already filters by date, so we only need to filter by search query
    List<Map<String, dynamic>> filtered = List.from(_allLogs);

    if (query.isNotEmpty) {
      filtered = filtered.where((log) {
        final purpose = log['purpose']?.toString().toLowerCase() ?? '';

        if (purpose.startsWith(query)) {
          return true;
        }

        final words = purpose.split(' ');
        for (final word in words) {
          if (word.startsWith(query)) {
            return true;
          }
        }

        return false;
      }).toList();
    }

    _filteredLogs = filtered;

    // Reset to page 1 when filters change
    final totalPages = (_filteredLogs.length / _itemsPerPage).ceil();
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = 1;
    } else if (_filteredLogs.isEmpty) {
      _currentPage = 1;
    }
  }

  List<Map<String, dynamic>> get _paginatedLogs {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredLogs.length) {
      return [];
    }
    return _filteredLogs.sublist(
      startIndex,
      endIndex > _filteredLogs.length ? _filteredLogs.length : endIndex,
    );
  }

  int get _totalPages => (_filteredLogs.length / _itemsPerPage).ceil();

  String _formatDateForDisplay(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$month/$day/$year';
  }

  Future<void> _refreshLogs() async {
    // Force stream refresh by recreating it with current selected date
    _streamKey++;
    _initializeStream();
    setState(() {});

    // Wait for the stream to emit at least one event
    // This ensures the RefreshIndicator shows its animation
    await _logsStream.first;
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
              // Deduction cards skeleton
              Expanded(
                child: ListView.builder(
                  itemCount: 6,
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
        onRefresh: _refreshLogs,
        color: const Color(0xFF00D4AA),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          key: ValueKey(_streamKey),
          stream: _logsStream,
          builder: (context, snapshot) {
            // Get cached logs for the selected date FIRST (before skeleton check)
            final List<Map<String, dynamic>> cachedForDate =
                _logsController.hasCachedDataFor(_selectedDate)
                    ? (_logsController.getCachedLogsForDate(_selectedDate) ??
                        const <Map<String, dynamic>>[])
                    : const <Map<String, dynamic>>[];
            final List<Map<String, dynamic>> liveRaw =
                snapshot.data ?? const <Map<String, dynamic>>[];
            final List<Map<String, dynamic>> liveForDate =
                _logsForSelectedDate(liveRaw, _selectedDate);

            final bool hasLive = liveForDate.isNotEmpty;
            final bool hasCached =
                cachedForDate.isNotEmpty || _lastKnownLogs.isNotEmpty;

            // Show skeleton loader only if still waiting for initial data
            // Don't show if data has been emitted (even if empty) or if cached data exists
            final bool showSkeleton = (_hasConnection != false) &&
                _isFirstLoad &&
                !snapshot.hasData &&
                !hasCached;

            if (showSkeleton) {
              return _buildSkeletonLoader(context);
            }

            if (!hasLive &&
                !hasCached &&
                (_hasConnection == false || snapshot.hasError)) {
              if (_isFirstLoad) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _isFirstLoad = false;
                    });
                  }
                });
              }
            }

            if (_isFirstLoad) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _isFirstLoad = false;
                  });
                }
              });
            }

            if (hasLive) {
              _allLogs = List<Map<String, dynamic>>.from(liveForDate);
              _lastKnownLogs = List<Map<String, dynamic>>.from(liveForDate);
            } else if (_lastKnownLogs.isNotEmpty) {
              _allLogs = List<Map<String, dynamic>>.from(_lastKnownLogs);
            } else {
              _allLogs = List<Map<String, dynamic>>.from(cachedForDate);
              _lastKnownLogs = List<Map<String, dynamic>>.from(cachedForDate);
            }

            _filterLogs();

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
                      // Search bar and date picker row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
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
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withOpacity(0.2),
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
                                  fillColor:
                                      Theme.of(context).colorScheme.surface,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                style: AppFonts.sfProStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                    _currentPage = 1;
                                    _isFirstLoad = true;
                                    _lastKnownLogs.clear();
                                    _allLogs = [];
                                    _filteredLogs = [];
                                    _streamKey++;
                                  });
                                  _initializeStream();
                                  _filterLogs();
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
                          child: _filteredLogs.isEmpty
                              ? _buildEmptyState(
                                  isOffline: _hasConnection == false,
                                  hasCache: _logsController
                                          .hasCachedDataFor(_selectedDate) ||
                                      _lastKnownLogs.isNotEmpty,
                                )
                              : Column(
                                  children: [
                                    Expanded(
                                      child: ListView.builder(
                                        padding: const EdgeInsets.all(12),
                                        itemCount: _paginatedLogs.length,
                                        itemBuilder: (context, index) {
                                          final log = _paginatedLogs[index];
                                          return _buildLogCard(log, index);
                                        },
                                      ),
                                    ),
                                    if (_filteredLogs.length >= _itemsPerPage)
                                      _buildPagination(),
                                  ],
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

  Widget _buildEmptyState({required bool isOffline, required bool hasCache}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF8B5A8B);

    final bool showOfflineEmpty = isOffline && !hasCache;
    final String title = showOfflineEmpty
        ? 'Deduction logs unavailable offline'
        : (_searchController.text.isEmpty
            ? 'No deduction logs found'
            : 'No logs found');
    final String subtitle = showOfflineEmpty
        ? 'Reconnect to the internet to refresh this date.'
        : (_searchController.text.isEmpty
            ? 'Pull down to fetch the latest deduction logs for this date.'
            : 'Try adjusting your search terms.');

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
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
                    title,
                    style: AppFonts.sfProStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: AppFonts.sfProStyle(
                      fontSize: 14,
                      color: textColor.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log, int index) {
    final theme = Theme.of(context);
    final supplies = log['supplies'] as List<dynamic>? ?? [];
    final createdDisplay = _formatDateTimeLabel(log['created_at']);
    final supplyCountLabel =
        supplies.length == 1 ? '1 supply' : '${supplies.length} supplies';
    final cardKey =
        log['id']?.toString() ?? 'idx_${index}_${log['created_at']}';
    final isExpanded = _expandedCards.contains(cardKey);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.colorScheme.surface,
      elevation: 2,
      shadowColor: theme.shadowColor.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCards.remove(cardKey);
                } else {
                  _expandedCards.add(cardKey);
                }
              });
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
                                createdDisplay,
                                style: AppFonts.sfProStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4AA).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00D4AA).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: const Color(0xFF00D4AA),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          supplyCountLabel,
                          style: AppFonts.sfProStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00D4AA),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.iconTheme.color?.withOpacity(0.8),
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? theme.colorScheme.surface
                    : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                border: Border.all(
                  color: theme.dividerColor.withOpacity(0.2),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            color: theme.textTheme.bodyMedium?.color,
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
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.8),
                          ),
                        ),
                      )
                    else
                      ...supplies.asMap().entries.map((entry) {
                        final supply = entry.value as Map<String, dynamic>;
                        return _buildSupplyCard(
                          context: context,
                          supply: supply,
                        );
                      }).toList(),

                    // Remarks Section (only show if remarks exist)
                    if (log['remarks'] != null &&
                        log['remarks'].toString().trim().isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Remarks:',
                          style: AppFonts.sfProStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          log['remarks'].toString().trim(),
                          style: AppFonts.sfProStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ],

                    // Deducted by section
                    if (log['created_by_name'] != null &&
                        log['created_by_name']
                            .toString()
                            .trim()
                            .isNotEmpty) ...[
                      const SizedBox(height: 34),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Deducted by ${log['created_by_name'].toString().trim()}',
                          style: AppFonts.sfProStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSupplyCard({
    required BuildContext context,
    required Map<String, dynamic> supply,
  }) {
    final theme = Theme.of(context);
    final deductQty = supply['deductQty'] ?? supply['quantity'] ?? 0;
    final imageUrl = supply['imageUrl']?.toString();
    final purposeRaw = (supply['purpose']?.toString() ?? '').trim();
    final purposeLabel = purposeRaw.isEmpty ? 'No Purpose' : purposeRaw;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.grey[700]!.withOpacity(0.5)
              : Colors.grey[300]!.withOpacity(0.8),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _formatExpiry(
                        supply['expiry'],
                        supply['noExpiry'] == true,
                      ),
                      style: AppFonts.sfProStyle(
                        fontSize: 12,
                        color:
                            theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4AA).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFF00D4AA).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        purposeLabel,
                        style: AppFonts.sfProStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF00D4AA),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4AA).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF00D4AA).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'x$deductQty',
                        style: AppFonts.sfProStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00D4AA),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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
        ],
      ),
    );
  }

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
      return '${packagingContentQuantity ?? ''} ${packagingContent} per $packagingUnit';
    } else if (packagingUnit != null && packagingUnit.toString().isNotEmpty) {
      return packagingUnit.toString();
    }
    return '';
  }

  Widget _buildPagination() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color backgroundColor =
        isDark ? theme.colorScheme.surface : const Color(0xFFE8D5E8);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(12),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Page $_currentPage of $_totalPages',
            style: AppFonts.sfProStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous button - IconButton with no background
              IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  color: _currentPage > 1
                      ? theme.textTheme.bodyLarge?.color
                      : theme.textTheme.bodyLarge?.color?.withOpacity(0.3),
                  size: 24,
                ),
                onPressed: _currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage--;
                        });
                      }
                    : null,
                tooltip: 'Previous',
              ),
              // Page number buttons
              ...List.generate(_totalPages, (index) {
                final pageNumber = index + 1;
                final isActive = pageNumber == _currentPage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _currentPage = pageNumber;
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 36,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive
                            ? theme.primaryColor.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.dividerColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '$pageNumber',
                        style: AppFonts.sfProStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              // Next button - IconButton with no background
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: _currentPage < _totalPages
                      ? theme.textTheme.bodyLarge?.color
                      : theme.textTheme.bodyLarge?.color?.withOpacity(0.3),
                  size: 24,
                ),
                onPressed: _currentPage < _totalPages
                    ? () {
                        setState(() {
                          _currentPage++;
                        });
                      }
                    : null,
                tooltip: 'Next',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTimeLabel(dynamic createdAt) {
    DateTime? parsed;
    if (createdAt is DateTime) {
      parsed = createdAt;
    } else if (createdAt is String && createdAt.isNotEmpty) {
      try {
        parsed = DateTime.parse(createdAt);
      } catch (_) {
        parsed = null;
      }
    }

    if (parsed == null) {
      return 'Deduction';
    }

    final local = parsed.toLocal();
    final datePart =
        '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}/${local.year}';
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;
    final timePart = '$displayHour:$minute $period';
    return '$datePart - $timePart';
  }
}
