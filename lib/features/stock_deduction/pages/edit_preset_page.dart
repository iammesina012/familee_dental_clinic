import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:projects/shared/themes/font.dart';
import 'package:projects/features/stock_deduction/controller/preset_controller.dart';

class EditPresetPage extends StatefulWidget {
  final Map<String, dynamic> preset;

  const EditPresetPage({super.key, required this.preset});

  @override
  State<EditPresetPage> createState() => _EditPresetPageState();
}

class _EditPresetPageState extends State<EditPresetPage> {
  final TextEditingController _nameController = TextEditingController();
  final PresetController _presetController = PresetController();
  List<Map<String, dynamic>> _presetSupplies = [];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.preset['name'] ?? '';
    _presetSupplies =
        List<Map<String, dynamic>>.from(widget.preset['supplies'] ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _openAddSupply() async {
    final existingDocIds =
        _presetSupplies.map((e) => e['docId']?.toString()).toList();

    final result = await Navigator.of(context).pushNamed(
      '/stock-deduction/add-supply-for-preset',
      arguments: {'existingDocIds': existingDocIds},
    );

    if (result is Map<String, dynamic>) {
      final docId = result['docId']?.toString();
      final existsIndex =
          _presetSupplies.indexWhere((e) => e['docId'] == docId);
      if (existsIndex != -1) {
        // Duplicate found - show dialog
        await _showDuplicateSupplyDialog(
            result['name']?.toString() ?? 'This supply');
        return;
      }
      setState(() {
        _presetSupplies.add(result);
      });
    } else if (result is List) {
      // Check for duplicates first
      for (final dynamic r in result) {
        if (r is Map<String, dynamic>) {
          final docId = r['docId']?.toString();
          final existsIndex =
              _presetSupplies.indexWhere((e) => e['docId'] == docId);
          if (existsIndex != -1) {
            // Duplicate found - show dialog
            await _showDuplicateSupplyDialog(
                r['name']?.toString() ?? 'This supply');
            return;
          }
        }
      }
      // If no duplicates found, add all items
      setState(() {
        for (final dynamic r in result) {
          if (r is Map<String, dynamic>) {
            _presetSupplies.add(r);
          }
        }
      });
    }
  }

  void _removeSupply(int index) {
    setState(() {
      _presetSupplies.removeAt(index);
    });
  }

  Future<void> _savePreset() async {
    final presetName = _nameController.text.trim();

    if (presetName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a preset name',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_presetSupplies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please add at least one supply to the preset',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if name has changed and if so, check for duplicates
    if (presetName.toLowerCase() !=
        (widget.preset['name'] ?? '').toLowerCase()) {
      try {
        final nameExists =
            await _presetController.isPresetNameExists(presetName);
        if (nameExists) {
          await _showDuplicateNameDialog();
          return; // Stay on this page, don't navigate back
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error checking preset name: $e',
              style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Check if exact supply set already exists (excluding current preset)
    try {
      final exactSetExists = await _presetController.isExactSupplySetExists(
          _presetSupplies,
          excludePresetId: widget.preset['id']);
      if (exactSetExists) {
        await _showDuplicateSupplySetDialog();
        return; // Stay on this page, don't navigate back
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error checking supply set: $e',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Update preset data
    final updatedPreset = {
      ...widget.preset,
      'name': presetName,
      'supplies': _presetSupplies,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    try {
      await _presetController.updatePreset(widget.preset['id'], updatedPreset);
      if (!mounted) return;

      Navigator.of(context)
          .pop(true); // Return true to indicate successful update
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update preset: $e',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showDuplicateNameDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Preset name already exists',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'A preset with this name already exists. Please choose a different name.',
            style: AppFonts.sfProStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: AppFonts.sfProStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDuplicateSupplyDialog(String supplyName) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Already in preset',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            '"$supplyName" is already in your preset list.',
            style: AppFonts.sfProStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: AppFonts.sfProStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDuplicateSupplySetDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Duplicate preset',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'A preset with the exact same supplies already exists. Please choose different supplies or a different combination.',
            style: AppFonts.sfProStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: AppFonts.sfProStyle(fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Check if there are unsaved changes
        final hasChanges = _nameController.text.trim() !=
                (widget.preset['name'] ?? '') ||
            _presetSupplies.length != (widget.preset['supplies']?.length ?? 0);

        if (hasChanges) {
          final shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(
                  'Unsaved Changes',
                  style: AppFonts.sfProStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                content: Text(
                  'You have unsaved changes. Are you sure you want to leave?',
                  style: AppFonts.sfProStyle(fontSize: 16),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancel',
                      style: AppFonts.sfProStyle(
                          fontSize: 16, color: Colors.grey[700]),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: Text(
                      'Leave',
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
          return shouldPop ?? false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9EFF2),
        appBar: AppBar(
          title: Text(
            'Edit Preset',
            style:
                AppFonts.sfProStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
          onPressed: _openAddSupply,
          backgroundColor: const Color(0xFF00D4AA),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
            child: Column(
              children: [
                // Preset name input and save button side by side
                Row(
                  children: [
                    // Preset name input with bookmark icon
                    Expanded(
                      child: Container(
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
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Enter preset name...',
                            hintStyle: AppFonts.sfProStyle(
                                fontSize: 16, color: Colors.grey[500]),
                            prefixIcon: Icon(Icons.bookmark_outline,
                                color: Colors.grey[500]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          style: AppFonts.sfProStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Save button
                    ElevatedButton(
                      onPressed:
                          _presetSupplies.isNotEmpty ? _savePreset : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _presetSupplies.isNotEmpty
                            ? const Color(0xFF00D4AA)
                            : Colors.grey[400],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Update Preset',
                        style: AppFonts.sfProStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Supplies list
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8D5E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _presetSupplies.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _presetSupplies.length,
                            itemBuilder: (context, index) {
                              final item = _presetSupplies[index];
                              return _buildSupplyCard(item, index);
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.bookmark,
                  size: 60,
                  color: Color(0xFF8B5A8B),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 16,
                      color: Color(0xFF8B5A8B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Supplies Added Yet',
            style: AppFonts.sfProStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8B5A8B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add supplies to this preset',
            style: AppFonts.sfProStyle(
              fontSize: 14,
              color: const Color(0xFF8B5A8B).withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplyCard(Map<String, dynamic> item, int index) {
    return Slidable(
      key: ValueKey('supply-${item['docId']}-$index'),
      closeOnScroll: true,
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        children: [
          SlidableAction(
            onPressed: (_) => _removeSupply(index),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item['imageUrl'] ?? '',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey[200],
                    child: const Icon(Icons.inventory,
                        color: Colors.grey, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item['name'] ?? '',
                  style: AppFonts.sfProStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
