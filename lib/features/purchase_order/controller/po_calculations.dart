import 'package:familee_dental/features/purchase_order/data/purchase_order.dart';

class POBusinessService {
  // Business logic methods that don't involve direct data access

  /// Calculate the total cost of a purchase order
  static double calculateTotalCost(PurchaseOrder po) {
    double total = 0.0;
    for (final supply in po.supplies) {
      final quantity = (supply['quantity'] ?? 0).toInt();
      final cost = (supply['cost'] ?? 0.0).toDouble();
      total += quantity * cost;
    }
    return total;
  }

  /// Calculate the progress percentage of received supplies
  static double calculateProgressPercentage(PurchaseOrder po) {
    if (po.totalCount == 0) return 0.0;
    return (po.receivedCount / po.totalCount) * 100;
  }

  /// Get the status color for UI display
  static String getStatusColor(PurchaseOrder po) {
    switch (po.status) {
      case 'Closed':
        return 'red';
      case 'Approval':
        return 'orange';
      case 'Cancelled':
        return 'red';
      case 'Open':
        return 'green';
      default:
        return 'grey';
    }
  }

  /// Validate if a PO can be approved
  static bool canApprove(PurchaseOrder po) {
    return po.status == 'Approval' && po.receivedCount > 0;
  }

  /// Validate if a PO can be closed
  static bool canClose(PurchaseOrder po) {
    return po.status == 'Approval' && po.receivedCount == po.totalCount;
  }

  /// Get formatted date string
  static String formatDate(DateTime date) {
    const months = [
      'Jan.',
      'Feb.',
      'Mar.',
      'Apr.',
      'May',
      'Jun.',
      'Jul.',
      'Aug.',
      'Sep.',
      'Oct.',
      'Nov.',
      'Dec.'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Get status display text
  static String getStatusDisplayText(String status) {
    switch (status) {
      case 'Open':
        return 'Open';
      case 'Approval':
        return 'Pending Approval';
      case 'Closed':
        return 'Completed';
      case 'Cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}
