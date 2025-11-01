import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/features/stock_deduction/controller/sd_edit_preset_controller.dart';
import 'package:familee_dental/features/activity_log/controller/sd_activity_controller.dart'; // Add this import

class EditPresetPage extends StatefulWidget {
  final Map<String, dynamic> preset;

  const EditPresetPage({super.key, required this.preset});

  @override
  State<EditPresetPage> createState() => _EditPresetPageState();
}

class _EditPresetPageState extends State<EditPresetPage> {
  final TextEditingController _nameController = TextEditingController();
  final SdEditPresetController _controller = SdEditPresetController();
  List<Map<String, dynamic>> _presetSupplies = [];

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.preset['name'] ?? '';
    // Initialize supplies and ensure quantities are set
    final supplies =
        List<Map<String, dynamic>>.from(widget.preset['supplies'] ?? []);
    _presetSupplies = supplies.map((supply) {
      return {
        ...supply,
        'quantity': supply['quantity'] ?? 1, // Initialize quantity if missing
      };
    }).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _openAddSupply() async {
    final existingDocIds = _controller.extractExistingDocIds(_presetSupplies);

    final result = await Navigator.of(context).pushNamed(
      '/stock-deduction/add-supply-for-preset',
      arguments: {'existingDocIds': existingDocIds},
    );

    final processedResult =
        _controller.processAddSupplyResult(result, _presetSupplies);

    if (processedResult != null) {
      if (processedResult['isDuplicate'] == true) {
        await _showDuplicateSupplyDialog(processedResult['supplyName']);
        return;
      }

      setState(() {
        if (processedResult['supply'] != null) {
          final supplyData = processedResult['supply'] as Map<String, dynamic>;
          final supply = {
            ...supplyData,
            'quantity': 1, // Initialize quantity to 1
          };
          _presetSupplies =
              _controller.addSupplyToPreset(_presetSupplies, supply);
        } else if (processedResult['supplies'] != null) {
          final suppliesList = processedResult['supplies'] as List;
          final supplies = suppliesList
              .map((supply) {
                final supplyData = supply as Map<String, dynamic>;
                return {
                  ...supplyData,
                  'quantity': 1, // Initialize quantity to 1
                };
              })
              .toList()
              .cast<Map<String, dynamic>>();
          _presetSupplies =
              _controller.addSuppliesToPreset(_presetSupplies, supplies);
        }
      });
    }
  }

  void _removeSupply(int index) {
    setState(() {
      _presetSupplies =
          _controller.removeSupplyFromPreset(_presetSupplies, index);
    });
  }

  void _incrementQty(int index) {
    setState(() {
      final int current = (_presetSupplies[index]['quantity'] ?? 1) as int;
      // No stock limit for presets - presets are templates
      final int next = current + 1;
      // Only limit to 999 for practicality
      _presetSupplies[index]['quantity'] = next > 999 ? 999 : next;
    });
  }

  void _decrementQty(int index) {
    setState(() {
      final current = (_presetSupplies[index]['quantity'] ?? 1) as int;
      if (current > 1) {
        _presetSupplies[index]['quantity'] = current - 1;
      }
    });
  }

  Future<void> _savePreset() async {
    final presetName = _nameController.text.trim();

    final validation =
        _controller.validatePresetData(presetName, _presetSupplies);
    if (!validation['isValid']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            validation['error'],
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if name has changed and if so, check for duplicates
    if (_controller.hasNameChanged(presetName, widget.preset['name'] ?? '')) {
      try {
        final nameExists = await _controller.isPresetNameExists(presetName);
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
      final exactSetExists = await _controller.isExactSupplySetExists(
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
    final updatedPreset = _controller.createUpdatedPresetData(
        widget.preset, presetName, _presetSupplies);

    try {
      await _controller.updatePreset(widget.preset['id'], updatedPreset);

      // Log the preset editing activity
      final fieldChanges = _controller.detectFieldChanges(
        widget.preset,
        presetName,
        _presetSupplies,
      );

      final SdActivityController activityController = SdActivityController();
      await activityController.logPresetEdited(
        originalPresetName: widget.preset['name'] ?? '',
        newPresetName: presetName,
        originalSupplies: _controller.getOriginalSupplies(widget.preset),
        newSupplies: _presetSupplies,
        fieldChanges: fieldChanges,
      );

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
        final hasChanges = _controller.hasUnsavedChanges(
            _nameController.text.trim(),
            _presetSupplies,
            widget.preset['name'] ?? '',
            List<Map<String, dynamic>>.from(widget.preset['supplies'] ?? []));

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
        resizeToAvoidBottomInset: false,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Edit Preset',
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
            Padding(
              padding: const EdgeInsets.only(right: 5.0),
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.red, size: 30),
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.pushNamed(context, '/notifications');
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openAddSupply,
          backgroundColor: const Color(0xFF00D4AA),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: ResponsiveContainer(
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
                  // Preset name input and save button side by side
                  Row(
                    children: [
                      // Preset name input with bookmark icon
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
                            ),
                          ),
                          child: TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              hintText: 'Enter preset name...',
                              hintStyle: AppFonts.sfProStyle(
                                  fontSize: 16,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withOpacity(0.6)),
                              prefixIcon: Icon(Icons.bookmark_outline,
                                  color: Theme.of(context).iconTheme.color),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Theme.of(context).colorScheme.surface,
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
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.surface
                            : const Color(0xFFE8D5E8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              Theme.of(context).dividerColor.withOpacity(0.2),
                        ),
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surface
                  : Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).dividerColor.withOpacity(0.2)
                    : Colors.transparent,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.bookmark,
                  size: 60,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF8B5A8B),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.surface
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.add,
                      size: 16,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF8B5A8B),
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF8B5A8B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add supplies to this preset',
            style: AppFonts.sfProStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.7)
                  : const Color(0xFF8B5A8B).withOpacity(0.7),
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
        color: Theme.of(context).colorScheme.surface,
        elevation: 2,
        shadowColor: Theme.of(context).shadowColor.withOpacity(0.15),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(0.2))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item['imageUrl'] ?? '',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey[200],
                    child: const Icon(Icons.inventory,
                        color: Colors.grey, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item['name'] ?? '',
                  style: AppFonts.sfProStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyMedium?.color),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _decrementQty(index),
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: Theme.of(context).iconTheme.color,
                    ),
                  ),
                  Text(
                    ((_presetSupplies[index]['quantity'] ?? 1) as int)
                        .toString(),
                    style: AppFonts.sfProStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _incrementQty(index),
                    icon: Icon(
                      Icons.add_circle_outline,
                      color: Theme.of(context).iconTheme.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
