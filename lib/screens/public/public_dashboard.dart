import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../services/data_service.dart';
import '../auth/login_screen.dart';
import 'activity_map_screen.dart';
import 'health_alert_screen.dart';
import 'prevention_guide_screen.dart';
import 'trend_timeline_screen.dart';

class PublicDashboard extends StatefulWidget {
  const PublicDashboard({super.key});

  @override
  State<PublicDashboard> createState() => _PublicDashboardState();
}

class _PublicDashboardState extends State<PublicDashboard> {
  final DataService _dataService = DataService();
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    final appState = context.read<AppState>();
    appState.setLoading(true);

    try {
      final results = await Future.wait([
        _dataService.getPublicDashboardData(),
        _dataService.getSettings(),
      ]);
      final dashboardData = results[0] as Map<String, dynamic>;
      final settingsList = results[1] as List<Map<String, dynamic>>;
      final settingsMap = <String, dynamic>{
        'rhu_contact_phone': 'RHU contact number not configured',
        'rhu_contact_hours': 'Contact the RHU for current operating hours',
        'emergency_text': 'For severe symptoms, go to the RHU or nearest hospital immediately.',
      };
      for (final setting in settingsList) {
        final key = setting['key'];
        if (key != null) settingsMap[key.toString()] = setting['value'];
      }
      if (!mounted) return;
      setState(() {
        _dashboardData = dashboardData;
        _isLoading = false;
      });
      appState.setDashboardData(dashboardData);
      appState.setSettings(settingsMap);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dashboardData = {
          'dataError': true,
          'hasReportableData': false,
          'hasThisWeekData': false,
          'lastUpdated': DateTime.now().toIso8601String(),
          'data': <Map<String, dynamic>>[],
        };
        _isLoading = false;
      });
      appState.setDashboardData(_dashboardData!);
    } finally {
      appState.setLoading(false);
    }
  }

  int _number(String key) => (_dashboardData?[key] as num?)?.toInt() ?? 0;

  bool get _hasError => _dashboardData?['dataError'] == true;
  bool get _hasReportableData => _dashboardData?['hasReportableData'] == true;
  bool get _hasThisWeekData => _dashboardData?['hasThisWeekData'] == true;

  String get _activityLabel {
    if (_hasError) return 'Data unavailable';
    if (!_hasThisWeekData) return 'No reportable total this week';
    final cases = _number('thisWeekCases');
    if (cases < 5) return 'LOW';
    if (cases < 15) return 'ELEVATED';
    return 'HIGH';
  }

  Color get _activityColor {
    if (_hasError || !_hasThisWeekData) return Colors.blueGrey;
    if (_number('thisWeekCases') < 5) return Colors.green.shade700;
    if (_number('thisWeekCases') < 15) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salcedo Dengue Watch'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh data'.tr(),
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Staff login'.tr(),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            icon: const Icon(Icons.login),
          ),
          IconButton(
            tooltip: 'Change language'.tr(),
            onPressed: () {
              final locale = appState.currentLocale.languageCode == 'en'
                  ? const Locale('fil')
                  : const Locale('en');
              appState.setLanguage(locale.languageCode);
              context.setLocale(locale);
            },
            icon: const Icon(Icons.language),
          ),
          IconButton(
            tooltip: 'About'.tr(),
            onPressed: _showAboutDialog,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildWelcomeHeader(),
                  if (_hasError) ...[
                    const SizedBox(height: 16),
                    _buildErrorCard(),
                  ],
                  const SizedBox(height: 16),
                  _buildActivityCard(),
                  const SizedBox(height: 12),
                  _buildStatistics(),
                  if (!_hasError && !_hasReportableData) ...[
                    const SizedBox(height: 12),
                    _buildSuppressionNote(),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Explore and take action'.tr(),
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildActionGrid(),
                  const SizedBox(height: 20),
                  _buildLastUpdated(),
                ],
              ),
            ),
    );
  }

  Widget _buildWelcomeHeader() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.green.shade800, Colors.green.shade600],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 26,
          backgroundColor: Colors.white24,
          child: Icon(Icons.health_and_safety, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Community dengue update'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Salcedo, Eastern Samar',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildErrorCard() => Card(
    color: Colors.red.shade50,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Public data could not be loaded. Check your connection and try again.'
                  .tr(),
              style: TextStyle(color: Colors.red.shade900),
            ),
          ),
          IconButton(
            tooltip: 'Retry'.tr(),
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    ),
  );

  Widget _buildActivityCard() => Card(
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'This week'.tr(),
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Icon(Icons.calendar_view_week, color: _activityColor),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _hasError || !_hasThisWeekData
                    ? '—'
                    : '${_number('thisWeekCases')}',
                style: TextStyle(
                  fontSize: 44,
                  height: 1,
                  fontWeight: FontWeight.bold,
                  color: _activityColor,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('reportable cases'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _activityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              _activityLabel.tr(),
              style: TextStyle(
                color: _activityColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _hasThisWeekData
                ? 'This is the municipality-wide total. Barangay-level weekly figures suppress groups below three cases.'
                      .tr()
                : 'No reportable cases have been recorded this week.'
                      .tr(),
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Widget _buildStatistics() => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: width,
            child: _buildStatCard(
              label: 'Reportable cases, all time'.tr(),
              value: _hasError || !_hasReportableData
                  ? '—'
                  : '${_number('totalCases')}',
              icon: Icons.analytics_outlined,
              color: Colors.teal,
            ),
          ),
          SizedBox(
            width: width,
            child: _buildStatCard(
              label: 'Affected barangays'.tr(),
              value: _hasError || !_hasReportableData
                  ? '—'
                  : '${_number('affectedBarangays')}',
              icon: Icons.location_city_outlined,
              color: Colors.deepOrange,
            ),
          ),
          SizedBox(
            width: width,
            child: _buildStatCard(
              label: 'Barangays in directory'.tr(),
              value: _hasError ? '—' : '${_number('registeredBarangays')}',
              icon: Icons.holiday_village_outlined,
              color: Colors.blue,
            ),
          ),
          SizedBox(
            width: width,
            child: _buildStatCard(
              label: 'Affected this week'.tr(),
              value: _hasError || !_hasThisWeekData
                  ? '—'
                  : '${_number('thisWeekAffectedBarangays')}',
              icon: Icons.map_outlined,
              color: Colors.purple,
            ),
          ),
        ],
      );
    },
  );

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );

  Widget _buildSuppressionNote() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.blueGrey.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, color: Colors.blueGrey.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Municipal totals include submitted, dated, non-duplicate cases. Barangay-level weekly groups and public map markers are shown only when at least three cases meet the selected period and area filters.'
                .tr(),
            style: TextStyle(color: Colors.blueGrey.shade800, fontSize: 12),
          ),
        ),
      ],
    ),
  );

  Widget _buildActionGrid() => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    childAspectRatio: 1.08,
    children: [
      _buildActionCard(
        icon: Icons.map_outlined,
        title: 'Activity map'.tr(),
        subtitle: 'Explore reportable activity by location'.tr(),
        onTap: () => _open(const ActivityMapScreen()),
      ),
      _buildActionCard(
        icon: Icons.show_chart,
        title: 'Trends & timeline'.tr(),
        subtitle: 'Review weekly patterns'.tr(),
        onTap: () => _open(const TrendTimelineScreen()),
      ),
      _buildActionCard(
        icon: Icons.health_and_safety_outlined,
        title: 'Health alert'.tr(),
        subtitle: 'Request a health worker follow-up'.tr(),
        onTap: () => _open(const HealthAlertScreen()),
        color: Colors.orange.shade50,
      ),
      _buildActionCard(
        icon: Icons.shield_outlined,
        title: 'Prevention guide'.tr(),
        subtitle: 'Learn the DOH 4S strategy'.tr(),
        onTap: () => _open(const PreventionGuideScreen()),
      ),
    ],
  );

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) => Card(
    color: color,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.green.shade800, size: 30),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildLastUpdated() {
    final raw = _dashboardData?['lastUpdated']?.toString();
    final updated = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
    return Center(
      child: Text(
        updated == null
            ? 'Updated time unavailable'.tr()
            : '${'Updated'.tr()} ${DateFormat.yMMMd().add_jm().format(updated)}',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Salcedo Dengue Watch',
      applicationVersion: '1.1.0',
      children: const [
        Text('Community dengue information for Salcedo, Eastern Samar.'),
      ],
    );
  }
}
