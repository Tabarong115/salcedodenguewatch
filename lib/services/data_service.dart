import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';  // Temporarily disabled
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DataService {
  final SupabaseClient _supabase = Supabase.instance.client;
  Database? _localDatabase;
  final bool _isOnline = true; // Default to online for now

  bool get isOnline => _isOnline;

  DataService() {
    // _initializeConnectivity();  // Temporarily disabled
    _initializeLocalDatabase();
  }

  // Temporarily disabled connectivity check
  /*
  Future<void> _initializeConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _isOnline = connectivityResult != ConnectivityResult.none;
    
    Connectivity().onConnectivityChanged.listen((result) {
      _isOnline = result != ConnectivityResult.none;
    });
  }
  */

  Future<void> _initializeLocalDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'dengue_watch.db');

    _localDatabase = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE draft_cases (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE draft_alerts (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // Public data methods (no authentication required)
  Future<Map<String, dynamic>> getPublicDashboardData() async {
    try {
      final response = await _supabase
          .rpc('get_public_dashboard_summary')
          .timeout(const Duration(seconds: 15));
      final rows = List<Map<String, dynamic>>.from(response);
      if (rows.isEmpty) throw StateError('Public dashboard summary is empty.');
      final summary = rows.first;

      return {
        'totalCases': (summary['total_cases'] as num?)?.toInt() ?? 0,
        'affectedBarangays':
            (summary['affected_barangays'] as num?)?.toInt() ?? 0,
        'registeredBarangays':
            (summary['registered_barangays'] as num?)?.toInt() ?? 0,
        'thisWeekCases': (summary['this_week_cases'] as num?)?.toInt() ?? 0,
        'thisWeekAffectedBarangays':
            (summary['this_week_affected_barangays'] as num?)?.toInt() ?? 0,
        'hasThisWeekData': summary['has_this_week_data'] == true,
        'hasReportableData': summary['has_reportable_data'] == true,
        'dataError': false,
        'weekStarting': summary['week_starting']?.toString(),
        'lastUpdated': DateTime.now().toIso8601String(),
        'data': <Map<String, dynamic>>[],
      };
    } catch (e) {
      debugPrint('Error fetching public data: $e');
      return {
        'totalCases': 0,
        'affectedBarangays': 0,
        'registeredBarangays': 0,
        'thisWeekCases': 0,
        'thisWeekAffectedBarangays': 0,
        'hasThisWeekData': false,
        'hasReportableData': false,
        'dataError': true,
        'lastUpdated': DateTime.now().toIso8601String(),
        'data': [],
      };
    }
  }

  /// Public, privacy-filtered case totals used by the trend timeline.
  /// This intentionally avoids the separate barangay-directory query used by
  /// the dashboard so the chart can load independently of that metadata view.
  Future<List<Map<String, dynamic>>> getPublicWeeklyCaseSummary() async {
    const pageSize = 1000;
    final weeklyData = <Map<String, dynamic>>[];
    final pageSignatures = <String>{};
    var offset = 0;
    while (true) {
      final page = await _supabase
          .from('public_cases_summary')
          .select()
          .order('week_starting', ascending: true)
          .order('barangay', ascending: true)
          .range(offset, offset + pageSize - 1)
          .timeout(const Duration(seconds: 15));
      final rows = List<Map<String, dynamic>>.from(page);
      weeklyData.addAll(rows);
      if (rows.length < pageSize) break;
      final first = rows.first;
      final last = rows.last;
      final signature =
          '${first['week_starting']}|${first['barangay']}|${last['week_starting']}|${last['barangay']}';
      if (!pageSignatures.add(signature)) {
        throw StateError('Public case summary pagination repeated a page.');
      }
      offset += pageSize;
    }
    return weeklyData;
  }

  /// Barangay names are public metadata and must not depend on whether any
  /// cases happen to pass the map's privacy suppression threshold.
  Future<List<String>> getPublicBarangayNames() async {
    final response = await _supabase
        .from('public_barangay_names')
        .select('name')
        .order('name')
        .timeout(const Duration(seconds: 15));
    return response.map((row) => row['name'] as String).toList();
  }

  /// Authenticated barangay names use the table's existing RLS policies.
  Future<List<String>> getScopedBarangayNames({
    String? assignedBarangayId,
  }) async {
    final response = await _supabase
        .from('barangays')
        .select('id, name')
        .order('name');
    return response
        .where(
          (row) => assignedBarangayId == null ||
              row['id'] == assignedBarangayId,
        )
        .map((row) => row['name'] as String)
        .toList();
  }

  /// Returns one coarse, barangay-level map marker for groups of at least
  /// three submitted cases. Individual case locations are never returned.
  Future<List<Map<String, dynamic>>> getPublicCaseMapData({
    DateTime? startDate,
    DateTime? endDate,
    String? barangay,
  }) async {
    try {
      final response = await _supabase.rpc(
        'get_public_case_map',
        params: {
          'p_start_date': startDate?.toIso8601String().substring(0, 10),
          'p_end_date': endDate?.toIso8601String().substring(0, 10),
          'p_barangay': barangay,
        },
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching public map clusters: $e');
      rethrow;
    }
  }

  /// Precise case dots for authenticated staff. The cases table's existing
  /// row-level security limits results to the signed-in user's assignments.
  Future<List<Map<String, dynamic>>> getScopedCaseMapData({
    DateTime? startDate,
    DateTime? endDate,
    String? barangay,
  }) async {
    final results = <Map<String, dynamic>>[];
    const pageSize = 1000;
    var offset = 0;
    while (true) {
      final response = await _supabase
          .from('cases')
          .select(
            'id, classification, status, outcome, report_date, barangay, latitude, longitude, is_submitted, is_duplicate_of',
          )
          .eq('is_submitted', true)
          .order('report_date', ascending: true)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);
      final page = List<Map<String, dynamic>>.from(response);
      for (final row in page) {
        if (row['is_duplicate_of'] != null ||
            row['latitude'] == null ||
            row['longitude'] == null ||
            row['report_date'] == null ||
            (barangay != null && row['barangay'] != barangay)) {
          continue;
        }
        final reportDate = DateTime.tryParse(row['report_date'] as String);
        if (reportDate == null ||
            (startDate != null && reportDate.isBefore(startDate)) ||
            (endDate != null && !reportDate.isBefore(endDate))) {
          continue;
        }
        final outcome = row['outcome'] as String?;
        final classification = row['classification'] as String?;
        final status = row['status'] as String?;
        final category = switch (outcome) {
          'death' => 'death',
          'recovered' => 'recovered',
          'ongoing' => 'active',
          _ when classification == 'confirmed' => 'active',
          _ when status == 'closed' => 'resolved',
          _ => 'probable',
        };
        results.add({
          'lat': (row['latitude'] as num).toDouble(),
          'lng': (row['longitude'] as num).toDouble(),
          'category': category,
          'barangay': row['barangay'] as String,
          'count': 1,
          'reportDate': reportDate,
        });
      }
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> getSettings() async {
    try {
      final selection = _supabase.auth.currentSession == null
          ? 'key, value'
          : '*';
      final response = await _supabase.from('settings').select(selection);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching settings: $e');
      return [];
    }
  }

  // Case management methods
  Future<bool> submitCase(Map<String, dynamic> caseData) async {
    try {
      if (_isOnline) {
        await _supabase.from('cases').insert(caseData);
        return true;
      } else {
        // Save as draft locally
        await _saveDraftCase(caseData);
        return true;
      }
    } catch (e) {
      debugPrint('Error submitting case: $e');
      if (!_isOnline) {
        await _saveDraftCase(caseData);
        return true;
      }
      return false;
    }
  }

  Future<bool> updateCase(String caseId, Map<String, dynamic> updates) async {
    try {
      if (_isOnline) {
        final response = await _supabase
            .from('cases')
            .update(updates)
            .eq('id', caseId)
            .select('id');
        return response.isNotEmpty;
      } else {
        // For offline updates, we'd need more complex logic
        return false;
      }
    } catch (e) {
      debugPrint('Error updating case: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getCases({
    String? barangay,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? assignedWorkerId,
    String? barangayId,
  }) async {
    try {
      var query = _supabase.from('cases').select();

      if (barangay != null) {
        query = query.eq('barangay', barangay);
      }

      if (barangayId != null) {
        query = query.eq('barangay_id', barangayId);
      }

      if (status != null) {
        query = query.eq('status', status);
      }

      if (startDate != null) {
        query = query.gte('report_date', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('report_date', endDate.toIso8601String());
      }

      if (assignedWorkerId != null) {
        query = query.eq('assigned_worker_id', assignedWorkerId);
      }

      const pageSize = 1000;
      final cases = <Map<String, dynamic>>[];
      var offset = 0;
      while (true) {
        final response = await query
            .order('report_date', ascending: false)
            .order('id', ascending: true)
            .range(offset, offset + pageSize - 1);
        final page = List<Map<String, dynamic>>.from(response);
        cases.addAll(page);
        if (page.length < pageSize) break;
        offset += pageSize;
      }
      return cases;
    } catch (e) {
      debugPrint('Error fetching cases: $e');
      return [];
    }
  }

  // Health alert methods
  Future<bool> submitHealthAlert(Map<String, dynamic> alertData) async {
    try {
      if (_isOnline) {
        await _supabase.from('health_alerts').insert(alertData);
        return true;
      } else {
        await _saveDraftAlert(alertData);
        return true;
      }
    } catch (e) {
      debugPrint('Error submitting health alert: $e');
      if (!_isOnline) {
        await _saveDraftAlert(alertData);
        return true;
      }
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getHealthAlerts({
    String? barangay,
    String? barangayId,
    String? status,
  }) async {
    try {
      var query = _supabase.from('health_alerts').select();

      if (barangay != null) {
        query = query.eq('barangay', barangay);
      }

      if (barangayId != null) {
        query = query.eq('barangay_id', barangayId);
      }

      if (status != null) {
        query = query.eq('followup_status', status);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching health alerts: $e');
      return [];
    }
  }

  /// Alerts remain on dashboards until a barangay BHW/BSI marks them confirmed.
  /// RLS on health_alerts scopes the returned reporter information to staff.
  Future<List<Map<String, dynamic>>> getUnverifiedHealthAlerts({
    String? barangay,
    String? barangayId,
  }) async {
    final alerts = await getHealthAlerts(
      barangay: barangay,
      barangayId: barangayId,
    );
    final unverified = alerts
        .where((alert) => alert['followup_status'] != 'confirmed')
        .toList();
    unverified.sort((a, b) {
      final left =
          DateTime.tryParse(a['submitted_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final right =
          DateTime.tryParse(b['submitted_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return unverified;
  }

  Future<bool> updateHealthAlert(
    String alertId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _supabase.from('health_alerts').update(updates).eq('id', alertId);
      return true;
    } catch (e) {
      debugPrint('Error updating health alert: $e');
      return false;
    }
  }

  RealtimeChannel listenForHealthAlertChanges(
    void Function(Map<String, dynamic> alert, PostgresChangeEvent event)
    onChange,
  ) {
    return _supabase
        .channel(
          'health-alert-inserts-${DateTime.now().microsecondsSinceEpoch}',
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'health_alerts',
          callback: (payload) => onChange(payload.newRecord, payload.eventType),
        )
        .subscribe();
  }

  Future<void> stopHealthAlertListener(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }

  // Response activity methods
  Future<bool> logResponseActivity(Map<String, dynamic> activityData) async {
    try {
      await _supabase.from('response_activities').insert(activityData);
      return true;
    } catch (e) {
      debugPrint('Error logging response activity: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getResponseActivities({
    String? barangay,
    String? barangayId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase.from('response_activities').select();

      if (barangay != null) {
        query = query.eq('barangay', barangay);
      }

      if (barangayId != null) {
        query = query.eq('barangay_id', barangayId);
      }

      if (startDate != null) {
        query = query.gte('activity_date', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('activity_date', endDate.toIso8601String());
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching response activities: $e');
      return [];
    }
  }

  // Draft management (offline support)
  Future<void> _saveDraftCase(Map<String, dynamic> caseData) async {
    if (_localDatabase == null) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _localDatabase!.insert('draft_cases', {
      'id': id,
      'data': caseData.toString(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _saveDraftAlert(Map<String, dynamic> alertData) async {
    if (_localDatabase == null) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _localDatabase!.insert('draft_alerts', {
      'id': id,
      'data': alertData.toString(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getDraftCases() async {
    if (_localDatabase == null) return [];

    final drafts = await _localDatabase!.query('draft_cases');
    return drafts.map((draft) {
      return {
        'id': draft['id'] as String,
        'data': draft['data'] as String,
        'created_at': draft['created_at'] as int,
      };
    }).toList();
  }

  Future<void> syncDrafts() async {
    if (!_isOnline) return;

    final draftCases = await getDraftCases();
    for (final draft in draftCases) {
      try {
        // Parse and submit the draft
        // This is simplified - in production, you'd want proper JSON parsing
        await _supabase.from('cases').insert({'data': draft['data']});
        await _localDatabase!.delete(
          'draft_cases',
          where: 'id = ?',
          whereArgs: [draft['id']],
        );
      } catch (e) {
        debugPrint('Error syncing draft: $e');
      }
    }
  }

  Future<bool> updateSetting(String key, String value) async {
    try {
      await _supabase.from('settings').update({'value': value}).eq('key', key);
      return true;
    } catch (e) {
      debugPrint('Error updating setting: $e');
      return false;
    }
  }

  // ============================================
  // STAFF DASHBOARD METHODS
  // ============================================

  /// Get overdue follow-ups: cases that haven't been followed up within expected timeframe
  /// Cases are considered overdue if they were reported more than 3 days ago and still pending
  Future<List<Map<String, dynamic>>> getOverdueFollowUps({
    String? assignedWorkerId,
    String? barangay,
    String? barangayId,
  }) async {
    try {
      final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));

      var query = _supabase
          .from('cases')
          .select()
          .eq('status', 'pending')
          .lt('report_date', threeDaysAgo.toIso8601String());

      if (assignedWorkerId != null) {
        query = query.eq('assigned_worker_id', assignedWorkerId);
      }

      if (barangay != null) {
        query = query.eq('barangay', barangay);
      }

      if (barangayId != null) {
        query = query.eq('barangay_id', barangayId);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching overdue follow-ups: $e');
      return [];
    }
  }

  /// Get pending response activities that need completion
  Future<List<Map<String, dynamic>>> getPendingActivities({
    String? assignedWorkerId,
    String? barangay,
    String? barangayId,
  }) async {
    try {
      var query = _supabase.from('response_activities').select();

      if (assignedWorkerId != null) {
        query = query.eq('created_by', assignedWorkerId);
      }

      if (barangay != null) {
        query = query.eq('barangay', barangay);
      }

      if (barangayId != null) {
        query = query.eq('barangay_id', barangayId);
      }

      final response = await query.order('activity_date', ascending: true);
      // Filter for recent activities (last 7 days) that might need follow-up
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentActivities = response.where((activity) {
        try {
          final activityDate = DateTime.parse(
            activity['activity_date'] as String,
          );
          return activityDate.isAfter(sevenDaysAgo);
        } catch (e) {
          return false;
        }
      }).toList();

      return List<Map<String, dynamic>>.from(recentActivities);
    } catch (e) {
      debugPrint('Error fetching pending activities: $e');
      return [];
    }
  }

  /// Get recent activity feed combining cases and health alerts
  Future<List<Map<String, dynamic>>> getRecentActivity({
    String? assignedWorkerId,
    String? barangay,
    String? barangayId,
    int limit = 10,
  }) async {
    try {
      // Get recent cases
      var casesQuery = _supabase
          .from('cases')
          .select(
            'id, classification, report_date, barangay, status, created_at, assigned_worker_id',
          );

      if (barangay != null) {
        casesQuery = casesQuery.eq('barangay', barangay);
      }

      if (barangayId != null) {
        casesQuery = casesQuery.eq('barangay_id', barangayId);
      }

      final cases = await casesQuery
          .order('created_at', ascending: false)
          .limit(limit);

      // Filter by assigned worker if provided (client-side filtering for simplicity)
      var filteredCases = cases;
      if (assignedWorkerId != null) {
        filteredCases = cases
            .where((c) => c['assigned_worker_id'] == assignedWorkerId)
            .toList();
      }

      // Get recent health alerts
      var alertsQuery = _supabase
          .from('health_alerts')
          .select('id, barangay, followup_status, submitted_at, urgency_flag');

      if (barangay != null) {
        alertsQuery = alertsQuery.eq('barangay', barangay);
      }

      final alerts = await alertsQuery
          .order('submitted_at', ascending: false)
          .limit(limit);

      // Combine and format activities
      final activities = <Map<String, dynamic>>[];

      for (final caseData in filteredCases) {
        activities.add({
          'type': 'case',
          'id': caseData['id'],
          'classification': caseData['classification'],
          'barangay': caseData['barangay'],
          'status': caseData['status'],
          'date': caseData['report_date'] ?? caseData['created_at'],
          'created_at': caseData['created_at'],
        });
      }

      for (final alertData in alerts) {
        activities.add({
          'type': 'alert',
          'id': alertData['id'],
          'barangay': alertData['barangay'],
          'status': alertData['followup_status'],
          'urgency': alertData['urgency_flag'],
          'date': alertData['submitted_at'],
          'created_at': alertData['submitted_at'],
        });
      }

      // Sort by date descending
      activities.sort((a, b) {
        final dateA = DateTime.parse(a['created_at'] as String);
        final dateB = DateTime.parse(b['created_at'] as String);
        return dateB.compareTo(dateA);
      });

      return activities.take(limit).toList();
    } catch (e) {
      debugPrint('Error fetching recent activity: $e');
      return [];
    }
  }

  /// Counts submitted, non-duplicate cases visible under the current user's
  /// RLS scope. Worker assignment is intentionally not used for these totals:
  /// it assigns follow-up responsibility, while RLS defines the case register
  /// a staff member may see.
  Future<Map<String, int>> getStaffCaseSummaryCounts({
    String? barangay,
    String? barangayId,
  }) async {
    const pageSize = 1000;
    var offset = 0;
    var newReports = 0;
    var activeCases = 0;
    var totalCases = 0;

    while (true) {
      var query = _supabase
          .from('cases')
          .select('id, status, classification, outcome, is_duplicate_of')
          .eq('is_submitted', true);
      if (barangay != null) query = query.eq('barangay', barangay);
      if (barangayId != null) query = query.eq('barangay_id', barangayId);

      final response = await query
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);
      final page = List<Map<String, dynamic>>.from(response);
      for (final row in page) {
        if (row['is_duplicate_of'] != null) continue;
        totalCases++;
        if (row['status'] == 'pending') newReports++;
        if (row['outcome'] == 'ongoing') activeCases++;
      }
      if (page.length < pageSize) break;
      offset += pageSize;
    }

    return {
      'newReports': newReports,
      'activeCases': activeCases,
      'totalCases': totalCases,
    };
  }

  /// Get comprehensive dashboard metrics for staff
  Future<Map<String, dynamic>> getStaffDashboardMetrics({
    String? assignedWorkerId,
    String? barangay,
    String? barangayId,
  }) async {
    try {
      // These dashboard sections are independent; fetch them concurrently to
      // avoid adding each Supabase round trip to the screen's loading time.
      final results = await Future.wait([
        getStaffCaseSummaryCounts(barangay: barangay, barangayId: barangayId),
        getUnverifiedHealthAlerts(barangay: barangay, barangayId: barangayId),
        getOverdueFollowUps(
          assignedWorkerId: assignedWorkerId,
          barangay: barangay,
          barangayId: barangayId,
        ),
        getPendingActivities(
          assignedWorkerId: assignedWorkerId,
          barangay: barangay,
          barangayId: barangayId,
        ),
        getRecentActivity(
          assignedWorkerId: assignedWorkerId,
          barangay: barangay,
          barangayId: barangayId,
          limit: 5,
        ),
        getDraftCases(),
      ]);
      final caseCounts = results[0] as Map<String, int>;
      final unverifiedAlerts = results[1] as List<Map<String, dynamic>>;
      final overdueFollowUps = results[2] as List<Map<String, dynamic>>;
      final pendingActivities = results[3] as List<Map<String, dynamic>>;
      final recentActivity = results[4] as List<Map<String, dynamic>>;
      final drafts = results[5] as List<Map<String, dynamic>>;

      return {
        'newReports': caseCounts['newReports']!,
        'activeCases': caseCounts['activeCases']!,
        'totalCases': caseCounts['totalCases']!,
        'newAlerts': unverifiedAlerts.length,
        'unverifiedAlerts': unverifiedAlerts,
        'overdueFollowUps': overdueFollowUps.length,
        'pendingActivities': pendingActivities.length,
        'recentActivity': recentActivity,
        'draftCount': drafts.length,
        'isOnline': _isOnline,
      };
    } catch (e) {
      debugPrint('Error fetching dashboard metrics: $e');
      return {
        'newReports': 0,
        'activeCases': 0,
        'totalCases': 0,
        'newAlerts': 0,
        'unverifiedAlerts': <Map<String, dynamic>>[],
        'overdueFollowUps': 0,
        'pendingActivities': 0,
        'recentActivity': [],
        'draftCount': 0,
        'isOnline': _isOnline,
      };
    }
  }
}
