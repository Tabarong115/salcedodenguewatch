import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import '../../services/data_service.dart';
import 'admin_settings_screen.dart';
import '../staff/health_alerts_list_screen.dart';
import '../public/activity_map_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminService _adminService = AdminService();
  final DataService _dataService = DataService();
  bool _isLoading = false;
  int _totalCases = 0;
  int _totalAlerts = 0;
  int _activeUsers = 0;
  int _pendingApprovals = 0;
  RealtimeChannel? _healthAlertChannel;
  List<Map<String, dynamic>> _unverifiedAlerts = [];

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _adminService.getAdminDashboard(),
        _dataService.getUnverifiedHealthAlerts(),
      ]);
      final data = results[0] as Map<String, dynamic>;
      final alerts = results[1] as List<Map<String, dynamic>>;
      if (!mounted) return;

      setState(() {
        _totalCases = data['total_cases'] ?? 0;
        _totalAlerts = alerts.length;
        _unverifiedAlerts = alerts;
        _activeUsers = data['users_count'] ?? 0;
        _pendingApprovals = data['pending_approvals'] ?? 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _totalCases = 0;
        _totalAlerts = 0;
        _unverifiedAlerts = [];
        _activeUsers = 0;
        _pendingApprovals = 0;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userName = authService.currentUser?.name ?? 'Administrator';

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
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
      drawer: _buildDrawer(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(userName),
                    const SizedBox(height: 16),
                    _buildOverviewStats(),
                    const SizedBox(height: 16),
                    _buildUnverifiedAlertsCard(),
                    const SizedBox(height: 16),
                    _buildAdminActions(context),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final authService = context.watch<AuthService>();
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.green.shade700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  authService.currentUser?.name ?? 'Admin',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  authService.currentUser?.email ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: Text('dashboard'.tr()),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text('settings'.tr()),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminSettingsScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text('logout'.tr()),
            onTap: () {
              authService.signOut();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(String userName) {
    return Card(
      color: Colors.green.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.green.shade700,
              radius: 30,
              child: Text(
                userName
                    .split(' ')
                    .map((n) => n[0])
                    .take(2)
                    .join()
                    .toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 20),
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
                    'Administrator'.tr(),
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

  Widget _buildOverviewStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Cases'.tr(),
                '$_totalCases',
                Icons.coronavirus,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Awaiting Verification'.tr(),
                '$_totalAlerts',
                Icons.notifications_active,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Active Users'.tr(),
                '$_activeUsers',
                Icons.people,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Pending'.tr(),
                '$_pendingApprovals',
                Icons.pending,
                Colors.purple,
              ),
            ),
          ],
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
                    '$_totalAlerts',
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
                  onTap: _openHealthAlerts,
                );
              }),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _openHealthAlerts,
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

  void _openHealthAlerts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HealthAlertsListScreen()),
    ).then((_) => _loadDashboardData());
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
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
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Administration'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.settings,
          title: 'App Settings'.tr(),
          subtitle: 'Configure users, barangays, RHU, and facilities'.tr(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminSettingsScreen(),
              ),
            );
          },
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          icon: Icons.assessment,
          title: 'Reports & Analytics'.tr(),
          subtitle: 'View detailed analytics and export data'.tr(),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Analytics feature coming in future update'.tr()),
              ),
            );
          },
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
          icon: Icons.history,
          title: 'Audit Log'.tr(),
          subtitle: 'View system activity and changes'.tr(),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Audit log feature coming in future update'.tr()),
              ),
            );
          },
          color: Colors.orange,
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          icon: Icons.dataset,
          title: 'Data Management'.tr(),
          subtitle: 'Import, export, and manage data'.tr(),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Data management feature coming in future update'.tr(),
                ),
              ),
            );
          },
          color: Colors.teal,
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
}
