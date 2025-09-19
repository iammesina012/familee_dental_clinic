import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/purchase_order.dart';
import 'po_firebase_controller.dart';
import 'po_calculations.dart';
import 'package:projects/features/activity_log/controller/po_activity_controller.dart';
import 'package:projects/features/notifications/controller/notifications_controller.dart';

class PODetailsController {
  final POFirebaseController _poController = POFirebaseController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Calculate total cost of all supplies in a PO
  double calculateTotalCost(PurchaseOrder po) {
    return POBusinessService.calculateTotalCost(po);
  }

  // Mark a supply as received with expiry date
  Future<PurchaseOrder> markSupplyAsReceived(
    PurchaseOrder po,
    int supplyIndex,
    DateTime? expiryDate,
    bool noExpiry,
  ) async {
    // Create a new list with updated supply status
    final updatedSupplies = List<Map<String, dynamic>>.from(po.supplies);

    // Update the supply with received status and expiry date
    updatedSupplies[supplyIndex] = {
      ...updatedSupplies[supplyIndex],
      'status': 'Received',
      'expiryDate': noExpiry
          ? 'No expiry'
          : '${expiryDate!.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}',
    };

    // Calculate new received count
    final newReceivedCount = updatedSupplies
        .where((supply) => supply['status'] == 'Received')
        .length;

    // Determine new status
    String newStatus = po.status;
    if (newReceivedCount == updatedSupplies.length) {
      newStatus = 'Approval';
    }

    // Create new PO instance with updated values
    final updatedPO = PurchaseOrder(
      id: po.id,
      code: po.code,
      name: po.name,
      createdAt: po.createdAt,
      status: newStatus,
      supplies: updatedSupplies,
      receivedCount: newReceivedCount,
    );

    // Save the updated PO directly to Firebase for real-time updates
    await _poController.updatePOInFirebase(updatedPO);

    // Log activity: Received #PO: Name with additional details of all supplies
    await PoActivityController().logPurchaseOrderReceived(
      poCode: updatedPO.code,
      poName: updatedPO.name,
      supplies: [updatedSupplies[supplyIndex]],
    );

    // Notify if moved to Approval
    if (po.status != 'Approval' && newStatus == 'Approval') {
      try {
        await NotificationsController()
            .createPOWaitingApprovalNotification(updatedPO.code);
      } catch (_) {}
    }

    return updatedPO;
  }

  // Approve a purchase order (change status to Closed)
  Future<PurchaseOrder> approvePurchaseOrder(PurchaseOrder po) async {
    // Create new PO instance with Closed status
    final updatedPO = PurchaseOrder(
      id: po.id,
      code: po.code,
      name: po.name,
      createdAt: po.createdAt,
      status: 'Closed',
      supplies: po.supplies,
      receivedCount: po.receivedCount,
    );

    // Save the updated PO directly to Firebase for real-time updates
    await _poController.updatePOInFirebase(updatedPO);

    // Restock inventory with received supplies
    await _restockInventory(updatedPO);

    // Log the purchase order approval
    await PoActivityController().logPurchaseOrderApproved(
      poCode: updatedPO.code,
      poName: updatedPO.name,
      supplies: updatedPO.supplies,
    );

    // Notify approval
    try {
      await NotificationsController()
          .createPOApprovedNotification(updatedPO.code);
    } catch (_) {}

    return updatedPO;
  }

  // Reject a purchase order (move back to Open for editing)
  Future<PurchaseOrder> rejectPurchaseOrder(PurchaseOrder po) async {
    // Reset all supplies back to Pending but KEEP any existing expiry dates
    final List<Map<String, dynamic>> resetSupplies = po.supplies
        .map((s) => {
              ...s,
              'status': 'Pending',
            })
        .toList();

    final updatedPO = PurchaseOrder(
      id: po.id,
      code: po.code,
      name: po.name,
      createdAt: po.createdAt,
      status: 'Open',
      supplies: resetSupplies,
      receivedCount: 0,
    );

    // Update in Firebase for real-time updates
    await _poController.updatePOInFirebase(updatedPO);

    // Log the purchase order rejection
    await PoActivityController().logPurchaseOrderRejected(
      poCode: updatedPO.code,
      poName: updatedPO.name,
      supplies: updatedPO.supplies,
    );

    // Notify rejection
    try {
      await NotificationsController()
          .createPORejectedNotification(updatedPO.code);
    } catch (_) {}

    return updatedPO;
  }

