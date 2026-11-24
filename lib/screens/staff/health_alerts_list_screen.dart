import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/data_service.dart';
import '../../services/auth_service.dart';

class HealthAlertsListScreen extends StatefulWidget {
  const HealthAlertsListScreen({super.key});

  @override
  State<HealthAlertsListScreen> createState() => _HealthAlertsListScreenState();
}

class _HealthAlertsListScreenState extends State<HealthAlertsListScreen> {
  final DataService _dataService = DataService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _alerts = [];
  String _filterStatus = 'all';
  String _searchQuery = '';
  RealtimeChannel? _healthAlertChannel;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _healthAlertChannel = _dataService.listenForHealthAlertChanges((
      alert,
      event,
    ) {
      _loadAlerts();
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

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();
      final user = authService.currentUser;

      // Get barangay filter based on user's role and assignments
      String? barangayFilter;
      String? barangayIdFilter;

      if (user?.role == 'admin' || user?.role == 'rhu_staff') {
        // Admin and RHU staff can see all alerts in their RHU
        barangayFilter = null;
        barangayIdFilter = null;
      } else {
        // For encoders, BHWs, etc., filter by their assigned barangay
        barangayFilter = null; // Don't filter by name, let RLS handle it
        barangayIdFilter = user?.barangayId; // Filter by barangay ID for RLS
      }

      // Fetch health alerts with role-based filtering
      var alerts = await _dataService.getHealthAlerts(
        barangay: barangayFilter,
        barangayId: barangayIdFilter,
      );

      if (mounted) {
        setState(() {
          _alerts = alerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _alerts = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading alerts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredAlerts {
    var filtered = _alerts;

    // Apply status filter
    if (_filterStatus != 'all') {
      filtered = filtered
          .where((a) => a['followup_status'] == _filterStatus)
          .toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((a) {
        final barangay = (a['barangay'] as String? ?? '').toLowerCase();
        final rawSymptoms = a['symptoms'];
        final symptoms =
            (rawSymptoms is List
                    ? rawSymptoms.join(', ')
                    : rawSymptoms?.toString() ?? '')
                .toLowerCase();
        return barangay.contains(query) || symptoms.contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Health Alerts'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAlerts),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAlerts.isEmpty
                ? _buildEmptyState()
                : _buildAlertList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search by barangay or symptoms'.tr(),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'All'.tr()),
                const SizedBox(width: 8),
                _buildFilterChip('new', 'New'.tr()),
                const SizedBox(width: 8),
                _buildFilterChip('acknowledged', 'Acknowledged'.tr()),
                const SizedBox(width: 8),
                _buildFilterChip('contacted', 'Contacted'.tr()),
                const SizedBox(width: 8),
                _buildFilterChip('confirmed', 'Confirmed'.tr()),
                const SizedBox(width: 8),
                _buildFilterChip('referred', 'Referred'.tr()),
                const SizedBox(width: 8),
                _buildFilterChip('closed', 'Closed'.tr()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status, String label) {
    final isSelected = _filterStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => setState(() => _filterStatus = status),
      selectedColor: Colors.green.shade200,
      checkmarkColor: Colors.green,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No health alerts found'.tr(),
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Alerts from residents will appear here'.tr(),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredAlerts.length,
      itemBuilder: (context, index) {
        final alertData = _filteredAlerts[index];
        return _buildAlertCard(alertData);
      },
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alertData) {
    final barangay = alertData['barangay'] as String? ?? 'Unknown';
    final status = alertData['followup_status'] as String? ?? 'new';
    final submittedAt = alertData['submitted_at'] as String?;
    final urgency = alertData['urgency_flag'] as bool? ?? false;
    final rawSymptoms = alertData['symptoms'];
    final symptoms = rawSymptoms is List
        ? rawSymptoms.join(', ')
        : rawSymptoms?.toString() ?? '';
    final contactNumber = alertData['contact_value'] as String? ?? '';
    final reporterName = alertData['reporter_name'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showAlertDetails(alertData),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (urgency)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Urgent'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (urgency) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      barangay,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
              const SizedBox(height: 8),
              if (reporterName.isNotEmpty)
                Text(
                  '${'Reported by'.tr()}: $reporterName',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                ),
              if (symptoms.isNotEmpty)
                Text(
                  symptoms,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    submittedAt != null
                        ? _formatDate(submittedAt)
                        : 'No date'.tr(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.contact_phone,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      contactNumber,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'new':
        color = Colors.red;
        label = 'New'.tr();
        break;
      case 'acknowledged':
        color = Colors.blue;
        label = 'Acknowledged'.tr();
        break;
      case 'contacted':
        color = Colors.orange;
        label = 'Contacted'.tr();
        break;
      case 'confirmed':
        color = Colors.green;
        label = 'Confirmed'.tr();
        break;
      case 'referred':
        color = Colors.purple;
        label = 'Referred'.tr();
        break;
      case 'closed':
        color = Colors.green;
        label = 'Closed'.tr();
        break;
      default:
        color = Colors.grey;
        label = status.tr();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null) return 'N/A'.tr();
    try {
      final date = DateTime.parse(dateString.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _showAlertDetails(Map<String, dynamic> alertData) {
    final currentStatus = alertData['followup_status'] as String? ?? 'new';
    final rawSymptoms = alertData['symptoms'];
    final role = context.read<AuthService>().currentUser?.role;
    final statuses = ['new', 'acknowledged', 'contacted'];
    if (role == 'bhw' || role == 'bsi') statuses.add('confirmed');
    statuses.addAll(['referred', 'closed']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Health Alert Details'.tr()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'This is a follow-up request, not a confirmed case. After field verification, record a confirmed case through Case Report when appropriate.'
                      .tr(),
                  style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
                ),
              ),
              _buildDetailRow('Barangay'.tr(), alertData['barangay']),
              _buildDetailRow('Reporter'.tr(), alertData['reporter_name']),
              _buildDetailRow(
                'Reporter address'.tr(),
                alertData['reporter_address'],
              ),
              _buildDetailRow('Reporter age'.tr(), alertData['reporter_age']),
              _buildDetailRow('Reporter sex'.tr(), alertData['reporter_sex']),
              _buildDetailRow(
                'Contact number'.tr(),
                alertData['contact_value'],
              ),
              _buildDetailRow('Status'.tr(), currentStatus),
              _buildDetailRow(
                'Submitted'.tr(),
                _formatDate(alertData['submitted_at']),
              ),
              _buildDetailRow(
                'Symptom Onset'.tr(),
                _formatDate(alertData['onset_date']),
              ),
              _buildDetailRow(
                'Symptoms'.tr(),
                rawSymptoms is List ? rawSymptoms.join(', ') : rawSymptoms,
              ),
              _buildDetailRow('Notes'.tr(), alertData['note']),
              if (alertData['urgency_flag'] == true)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Marked as urgent'.tr(),
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'.tr()),
          ),
          DropdownButton<String>(
            value: statuses.contains(currentStatus) ? currentStatus : null,
            hint: Text(_getStatusDisplayName(currentStatus)),
            items: statuses.map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(_getStatusDisplayName(status)),
              );
            }).toList(),
            onChanged: (newStatus) {
              if (newStatus != null) {
                _updateAlertStatus(alertData['id'] as String, newStatus);
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'new':
        return 'New'.tr();
      case 'acknowledged':
        return 'Acknowledged'.tr();
      case 'contacted':
        return 'Contacted'.tr();
      case 'confirmed':
        return 'Confirmed'.tr();
      case 'referred':
        return 'Referred'.tr();
      case 'closed':
        return 'Closed'.tr();
      default:
        return status;
    }
  }

  Future<void> _updateAlertStatus(String alertId, String newStatus) async {
    try {
      final success = await _dataService.updateHealthAlert(alertId, {
        'followup_status': newStatus,
        'follow_up_updated_at': DateTime.now().toIso8601String(),
      });

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Alert status updated to ${_getStatusDisplayName(newStatus)}'
                  .tr(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadAlerts();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update alert status'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating alert: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
