import 'package:flutter/material.dart';
import 'package:projects/shared/themes/font.dart';
import 'package:projects/features/notifications/controller/notifications_controller.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF9EFF2),
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        title: Text(
          "Notifications",
          style: AppFonts.sfProStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        toolbarHeight: 70,
        iconTheme: const IconThemeData(size: 30, color: Colors.black),
        elevation: 5,
        shadowColor: Colors.black54,
        actions: const [],
      ),
      // No drawer on this page; show back button instead
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE8D5E8),
              borderRadius: BorderRadius.circular(12),
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
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.notifications_none,
                                  size: 60,
                                  color: Color(0xFF8B5A8B),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No Notifications Yet',
                                style: AppFonts.sfProStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8B5A8B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You\'re all caught up',
                                style: AppFonts.sfProStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF8B5A8B),
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
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.black.withOpacity(0.15),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '$unreadCount unread',
                                    style: AppFonts.sfProStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
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
                                          color: Colors.black.withOpacity(0.2)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      backgroundColor: Colors.white,
                                    ),
                                    child: Text(
                                      'See previous notifications',
                                      style: AppFonts.sfProStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
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
                int desiredTab = 0; // Open
                if (notification.type == 'po_waiting')
                  desiredTab = 1; // Approval
                if (notification.type == 'po_approved')
                  desiredTab = 2; // Closed
                // Push PO page, then try to open the specific PO details
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
              } else if ((notification.supplyName ?? '').isNotEmpty) {
                // Navigate to inventory and open the earliest batch for this supply name
                if (context.mounted) {
                  await Navigator.pushNamed(context, '/inventory', arguments: {
                    'highlightSupplyName': notification.supplyName,
                  });
                  // The inventory list will show the item; user can tap through
                }
              }
            } catch (_) {}
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.black.withOpacity(0.08),
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
                                color: Colors.black54,
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
