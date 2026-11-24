import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================
  // RHU MANAGEMENT
  // ============================================

  Future<List<Map<String, dynamic>>> getRHUs() async {
    try {
      final response = await _supabase.from('rhu').select().order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching RHUs: $e');
      return [];
    }
  }

  Future<bool> createRHU({
    required String name,
    required String region,
    required String contactPerson,
    required String contactNumber,
    required String email,
    required String address,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _supabase.from('rhu').insert({
        'name': name,
        'region': region,
        'contact_person': contactPerson,
        'contact_number': contactNumber,
        'email': email,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      });
      return true;
    } catch (e) {
      debugPrint('Error creating RHU: $e');
      return false;
    }
  }

  Future<bool> updateRHU(String rhuId, Map<String, dynamic> updates) async {
    try {
      await _supabase.from('rhu').update(updates).eq('id', rhuId);
      return true;
    } catch (e) {
      debugPrint('Error updating RHU: $e');
      return false;
    }
  }

  Future<bool> deleteRHU(String rhuId) async {
    try {
      await _supabase.from('rhu').delete().eq('id', rhuId);
      return true;
    } catch (e) {
      debugPrint('Error deleting RHU: $e');
      return false;
    }
  }

  // ============================================
  // BARANGAY MANAGEMENT
  // ============================================

  Future<List<Map<String, dynamic>>> getBarangays({String? rhuId}) async {
    try {
      final selection = _supabase.auth.currentSession == null
          ? 'id, name, region'
          : '*';
      var query = _supabase.from('barangays').select(selection);
      if (rhuId != null) {
        query = query.eq('rhu_id', rhuId);
      }
      final response = await query.order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching barangays: $e');
      return [];
    }
  }

  Future<bool> createBarangay({
    required String rhuId,
    required String name,
    required String region,
    int? population,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _supabase.from('barangays').insert({
        'rhu_id': rhuId,
        'name': name,
        'region': region,
        'population': population,
        'latitude': latitude,
        'longitude': longitude,
      });
      return true;
    } catch (e) {
      debugPrint('Error creating barangay: $e');
      return false;
    }
  }

  Future<bool> updateBarangay(
    String barangayId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _supabase.from('barangays').update(updates).eq('id', barangayId);
      return true;
    } catch (e) {
      debugPrint('Error updating barangay: $e');
      return false;
    }
  }

  Future<bool> deleteBarangay(String barangayId) async {
    try {
      await _supabase.from('barangays').delete().eq('id', barangayId);
      return true;
    } catch (e) {
      debugPrint('Error deleting barangay: $e');
      return false;
    }
  }

  // ============================================
  // FACILITY MANAGEMENT
  // ============================================

  Future<List<Map<String, dynamic>>> getFacilities({String? rhuId}) async {
    try {
      var query = _supabase.from('facilities').select();
      if (rhuId != null) {
        query = query.eq('rhu_id', rhuId);
      }
      final response = await query.order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching facilities: $e');
      return [];
    }
  }

  Future<bool> createFacility({
    required String rhuId,
    required String name,
    required String facilityType,
    required String contactPerson,
    required String contactNumber,
    required String email,
    required String address,
    required String barangay,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _supabase.from('facilities').insert({
        'rhu_id': rhuId,
        'name': name,
        'facility_type': facilityType,
        'contact_person': contactPerson,
        'contact_number': contactNumber,
        'email': email,
        'address': address,
        'barangay': barangay,
        'latitude': latitude,
        'longitude': longitude,
      });
      return true;
    } catch (e) {
      debugPrint('Error creating facility: $e');
      return false;
    }
  }

  Future<bool> updateFacility(
    String facilityId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _supabase.from('facilities').update(updates).eq('id', facilityId);
      return true;
    } catch (e) {
      debugPrint('Error updating facility: $e');
      return false;
    }
  }

  Future<bool> deleteFacility(String facilityId) async {
    try {
      await _supabase.from('facilities').delete().eq('id', facilityId);
      return true;
    } catch (e) {
      debugPrint('Error deleting facility: $e');
      return false;
    }
  }

  // ============================================
  // USER MANAGEMENT
  // ============================================

  Future<List<Map<String, dynamic>>> getUsers({
    String? rhuId,
    String? facilityId,
    String? barangayId,
  }) async {
    try {
      var query = _supabase.from('users').select();

      if (rhuId != null) {
        query = query.eq('rhu_id', rhuId);
      }
      if (facilityId != null) {
        query = query.eq('facility_id', facilityId);
      }
      if (barangayId != null) {
        query = query.eq('barangay_id', barangayId);
      }

      final response = await query.order('name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching users: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRoles() async {
    try {
      final response = await _supabase
          .from('roles')
          .select()
          .eq('is_assignable', true)
          .order('display_name');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching roles: $e');
      return [];
    }
  }

  /// Invite a staff user through the privileged server-side function.
  /// Returns null on success or a user-facing error message on failure.
  Future<String?> createUser({
    required String email,
    required String name,
    required String roleId,
    String? rhuId,
    String? facilityId,
    String? barangayId,
  }) async {
    try {
      final roles = await getRoles();
      final role = roles.firstWhere(
        (item) => item['id']?.toString() == roleId,
        orElse: () => <String, dynamic>{},
      );
      if (role.isEmpty || role['is_assignable'] != true) {
        return 'Select a valid assignable role.';
      }
      if (role['requires_rhu'] == true && (rhuId == null || rhuId.isEmpty)) {
        return 'An RHU assignment is required for this role.';
      }
      if (role['requires_facility'] == true &&
          (facilityId == null || facilityId.isEmpty)) {
        return 'A facility assignment is required for this role.';
      }
      if (role['requires_barangay'] == true &&
          (barangayId == null || barangayId.isEmpty)) {
        return 'A barangay assignment is required for this role.';
      }

      final response = await _supabase.functions.invoke(
        'admin-create-user',
        body: {
          'email': email.trim(),
          'name': name.trim(),
          'role': role['id'],
          'rhu_id': role['requires_rhu'] == true ? rhuId : null,
          'facility_id': role['requires_facility'] == true ? facilityId : null,
          'barangay_id': role['requires_barangay'] == true ? barangayId : null,
        },
      );
      if (response.status < 200 || response.status >= 300) {
        final data = response.data;
        if (data is Map && data['error'] is String) {
          return data['error'] as String;
        }
        return 'Invitation could not be created (HTTP ${response.status}).';
      }
      return null;
    } catch (e) {
      debugPrint('Error creating user: $e');
      return e.toString();
    }
  }

  Future<bool> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      debugPrint('Updating user with ID: $userId');
      debugPrint('Updates: $updates');

      final roleId = updates['role'] as String?;
      if (roleId == null || roleId.isEmpty) return false;

      final role = await _supabase
          .from('roles')
          .select(
            'id, is_assignable, requires_rhu, requires_facility, requires_barangay',
          )
          .eq('id', roleId)
          .maybeSingle();
      if (role == null || role['is_assignable'] != true) return false;

      String? scopeId(String key) {
        final value = updates[key];
        return value is String && value.isNotEmpty ? value : null;
      }

      if (role['requires_rhu'] == true && scopeId('rhu_id') == null) {
        return false;
      }
      if (role['requires_facility'] == true && scopeId('facility_id') == null) {
        return false;
      }
      if (role['requires_barangay'] == true && scopeId('barangay_id') == null) {
        return false;
      }

      final processedUpdates = <String, dynamic>{
        ...updates,
        'role': role['id'],
        'rhu_id': role['requires_rhu'] == true ? scopeId('rhu_id') : null,
        'facility_id': role['requires_facility'] == true
            ? scopeId('facility_id')
            : null,
        'barangay_id': role['requires_barangay'] == true
            ? scopeId('barangay_id')
            : null,
        'updated_at': DateTime.now().toIso8601String(),
      };

      debugPrint('Processed updates: $processedUpdates');

      final response = await _supabase
          .from('users')
          .update(processedUpdates)
          .eq('id', userId)
          .select();

      debugPrint('Update response: $response');

      if (response.isEmpty) {
        debugPrint('No user found with ID: $userId');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error updating user: $e');
      debugPrint('Error details: ${e.toString()}');
      return false;
    }
  }

  Future<bool> deactivateUser(String userId) async {
    try {
      await _supabase.from('users').update({'active': false}).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('Error deactivating user: $e');
      return false;
    }
  }

  Future<bool> reactivateUser(String userId) async {
    try {
      await _supabase.from('users').update({'active': true}).eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('Error reactivating user: $e');
      return false;
    }
  }

  // ============================================
  // STATISTICS & REPORTING
  // ============================================

  Future<Map<String, dynamic>> getAdminDashboard() async {
    try {
      // The dashboard only needs user and case totals. Avoid loading every
      // RHU, facility, barangay, user profile, and case row just to count them.
      final results = await Future.wait([
        _supabase.from('users').select('active'),
        _supabase
            .from('cases')
            .select('classification, is_duplicate_of')
            .eq('is_submitted', true),
      ]);
      final users = List<Map<String, dynamic>>.from(results[0] as List);
      final casesResponse = List<Map<String, dynamic>>.from(
        results[1] as List,
      );

      final reportableCases = casesResponse
          .where((c) => c['is_duplicate_of'] == null)
          .toList();
      final totalSubmittedCases = reportableCases.length;
      final confirmedCases = reportableCases
          .where((c) => c['classification'] == 'confirmed')
          .length;

      return {
        'users_count': users.length,
        'pending_approvals': users.where((u) => u['active'] == false).length,
        'total_cases': totalSubmittedCases,
        'confirmed_cases': confirmedCases,
        'pending_cases':
            totalSubmittedCases - confirmedCases, // simplified; can be improved
      };
    } catch (e) {
      debugPrint('Error fetching admin dashboard: $e');
      return {};
    }
  }
}
