import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/stock_deduction/controller/sd_create_preset_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';

class CreatePresetPage extends StatefulWidget {
  const CreatePresetPage({super.key});

  @override
  State<CreatePresetPage> createState() => _CreatePresetPageState();
}

class _CreatePresetPageState extends State<CreatePresetPage> {
  final TextEditingController _presetNameController = TextEditingController();
  final List<Map<String, dynamic>> _presetSupplies = [];
  final SdCreatePresetController _controller = SdCreatePresetController();

  @override
  void initState() {
    super.initState();
    _presetNameController.addListener(() {
      setState(() {
        // Trigger rebuild to update Save button state
      });
    });
  }

  @override
  void dispose() {
    _presetNameController.dispose();
    super.dispose();
  }

  void _openAddSupply() async {
    final existingDocIds = _controller.extractExistingDocIds(_presetSupplies);
    final result = await Navigator.of(context).pushNamed(
      '/stock-deduction/add-supply-for-preset',
      arguments: {'existingDocIds': existingDocIds},
    );
    if (result is Map<String, dynamic>) {
      // Check if supply is already in current preset
      if (_controller.isSupplyInPreset(result, _presetSupplies)) {
        await _showDuplicateSupplyDialog(_controller.extractSupplyName(result));
        return;
      }

      setState(() {
        _presetSupplies.add(result);
      });
    } else if (result is List) {
      // Check for duplicates within current preset
      if (_controller.hasDuplicateSupplies(result, _presetSupplies)) {
        final duplicateName =
            _controller.getFirstDuplicateSupplyName(result, _presetSupplies);
        if (duplicateName != null) {
          await _showDuplicateSupplyDialog(duplicateName);
        }
        return;
      }

      // If no duplicates found, add all items
      setState(() {
        final validSupplies = _controller.processSuppliesResult(result);
        _presetSupplies.addAll(validSupplies);
      });
    }
  }

  void _removeSupplyAt(int index) {
    setState(() {
      _presetSupplies.removeAt(index);
    });
  }

  Future<void> _savePreset() async {
    if (_controller.isPresetNameEmpty(_presetNameController.text)) {
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

    if (_controller.isPresetEmpty(_presetSupplies)) {
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

    // Check if preset name already exists
    try {
      final nameExists =
          await _controller.isPresetNameExists(_presetNameController.text);
      if (nameExists) {
        await _showDuplicateNameDialog(_presetNameController.text.trim());
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

    // Check if exact supply set already exists
    try {
      final exactSetExists =
          await _controller.isExactSupplySetExists(_presetSupplies);
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

    // Create preset data
    final presetData = _controller.createPresetData(
        _presetNameController.text, _presetSupplies);

    // Return to preset management page for Supabase saving
    Navigator.of(context).pop(presetData);
  }

  Future<bool> _confirmLeave() async {
    if (!_controller.hasUnsavedChanges(
        _presetNameController.text, _presetSupplies)) {
      return true;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Discard preset?',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'You have unsaved changes. If you leave this page, your preset will be lost.',
            style: AppFonts.sfProStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Stay',
                style:
                    AppFonts.sfProStyle(fontSize: 16, color: Colors.grey[700]),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
    return shouldLeave ?? false;
  }

  Future<void> _showOutOfStockDialog(String supplyName) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Out of stock',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            '"$supplyName" has no available stock to add to preset.',
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

  Future<void> _showDuplicateNameDialog(String presetName) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Preset name exists',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'A preset named "$presetName" already exists. Please choose a different name.',
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
      onWillPop: _confirmLeave,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Create Preset',
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
              padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width < 768 ? 8.0 : 16.0),
              child: Column(
                children: [
                  // Preset name input and Save button row
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
                            ),
                          ),
                          child: TextField(
                            controller: _presetNameController,
                            decoration: InputDecoration(
                              hintText: 'Enter preset name...',
                              hintStyle: AppFonts.sfProStyle(
                                fontSize: 16,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withOpacity(0.6),
                              ),
                              prefixIcon: Icon(Icons.bookmark_outline,
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
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: (_presetNameController.text.trim().isEmpty ||
                                _presetSupplies.isEmpty)
                            ? null
                            : _savePreset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              (_presetNameController.text.trim().isEmpty ||
                                      _presetSupplies.isEmpty)
                                  ? Colors.grey[400]
                                  : const Color(0xFF00D4AA),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Save Preset',
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
                                return Slidable(
                                  key: ValueKey(
                                      'preset-${item['docId'] ?? index}'),
                                  closeOnScroll: true,
                                  endActionPane: ActionPane(
                                    motion: const DrawerMotion(),
                                    extentRatio: 0.28,
                                    children: [
                                      SlidableAction(
                                        onPressed: (_) =>
                                            _removeSupplyAt(index),
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
                                    color:
                                        Theme.of(context).colorScheme.surface,
                                    elevation: 2,
                                    shadowColor: Theme.of(context)
                                        .shadowColor
                                        .withOpacity(0.15),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: Theme.of(context)
                                              .dividerColor
                                              .withOpacity(0.2),
                                        )),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.network(
                                              item['imageUrl'] ?? '',
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                width: 40,
                                                height: 40,
                                                color: Colors.grey[200],
                                                child: const Icon(
                                                    Icons.inventory,
                                                    color: Colors.grey,
                                                    size: 20),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              item['name'] ?? '',
                                              style: AppFonts.sfProStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.color),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
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
            child: const Icon(
              Icons.bookmark_add_outlined,
              size: 60,
              color: Colors.white,
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
}