  // Restock inventory with received supplies from PO
  Future<void> _restockInventory(PurchaseOrder po) async {
    // Get only received supplies
    final receivedSupplies =
        po.supplies.where((supply) => supply['status'] == 'Received').toList();

    for (final supply in receivedSupplies) {
      final supplyName = supply['supplyName'] ?? supply['name'] ?? '';
      final brandName = supply['brandName'] ?? supply['brand'] ?? 'N/A';
      final supplierName =
          supply['supplierName'] ?? supply['supplier'] ?? 'N/A';
      final int totalQuantity = supply['quantity'] ?? 0;
      final expiryDate = supply['expiryDate'];
      final List<dynamic>? expiryBatches =
          (supply['expiryBatches'] as List<dynamic>?);

      // Prepare existing items lookup (by name+brand)
      await _firestore
          .collection('supplies')
          .where('name', isEqualTo: supplyName)
          // .where('brand', isEqualTo: brandName)
          .get();

      // Restock helper to merge one batch into inventory
      Future<void> mergeOneBatch(
          {required int qty, required String? exp}) async {
        // Normalize expiry to canonical date (yyyy-MM-dd) or null
        String? normalize(String? v) {
          if (v == null) return null;
          if (v.toLowerCase() == 'no expiry') return null;
          final s = v.replaceAll('/', '-');
          final core = s.length >= 10 ? s.substring(0, 10) : s;
          try {
            final dt = DateTime.tryParse(core);
            if (dt == null) return null;
            final y = dt.year.toString().padLeft(4, '0');
            final m = dt.month.toString().padLeft(2, '0');
            final d = dt.day.toString().padLeft(2, '0');
            return '$y-$m-$d';
          } catch (_) {
            return null;
          }
        }

        final String? expNorm = normalize(exp);
        // Fetch fresh snapshot per batch to avoid stale zero-stock merging
        final freshSnapshot = await _firestore
            .collection('supplies')
            .where('name', isEqualTo: supplyName)
            // .where('brand', isEqualTo: brandName)
            .get();
        final freshDocs = freshSnapshot.docs;

        bool foundMatchingExpiry = false;
        QueryDocumentSnapshot<Map<String, dynamic>>? zeroStockDoc;
        QueryDocumentSnapshot<Map<String, dynamic>>? sameExpiryDoc;
        for (final doc in freshDocs) {
          final data = doc.data();
          final int s = (data['stock'] ?? 0) as int;
          final bool isArchived = (data['archived'] ?? false) as bool;
          if (!isArchived && s == 0) {
            zeroStockDoc = doc;
          }
          final dynamic otherExpiryRaw = data['expiry'];
          final String? otherExpiry =
              (otherExpiryRaw == null || otherExpiryRaw.toString().isEmpty)
                  ? null
                  : otherExpiryRaw.toString();
          final String? otherNorm = normalize(otherExpiry);
          final bool expiryMatches = (expNorm == null &&
                  (data['noExpiry'] ?? false) == true) ||
              (expNorm != null && otherNorm != null && otherNorm == expNorm);
          if (expiryMatches) {
            sameExpiryDoc = doc;
          }
        }

        if (zeroStockDoc != null) {
          int mergedStock = qty;
          if (sameExpiryDoc != null && sameExpiryDoc.id != zeroStockDoc.id) {
            final int matchStock = (sameExpiryDoc.data()['stock'] ?? 0) as int;
            mergedStock += matchStock;
          }

          await zeroStockDoc.reference.update({
            'stock': mergedStock,
            'expiry': expNorm,
            'noExpiry': expNorm == null,
            'archived': false,
          });

          if (sameExpiryDoc != null && sameExpiryDoc.id != zeroStockDoc.id) {
            await sameExpiryDoc.reference.delete();
          }

          foundMatchingExpiry = true;
        }

        for (final doc in freshDocs) {
          final existingData = doc.data();
          final existingExpiry = existingData['expiry'];
          final existingNoExpiry = existingData['noExpiry'] ?? false;

          bool expiryMatches = false;
          if (expNorm == null && existingNoExpiry) {
            expiryMatches = true;
          } else if (expNorm != null &&
              normalize(existingExpiry?.toString()) == expNorm) {
            expiryMatches = true;
          }

          if (!foundMatchingExpiry && expiryMatches) {
            final currentStock = existingData['stock'] ?? 0;
            final newStock = currentStock + qty;

            await doc.reference.update({
              'stock': newStock,
            });

            foundMatchingExpiry = true;
            break;
          }
        }

        if (!foundMatchingExpiry) {
          // Derive canonical metadata from existing docs
          String category = "Dental Materials";
          String unit = "pcs";
          String imageUrl = "";
          double itemCost = 0.0;
          if (freshDocs.isNotEmpty) {
            String canonicalCategory = '';
            String canonicalUnit = '';
            String canonicalImageUrl = '';
            double? canonicalCost;
            for (final d in freshDocs) {
              final data = d.data();
              final cat = (data['category'] ?? '').toString();
              if (canonicalCategory.isEmpty &&
                  cat.isNotEmpty &&
                  cat != 'Restocked') {
                canonicalCategory = cat;
              }
              final unitVal = (data['unit'] ?? '').toString();
              if (canonicalUnit.isEmpty && unitVal.isNotEmpty) {
                canonicalUnit = unitVal;
              }
              final img = (data['imageUrl'] ?? '').toString();
              if (canonicalImageUrl.isEmpty && img.isNotEmpty) {
                canonicalImageUrl = img;
              }
              final costVal = (data['cost'] ?? 0).toDouble();
              if (canonicalCost == null || costVal > 0) {
                canonicalCost = costVal;
              }
            }
            category =
                canonicalCategory.isNotEmpty ? canonicalCategory : category;
            unit = canonicalUnit.isNotEmpty ? canonicalUnit : unit;
            imageUrl = canonicalImageUrl;
            itemCost = canonicalCost ?? 0.0;
          }

          final newSupplyData = {
            "name": supplyName,
            "imageUrl": imageUrl,
            "category": category,
            "cost": itemCost,
            "stock": qty,
            "unit": unit,
            "supplier": supplierName,
            "brand": brandName,
            "expiry": expNorm,
            "noExpiry": expNorm == null,
            "archived": false,
            "createdAt": FieldValue.serverTimestamp(),
          };
          await _firestore.collection('supplies').add(newSupplyData);
        }
      }

      // If we have explicit batches, restock each; otherwise restock single batch
      if (expiryBatches != null && expiryBatches.isNotEmpty) {
        for (final b in expiryBatches) {
          final int q = int.tryParse('${b['quantity'] ?? 0}') ?? 0;
          final String? e = (b['expiryDate']?.toString().isNotEmpty ?? false)
              ? b['expiryDate'].toString()
              : null;
          if (q > 0) {
            await mergeOneBatch(qty: q, exp: e);
          }
        }
      } else {
        final int singleQty = totalQuantity;
        // Ensure we pass canonical yyyy-MM-dd when present
        final String? singleExp = (expiryDate == null)
            ? null
            : '${expiryDate.year.toString().padLeft(4, '0')}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}';
        if (singleQty > 0) {
          await mergeOneBatch(qty: singleQty, exp: singleExp);
        }
      }
    }
  }

