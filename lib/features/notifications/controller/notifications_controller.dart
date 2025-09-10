import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final String type;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.type,
    this.isRead = false,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    final Timestamp ts = (data['createdAt'] as Timestamp?) ?? Timestamp.now();
    return AppNotification(
      id: id,
      title: (data['title'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      createdAt: ts.toDate(),
      type: (data['type'] ?? 'general').toString(),
      isRead: (data['isRead'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'type': type,
      'isRead': isRead,
    };
  }
}

class NotificationsController {
  final FirebaseFirestore firestore;

  NotificationsController({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<AppNotification>> getNotificationsStream() {
    return firestore
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> createNotification({
    required String title,
    required String message,
    required String type,
  }) async {
    final docRef = firestore.collection('notifications').doc();
    await docRef.set({
      'title': title,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
      'type': type,
      'isRead': false,
    });
  }

  // Inventory stock alert methods
  Future<void> createLowStockNotification(
      String supplyName, int currentStock) async {
    await createNotification(
      title: 'Low Stock Alert',
      message: '$supplyName is running low ($currentStock remaining)',
      type: 'low_stock',
    );
  }

  Future<void> createOutOfStockNotification(String supplyName) async {
    await createNotification(
      title: 'Out of Stock Alert',
      message: '$supplyName is now out of stock',
      type: 'out_of_stock',
    );
  }

  Future<void> createExpiringNotification(
      String supplyName, int daysUntilExpiry) async {
    await createNotification(
      title: 'Expiring Soon',
      message: '$supplyName expires in $daysUntilExpiry days',
      type: 'expiring',
    );
  }

  Future<void> createExpiredNotification(String supplyName) async {
    await createNotification(
      title: 'Expired Item',
      message: '$supplyName has expired',
      type: 'expired',
    );
  }

  Future<void> createInStockNotification(
      String supplyName, int newStock) async {
    await createNotification(
      title: 'Restocked',
      message: '$supplyName is back in stock ($newStock available)',
      type: 'in_stock',
    );
  }

  Future<void> markAsRead(String id) async {
    await firestore.collection('notifications').doc(id).update({
      'isRead': true,
    });
  }

  Future<void> deleteNotification(String id) async {
    await firestore.collection('notifications').doc(id).delete();
  }

  Future<void> clearAll() async {
    final snap = await firestore.collection('notifications').get();
    final batch = firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  String getRelativeTime(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}m ago';
    } else {
      return '${(difference.inDays / 365).floor()}y ago';
    }
  }

  // Helper method to check if stock level triggers a notification
  Future<void> checkStockLevelNotification(
      String supplyName, int newStock, int previousStock) async {
    // Check for out of stock (from any stock to 0)
    if (newStock == 0 && previousStock > 0) {
      await createOutOfStockNotification(supplyName);
      return;
    }

    // Check for restocked (from 0 to any positive stock)
    if (newStock > 0 && previousStock == 0) {
      await createInStockNotification(supplyName, newStock);
      return;
    }

    // Check for low stock (from >2 to 1-2)
    if (newStock <= 2 && newStock > 0 && previousStock > 2) {
      await createLowStockNotification(supplyName, newStock);
      return;
    }

    // Check for back to normal stock (from 1-2 to 3+)
    if (newStock >= 3 && previousStock <= 2 && previousStock > 0) {
      await createInStockNotification(supplyName, newStock);
      return;
    }
  }

  // Helper method to check expiry notifications
  Future<void> checkExpiryNotification(
      String supplyName, String? expiryDate, bool noExpiry) async {
    if (noExpiry || expiryDate == null || expiryDate.isEmpty) {
      return; // No expiry to check
    }

    final expiry = DateTime.tryParse(expiryDate);
    if (expiry == null) return;

    final today = DateTime.now();
    final daysUntilExpiry = expiry.difference(today).inDays;

    // Check if expired
    if (expiry.isBefore(today)) {
      await createExpiredNotification(supplyName);
      return;
    }

    // Check if expiring soon (30 days or less)
    if (daysUntilExpiry <= 30 && daysUntilExpiry >= 0) {
      await createExpiringNotification(supplyName, daysUntilExpiry);
      return;
    }
  }
}
