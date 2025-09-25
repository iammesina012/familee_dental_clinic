import 'package:flutter/material.dart';
import 'package:projects/shared/themes/font.dart';
import 'package:projects/features/notifications/controller/notifications_controller.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:projects/features/inventory/data/inventory_item.dart';
import 'package:projects/features/inventory/pages/expired_view_supply_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationsController _controller = NotificationsController();
  int _visibleCount = 10; // show 10 initially, then 20 max

  @override
  void initState() {
    super.initState();
    // Enforce max 20 on entry (older ones are deleted)
    // Fire and forget; UI listens to stream
    _controller.enforceMaxNotifications(max: 20);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: BackButton(color: theme.iconTheme.color),
        title: Text(
          "Notifications",
          style: AppFonts.sfProStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: theme.appBarTheme.elevation,
        shadowColor: theme.appBarTheme.shadowColor,
        actions: const [],
      ),
      // No drawer on this page; show back button instead
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
              boxShadow: [],
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<AppNotification>>(
                    stream: _controller.getNotificationsStreamLimited(max: 20),
                    builder: (context, snapshot) {
                      final all = snapshot.data ?? const <AppNotification>[];
                      final items = all.take(_visibleCount).toList();
                      final unreadCount = all.where((n) => !(n.isRead)).length;
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          all.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (all.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.notifications_none,
                                  size: 60,
                                  color:
                                      theme.iconTheme.color?.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No Notifications Yet',
                                style: AppFonts.sfProStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You\'re all caught up',
                                style: AppFonts.sfProStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final bool showLoadMore =
                          all.length > _visibleCount && _visibleCount == 10;
                      final int listCount =
                          items.length + (showLoadMore ? 1 : 0);

                      return Column(
                        children: [
                          // Unread chip at top-right of the purple panel
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Row(
                              children: [
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: scheme.surface,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color:
                                          theme.dividerColor.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '$unreadCount unread',
                                    style: AppFonts.sfProStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: listCount,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                if (showLoadMore && index == items.length) {
                                  return OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _visibleCount = 20; // reveal up to 20
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: theme.dividerColor
                                              .withOpacity(0.2)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      backgroundColor: scheme.surface,
                                    ),
                                    child: Text(
                                      'See previous notifications',
                                      style: AppFonts.sfProStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            theme.textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                  );
                                }

                                final n = items[index];
                                return _NotificationTile(
                                  notification: n,
                                  controller: _controller,
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final NotificationsController controller;

  const _NotificationTile({
    required this.notification,
    required this.controller,
  });

  // Ensure only one banner is visible at a time across tiles
  static OverlayEntry? _activeBanner;
  static bool _bannerVisible = false;

  @override
  Widget build(BuildContext context) {
    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _showDeleteConfirmation(context),
            backgroundColor: const Color(0xFFE44B4D),
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (!notification.isRead) {
              await controller.markAsRead(notification.id);
            }
            // Navigate based on notification type
            try {
              if (notification.type.startsWith('po_') &&
                  (notification.poCode ?? '').isNotEmpty) {
                // Jump to Purchase Order page and open correct tab
                final String code = notification.poCode!;
                // Check live status before navigating; if missing, show banner here
                try {
                  final data = await Supabase.instance.client
                      .from('purchase_orders')
                      .select('*')
                      .eq('code', code)
                      .limit(1);
                  if (data.isEmpty) {
                    _showNotFoundOverlay(context,
                        title: 'Purchase Order Not Found',
                        message:
                            'This purchase order ($code) no longer exists.');
                    return;
                  }
                  final poData = data.first;
                  if ((poData['status'] as String?) == null ||
                      (poData['id'] as String?) == null) {
                    // Defensive: malformed doc treated as unavailable
                    _showNotFoundOverlay(context,
                        title: 'Purchase Order Not Available',
                        message: 'Please try again in a moment.');
                    return;
                  }
                  final String status = (poData['status'] ?? 'Open') as String;
                  int desiredTab;
                  switch (status) {
                    case 'Approval':
                      desiredTab = 1;
                      break;
                    case 'Closed':
                      desiredTab = 2;
                      break;
                    default:
                      desiredTab = 0;
                  }
                  if (context.mounted) {
                    await Navigator.pushNamed(
                      context,
                      '/purchase-order',
                      arguments: {
                        'initialTab': desiredTab,
                        'openPOCode': code,
                      },
                    );
                  }
                } catch (_) {
                  _showNotFoundOverlay(context,
                      title: 'Unable to Open Purchase Order',
                      message: 'Please try again in a moment.');
                }
              } else if ((notification.supplyName ?? '').isNotEmpty) {
                // Inventory notifications
                final String name = notification.supplyName!;
                if (notification.type == 'expired') {
                  // Open specific expired batch directly
                  try {
                    final data = await Supabase.instance.client
                        .from('supplies')
                        .select('*')
                        .eq('name', name);
                    if (data.isNotEmpty) {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      InventoryItem? chosen;
                      DateTime? earliest;
                      for (final d in data) {
                        if ((d['expiry'] ?? '').toString().isEmpty) continue;
                        final parsed = DateTime.tryParse(
                            (d['expiry'] as String).replaceAll('/', '-'));
                        if (parsed == null) continue;
                        final dateOnly =
                            DateTime(parsed.year, parsed.month, parsed.day);
                        final isExpired = dateOnly.isBefore(today) ||
                            dateOnly.isAtSameMomentAs(today);
                        if (!isExpired) continue;
                        // Build InventoryItem lazily for the first qualified doc
                        if (earliest == null || dateOnly.isBefore(earliest)) {
                          earliest = dateOnly;
                          chosen = InventoryItem(
                            id: d['id'] as String,
                            name: (d['name'] ?? '').toString(),
                            imageUrl: (d['image_url'] ?? '').toString(),
                            category: (d['category'] ?? '').toString(),
                            cost: ((d['cost'] ?? 0) as num).toDouble(),
                            stock: (d['stock'] ?? 0) as int,
                            unit: (d['unit'] ?? '').toString(),
                            supplier: (d['supplier'] ?? '').toString(),
                            brand: (d['brand'] ?? '').toString(),
                            expiry: (d['expiry'] ?? '').toString(),
                            noExpiry: (d['no_expiry'] ?? false) as bool,
                            archived: (d['archived'] ?? false) as bool,
                          );
                        }
                      }
                      if (chosen != null && context.mounted) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExpiredViewSupplyPage(
                                item: chosen as InventoryItem),
                          ),
                        );
                        return;
                      }
                    }
                  } catch (_) {}
                  // Fallback: open Expired list page so user can locate it
                  if (context.mounted) {
                    await Navigator.pushNamed(context, '/inventory',
                        arguments: {'highlightSupplyName': name});
                  }
                } else {
                  // Default: open Inventory and deep-link
                  if (context.mounted) {
                    await Navigator.pushNamed(context, '/inventory',
                        arguments: {
                          'highlightSupplyName': name,
                        });
                  }
                }
              }
            } catch (_) {}
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.12),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            height: 80, // Reduced height for tighter layout
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _getIconBackgroundColor(notification.type)
                        .withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForType(notification.type),
                    color: _getIconBackgroundColor(notification.type),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          notification.message,
                          style: AppFonts.sfProStyle(
                            fontSize: 15,
                            fontWeight: notification.isRead
                                ? FontWeight.w500
                                : FontWeight.bold,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Row(
                          children: [
                            if (!notification.isRead) ...[
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF007AFF),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              controller
                                  .getRelativeTime(notification.createdAt),
                              style: AppFonts.sfProStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotFoundOverlay(BuildContext context,
      {required String title, required String message}) {
    if (_bannerVisible) return; // already showing
    // Remove any stale banner just in case
    _activeBanner?.remove();
    final overlay = OverlayEntry(
      builder: (_) => _AnimatedTopBanner(
        title: title,
        message: message,
        onDismiss: () {
          _activeBanner?.remove();
          _activeBanner = null;
          _bannerVisible = false;
        },
      ),
    );
    _activeBanner = overlay;
    _bannerVisible = true;
    Overlay.of(context).insert(overlay);
  }

  // Animated banner reused from PO page style with bounce + fade
  // Shows at top, auto-dismisses, uses SF Pro and same red gradient
  Color _getIconBackgroundColor(String type) {
    switch (type) {
      case 'low_stock':
        return const Color(0xFFF77436);
      case 'out_of_stock':
        return const Color(0xFFE44B4D);
      case 'expiring':
        return const Color(0xFFDEA805);
      case 'expired':
        return const Color(0xFF8B0000);
      case 'in_stock':
        return const Color(0xFF1ACB5D);
      case 'po_rejected':
        return const Color(0xFFE44B4D);
      case 'po_waiting':
        return const Color(0xFF8A8A8A);
      case 'po_approved':
        return const Color(0xFF1ACB5D);
      default:
        return const Color(0xFFB37BE6);
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'low_stock':
        return Icons.warning;
      case 'out_of_stock':
        return Icons.cancel;
      case 'expiring':
        return Icons.schedule;
      case 'expired':
        return Icons.error;
      case 'in_stock':
        return Icons.check_circle;
      case 'po_rejected':
        return Icons.close; // X
      case 'po_waiting':
        return Icons.access_time; // clock
      case 'po_approved':
        return Icons.check; // check
      default:
        return Icons.notifications;
    }
  }

  // summary handling removed

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Delete Notification',
            style: AppFonts.sfProStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this notification?',
            style: AppFonts.sfProStyle(
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: AppFonts.sfProStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await controller.deleteNotification(notification.id);
              },
              child: Text(
                'Delete',
                style: AppFonts.sfProStyle(
                  fontSize: 14,
                  color: const Color(0xFFE44B4D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AnimatedTopBanner extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback onDismiss;

  const _AnimatedTopBanner({
    required this.title,
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_AnimatedTopBanner> createState() => _AnimatedTopBannerState();
}

class _AnimatedTopBannerState extends State<_AnimatedTopBanner>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -2.0),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.bounceOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideController.forward();
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 4000), () {
      if (mounted) _fadeOut();
    });
  }

  Future<void> _fadeOut() async {
    await _fadeController.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 88),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFEE5A52)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.error_outline,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.sfProStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.sfProStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _fadeOut,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
