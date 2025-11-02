import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:familee_dental/shared/drawer.dart';
import 'package:familee_dental/shared/themes/font.dart';
import 'package:familee_dental/features/stock_deduction/controller/sd_approval_controller.dart';
import 'package:familee_dental/features/inventory/controller/inventory_controller.dart';
import 'package:familee_dental/features/inventory/data/inventory_item.dart';
import 'package:familee_dental/features/activity_log/controller/sd_activity_controller.dart';
import 'package:familee_dental/shared/widgets/notification_badge_button.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/features/auth/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StockDeductionPage extends StatefulWidget {
  const StockDeductionPage({super.key});

  @override
  State<StockDeductionPage> createState() => _StockDeductionPageState();
}

class _StockDeductionPageState extends State<StockDeductionPage> {
  final List<Map<String, dynamic>> _deductions = [];
  final InventoryController _inventoryController = InventoryController();
  final SdActivityController _activityController = SdActivityController();
  final ApprovalController _approvalController = ApprovalController();
  OverlayEntry? _undoOverlayEntry;
  Route? _currentRoute;

  String? _userName;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _currentRoute = ModalRoute.of(context);
    });
  }

  Future<void> _loadUserData() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser != null) {
        // Try to get user data from user_roles table (same approach as Dashboard)
        final response = await supabase
            .from('user_roles')
            .select('*')
            .eq('id', currentUser.id)
            .limit(1)
            .maybeSingle();

        if (mounted) {
          setState(() {
            if (response != null &&
                response['name'] != null &&
                response['name'].toString().trim().isNotEmpty) {
              // Use data from user_roles table
              _userName = response['name'].toString().trim();
              _userRole = response['role']?.toString().trim() ?? 'Admin';
            } else {
              // Fallback to auth user data
              final displayName =
                  currentUser.userMetadata?['display_name']?.toString().trim();
              final emailName = currentUser.email?.split('@')[0].trim();
              _userName = displayName ?? emailName ?? 'User';
              _userRole = 'Admin';
            }
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _userName = 'User';
          _userRole = 'Admin';
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newRoute = ModalRoute.of(context);
    if (_currentRoute != newRoute) {
      _currentRoute = newRoute;
      // Remove undo banner when navigating away from this page
      _removeUndoOverlay();
    }
  }

  @override
  void dispose() {
    _removeUndoOverlay();
    super.dispose();
  }

  void _openAddSupply() async {
    final existingDocIds = _deductions
        .map((e) => (e['docId'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();
    final result = await Navigator.of(context).pushNamed(
      '/stock-deduction/add-supply',
      arguments: {'existingDocIds': existingDocIds},
    );
    if (result is Map<String, dynamic>) {
      final int stock = (result['stock'] ?? 0) as int;
      if (stock <= 0) {
        await _showOutOfStockDialog(
            result['name']?.toString() ?? 'This supply');
        return;
      }

      final docId = result['docId']?.toString();
      final existsIndex = _deductions.indexWhere((e) => e['docId'] == docId);
      if (existsIndex != -1) {
        // Duplicate found - show dialog
        await _showDuplicateDialog(result['name']?.toString() ?? 'This supply');
        return;
      }

      setState(() {
        _deductions.add({
          ...result,
          'deductQty': stock > 0 ? 1 : 0,
        });
      });
    } else if (result is List) {
      for (final dynamic r in result) {
        if (r is Map<String, dynamic>) {
          final int stock = (r['stock'] ?? 0) as int;
          if (stock <= 0) {
            continue; // skip out of stock in bulk add
          }
          final docId = r['docId']?.toString();
          final existsIndex =
              _deductions.indexWhere((e) => e['docId'] == docId);
          if (existsIndex != -1) {
            // Duplicate found - show dialog
            await _showDuplicateDialog(r['name']?.toString() ?? 'This supply');
            return;
          }
        }
      }

      // If no duplicates found, add all items
      setState(() {
        for (final dynamic r in result) {
          if (r is Map<String, dynamic>) {
            final int stock = (r['stock'] ?? 0) as int;
            if (stock > 0) {
              _deductions.add({
                ...r,
                'deductQty': stock > 0 ? 1 : 0,
              });
            }
          }
        }
      });
    }
  }

  void _incrementQty(int index) {
    setState(() {
      final int current = (_deductions[index]['deductQty'] as int);
      final int maxStock = (_deductions[index]['stock'] ?? 0) as int;
      final int next = current + 1;
      // Limit to both max stock and 99
      final int limit = maxStock < 99 ? maxStock : 99;
      _deductions[index]['deductQty'] = next > limit ? limit : next;
    });
  }

  void _decrementQty(int index) {
    setState(() {
      final current = _deductions[index]['deductQty'] as int;
      if (current > 1) {
        _deductions[index]['deductQty'] = current - 1;
      }
    });
  }

  void _removeDeductionAt(int index) {
    setState(() {
      _deductions.removeAt(index);
    });
  }

  // Intentionally no snackbar/info popups here for duplicates; handled in Add Supply page

  Future<void> _save() async {
    if (_deductions.isEmpty) return;

    // Show Purpose selection modal first
    final purposeResult = await _showPurposeModal();
    if (purposeResult == null) return;

    final purpose = purposeResult['purpose'] as String;

    try {
      // Convert deductions to approval format
      final supplies = _deductions.map((deduction) {
        return {
          'docId': deduction['docId'], // Save docId to match exact batch
          'name': deduction['name'] ?? '',
          'type': deduction['type'] ?? '',
          'brand': deduction['brand'] ?? '',
          'quantity': deduction['deductQty'] ?? 0,
          'imageUrl': deduction['imageUrl'] ?? '',
          'packagingContent': deduction['packagingContent'],
          'packagingContentQuantity': deduction['packagingContentQuantity'],
          'packagingUnit': deduction['packagingUnit'],
          'expiry': deduction['expiry'],
          'noExpiry': deduction['noExpiry'],
        };
      }).toList();

      // Create approval instead of immediately deducting
      await _approvalController.saveApproval({
        'preset_name':
            purpose, // Use purpose as preset_name for direct deductions
        'supplies': supplies,
        'patient_name': '', // Empty for direct deductions
        'age': '',
        'gender': '',
        'conditions': '',
        'purpose': purpose,
        'remarks': '',
      });

      // Clear the deductions list since they've been sent for approval
      setState(() {
        _deductions.clear();
      });

      // Show success message and navigate to approval page
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stock deduction request sent for approval',
              style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF00D4AA),
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate to approval page to see pending approvals
        Navigator.of(context).pushNamed('/stock-deduction/approval');
      }
    } catch (e) {
      // Show error message if approval creation fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to create approval: $e',
              style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showPurposeModal() async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const _PurposeSelectionDialog();
      },
    );
  }

  void _removeUndoOverlay() {
    _undoOverlayEntry?.remove();
    _undoOverlayEntry = null;
  }

  void _createPreset() async {
    // Navigate to Service Management page
    final result = await Navigator.of(context)
        .pushNamed('/stock-deduction/service-management');

    // Handle the preset that was selected
    if (result != null && result is Map<String, dynamic>) {
      if (result['action'] == 'use_preset' && result['preset'] != null) {
        await _loadPresetIntoDeductions(result['preset']);
      }
    }
  }

  void _openDeductionLogs() async {
    // Navigate to Deduction Logs page
    await Navigator.of(context).pushNamed('/stock-deduction/deduction-logs');
  }

  void _openApproval() async {
    // Navigate to Approval page
    await Navigator.of(context).pushNamed('/stock-deduction/approval');
  }

  Future<void> _loadPresetIntoDeductions(Map<String, dynamic> preset) async {
    try {
      final supplies = preset['supplies'] as List<dynamic>? ?? [];

      // Check if ALL supplies from the preset are already in the current deductions list
      final List<String> existingSupplyNames = _deductions
          .map((e) =>
              '${e['name']?.toString() ?? ''} - ${e['brand']?.toString() ?? ''}')
          .toList();

      final List<String> presetSupplyNames = supplies
          .map((e) =>
              '${e['name']?.toString() ?? ''} - ${e['brand']?.toString() ?? ''}')
          .toList();

      final List<String> duplicates = existingSupplyNames
          .where((name) => presetSupplyNames.contains(name))
          .toList();

      // Only prevent loading if ALL supplies from the preset are already in the list
      if (duplicates.length == presetSupplyNames.length &&
          presetSupplyNames.isNotEmpty) {
        await _showPresetAlreadyLoadedDialog(
            preset['name']?.toString() ?? 'This preset');
        return;
      }

      // Get current inventory data to update stock and expiry information
      // Use inventory controller instead of catalog controller for proper FIFO logic
      List<GroupedInventoryItem> currentInventory = [];
      try {
        currentInventory = await _inventoryController
            .getGroupedSuppliesStream(archived: false)
            .first;
      } catch (e) {
        print('Error loading current inventory: $e');
        // Continue with empty inventory - will handle as missing items
      }

      setState(() {
        _deductions.clear();
        for (final supply in supplies) {
          if (supply is Map<String, dynamic>) {
            final supplyName = supply['name']?.toString() ?? '';
            final supplyBrand = supply['brand']?.toString() ?? '';

            // Find current inventory data for this supply by name and brand
            GroupedInventoryItem? currentItem;
            try {
              currentItem = currentInventory.firstWhere(
                (item) =>
                    item.mainItem.name == supplyName &&
                    item.mainItem.brand == supplyBrand,
              );
            } catch (e) {
              currentItem = null;
            }

            if (currentItem != null) {
              // Block expired items from deduction. Treat them as missing (0 stock, no expiry).
              if (currentItem.getStatus() == 'Expired') {
                _deductions.add({
                  'docId': null,
                  'name': currentItem.mainItem.name,
                  'type': currentItem.mainItem.type,
                  'brand': currentItem.mainItem.brand,
                  'imageUrl': currentItem.mainItem.imageUrl,
                  'expiry': null,
                  'noExpiry': true,
                  'stock': 0,
                  'deductQty': 0,
                });
              } else {
                // Use current inventory data instead of stored preset values
                // For stock deduction, we need to include all batches (earliest expiry first)
                final allBatches = [
                  currentItem.mainItem,
                  ...currentItem.variants
                ];
                final validBatches =
                    allBatches.where((batch) => batch.stock > 0).toList();

                // Sort by expiry (earliest first, no expiry last)
                validBatches.sort((a, b) {
                  if (a.noExpiry && b.noExpiry) return 0;
                  if (a.noExpiry) return 1;
                  if (b.noExpiry) return -1;

                  final aExpiry = a.expiry != null
                      ? DateTime.tryParse(a.expiry!.replaceAll('/', '-'))
                      : null;
                  final bExpiry = b.expiry != null
                      ? DateTime.tryParse(b.expiry!.replaceAll('/', '-'))
                      : null;

                  if (aExpiry == null && bExpiry == null) return 0;
                  if (aExpiry == null) return 1;
                  if (bExpiry == null) return -1;
                  return aExpiry.compareTo(bExpiry);
                });

                // Add the earliest expiry batch with stock as the main deduction item
                if (validBatches.isNotEmpty) {
                  final primaryBatch = validBatches.first;

                  // Use preset quantity if available, otherwise default to 1
                  final int presetQuantity = (supply['quantity'] ?? 1) as int;
                  final int defaultQty =
                      primaryBatch.stock > 0 ? presetQuantity : 0;
                  final int deductQty = defaultQty > primaryBatch.stock
                      ? primaryBatch.stock
                      : defaultQty;

                  _deductions.add({
                    'docId': primaryBatch.id,
                    'name': primaryBatch.name,
                    'type': primaryBatch.type,
                    'brand': primaryBatch.brand,
                    'imageUrl': primaryBatch.imageUrl,
                    'expiry': primaryBatch.expiry,
                    'noExpiry': primaryBatch.noExpiry,
                    'stock': primaryBatch.stock,
                    'deductQty': deductQty,
                    'allBatches': validBatches
                        .map((batch) => {
                              'docId': batch.id,
                              'stock': batch.stock,
                              'expiry': batch.expiry,
                            })
                        .toList(),
                  });
                }
              }
            } else {
              // Not in current inventory (likely expired/removed)
              // Use a safe placeholder so it cannot be deducted
              _deductions.add({
                'docId': null,
                'name': supplyName,
                'type': supply['type'],
                'brand': supplyBrand,
                'imageUrl': (supply['imageUrl'] ?? '').toString(),
                'expiry': null,
                'noExpiry': true,
                'stock': 0,
                'deductQty': 0,
              });
            }
          }
        }
      });

      // Log preset usage activity
      await _activityController.logPresetUsed(
        presetName: preset['name']?.toString() ?? 'Unknown',
        supplies: supplies.cast<Map<String, dynamic>>(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Preset "${preset['name']}" loaded with ${_deductions.length} supplies',
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
            'Failed to load preset: $e',
            style: AppFonts.sfProStyle(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _confirmLeave() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Discard changes?',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'You have supplies added. If you leave this page, your list will be cleared.',
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

  String _formatExpiry(dynamic expiry, bool? noExpiry) {
    if (noExpiry == true) return 'No Expiry';
    if (expiry == null) return 'No Expiry';
    final String raw = expiry.toString();
    if (raw.isEmpty) return 'No Expiry';
    // Normalize dashes to slashes for consistency
    final dashDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (dashDate.hasMatch(raw)) {
      return raw.replaceAll('-', '/');
    }
    return raw;
  }

  Widget _expiryChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 12,
              color: Theme.of(context).iconTheme.color?.withOpacity(0.8)),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppFonts.sfProStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _stockChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 12,
              color: Theme.of(context).iconTheme.color?.withOpacity(0.8)),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppFonts.sfProStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
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
            '"$supplyName" has no available stock to deduct.',
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

  Future<void> _showDuplicateDialog(String supplyName) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Already added',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            '"$supplyName" is already in your deduction list.',
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

  Future<void> _showPresetAlreadyLoadedDialog(String presetName) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Preset already loaded',
            style:
                AppFonts.sfProStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: Text(
            '"$presetName" contains supplies that are already in your deduction list.',
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
          if (_deductions.isNotEmpty) {
            return await _confirmLeave();
          }
          // Navigate back to Dashboard when back button is pressed
          // Use popUntil to go back to existing Dashboard instead of creating a new one
          Navigator.popUntil(
              context, (route) => route.settings.name == '/dashboard');
          return false; // Prevent default back behavior
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF3A3A3A)
              : const Color(0xFFF5F5F5),
          drawer: MediaQuery.of(context).size.width >= 900
              ? null
              : MyDrawer(
                  beforeNavigate: () async {
                    if (_deductions.isNotEmpty) {
                      return await _confirmLeave();
                    }
                    return true;
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: _openAddSupply,
            backgroundColor: const Color(0xFF00D4AA),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: MediaQuery.of(context).size.width >= 900
              ? _buildWithNavigationRail()
              : RefreshIndicator(
                  onRefresh: () async {
                    // Refresh deductions if needed
                    setState(() {});
                  },
                  child: _buildStockDeductionContent(),
                ),
        ));
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
            child: Icon(
              Icons.shopping_basket_outlined,
              size: 60,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF8B5A8B),
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
            'Tap the + button to add supplies',
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

  Widget _buildWithNavigationRail() {
    final theme = Theme.of(context);

    // Main destinations (top section)
    final List<_RailDestination> mainDestinations = [
      _RailDestination(
          icon: Icons.dashboard, label: 'Dashboard', route: '/dashboard'),
      _RailDestination(
          icon: Icons.inventory, label: 'Inventory', route: '/inventory'),
      _RailDestination(
          icon: Icons.shopping_cart,
          label: 'Purchase Order',
          route: '/purchase-order'),
      _RailDestination(
          icon: Icons.playlist_remove,
          label: 'Stock Deduction',
          route: '/stock-deduction'),
    ];

    // Use the same role logic as drawer for conditional Activity Log
    final userRoleProvider = UserRoleProvider();
    final canAccessActivityLog = userRoleProvider.canAccessActivityLog();

    // Bottom destinations (Settings and Logout)
    final List<_RailDestination> bottomDestinations = [
      _RailDestination(
          icon: Icons.settings, label: 'Settings', route: '/settings'),
      _RailDestination(icon: Icons.logout, label: 'Logout', route: '/logout'),
    ];

    // Stock Deduction is selected here (index 3)
    final int selectedIndex = 3;

    return Row(
      children: [
        Container(
          width: 220,
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              // Logo and brand
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 35.0, 16.0, 16.0),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.asset(
                          'assets/images/logo/logo_101.png',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 60,
                              height: 60,
                              color: Colors.blue,
                              child: const Icon(
                                Icons.medical_services,
                                color: Colors.white,
                                size: 30,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Flexible(
                      child: Transform.translate(
                        offset: const Offset(0, 8),
                        child: Transform.scale(
                          scale: 2.9,
                          child: theme.brightness == Brightness.dark
                              ? ColorFiltered(
                                  colorFilter: const ColorFilter.matrix([
                                    1.5, 0, 0, 0, 0, // Red channel - brighten
                                    0, 1.5, 0, 0, 0, // Green channel - brighten
                                    0, 0, 1.5, 0, 0, // Blue channel - brighten
                                    0, 0, 0, 1, 0, // Alpha channel - unchanged
                                  ]),
                                  child: Image.asset(
                                    'assets/images/logo/tita_doc_2.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Text(
                                        'FamiLee Dental',
                                        style: AppFonts.sfProStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: theme
                                              .textTheme.titleMedium?.color,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/logo/tita_doc_2.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text(
                                      'FamiLee Dental',
                                      style: AppFonts.sfProStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color:
                                            theme.textTheme.titleMedium?.color,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Navigation items
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // MENU section header
                    _buildSectionHeader(theme, 'MENU'),
                    const SizedBox(height: 8),
                    // MENU items
                    for (int i = 0; i < mainDestinations.length; i++)
                      _buildRailDestinationTile(
                        context: context,
                        theme: theme,
                        destination: mainDestinations[i],
                        isSelected: i == selectedIndex,
                        onTap: () async {
                          final dest = mainDestinations[i];
                          final currentRoute =
                              ModalRoute.of(context)?.settings.name;

                          // Check if there are unsaved deductions before navigation
                          bool canNavigate = true;
                          if (_deductions.isNotEmpty &&
                              currentRoute != dest.route) {
                            canNavigate = await _confirmLeave();
                            if (!canNavigate) return;
                          }

                          if (currentRoute != dest.route) {
                            Navigator.pushNamed(context, dest.route);
                          }
                        },
                      ),
                    // Activity Logs (if accessible) - part of MENU
                    if (canAccessActivityLog)
                      _buildRailDestinationTile(
                        context: context,
                        theme: theme,
                        destination: _RailDestination(
                          icon: Icons.history,
                          label: 'Activity Logs',
                          route: '/activity-log',
                        ),
                        isSelected: false,
                        onTap: () async {
                          final currentRoute =
                              ModalRoute.of(context)?.settings.name;

                          // Check if there are unsaved deductions before navigation
                          bool canNavigate = true;
                          if (_deductions.isNotEmpty &&
                              currentRoute != '/activity-log') {
                            canNavigate = await _confirmLeave();
                            if (!canNavigate) return;
                          }

                          if (currentRoute != '/activity-log') {
                            Navigator.pushNamed(context, '/activity-log');
                          }
                        },
                      ),
                  ],
                ),
              ),
              // GENERAL section at the bottom
              _buildSectionHeader(theme, 'GENERAL'),
              const SizedBox(height: 8),
              // GENERAL items
              for (int i = 0; i < bottomDestinations.length; i++)
                _buildRailDestinationTile(
                  context: context,
                  theme: theme,
                  destination: bottomDestinations[i],
                  isSelected: false,
                  onTap: () async {
                    final dest = bottomDestinations[i];
                    final currentRoute = ModalRoute.of(context)?.settings.name;

                    // Handle logout separately
                    if (dest.route == '/logout') {
                      // Check if there are unsaved deductions before logout
                      bool canNavigate = true;
                      if (_deductions.isNotEmpty) {
                        canNavigate = await _confirmLeave();
                        if (!canNavigate) return;
                      }
                      await _handleLogout();
                      return;
                    }

                    // Check if there are unsaved deductions before navigation
                    bool canNavigate = true;
                    if (_deductions.isNotEmpty && currentRoute != dest.route) {
                      canNavigate = await _confirmLeave();
                      if (!canNavigate) return;
                    }

                    if (currentRoute != dest.route) {
                      Navigator.pushNamed(context, dest.route);
                    }
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: theme.brightness == Brightness.dark
              ? Colors.grey.shade700
              : Colors.grey.shade200,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              // Refresh deductions if needed
              setState(() {});
            },
            child: _buildStockDeductionContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String label) {
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: AppFonts.sfProStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildRailDestinationTile({
    required BuildContext context,
    required ThemeData theme,
    required _RailDestination destination,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Stack(
        children: [
          // Background with rounded right corners
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    destination.icon,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodyMedium?.color,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      destination.label,
                      style: AppFonts.sfProStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Vertical indicator line on the left
          if (isSelected)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    bottomLeft: Radius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWelcomePanel(ThemeData theme) {
    final userName = _userName ?? 'User';
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: theme.colorScheme.surface,
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row with greeting on left and account section on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side - Greeting message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Stock Deduction",
                        style: AppFonts.sfProStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Efficiently manage and deduct stock quantities with ease.",
                        style: AppFonts.sfProStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Right side - Notification button and Account section
                Row(
                  children: [
                    // Notification button
                    const NotificationBadgeButton(),
                    const SizedBox(width: 8),
                    // Avatar with first letter
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: AppFonts.sfProStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name and role
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userName,
                          style: AppFonts.sfProStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          _userRole ?? 'Admin',
                          style: AppFonts.sfProStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockDeductionContent() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome Panel (with notification and account)
          _buildWelcomePanel(theme),
          const SizedBox(height: 12),
          // Top bar for in-page actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Deduction Logs button - Only for Owner and Admin
              if (!UserRoleProvider().isStaff)
                ElevatedButton(
                  onPressed: _openDeductionLogs,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4AA),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Deduction Logs',
                    style: AppFonts.sfProStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (!UserRoleProvider().isStaff) const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _createPreset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4AA),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Service',
                  style: AppFonts.sfProStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _openApproval,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4AA),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Approval',
                  style: AppFonts.sfProStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _deductions.isEmpty ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _deductions.isEmpty
                      ? Colors.grey[400]
                      : const Color(0xFF00D4AA),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Deduct',
                  style: AppFonts.sfProStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? theme.colorScheme.surface
                    : const Color(0xFFE8D5E8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withOpacity(0.2),
                ),
              ),
              child: _deductions.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _deductions.length,
                      itemBuilder: (context, index) {
                        final item = _deductions[index];
                        return Slidable(
                          key: ValueKey('deduct-${item['docId'] ?? index}'),
                          closeOnScroll: true,
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.35,
                            children: [
                              SlidableAction(
                                onPressed: (_) => _removeDeductionAt(index),
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
                            color: theme.colorScheme.surface,
                            elevation: 2,
                            shadowColor: theme.shadowColor.withOpacity(0.15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: theme.dividerColor.withOpacity(0.2),
                                  width: 1,
                                )),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 16),
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 84),
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
                                              color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            (item['name'] ?? '') +
                                                (item['type'] != null &&
                                                        item['type']
                                                            .toString()
                                                            .isNotEmpty
                                                    ? '(${item['type']})'
                                                    : ''),
                                            style: AppFonts.sfProStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: theme.textTheme
                                                    .bodyMedium?.color),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          _expiryChip('Expiry: ' +
                                              _formatExpiry(item['expiry'],
                                                  item['noExpiry'] as bool?)),
                                          const SizedBox(height: 6),
                                          _stockChip('Stock: ' +
                                              ((_deductions[index]['stock'] ??
                                                      0) as int)
                                                  .toString()),
                                        ],
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
                                            color: theme.iconTheme.color,
                                          ),
                                        ),
                                        Text(
                                          (_deductions[index]['deductQty']
                                                  as int)
                                              .toString(),
                                          style: AppFonts.sfProStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: theme
                                                  .textTheme.bodyMedium?.color),
                                        ),
                                        IconButton(
                                          onPressed: () => _incrementQty(index),
                                          icon: Icon(
                                            Icons.add_circle_outline,
                                            color: theme.iconTheme.color,
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
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
    );
  }

  Future<void> _handleLogout() async {
    // Check for unsaved deductions
    bool canLogout = true;
    if (_deductions.isNotEmpty) {
      canLogout = await _confirmLeave();
    }

    if (!canLogout) return;

    final shouldLogout = await _showLogoutDialog(context);
    if (shouldLogout == true) {
      final authService = AuthService();
      await authService.logout();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<bool> _showLogoutDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 400,
                  minWidth: 350,
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout,
                        color: Colors.red,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Are you sure you want to logout?',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Yes',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade300,
                                ),
                              ),
                            ),
                            child: Text(
                              'No',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w500,
                                color: theme.textTheme.bodyMedium?.color,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;
  }
}

class _PurposeSelectionDialog extends StatefulWidget {
  const _PurposeSelectionDialog();

  @override
  State<_PurposeSelectionDialog> createState() =>
      _PurposeSelectionDialogState();
}

class _PurposeSelectionDialogState extends State<_PurposeSelectionDialog> {
  String? selectedPurpose;
  final TextEditingController remarksController = TextEditingController();
  bool showRemarksField = false;

  @override
  void dispose() {
    remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          minWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Purpose',
              style: AppFonts.sfProStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 20),
            // Scrollable content area
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Radio buttons for purposes
                    ..._buildPurposeOptions(theme, selectedPurpose, (value) {
                      setState(() {
                        selectedPurpose = value;
                        showRemarksField = value == 'Other';
                      });
                    }),
                    const SizedBox(height: 4),
                    // Text field for "Other" option (single line)
                    if (showRemarksField) ...[
                      TextField(
                        controller: remarksController,
                        decoration: InputDecoration(
                          hintText: 'Please specify',
                          hintStyle: AppFonts.sfProStyle(
                            fontSize: 14,
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.6),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: theme.dividerColor.withOpacity(0.3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: theme.dividerColor.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF00D4AA),
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? theme.colorScheme.surface
                              : Colors.grey[50],
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        style: AppFonts.sfProStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Buttons (fixed at bottom)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isDark
                            ? Colors.grey.shade600
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: AppFonts.sfProStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: selectedPurpose == null ||
                          (selectedPurpose == 'Other' &&
                              remarksController.text.trim().isEmpty)
                      ? null
                      : () {
                          // If "Other" is selected, use the input text as the purpose
                          final purpose = selectedPurpose == 'Other'
                              ? remarksController.text.trim()
                              : selectedPurpose!;
                          Navigator.of(context).pop({
                            'purpose': purpose,
                            'remarks': null,
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedPurpose == null ||
                            (selectedPurpose == 'Other' &&
                                remarksController.text.trim().isEmpty)
                        ? Colors.grey[400]
                        : const Color(0xFF00D4AA),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Proceed',
                    style: AppFonts.sfProStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPurposeOptions(
    ThemeData theme,
    String? selectedPurpose,
    Function(String?) onChanged,
  ) {
    final purposes = [
      'Office Used',
      'Damaged',
      'Contaminated',
      'Lost/Missing',
      'Stock Correction',
      'Returned to Supplier',
      'Other',
    ];

    return purposes.map((purpose) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => onChanged(purpose),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? theme.colorScheme.surface
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selectedPurpose == purpose
                    ? const Color(0xFF00D4AA)
                    : theme.dividerColor.withOpacity(0.3),
                width: selectedPurpose == purpose ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Radio<String>(
                  value: purpose,
                  groupValue: selectedPurpose,
                  onChanged: onChanged,
                  activeColor: const Color(0xFF00D4AA),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    purpose,
                    style: AppFonts.sfProStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
}

class _RailDestination {
  final IconData icon;
  final String label;
  final String route;

  _RailDestination(
      {required this.icon, required this.label, required this.route});
}
