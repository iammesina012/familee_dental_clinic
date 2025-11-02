import 'package:supabase_flutter/supabase_flutter.dart';

class ApprovalController {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _table = 'stock_deduction_approvals';

  // Get all approvals as a stream (only pending ones)
  // NOTE: We use .eq('status', 'pending') at database level to optimize initial query,
  // but we also filter in Dart as a safety net because Supabase real-time streams
  // can emit updates for rows that no longer match the filter (e.g., when status changes).
  Stream<List<Map<String, dynamic>>> getApprovalsStream() {
    return _supabase
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('status', 'pending') // Database-level filter: only pending
        .order('created_at', ascending: false)
        .map((data) {
          // Filter for pending status INSIDE Dart (safety net for real-time updates)
          // This ensures that when a row's status changes to 'rejected' or 'approved',
          // Supabase sends a real-time update and this filter immediately excludes it
          return data.where((row) {
            final rawStatus = row['status'] as String?;
            // Explicitly check and exclude rejected/approved FIRST
            if (rawStatus == 'rejected' || rawStatus == 'approved') {
              return false; // Exclude immediately - don't process these
            }
            // Only include pending or null status
            return rawStatus == 'pending' || rawStatus == null;
          }).map((row) {
            // Convert snake_case to camelCase for application use
            return {
              'id': row['id'],
              'presetName': row['preset_name'] ?? row['presetName'],
              'name': row['preset_name'] ?? row['name'], // For compatibility
              'supplies': row['supplies'],
              'patientName': row['patient_name'] ?? row['patientName'],
              'age': row['age'],
              'gender': row['gender'],
              'sex': row['gender'], // Map gender to sex for display
              'conditions': row['conditions'],
              'purpose': row['purpose'],
              'remarks': row['remarks'],
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
            approvalData[
                'purpose'] ?? // Use purpose if preset_name not provided
            'Unknown Preset',
        'supplies': approvalData['supplies'] ?? [],
        'patient_name':
            approvalData['patientName'] ?? approvalData['patient_name'] ?? '',
        'age': approvalData['age'] ?? '',
        'gender': approvalData['sex'] ??
            approvalData['gender'] ??
            '', // Store sex in gender column
        'conditions': approvalData['conditions'] ?? '',
        'purpose': approvalData['purpose'] ?? '',
        'remarks': approvalData['remarks'] ?? '',
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
        'sex': response['sex'], // Include sex field
        'conditions': response['conditions'],
        'purpose': response['purpose'],
        'remarks': response['remarks'],
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
