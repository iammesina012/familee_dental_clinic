import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive storage helper for managing persistent caching across the app
class HiveStorage {
  // Box names for dashboard module
  static const String dashboardExpiryCountsBox = 'dashboard_expiry_counts';
  static const String dashboardSupplyCountsBox = 'dashboard_supply_counts';
  static const String dashboardPOCountsBox = 'dashboard_po_counts';
  static const String dashboardSuppliesByStatusBox =
      'dashboard_supplies_by_status';
  static const String dashboardPOsByStatusBox = 'dashboard_pos_by_status';
  static const String fastMovingItemsBox = 'fast_moving_items';
  static const String usageSpeedBox = 'usage_speed_items';

  // Box names for inventory module
  static const String inventorySuppliesBox = 'inventory_supplies';
  static const String inventoryGroupedSuppliesBox =
      'inventory_grouped_supplies';
  static const String expiredSuppliesBox = 'expired_supplies';
  static const String expiredViewSuppliesBox = 'expired_view_supplies';
  static const String expiredOtherBatchesBox = 'expired_other_batches';
  static const String expiredAggregatedStockBox = 'expired_aggregated_stock';
  static const String viewSuppliesBox = 'view_supplies';
  static const String viewSupplyTypesBox = 'view_supply_types';
  static const String catalogProductsBox = 'catalog_products';
  static const String archiveSuppliesBox = 'archive_supplies';
  static const String filterBrandsBox = 'filter_brands';
  static const String filterSuppliersBox = 'filter_suppliers';
  static const String filterBrandNamesBox = 'filter_brand_names';
  static const String filterSupplierNamesBox = 'filter_supplier_names';
  static const String categoriesBox = 'categories';

  // Box name for user data (username and role)
  static const String userDataBox = 'user_data';

  // Box name for edit profile data (name, username, email, role, id)
  static const String editProfileBox = 'edit_profile_data';

  // Box name for employee list data
  static const String employeeListBox = 'employee_list';

  // Box name for individual employee data (for Edit Employee page)
  static const String editEmployeeBox = 'edit_employee_data';

  // Box name for backup and restore data (backup list and auto-backup settings)
  static const String backupRestoreBox = 'backup_restore_data';

  // Box names for purchase order module
  static const String poOpenPOsBox = 'po_open_pos';
  static const String poPartialPOsBox = 'po_partial_pos';
  static const String poApprovalPOsBox = 'po_approval_pos';
  static const String poClosedPOsBox = 'po_closed_pos';
  static const String poAllPOsBox = 'po_all_pos';

  // Box names for stock deduction module
  static const String sdLogsBox =
      'sd_logs'; // Per-date logs stored with date keys
  static const String sdPendingApprovalsBox = 'sd_pending_approvals';

  // Box names for activity log module
  static const String activityLogsBox =
      'activity_logs'; // Per-date logs stored with date keys

  // Box name for notifications module
  static const String notificationsBox = 'notifications';

  /// Initialize Hive storage
  /// Call this once in main() before runApp()
  static Future<void> initialize() async {
    try {
      await Hive.initFlutter();
      debugPrint("Hive initialized successfully!");
    } catch (e) {
      debugPrint("Hive initialization failed: $e");
    }
  }

  /// Open a Hive box (creates if doesn't exist)
  static Future<Box> openBox(String boxName) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        return Hive.box(boxName);
      }
      return await Hive.openBox(boxName);
    } catch (e) {
      debugPrint("Error opening Hive box '$boxName': $e");
      rethrow;
    }
  }

  /// Get a box (must be opened first)
  static Box? getBox(String boxName) {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box(boxName);
    }
    return null;
  }

  /// Close a box
  static Future<void> closeBox(String boxName) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
    } catch (e) {
      debugPrint("Error closing Hive box '$boxName': $e");
    }
  }

  /// Clear all data from a box
  static Future<void> clearBox(String boxName) async {
    try {
      final box = getBox(boxName);
      if (box != null) {
        await box.clear();
      }
    } catch (e) {
      debugPrint("Error clearing Hive box '$boxName': $e");
    }
  }
}
