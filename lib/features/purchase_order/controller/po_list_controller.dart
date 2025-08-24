import '../data/purchase_order.dart';
import 'po_firebase_controller.dart';
import 'po_calculations.dart';

class POListController {
  final POFirebaseController _poController = POFirebaseController();

  // Load all POs from Firebase stream
  Stream<List<PurchaseOrder>> getAllPOsStream() {
    return _poController.getAllPOsStream();
  }

  // Load closed POs from Firebase stream
  Stream<List<PurchaseOrder>> getClosedPOsStream() {
    return _poController.getClosedPOsStream();
  }

  // Load approval POs from Firebase stream
  Stream<List<PurchaseOrder>> getApprovalPOsStream() {
    return _poController.getApprovalPOsStream();
  }

  // Load open POs from Firebase stream
  Stream<List<PurchaseOrder>> getOpenPOsStream() {
    return _poController.getOpenPOsStream();
  }

  // Get all POs from local storage (backup)
  Future<List<PurchaseOrder>> getAllPOs() async {
    return await _poController.getAll();
  }

  // Get current sequence number
  Future<int> getCurrentSequence() async {
    return await _poController.getCurrentSequence();
  }

  // Clear all POs (local and Firebase)
  Future<void> clearAllPOs() async {
    await _poController.clearAllPOs();
  }

  // Filter POs by search query and active tab
  List<PurchaseOrder> filterPOs(
    List<PurchaseOrder> allPOs,
    List<PurchaseOrder> closedPOs,
    String searchQuery,
    int activeTabIndex,
  ) {
    final query = searchQuery.trim().toLowerCase();
    List<PurchaseOrder> filtered;

    // Use Firebase data for all tabs
    if (activeTabIndex == 2) {
      // Closed tab - use Firebase closed POs
      filtered = closedPOs;
    } else {
      // Open and Approval tabs - use Firebase data filtered by status
      final tabStatus = activeTabIndex == 0 ? 'Open' : 'Approval';
      filtered = allPOs.where((po) => po.status == tabStatus).toList();
    }

    // Filter by search
    if (query.isNotEmpty) {
      filtered = filtered
          .where((po) =>
              po.code.toLowerCase().contains(query) ||
              po.name.toLowerCase().contains(query))
          .toList();
    }
    return filtered;
  }

  // Calculate summary counts for each status
  Map<String, int> calculateSummaryCounts(
    List<PurchaseOrder> allPOs,
    List<PurchaseOrder> closedPOs,
  ) {
    int openCount = allPOs.where((po) => po.status == 'Open').length;
    int approvalCount = allPOs.where((po) => po.status == 'Approval').length;
    int closedCount = closedPOs.length;

    return {
      'Open': openCount,
      'Approval': approvalCount,
      'Closed': closedCount,
    };
  }

  // Use centralized calculation methods
  String formatDate(DateTime date) {
    return POBusinessService.formatDate(date);
  }

  // Get status color for PO
  String getStatusColor(String status) {
    // Create a temporary PO object to use the centralized method
    final tempPO = PurchaseOrder(
      id: '',
      code: '',
      name: '',
      status: status,
      supplies: [],
      receivedCount: 0,
      createdAt: DateTime.now(),
    );
    return POBusinessService.getStatusColor(tempPO);
  }

  // Calculate progress percentage for PO
  double calculateProgressPercentage(PurchaseOrder po) {
    return POBusinessService.calculateProgressPercentage(po);
  }

  // Delete a PO from Firebase
  Future<void> deletePO(String poId) async {
    await _poController.deletePOFromFirebase(poId);
  }
}
