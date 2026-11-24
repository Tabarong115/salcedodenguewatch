import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../services/data_service.dart';
import '../../services/auth_service.dart';
import 'case_report_screen.dart';

class CaseListScreen extends StatefulWidget {
  const CaseListScreen({super.key});

  @override
  State<CaseListScreen> createState() => _CaseListScreenState();
}

class _CaseListScreenState extends State<CaseListScreen> {
  final DataService _dataService = DataService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _cases = [];
  String _filterStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
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
        // Admin and RHU staff can see all cases in their RHU
        barangayFilter = null;
        barangayIdFilter = null;
      } else {
        // RLS limits the rows to this account's assigned jurisdiction.
        barangayFilter = null; // Don't filter by name, let RLS handle it
        barangayIdFilter = user?.barangayId; // Filter by barangay ID for RLS
      }

      // Fetch all cases available in the user's jurisdiction. Assignment to a
      // particular worker controls follow-up work, not whether the case exists
      // in the barangay case register.
      final cases = await _dataService.getCases(
        barangay: barangayFilter,
        barangayId: barangayIdFilter,
      );

      if (mounted) {
        setState(() {
          _cases = cases;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cases = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading cases: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredCases {
    var filtered = _cases;

    // Apply status filter
    if (_filterStatus != 'all') {
      filtered = filtered.where((c) => c['status'] == _filterStatus).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        final barangay = (c['barangay'] as String? ?? '').toLowerCase();
        final classification = (c['classification'] as String? ?? '')
            .toLowerCase();
        return barangay.contains(query) || classification.contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Case List'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCases),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCases.isEmpty
                ? _buildEmptyState()
                : _buildCaseList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CaseReportScreen()),
          ).then((_) => _loadCases());
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
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
              hintText: 'Search by barangay or classification'.tr(),
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
                _buildFilterChip('pending', 'Pending'.tr()),
                const SizedBox(width: 8),
                _buildFilterChip('investigation', 'Investigating'.tr()),
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
          Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No cases found'.tr(),
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a new case report'.tr(),
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredCases.length,
      itemBuilder: (context, index) {
        final caseData = _filteredCases[index];
        return _buildCaseCard(caseData);
      },
    );
  }

  Widget _buildCaseCard(Map<String, dynamic> caseData) {
    final classification = caseData['classification'] as String? ?? 'unknown';
    final barangay = caseData['barangay'] as String? ?? 'Unknown';
    final status = caseData['status'] as String? ?? 'pending';
    final reportDate = caseData['report_date'] as String?;
    final ageBand = caseData['age_band'] as String?;
    final sex = caseData['sex'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showCaseDetails(caseData),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildClassificationIcon(classification),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          barangay,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (ageBand != null || sex != null)
                          Text(
                            '${ageBand ?? ''} ${sex ?? ''}'.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    reportDate != null
                        ? _formatDate(reportDate)
                        : 'No date'.tr(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClassificationIcon(String classification) {
    IconData icon;
    Color color;

    switch (classification) {
      case 'suspected':
        icon = Icons.help_outline;
        color = Colors.orange;
        break;
      case 'probable':
        icon = Icons.question_mark;
        color = Colors.orange.shade700;
        break;
      case 'confirmed':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      default:
        icon = Icons.medical_services;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'Pending'.tr();
        break;
      case 'investigation':
        color = Colors.blue;
        label = 'Investigating'.tr();
        break;
      case 'closed':
        color = Colors.grey;
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _showCaseDetails(Map<String, dynamic> caseData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Case Details'.tr()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                'Classification'.tr(),
                caseData['classification'],
              ),
              _buildDetailRow('Barangay'.tr(), caseData['barangay']),
              _buildDetailRow('Purok'.tr(), caseData['purok']),
              _buildDetailRow('Age Band'.tr(), caseData['age_band']),
              _buildDetailRow('Sex'.tr(), caseData['sex']),
              _buildDetailRow('Status'.tr(), caseData['status']),
              _buildDetailRow(
                'Report Date'.tr(),
                _formatDate(caseData['report_date']),
              ),
              _buildDetailRow(
                'Symptom Onset'.tr(),
                _formatDate(caseData['symptom_onset_date']),
              ),
              _buildDetailRow('Lab Result'.tr(), caseData['lab_result']),
              _buildDetailRow('Outcome'.tr(), caseData['outcome']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditCaseDialog(caseData);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Edit'.tr()),
          ),
        ],
      ),
    );
  }

  void _showEditCaseDialog(Map<String, dynamic> caseData) {
    var selectedStatus = caseData['status'] as String? ?? 'pending';
    String? selectedOutcome = caseData['outcome'] as String?;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update case status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(labelText: 'Case status'),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(
                    value: 'investigation',
                    child: Text('Investigation'),
                  ),
                  DropdownMenuItem(value: 'closed', child: Text('Closed')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedStatus = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedOutcome ?? '',
                decoration: const InputDecoration(labelText: 'Patient outcome'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Not recorded')),
                  DropdownMenuItem(value: 'ongoing', child: Text('Ongoing')),
                  DropdownMenuItem(
                    value: 'recovered',
                    child: Text('Recovered'),
                  ),
                  DropdownMenuItem(value: 'death', child: Text('Death')),
                  DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
                ],
                onChanged: (value) => setDialogState(
                  () => selectedOutcome = value == null || value.isEmpty
                      ? null
                      : value,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Recovered and deceased cases are automatically closed. The activity map updates from this outcome.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                var status = selectedStatus;
                if (selectedOutcome == 'recovered' ||
                    selectedOutcome == 'death') {
                  status = 'closed';
                } else if (selectedOutcome == 'ongoing' && status == 'closed') {
                  status = 'investigation';
                }
                final success = await _dataService.updateCase(
                  caseData['id'] as String,
                  {
                    'status': status,
                    'outcome': selectedOutcome,
                    'outcome_date':
                        selectedOutcome == 'recovered' ||
                            selectedOutcome == 'death'
                        ? caseData['outcome_date'] ??
                              DateTime.now().toIso8601String()
                        : null,
                  },
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;
                if (success) {
                  await _loadCases();
                } else {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not update this case. Check your access and try again.',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
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
}
