import 'dart:convert';

class PurchaseOrder {
  final String id; // unique id
  final String code; // e.g., #PO1
  final String name; // user-provided name
  final DateTime createdAt;
  final String status; // Open, Approval, Closed
  final List<Map<String, dynamic>> supplies; // each with quantity, etc.
  final int receivedCount; // number of supplies received

  PurchaseOrder({
    required this.id,
    required this.code,
    required this.name,
    required this.createdAt,
    required this.status,
    required this.supplies,
    required this.receivedCount,
  });

  int get totalCount => supplies.length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'status': status,
      'supplies': supplies,
      'received_count': receivedCount,
    };
  }

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) {
    return PurchaseOrder(
      id: map['id'] as String? ?? '',
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      status: map['status'] as String? ?? 'Open',
      supplies: (map['supplies'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      receivedCount: (map['received_count'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory PurchaseOrder.fromJson(String source) =>
      PurchaseOrder.fromMap(json.decode(source) as Map<String, dynamic>);
}