  // Check if a supply is already received
  bool isSupplyReceived(Map<String, dynamic> supply) {
    return supply['status'] == 'Received';
  }

  // Get supply name with fallbacks
  String getSupplyName(Map<String, dynamic> supply) {
    return supply['supplyName'] ?? supply['name'] ?? 'Unknown Supply';
  }

  // Get brand name with fallbacks
  String getBrandName(Map<String, dynamic> supply) {
    return supply['brandName'] ?? supply['brand'] ?? 'N/A';
  }

  // Get supplier name with fallbacks
  String getSupplierName(Map<String, dynamic> supply) {
    return supply['supplierName'] ?? supply['supplier'] ?? 'N/A';
  }

  // Calculate subtotal for a supply
  double calculateSupplySubtotal(Map<String, dynamic> supply) {
    final quantity = supply['quantity'] ?? 0;
    final cost = supply['cost'] ?? 0.0;
    return quantity * cost;
  }

  // Check if PO can be approved (all supplies received)
  bool canApprovePO(PurchaseOrder po) {
    return po.status == 'Approval' && po.receivedCount == po.supplies.length;
  }

  // Check if PO can be rejected (currently in Approval state)
  bool canRejectPO(PurchaseOrder po) {
    return po.status == 'Approval';
  }

  // Check if PO is closed
  bool isPOClosed(PurchaseOrder po) {
    return po.status == 'Closed';
  }
}
