import 'package:supabase_flutter/supabase_flutter.dart';

class ApprovalController {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _table = 'stock_deduction_approvals';

  // Get all approvals as a stream
  Stream<List<Map<String, dynamic>>> getApprovalsStream() {
    return _supabase
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          return data.map((row) {
            // Convert snake_case to camelCase for application use
            return {
              'id': row['id'],
              'presetName': row['preset_name'] ?? row['presetName'],
              'name': row['preset_name'] ?? row['name'], // For compatibility
              'supplies': row['supplies'],
              'patientName': row['patient_name'] ?? row['patientName'],
              'age': row['age'],
              'gender': row['gender'],
              'conditions': row['conditions'],
              'status': row['status'] ?? 'pending',
              'created_at': row['created_at'],
            };
          }).toList();
        });
  }

  // Save a new approval to Supabase
  Future<void> saveApproval(Map<String, dynamic> approvalData) async {
    try {
      // Convert camelCase keys to snake_case to match database schema
      final dataToSave = <String, dynamic>{
        'preset_name': approvalData['presetName'] ??
            approvalData['preset_name'] ??
            'Unknown Preset',
        'supplies': approvalData['supplies'] ?? [],
        'patient_name':
            approvalData['patientName'] ?? approvalData['patient_name'] ?? '',
        'age': approvalData['age'] ?? '',
        'gender': approvalData['gender'] ?? '',
        'conditions': approvalData['conditions'] ?? '',
        'created_at':
            approvalData['created_at'] ?? DateTime.now().toIso8601String(),
      };

      await _supabase.from(_table).insert(dataToSave);
    } catch (e) {
      throw Exception('Failed to save approval: $e');
    }
  }

  // Delete an approval
  Future<void> deleteApproval(String approvalId) async {
    try {
      await _supabase.from(_table).delete().eq('id', approvalId);
    } catch (e) {
      throw Exception('Failed to delete approval: $e');
    }
  }

  // Get a specific approval by ID
  Future<Map<String, dynamic>?> getApprovalById(String approvalId) async {
    try {
      final response = await _supabase
          .from(_table)
          .select('*')
          .eq('id', approvalId)
          .single();

      // Convert snake_case to camelCase for application use
      return {
        'id': response['id'],
        'presetName': response['preset_name'] ?? response['presetName'],
        'name':
            response['preset_name'] ?? response['name'], // For compatibility
        'supplies': response['supplies'],
        'patientName': response['patient_name'] ?? response['patientName'],
        'age': response['age'],
        'gender': response['gender'],
        'conditions': response['conditions'],
        'status': response['status'] ?? 'pending',
        'created_at': response['created_at'],
      };
    } catch (e) {
      return null;
    }
  }

  // Update approval status to approved
  Future<void> approveApproval(String approvalId) async {
    try {
      await _supabase
          .from(_table)
          .update({'status': 'approved'}).eq('id', approvalId);
    } catch (e) {
      throw Exception('Failed to approve: $e');
    }
  }

  // Update approval status to rejected
  Future<void> rejectApproval(String approvalId) async {
    try {
      await _supabase
          .from(_table)
          .update({'status': 'rejected'}).eq('id', approvalId);
    } catch (e) {
      throw Exception('Failed to reject: $e');
    }
  }
}
