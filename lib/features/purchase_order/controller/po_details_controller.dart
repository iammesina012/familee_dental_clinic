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
      // Reload fresh PO from database to ensure we have the latest supply data
      final freshPO = await _poController.getPOByIdFromSupabase(po.id);
      if (freshPO == null) {
        throw Exception('PO not found');
      }

      // Check if there are any partially received supplies
      final hasPartiallyReceived = freshPO.supplies
          .any((supply) => supply['status'] == 'Partially Received');

      // Check if there are any pending supplies
      final hasPendingSupplies =
          freshPO.supplies.any((supply) => supply['status'] == 'Pending');

      // Check if all supplies are fully received
      final allSuppliesReceived =
          freshPO.supplies.every((supply) => supply['status'] == 'Received');

      // First, restock inventory with received supplies (before changing status)
      // This will update the restockedQuantities in the supplies
      final restockedSupplies = await _restockInventory(freshPO);

      // Determine the new status based on the supplies' states
      String newStatus;
      if (allSuppliesReceived) {
        // All supplies fully received -> Closed
        newStatus = 'Closed';
      } else if (hasPartiallyReceived || hasPendingSupplies) {
        // Some supplies partially received or still pending -> Partially Received
        newStatus = 'Partially Received';
      } else {
        // Fallback: should not happen, but set to Partially Received to be safe
        newStatus = 'Partially Received';
      }

      // Only after successful restock, create new PO instance with the updated supplies
      final updatedPO = PurchaseOrder(
        id: freshPO.id,
        code: freshPO.code,
        name: freshPO.name,
        createdAt: freshPO.createdAt,
        status: newStatus,
        supplies:
            restockedSupplies, // Use the supplies with updated restockedQuantities
        receivedCount: freshPO.receivedCount,
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

  // Reject a purchase order (move back to Open or Partially Received)
  Future<PurchaseOrder> rejectPurchaseOrder(PurchaseOrder po) async {
    // Keep receipt details but subtract the most recent partial receive quantities
    // Then recalculate status based on remaining partial receives
    final List<Map<String, dynamic>> resetSupplies = po.supplies.map((s) {
      final updatedSupply = Map<String, dynamic>.from(s);

      // Keep all receipt-related fields - don't clear them
      // Subtract the most recent partial receive quantities from receivedQuantities
      final receivedQuantitiesRaw = updatedSupply['receivedQuantities'];
      final receivedQuantities =
          receivedQuantitiesRaw != null && receivedQuantitiesRaw is Map
              ? Map<String, int>.from(receivedQuantitiesRaw)
              : <String, int>{};

      // Get the most recent partial receive quantities (lastPartialReceiveQuantities)
      final lastPartialReceiveQuantitiesRaw =
          updatedSupply['lastPartialReceiveQuantities'];
      final lastPartialReceiveQuantities =
          lastPartialReceiveQuantitiesRaw != null &&
                  lastPartialReceiveQuantitiesRaw is Map
              ? Map<String, int>.from(lastPartialReceiveQuantitiesRaw)
              : <String, int>{};

      // Debug logging
      final supplyName = getSupplyName(updatedSupply);
      print('Debug: Rejecting - Supply: $supplyName');
      print('Debug: receivedQuantities before: $receivedQuantities');
      print(
          'Debug: lastPartialReceiveQuantities: $lastPartialReceiveQuantities');

      // Check if this supply has lastPartialReceiveQuantities (indicating it was part of the most recent partial receive)
      final hasLastPartialReceive = lastPartialReceiveQuantities.isNotEmpty;

      // Subtract the most recent partial receive quantities (only if supply has lastPartialReceiveQuantities)
      if (hasLastPartialReceive) {
        // This supply was part of the most recent partial receive - subtract those quantities
        for (final entry in lastPartialReceiveQuantities.entries) {
          final expiryDate = entry.key;
          final qtyToSubtract = entry.value;
          final currentQty = receivedQuantities[expiryDate] ?? 0;
          final newQty =
              (currentQty - qtyToSubtract).clamp(0, double.infinity).toInt();

          if (newQty > 0) {
            receivedQuantities[expiryDate] = newQty;
          } else {
            receivedQuantities.remove(expiryDate);
          }
        }
        updatedSupply['receivedQuantities'] =
            receivedQuantities.isNotEmpty ? receivedQuantities : null;
        updatedSupply['lastPartialReceiveQuantities'] =
            null; // Clear after subtracting

        print(
            'Debug: receivedQuantities after subtracting: $receivedQuantities');

        // Recalculate status based on remaining receivedQuantities
        if (receivedQuantities.isNotEmpty) {
          final totalQuantity =
              int.tryParse('${updatedSupply['quantity'] ?? 0}') ?? 0;
          final totalReceived =
              receivedQuantities.values.fold(0, (sum, qty) => sum + qty);

          print(
              'Debug: totalQuantity: $totalQuantity, totalReceived: $totalReceived');

          if (totalReceived >= totalQuantity) {
            updatedSupply['status'] = 'Received';
            print('Debug: Status set to Received');
          } else if (totalReceived > 0) {
            updatedSupply['status'] = 'Partially Received';
            print('Debug: Status set to Partially Received');
          } else {
            // This shouldn't happen if receivedQuantities.isNotEmpty and totalReceived is 0
            // But just in case, set to Pending
            updatedSupply['status'] = 'Pending';
            print('Debug: Status set to Pending (totalReceived is 0)');
          }
        } else {
          // No partial receives after subtracting
          // Check if this supply was previously 'Received' (fully received after partial receives)
          // If so, restore it to 'Partially Received' with the quantity before it became fully received
          final currentStatus = updatedSupply['status']?.toString() ?? '';
          final totalQuantity =
              int.tryParse('${updatedSupply['quantity'] ?? 0}') ?? 0;

          if (currentStatus == 'Received' &&
              lastPartialReceiveQuantities.isNotEmpty) {
            // This supply was fully 'Received' and we're rejecting the last partial
            // Restore it to 'Partially Received' by reconstructing the previous partial state
            // The previous partial state = current receivedQuantities (before subtracting) - lastPartialReceiveQuantities
            // But since receivedQuantities is now empty after subtracting, we need to reconstruct it

            // Reconstruct receivedQuantities by subtracting lastPartialReceiveQuantities from the expected total
            // If the supply was fully received (2/2) and we subtract the last partial (1), it should go back to (1/2)
            final reconstructedReceivedQuantities = <String, int>{};
            for (final entry in lastPartialReceiveQuantities.entries) {
              final expiryDate = entry.key;
              // The quantity before full receipt = totalQuantity - lastPartialReceiveQuantities
              final previousPartialQty = (totalQuantity - entry.value)
                  .clamp(0, double.infinity)
                  .toInt();
              if (previousPartialQty > 0) {
                reconstructedReceivedQuantities[expiryDate] =
                    previousPartialQty;
              }
            }

            if (reconstructedReceivedQuantities.isNotEmpty) {
              updatedSupply['receivedQuantities'] =
                  reconstructedReceivedQuantities;
              updatedSupply['status'] = 'Partially Received';
              print(
                  'Debug: Restored to Partially Received with quantities: $reconstructedReceivedQuantities');
            } else {
              updatedSupply['status'] = 'Pending';
              print(
                  'Debug: Status set to Pending (could not reconstruct partial state)');
            }
          } else {
            updatedSupply['status'] = 'Pending';
            print('Debug: Status set to Pending (receivedQuantities is empty)');
          }
        }
      } else {
        // Supply doesn't have lastPartialReceiveQuantities
        // Check if ANY supply in the PO has lastPartialReceiveQuantities to determine if we're rejecting 2nd partial
        final hasAnyLastPartialReceive = po.supplies.any((s) {
          final lastPartial = s['lastPartialReceiveQuantities'];
          return lastPartial != null &&
              lastPartial is Map &&
              Map.from(lastPartial).isNotEmpty;
        });

        if (hasAnyLastPartialReceive) {
          // We're rejecting 2nd partial - preserve supplies that are already 'Received' and don't have lastPartialReceiveQuantities
          // (These were received in the 1st partial and restocked to inventory)
          final currentStatus = updatedSupply['status']?.toString() ?? '';
          if (currentStatus == 'Received' && receivedQuantities.isEmpty) {
            // Fully received through 1st partial - preserve status
            updatedSupply['status'] = 'Received';
          } else if (receivedQuantities.isNotEmpty) {
            // Has receivedQuantities but no lastPartialReceiveQuantities - recalculate
            final totalQuantity =
                int.tryParse('${updatedSupply['quantity'] ?? 0}') ?? 0;
            final totalReceived =
                receivedQuantities.values.fold(0, (sum, qty) => sum + qty);

            if (totalReceived >= totalQuantity) {
              updatedSupply['status'] = 'Received';
            } else if (totalReceived > 0) {
              updatedSupply['status'] = 'Partially Received';
            } else {
              updatedSupply['status'] = 'Pending';
            }
          } else {
            // No receivedQuantities and not already received - keep current status
            // Status should already be correct from the original supply
          }
        } else {
          // We're rejecting 1st partial - reset everything to Pending
          updatedSupply['status'] = 'Pending';
          updatedSupply['receivedQuantities'] = null;
        }
      }

      return updatedSupply;
    }).toList();

    // Check if we're rejecting 1st partial (no supplies have lastPartialReceiveQuantities)
    final isRejectingFirstPartial = !po.supplies.any((s) {
      final lastPartial = s['lastPartialReceiveQuantities'];
      return lastPartial != null &&
          lastPartial is Map &&
          Map.from(lastPartial).isNotEmpty;
    });

    // Check if there are any partial receives remaining after subtracting the most recent one
    final hasRemainingPartialReceives = resetSupplies.any((supply) =>
        supply['status'] == 'Partially Received' ||
        supply['status'] == 'Received');

    // If rejecting 1st partial, always go to Open and clear receipt details
    // If rejecting 2nd partial and there are remaining receives, go to Partially Received and keep receipt details
    if (isRejectingFirstPartial) {
      // Rejecting 1st partial - clear receipt details and reset to Open
      for (int i = 0; i < resetSupplies.length; i++) {
        resetSupplies[i] = {
          ...resetSupplies[i],
          'receivedAt': null,
          'receiptDrNo': null,
          'receiptRecipient': null,
          'receiptRemarks': null,
          'receiptImagePath': null,
          'receiptImageUrl': null,
          'receiptDate': null,
          'savedAt': null,
        };
      }
      // Always go to Open when rejecting 1st partial
      final newStatus = 'Open';

      // Calculate received count
      final newReceivedCount = resetSupplies
          .where((supply) => supply['status'] == 'Received')
          .length;

      final updatedPO = PurchaseOrder(
        id: po.id,
        code: po.code,
        name: po.name,
        createdAt: po.createdAt,
        status: newStatus,
        supplies: resetSupplies,
        receivedCount: newReceivedCount,
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

    // We're rejecting 2nd partial
    // If there are remaining partial receives (rejecting 2nd partial), keep receipt details
    // If no remaining partial receives, clear receipt details (shouldn't happen for 2nd partial)
    if (!hasRemainingPartialReceives) {
      // This shouldn't happen for 2nd partial, but clear receipt details just in case
      for (int i = 0; i < resetSupplies.length; i++) {
        resetSupplies[i] = {
          ...resetSupplies[i],
          'receivedAt': null,
          'receiptDrNo': null,
          'receiptRecipient': null,
          'receiptRemarks': null,
          'receiptImagePath': null,
          'receiptImageUrl': null,
          'receiptDate': null,
          'savedAt': null,
        };
      }
    }
    // If hasRemainingPartialReceives is true, keep receipt details (already in resetSupplies)

    // Determine new status for 2nd partial rejection
    String newStatus;
    if (hasRemainingPartialReceives) {
      // If there are still partial receives, go back to Partially Received
      newStatus = 'Partially Received';
    } else {
      // If no partial receives (shouldn't happen for 2nd partial), go back to Open
      newStatus = 'Open';
    }

    // Calculate received count
    final newReceivedCount =
        resetSupplies.where((supply) => supply['status'] == 'Received').length;

    final updatedPO = PurchaseOrder(
      id: po.id,
      code: po.code,
      name: po.name,
      createdAt: po.createdAt,
      status: newStatus,
      supplies: resetSupplies,
      receivedCount: newReceivedCount,
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
  Future<List<Map<String, dynamic>>> _restockInventory(PurchaseOrder po) async {
    try {
      // Get received and partially received supplies
      final receivedSupplies = po.supplies
          .where((supply) =>
              supply['status'] == 'Received' ||
              supply['status'] == 'Partially Received')
          .toList();

      if (receivedSupplies.isEmpty) {
        print('No received supplies to restock');
        return po.supplies;
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

        // Check if this supply was already fully restocked (for "Received" status)
        if (supply['status'] == 'Received' &&
            supply['alreadyFullyRestocked'] == true) {
          print(
              'Supply $supplyName already fully restocked in previous approval, skipping');
          continue;
        }

        // Check if this is a partially received supply
        final Map<String, int>? receivedQuantities =
            supply['receivedQuantities'] != null
                ? Map<String, int>.from(supply['receivedQuantities'])
                : null;

        final Map<String, int> restockedQuantities =
            supply['restockedQuantities'] != null
                ? Map<String, int>.from(supply['restockedQuantities'])
                : <String, int>{};

        // If we have receivedQuantities (partial receive), restock only the difference
        if (receivedQuantities != null && receivedQuantities.isNotEmpty) {
          bool hasSomethingToRestock = false;

          for (final entry in receivedQuantities.entries) {
            final String expiryKey = entry.key;
            final int totalReceived = entry.value;
            final int alreadyRestocked = restockedQuantities[expiryKey] ?? 0;
            final int quantitiesToRestock = totalReceived - alreadyRestocked;

            if (quantitiesToRestock > 0) {
              hasSomethingToRestock = true;
              String? expDate = expiryKey == 'No expiry' || expiryKey.isEmpty
                  ? null
                  : expiryKey;
              await mergeOneBatch(qty: quantitiesToRestock, exp: expDate);

              // Update restockedQuantities to track what we just restocked
              restockedQuantities[expiryKey] = totalReceived;
            }
          }

          // Only update the supply if we actually restocked something
          if (hasSomethingToRestock) {
            supply['restockedQuantities'] = restockedQuantities;
          }
        } else if (expiryBatches != null && expiryBatches.isNotEmpty) {
          // Fully received supply with explicit batches - mark as fully restocked after restocking
          supply['alreadyFullyRestocked'] = true;
          // If we have explicit batches, restock each; otherwise restock single batch
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
          // Fully received supply with single batch - mark as fully restocked
          supply['alreadyFullyRestocked'] = true;
        }
      }

      // Return the updated supplies with restockedQuantities
      return po.supplies;
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

  // Check if PO can be approved (in Approval status)
  bool canApprovePO(PurchaseOrder po) {
    return po.status == 'Approval';
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

  // Process multiple partial receives at once
  Future<PurchaseOrder> processMultiplePartialReceives({
    required PurchaseOrder po,
    required Map<String, Map<String, int>> supplyQuantities,
  }) async {
    try {
      print(
          'Debug: Processing multiple partial receives for ${supplyQuantities.length} supplies');

      // Create a copy of the PO supplies to work with
      final updatedSupplies = List<Map<String, dynamic>>.from(po.supplies);

      // Debug: Print all supplies in PO
      print('Debug: PO has ${updatedSupplies.length} supplies:');
      for (int i = 0; i < updatedSupplies.length; i++) {
        final supply = updatedSupplies[i];
        final supplyId = supply['supplyId']?.toString() ??
            supply['id']?.toString() ??
            supply['name']?.toString() ??
            'unknown';
        final supplyType = supply['type']?.toString() ?? '';
        final supplyName = getSupplyName(supply);
        print(
            '  [$i] supplyId: $supplyId, type: $supplyType, name: $supplyName');
      }

      // Process each supply
      for (final supplyEntry in supplyQuantities.entries) {
        final uniqueKey = supplyEntry.key;
        final expiryQuantities = supplyEntry.value;

        // Parse the unique key to get supplyId and type
        // Format: "supplyId_type" or just "supplyId" if no type
        final parts = uniqueKey.split('_');
        final baseSupplyId = parts.length > 1
            ? parts.sublist(0, parts.length - 1).join('_')
            : uniqueKey;
        final supplyType = parts.length > 1 ? parts.last : '';

        print(
            'Debug: Processing supplyId: $baseSupplyId, type: $supplyType, uniqueKey: $uniqueKey with quantities: $expiryQuantities');

        // Find the supply in the PO
        int supplyIndex = -1;

        // Strategy 1: Match by supplyId/name AND type (if type is provided)
        if (supplyType.isNotEmpty) {
          print(
              'Debug: Trying Strategy 1 - Match by ID and type: baseSupplyId=$baseSupplyId, type=$supplyType');
          supplyIndex = updatedSupplies.indexWhere((supply) {
            final supplyIdFromSupply = supply['supplyId']?.toString() ??
                supply['id']?.toString() ??
                supply['name']?.toString() ??
                '';
            final supplyTypeFromSupply = supply['type']?.toString() ?? '';
            final matches = supplyIdFromSupply == baseSupplyId &&
                supplyTypeFromSupply == supplyType;
            if (matches) {
              print(
                  'Debug: Found match in Strategy 1 at index: ${updatedSupplies.indexOf(supply)}');
            }
            return matches;
          });

          // If not found with ID, try matching by name and type
          if (supplyIndex == -1) {
            print(
                'Debug: Trying Strategy 1b - Match by name and type: baseSupplyId=$baseSupplyId, type=$supplyType');
            supplyIndex = updatedSupplies.indexWhere((supply) {
              final supplyName = getSupplyName(supply);
              final supplyTypeFromSupply = supply['type']?.toString() ?? '';
              final matches = supplyName == baseSupplyId &&
                  supplyTypeFromSupply == supplyType;
              if (matches) {
                print(
                    'Debug: Found match in Strategy 1b at index: ${updatedSupplies.indexOf(supply)}');
              }
              return matches;
            });
          }
        }

        // Strategy 2: If no type or not found, try exact match with supplyId (original behavior)
        if (supplyIndex == -1) {
          supplyIndex = updatedSupplies.indexWhere((supply) {
            final supplyIdFromSupply = supply['supplyId']?.toString() ??
                supply['id']?.toString() ??
                supply['name']?.toString() ??
                '';
            return supplyIdFromSupply == baseSupplyId;
          });
        }

        // Strategy 3: If not found, try matching by name
        if (supplyIndex == -1) {
          supplyIndex = updatedSupplies.indexWhere((supply) {
            final supplyName = getSupplyName(supply);
            return supplyName == baseSupplyId;
          });
        }

        if (supplyIndex == -1) {
          print(
              'Debug: Supply not found: baseSupplyId=$baseSupplyId, type=$supplyType, uniqueKey=$uniqueKey');
          continue;
        }

        final supply = updatedSupplies[supplyIndex];
        print(
            'Debug: Found supply at index $supplyIndex: ${getSupplyName(supply)}');

        // Update the supply's received quantities
        final updatedSupply = Map<String, dynamic>.from(supply);

        // Initialize received quantities if not exists
        if (updatedSupply['receivedQuantities'] == null) {
          updatedSupply['receivedQuantities'] = <String, int>{};
        }

        // Update received quantities for all expiry dates
        final receivedQuantities =
            Map<String, int>.from(updatedSupply['receivedQuantities']);

        // Store the quantities from this partial receive so we can subtract them if rejected
        final lastPartialReceiveQuantities =
            Map<String, int>.from(expiryQuantities);
        updatedSupply['lastPartialReceiveQuantities'] =
            lastPartialReceiveQuantities;

        for (final expiryEntry in expiryQuantities.entries) {
          final expiryDate = expiryEntry.key;
          final receivedQty = expiryEntry.value;

          // Add to existing quantity instead of overwriting
          final existingQty = receivedQuantities[expiryDate] ?? 0;
          receivedQuantities[expiryDate] = existingQty + receivedQty;
          print(
              'Debug: Added received quantity for $expiryDate: $receivedQty (total: ${receivedQuantities[expiryDate]})');
        }
        updatedSupply['receivedQuantities'] = receivedQuantities;

        // Calculate total received quantity across all expiry batches
        final totalQuantity = int.tryParse('${supply['quantity'] ?? 0}') ?? 0;
        final totalReceived =
            receivedQuantities.values.fold(0, (sum, qty) => sum + qty);

        print(
            'Debug: Total quantity: $totalQuantity, Total received: $totalReceived');

        // Update status based on total received vs total quantity
        if (totalReceived >= totalQuantity) {
          updatedSupply['status'] = 'Received';
          print('Debug: Supply marked as Received');
        } else if (totalReceived > 0) {
          updatedSupply['status'] = 'Partially Received';
          print('Debug: Supply marked as Partially Received');
        } else {
          updatedSupply['status'] = 'Pending';
          print('Debug: Supply remains Pending');
        }

        // Update the supply in the list
        updatedSupplies[supplyIndex] = updatedSupply;
        print(
            'Debug: Updated supply $baseSupplyId (type: $supplyType) with status: ${updatedSupply['status']}');
      }

      // Check if any supplies are received (fully or partially)
      final hasAnyReceivedSupplies = updatedSupplies.any((supply) =>
          supply['status'] == 'Received' ||
          supply['status'] == 'Partially Received');

      // Determine new PO status
      // If ANY supplies are received (even partially), move to Approval section
      String newStatus = po.status;
      if (hasAnyReceivedSupplies && updatedSupplies.isNotEmpty) {
        newStatus = 'Approval';
        print('Debug: Some supplies received, updating PO status to Approval');
      }

      // Calculate new received count
      final newReceivedCount = updatedSupplies
          .where((supply) => supply['status'] == 'Received')
          .length;

      // Update the PO in database once with all changes
      final updatedPO = PurchaseOrder(
        id: po.id,
        code: po.code,
        name: po.name,
        supplies: updatedSupplies,
        status: newStatus,
        createdAt: po.createdAt,
        receivedCount: newReceivedCount,
      );

      print('Debug: Saving updated PO to database with all changes...');
      print('Debug: New PO status: $newStatus');
      await _poController.save(updatedPO);
      print('Debug: PO saved successfully with all partial receives');

      // Log activities for all supplies
      for (final supplyEntry in supplyQuantities.entries) {
        final supplyId = supplyEntry.key;
        final expiryQuantities = supplyEntry.value;

        for (final expiryEntry in expiryQuantities.entries) {
          final expiryDate = expiryEntry.key;
          final receivedQty = expiryEntry.value;

          await _logPartialReceiveActivity(
              po.id, supplyId, receivedQty, expiryDate);
        }
      }
      print('Debug: All activities logged successfully');

      return updatedPO;
    } catch (e) {
      throw Exception('Failed to process multiple partial receives: $e');
    }
  }

  // Process partial receive for a specific supply
  Future<void> processPartialReceive({
    required PurchaseOrder po,
    required String supplyId,
    required int receivedQuantity,
    required String expiryDate,
  }) async {
    try {
      // Debug: Print all supplies for troubleshooting
      print('Debug: Looking for supplyId: $supplyId');
      print('Debug: Available supplies in PO:');
      for (int i = 0; i < po.supplies.length; i++) {
        final supply = po.supplies[i];
        final supplyName = getSupplyName(supply);
        final supplyIdFromSupply = supply['id']?.toString() ??
            supply['name']?.toString() ??
            'supply_$i';
        print('  [$i] Name: $supplyName, ID: $supplyIdFromSupply');
      }

      // Find the supply in the PO - try multiple matching strategies
      int supplyIndex = -1;

      // Strategy 1: Exact match with ID or name
      print('Debug: Strategy 1 - Trying exact match for supplyId: $supplyId');
      supplyIndex = po.supplies.indexWhere((supply) {
        final supplyIdFromSupply = supply['supplyId']?.toString() ??
            supply['id']?.toString() ??
            supply['name']?.toString() ??
            '';
        final matches = supplyIdFromSupply == supplyId;
        print(
            'Debug: Comparing "$supplyIdFromSupply" == "$supplyId" -> $matches');
        return matches;
      });
      print('Debug: Strategy 1 result: supplyIndex = $supplyIndex');

      // Strategy 2: If not found, try matching by name only
      if (supplyIndex == -1) {
        print('Debug: Strategy 2 - Trying name match for supplyId: $supplyId');
        supplyIndex = po.supplies.indexWhere((supply) {
          final supplyName = getSupplyName(supply);
          final matches = supplyName == supplyId;
          print(
              'Debug: Comparing supplyName "$supplyName" == "$supplyId" -> $matches');
          return matches;
        });
        print('Debug: Strategy 2 result: supplyIndex = $supplyIndex');
      }

      // Strategy 3: If still not found, try index-based matching
      if (supplyIndex == -1) {
        print('Debug: Strategy 3 - Trying index match for supplyId: $supplyId');
        final indexMatch = RegExp(r'supply_(\d+)').firstMatch(supplyId);
        if (indexMatch != null) {
          final index = int.tryParse(indexMatch.group(1) ?? '');
          print('Debug: Extracted index: $index');
          if (index != null && index < po.supplies.length) {
            supplyIndex = index;
            print('Debug: Strategy 3 result: supplyIndex = $supplyIndex');
          }
        }
        print('Debug: Strategy 3 final result: supplyIndex = $supplyIndex');
      }

      if (supplyIndex == -1) {
        print('Debug: Supply not found with any strategy');
        throw Exception('Supply not found: $supplyId');
      }

      final supply = po.supplies[supplyIndex];
      print(
          'Debug: Found supply at index $supplyIndex: ${getSupplyName(supply)}');

      // Update the supply's received quantities
      final updatedSupply = Map<String, dynamic>.from(supply);

      // Initialize received quantities if not exists
      if (updatedSupply['receivedQuantities'] == null) {
        updatedSupply['receivedQuantities'] = <String, int>{};
      }

      // Update received quantity for this expiry batch
      final receivedQuantities =
          Map<String, int>.from(updatedSupply['receivedQuantities']);
      receivedQuantities[expiryDate] = receivedQuantity;
      updatedSupply['receivedQuantities'] = receivedQuantities;

      // Calculate total received quantity across all expiry batches
      final totalQuantity = int.tryParse('${supply['quantity'] ?? 0}') ?? 0;
      final totalReceived =
          receivedQuantities.values.fold(0, (sum, qty) => sum + qty);

      print(
          'Debug: Total quantity: $totalQuantity, Total received: $totalReceived');

      // Update status based on total received vs total quantity
      if (totalReceived >= totalQuantity) {
        updatedSupply['status'] = 'Received';
        print('Debug: Supply marked as Received');
      } else if (totalReceived > 0) {
        updatedSupply['status'] = 'Partially Received';
        print('Debug: Supply marked as Partially Received');
      } else {
        updatedSupply['status'] = 'Pending';
        print('Debug: Supply remains Pending');
      }

      // Update the supply in the PO
      final updatedSupplies = List<Map<String, dynamic>>.from(po.supplies);
      updatedSupplies[supplyIndex] = updatedSupply;

      // Update the PO in database
      final updatedPO = PurchaseOrder(
        id: po.id,
        code: po.code,
        name: po.name,
        supplies: updatedSupplies,
        status: po.status,
        createdAt: po.createdAt,
        receivedCount: po.receivedCount,
      );

      print('Debug: Saving updated PO to database...');
      await _poController.save(updatedPO);
      print('Debug: PO saved successfully');

      // Log the activity
      await _logPartialReceiveActivity(
          po.id, supplyId, receivedQuantity, expiryDate);
      print('Debug: Activity logged successfully');
    } catch (e) {
      throw Exception('Failed to process partial receive: $e');
    }
  }

  // Log partial receive activity
  Future<void> _logPartialReceiveActivity(
    String poId,
    String supplyId,
    int quantity,
    String expiryDate,
  ) async {
    try {
      await _supabase.from('activity_logs').insert({
        'po_id': poId,
        'action': 'partial_receive',
        'details': 'Received $quantity units for expiry $expiryDate',
        'supply_id': supplyId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Log error but don't fail the main operation
      print('Failed to log activity: $e');
    }
  }
}
