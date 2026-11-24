import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import 'case_report_screen.dart';
import 'response_activity_screen.dart';
import 'case_list_screen.dart';
import 'health_alerts_list_screen.dart';
import '../public/activity_map_screen.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  final DataService _dataService = DataService();
  bool _isLoading = true;

  int _newReports = 0;
  int _newAlerts = 0;
  int _activeCases = 0;
  int _totalCases = 0;
  int _overdueFollowUps = 0;
  int _pendingActivities = 0;
  int _draftCount = 0;
  bool _isOnline = true;

  List<Map<String, dynamic>> _recentActivity = [];
  List<Map<String, dynamic>> _unverifiedAlerts = [];
  RealtimeChannel? _healthAlertChannel;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _healthAlertChannel = _dataService.listenForHealthAlertChanges((
      alert,
      event,
    ) {
      _loadDashboardData();
      if (event == PostgresChangeEvent.insert &&
          mounted &&
          (ModalRoute.of(context)?.isCurrent ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'New health report from ${alert['barangay'] ?? 'your area'}'.tr(),
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    final channel = _healthAlertChannel;
    if (channel != null) _dataService.stopHealthAlertListener(channel);
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;

      // Get barangay filter based on user's role and assignments
      String? barangayFilter;
      String? barangayIdFilter;
      String? assignedWorkerId;

      if (user?.role == 'admin' || user?.role == 'rhu_staff') {
        // Admin sees all rows; RHU staff use their municipality-wide RLS scope.
        assignedWorkerId = null; // No worker filter
        barangayFilter = null; // No barangay filter
        barangayIdFilter = null;
      } else {
        // For encoders, BHWs, etc., filter by their assigned barangay and worker ID
        barangayFilter = null; // Don't filter by name, let RLS handle it
        barangayIdFilter = user?.barangayId; // Filter by barangay ID for RLS
        assignedWorkerId = user?.id;
      }

      // Fetch comprehensive dashboard metrics with role-based filtering
      final metrics = await _dataService.getStaffDashboardMetrics(
        assignedWorkerId: assignedWorkerId,
        barangay: barangayFilter,
        barangayId: barangayIdFilter,
      );

      if (!mounted) return;
      setState(() {
        _newReports = metrics['newReports'] as int;
        _newAlerts = metrics['newAlerts'] as int;
        _activeCases = metrics['activeCases'] as int;
        _totalCases = metrics['totalCases'] as int;
        _unverifiedAlerts =
            metrics['unverifiedAlerts'] as List<Map<String, dynamic>>;
        _overdueFollowUps = metrics['overdueFollowUps'] as int;
        _pendingActivities = metrics['pendingActivities'] as int;
        _draftCount = metrics['draftCount'] as int;
        _isOnline = metrics['isOnline'] as bool;
        _recentActivity =
            (metrics['recentActivity'] as List<Map<String, dynamic>>);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _newReports = 0;
        _newAlerts = 0;
        _activeCases = 0;
        _totalCases = 0;
        _unverifiedAlerts = [];
        _overdueFollowUps = 0;
        _pendingActivities = 0;
        _draftCount = 0;
        _isOnline = true;
        _recentActivity = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;
    final userName = user?.name ?? 'Staff Member';
    final userRole = user?.role ?? 'encoder';

    return Scaffold(
      appBar: AppBar(
        title: Text('Staff Dashboard'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (_draftCount > 0)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.drafts),
                  onPressed: () => _showDraftsDialog(context),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$_draftCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(userName, userRole),
                    const SizedBox(height: 16),
                    _buildConnectionStatus(),
                    const SizedBox(height: 16),
                    _buildQuickStats(),
                    const SizedBox(height: 16),
                    _buildUnverifiedAlertsCard(),
                    const SizedBox(height: 16),
                    _buildPriorityTasks(),
                    const SizedBox(height: 16),
                    _buildRecentActivity(),
                    const SizedBox(height: 16),
                    _buildActionCards(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeCard(String userName, String userRole) {
    return Card(
      color: Colors.green.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.green.shade700,
              child: Text(
                userName
                    .split(' ')
                    .map((n) => n[0])
                    .take(2)
                    .join()
                    .toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $userName'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getRoleDisplayName(userRole),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return 'Administrator'.tr();
      case 'rhu_staff':
        return 'RHU Staff'.tr();
      case 'encoder':
        return 'Encoder'.tr();
      case 'bhw':
        return 'Barangay Health Worker'.tr();
      case 'bsi':
        return 'Barangay Sanitation Inspector'.tr();
      case 'hospital_staff':
        return 'Hospital Staff'.tr();
      default:
        return role.tr();
    }
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isOnline ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isOnline ? Colors.green.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: _isOnline ? Colors.green.shade700 : Colors.orange.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            _isOnline
                ? 'Online - Data synced'.tr()
                : 'Offline - Drafts saved locally'.tr(),
            style: TextStyle(
              color: _isOnline ? Colors.green.shade700 : Colors.orange.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 4,
      // Leave enough vertical room for wrapped labels and hints on narrow
      // phones and in Filipino, where the same text can take more lines.
      childAspectRatio: 0.82,
      children: [
        _buildStatCard(
          'New Reports'.tr(),
          '$_newReports',
          Icons.description,
          Colors.blue,
          hint: 'Submitted and awaiting review'.tr(),
        ),
        _buildStatCard(
          'Unverified Alerts'.tr(),
          '$_newAlerts',
          Icons.notifications_active,
          Colors.orange,
          hint: 'Awaiting BHW/BSI verification'.tr(),
        ),
        _buildStatCard(
          'Active Cases'.tr(),
          '$_activeCases',
          Icons.healing,
          Colors.teal,
          hint: 'Outcome is ongoing'.tr(),
        ),
        _buildStatCard(
          'Reportable Cases'.tr(),
          '$_totalCases',
          Icons.coronavirus,
          Colors.green.shade700,
          hint: 'Submitted, non-duplicate cases'.tr(),
        ),
      ],
    );
  }

  Widget _buildUnverifiedAlertsCard() {
    final hasAlerts = _unverifiedAlerts.isNotEmpty;
    return Card(
      color: hasAlerts ? Colors.orange.shade50 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasAlerts
                      ? Icons.notification_important
                      : Icons.verified_user,
                  color: hasAlerts ? Colors.deepOrange : Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Awaiting BHW/BSI verification'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: hasAlerts ? Colors.deepOrange : Colors.green,
                  child: Text(
                    '$_newAlerts',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hasAlerts
                  ? 'These alerts stay here until a BHW/BSI confirms them.'.tr()
                  : 'No unverified health alerts.'.tr(),
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
            ),
            if (hasAlerts) ...[
              const SizedBox(height: 8),
              ..._unverifiedAlerts.map((alert) {
                final reporter = alert['reporter_name']?.toString();
                final status = alert['followup_status']?.toString() ?? 'new';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    alert['urgency_flag'] == true
                        ? Icons.warning_amber_rounded
                        : Icons.location_on_outlined,
                    color: alert['urgency_flag'] == true
                        ? Colors.red
                        : Colors.deepOrange,
                  ),
                  title: Text(alert['barangay']?.toString() ?? 'Barangay'),
                  subtitle: Text(
                    [
                      if (reporter != null && reporter.isNotEmpty) reporter,
                      status,
                    ].join(' • '),
                  ),
                  onTap: _navigateToHealthAlerts,
                );
              }),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _navigateToHealthAlerts,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text('Review alerts'.tr()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    required String hint,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              hint,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityTasks() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Priority Tasks'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTaskItem(
              icon: Icons.priority_high,
              title: 'Overdue Follow-ups'.tr(),
              count: _overdueFollowUps,
              color: Colors.red,
              onTap: () => _navigateToOverdueFollowUps(),
            ),
            const SizedBox(height: 12),
            _buildTaskItem(
              icon: Icons.assignment,
              title: 'Pending Activities'.tr(),
              count: _pendingActivities,
              color: Colors.orange,
              onTap: () => _navigateToPendingActivities(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (_recentActivity.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._recentActivity
                .take(3)
                .map((activity) => _buildActivityItem(activity)),
            if (_recentActivity.length > 3)
              TextButton(
                onPressed: () => _navigateToAllActivity(),
                child: Text('View all activity'.tr()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final type = activity['type'] as String;
    final isCase = type == 'case';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCase
                  ? Colors.blue.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCase ? Icons.medical_services : Icons.notifications,
              color: isCase ? Colors.blue : Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCase
                      ? 'New ${activity['classification']} case'.tr()
                      : 'Health alert from ${activity['barangay']}'.tr(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatActivityDate(activity['date'] as String),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  String _formatActivityDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now'.tr();
      }
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildTaskItem({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap:
          onTap ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$title feature coming soon'.tr())),
            );
          },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 16))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildActionCards() {
    return Column(
      children: [
        _buildActionCard(
          icon: Icons.add_circle,
          title: 'New Case Report'.tr(),
          subtitle: 'Add a new dengue case'.tr(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CaseReportScreen()),
            ).then((_) => _loadDashboardData());
          },
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          icon: Icons.assignment_turned_in,
          title: 'Response Activities'.tr(),
          subtitle: 'Log field work and interventions'.tr(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ResponseActivityScreen(),
              ),
            ).then((_) => _loadDashboardData());
          },
          color: Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          icon: Icons.list_alt,
          title: 'View All Cases'.tr(),
          subtitle: 'Browse and manage cases'.tr(),
          onTap: () => _navigateToCaseList(),
          color: Colors.purple,
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          icon: Icons.map_outlined,
          title: 'Case Location Map',
          subtitle: 'View precise locations for cases you can access',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ActivityMapScreen(staffMode: true),
              ),
            );
          },
          color: Colors.teal,
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          icon: Icons.notifications,
          title: 'Health Alerts'.tr(),
          subtitle: 'Review community alerts'.tr(),
          onTap: () => _navigateToHealthAlerts(),
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    final authService = context.read<AuthService>();
    await authService.signOut();
  }

  void _showDraftsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Draft Reports'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.drafts, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '$_draftCount ${'draft report(s) saved locally'.tr()}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _isOnline
                  ? 'Reports will sync when you submit them'.tr()
                  : 'Reports will sync when connection is restored'.tr(),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'.tr()),
          ),
          if (_isOnline)
            ElevatedButton(
              onPressed: () {
                _dataService.syncDrafts();
                Navigator.pop(context);
                _loadDashboardData();
              },
              child: Text('Sync Now'.tr()),
            ),
        ],
      ),
    );
  }

  void _navigateToCaseList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CaseListScreen()),
    ).then((_) => _loadDashboardData());
  }

  void _navigateToHealthAlerts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HealthAlertsListScreen()),
    ).then((_) => _loadDashboardData());
  }

  void _navigateToOverdueFollowUps() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Showing overdue follow-ups in case list'.tr())),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CaseListScreen()),
    ).then((_) => _loadDashboardData());
  }

  void _navigateToPendingActivities() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pending activities screen coming soon'.tr())),
    );
  }

  void _navigateToAllActivity() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Activity feed screen coming soon'.tr())),
    );
  }
}
