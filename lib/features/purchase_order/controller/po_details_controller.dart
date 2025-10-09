import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/features/purchase_order/data/purchase_order.dart';
import 'package:familee_dental/features/purchase_order/controller/po_supabase_controller.dart';
import 'package:familee_dental/features/purchase_order/controller/po_calculations.dart';
import 'package:familee_dental/features/activity_log/controller/po_activity_controller.dart';
import 'package:familee_dental/features/notifications/controller/notifications_controller.dart';

class PODetailsController {
  final POSupabaseController _poController = POSupabaseController();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Calculate total cost of all supplies in a PO
  double calculateTotalCost(PurchaseOrder po) {
    return POBusinessService.calculateTotalCost(po);
  }

  // Group supplies by supplier
  Map<String, List<Map<String, dynamic>>> groupSuppliesBySupplier(
      List<Map<String, dynamic>> supplies) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final supply in supplies) {
      final supplier = getSupplierName(supply);
      grouped[supplier] ??= [];
      grouped[supplier]!.add(supply);
    }
    return grouped;
  }

  // Check if PO can be received (pending status)
  bool canReceivePO(PurchaseOrder po) {
    return po.status == 'Pending';
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

    // Save the updated PO directly to Supabase for real-time updates
    await _poController.updatePOInSupabase(updatedPO);

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
    try {
      // First, restock inventory with received supplies (before changing status)
      await _restockInventory(po);

      // Only after successful restock, create new PO instance with Closed status
      final updatedPO = PurchaseOrder(
        id: po.id,
        code: po.code,
        name: po.name,
        createdAt: po.createdAt,
        status: 'Closed',
        supplies: po.supplies,
        receivedCount: po.receivedCount,
      );

      // Save the updated PO directly to Supabase for real-time updates
      await _poController.updatePOInSupabase(updatedPO);

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
    } catch (e) {
      print('Error in approvePurchaseOrder: $e');
      rethrow;
    }
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

    // Update in Supabase for real-time updates
    await _poController.updatePOInSupabase(updatedPO);

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
    try {
      // Get only received supplies
      final receivedSupplies = po.supplies
          .where((supply) => supply['status'] == 'Received')
          .toList();

      if (receivedSupplies.isEmpty) {
        print('No received supplies to restock');
        return;
      }

      print('Restocking ${receivedSupplies.length} received supplies');

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
        print('Looking up existing supplies for: $supplyName');
        try {
          await _supabase.from('supplies').select('*').eq('name', supplyName);
        } catch (e) {
          print('Error querying supplies table: $e');
          rethrow;
        }

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
          final freshResponse = await _supabase
              .from('supplies')
              .select('*')
              .eq('name', supplyName);
          final freshDocs = freshResponse;

          // Check for exact batch match (name + brand + supplier + cost + unit + expiry)
          bool foundExactBatch = false;
          for (final doc in freshDocs) {
            final data = doc;
            final existingBrand = (data['brand'] ?? '').toString().trim();
            final existingSupplier = (data['supplier'] ?? '').toString().trim();
            final existingCost = (data['cost'] ?? 0).toDouble();
            final existingUnit = (data['unit'] ?? '').toString().trim();
            final existingExpiry = data['expiry'];
            final existingNoExpiry = (data['no_expiry'] ?? false) as bool;

            // Check if this is an exact batch match
            bool brandMatches =
                existingBrand.toLowerCase() == brandName.toLowerCase();
            bool supplierMatches =
                existingSupplier.toLowerCase() == supplierName.toLowerCase();
            bool costMatches = existingCost == (supply['cost'] ?? 0.0);
            bool unitMatches = existingUnit.toLowerCase() ==
                (supply['unit'] ?? '').toString().toLowerCase();

            bool expiryMatches = false;
            if (expNorm == null && existingNoExpiry) {
              expiryMatches = true;
            } else if (expNorm != null &&
                normalize(existingExpiry?.toString()) == expNorm) {
              expiryMatches = true;
            }

            // If all criteria match, merge with this batch
            if (brandMatches &&
                supplierMatches &&
                costMatches &&
                unitMatches &&
                expiryMatches) {
              final currentStock = (data['stock'] ?? 0) as int;
              final newStock = currentStock + qty;

              await _supabase.from('supplies').update({
                'stock': newStock,
              }).eq('id', doc['id']);

              foundExactBatch = true;
              break;
            }
          }

          // If no exact batch found, create a new batch
          if (!foundExactBatch) {
            // Derive canonical metadata from existing docs
            String category = "Dental Materials";
            String unit = (supply['unit'] ?? 'pcs').toString();
            String imageUrl = "";
            double itemCost = (supply['cost'] ?? 0.0).toDouble();

            if (freshDocs.isNotEmpty) {
              String canonicalCategory = '';
              String canonicalImageUrl = '';
              for (final d in freshDocs) {
                final data = d;
                final cat = (data['category'] ?? '').toString();
                if (canonicalCategory.isEmpty &&
                    cat.isNotEmpty &&
                    cat != 'Restocked') {
                  canonicalCategory = cat;
                }
                final img = (data['image_url'] ?? '').toString();
                if (canonicalImageUrl.isEmpty && img.isNotEmpty) {
                  canonicalImageUrl = img;
                }
              }
              category =
                  canonicalCategory.isNotEmpty ? canonicalCategory : category;
              imageUrl = canonicalImageUrl;
            }

            final newSupplyData = {
              "name": supplyName,
              "image_url": imageUrl,
              "category": category,
              "cost": itemCost,
              "stock": qty,
              "unit": unit,
              "supplier": supplierName,
              "brand": brandName,
              "expiry": expNorm,
              "no_expiry": expNorm == null,
              "archived": false,
              "created_at": DateTime.now().toIso8601String(),
            };
            await _supabase.from('supplies').insert(newSupplyData);
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
    } catch (e) {
      print('Error in _restockInventory: $e');
      rethrow;
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

  // ===== RECIPIENT SUGGESTIONS METHODS =====
  static const String _recipientSuggestionsCollection = 'recipient_suggestions';

  // Get recipient suggestions based on input text
  Future<List<String>> getRecipientSuggestions(String input) async {
    if (input.trim().isEmpty) return [];

    final suggestions = await _getAllRecipientSuggestions();
    final query = input.toLowerCase().trim();

    // Filter suggestions that contain the input text
    final filtered = suggestions
        .where((suggestion) => suggestion.toLowerCase().contains(query))
        .toList();

    // Return top 5 suggestions (already sorted by frequency from Supabase)
    return filtered.take(5).toList();
  }

  // Add a new recipient name to suggestions (called when receipt is saved)
  Future<void> addRecipientSuggestion(String recipientName) async {
    if (recipientName.trim().isEmpty) return;

    final normalizedName = recipientName.trim();

    // Increment frequency (this will create or update the suggestion)
    await _incrementRecipientFrequency(normalizedName);
  }

  // Get all recipient suggestions from Supabase
  Future<List<String>> _getAllRecipientSuggestions() async {
    try {
      final response = await _supabase
          .from(_recipientSuggestionsCollection)
          .select('name')
          .order('frequency', ascending: false)
          .limit(20);

      return response.map((row) => row['name'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  // Get frequency of a recipient suggestion from Supabase
  Future<int> _getRecipientFrequency(String name) async {
    try {
      final response = await _supabase
          .from(_recipientSuggestionsCollection)
          .select('frequency')
          .eq('name', name)
          .maybeSingle();

      return response?['frequency'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Increment frequency for a recipient suggestion in Supabase
  Future<void> _incrementRecipientFrequency(String name) async {
    try {
      // Use timestamp for unique ID to avoid conflicts
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final docId = timestamp.toString();

      // Check if this exact name already exists
      final existingSuggestion = await _findExistingSuggestion(name);

      if (existingSuggestion != null) {
        // Update existing suggestion
        await _supabase.from(_recipientSuggestionsCollection).update({
          'frequency': existingSuggestion['frequency'] + 1,
          'last_used': DateTime.now().toIso8601String(),
        }).eq('id', existingSuggestion['id']);
      } else {
        // Create new suggestion with frequency 1
        await _supabase.from(_recipientSuggestionsCollection).insert({
          'id': docId,
          'name': name,
          'frequency': 1,
          'last_used': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // Find existing suggestion by name (not ID)
  Future<Map<String, dynamic>?> _findExistingSuggestion(String name) async {
    try {
      final response = await _supabase
          .from(_recipientSuggestionsCollection)
          .select('*')
          .eq('name', name)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  // ===== RECEIPT NUMBER VALIDATION =====

  // Check if receipt number already exists in any PO
  Future<bool> isReceiptNumberDuplicate(String receiptNumber) async {
    if (receiptNumber.trim().isEmpty) return false;

    try {
      // Search through all purchase orders for this receipt number
      final response = await _supabase
          .from('purchase_orders')
          .select('supplies')
          .not('supplies', 'is', null);

      for (final po in response) {
        final supplies = po['supplies'] as List<dynamic>?;
        if (supplies != null) {
          for (final supply in supplies) {
            final receiptDrNo = supply['receiptDrNo'] as String?;
            if (receiptDrNo != null &&
                receiptDrNo.trim().toLowerCase() ==
                    receiptNumber.trim().toLowerCase()) {
              return true; // Found duplicate
            }
          }
        }
      }

      return false; // No duplicate found
    } catch (e) {
      return false; // On error, allow the receipt number
    }
  }
}
