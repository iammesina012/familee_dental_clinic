import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:projects/shared/themes/font.dart';
import 'package:projects/features/stock_deduction/controller/preset_controller.dart';
import 'package:projects/features/stock_deduction/pages/edit_preset_page.dart';

class PresetManagementPage extends StatefulWidget {
  const PresetManagementPage({super.key});

  @override
  State<PresetManagementPage> createState() => _PresetManagementPageState();
}

class _PresetManagementPageState extends State<PresetManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  final PresetController _presetController = PresetController();
  List<Map<String, dynamic>> _allPresets = [];
  List<Map<String, dynamic>> _filteredPresets = [];
  Timer? _debounceTimer;
  // Initialize the cached stream at declaration so hot reloads don't cause late-init errors
  final Stream<List<Map<String, dynamic>>> _presetsStream =
      PresetController().getPresetsStream();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
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

  void _createNewPreset() async {
    final result =
        await Navigator.of(context).pushNamed('/stock-deduction/create-preset');
    if (result is Map<String, dynamic>) {
      try {
        await _presetController.savePreset(result);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Preset saved successfully',
              style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF00D4AA),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save preset: $e',
              style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9EFF2),
      appBar: AppBar(
        title: Text(
          'Preset Management',
          style: AppFonts.sfProStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        toolbarHeight: 70,
        iconTheme: const IconThemeData(size: 30, color: Colors.black),
        elevation: 5,
        shadowColor: Colors.black54,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined,
                  color: Colors.red, size: 30),
              tooltip: 'Notifications',
              onPressed: () {},
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewPreset,
        backgroundColor: const Color(0xFF00D4AA),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _presetsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00D4AA),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading presets: ${snapshot.error}',
                style: AppFonts.sfProStyle(fontSize: 16, color: Colors.red),
              ),
            );
          }

          _allPresets = snapshot.data ?? [];
          _filterPresets();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
              child: Column(
                children: [
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search presets...',
                        hintStyle: AppFonts.sfProStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                        ),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
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
                        color: const Color(0xFFE8D5E8),
                        borderRadius: BorderRadius.circular(12),
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
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.bookmark_outline,
              size: 60,
              color: Color(0xFF8B5A8B),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchController.text.isEmpty
                ? 'No Presets Created Yet'
                : 'No Presets Found',
            style: AppFonts.sfProStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8B5A8B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isEmpty
                ? 'Use the + button to create a new preset'
                : 'Try adjusting your search terms',
            style: AppFonts.sfProStyle(
              fontSize: 14,
              color: const Color(0xFF8B5A8B).withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard(Map<String, dynamic> preset, int index) {
    return Slidable(
      key: ValueKey('preset-${preset['id'] ?? index}'),
      closeOnScroll: true,
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => _editPreset(preset),
            backgroundColor: const Color(0xFF00D4AA),
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: 'Edit',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => _deletePreset(preset),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Remove',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => _usePreset(preset),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bookmark,
                      color: const Color(0xFF00D4AA),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        preset['name'] ?? 'Unnamed Preset',
                        style: AppFonts.sfProStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${preset['supplies']?.length ?? 0} supplies',
                  style: AppFonts.sfProStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _usePreset(Map<String, dynamic> preset) {
    // Navigate back to Quick Deduction with preset data
    Navigator.of(context).pop({
      'action': 'use_preset',
      'preset': preset,
    });
  }

  void _editPreset(Map<String, dynamic> preset) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditPresetPage(preset: preset),
      ),
    );

    if (result == true) {
      // Preset was updated successfully
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Preset updated successfully',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF00D4AA),
        ),
      );
    }
  }

  void _deletePreset(Map<String, dynamic> preset) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Delete Preset',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "${preset['name']}"? This action cannot be undone.',
            style: AppFonts.sfProStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style:
                    AppFonts.sfProStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _presetController.deletePreset(preset['id']);
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Preset deleted successfully',
                        style: AppFonts.sfProStyle(
                            fontSize: 14, color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFF00D4AA),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Failed to delete preset: $e',
                        style: AppFonts.sfProStyle(
                            fontSize: 14, color: Colors.white),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(
                'Delete',
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
  }
}
