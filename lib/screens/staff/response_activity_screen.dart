import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';

class ResponseActivityScreen extends StatefulWidget {
  const ResponseActivityScreen({super.key});

  @override
  State<ResponseActivityScreen> createState() => _ResponseActivityScreenState();
}

class _ResponseActivityScreenState extends State<ResponseActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dataService = DataService();
  final _adminService = AdminService();
  final _purokController = TextEditingController();
  final _householdsController = TextEditingController();
  final _areaController = TextEditingController();
  final _findingsController = TextEditingController();
  final _notesController = TextEditingController();

  static const _activityTypes = <String>[
    'search_and_destroy',
    'cleanup_drive',
    'inspection',
    'larval_source_reduction',
    'fogging_spraying',
    'health_education',
    'referral',
  ];

  String? _activityType;
  DateTime _activityDate = DateTime.now();
  String? _barangayId;
  String? _barangayName;
  List<Map<String, dynamic>> _barangays = [];
  List<String> _availableTeams = [];
  final Set<String> _selectedTeams = {};
  bool _loadingBarangays = true;
  bool _saving = false;
  String? _barangayLoadError;

  @override
  void initState() {
    super.initState();
    _loadBarangays();
  }

  Future<void> _loadBarangays() async {
    final user = context.read<AuthService>().currentUser;
    if (mounted) {
      setState(() {
        _loadingBarangays = true;
        _barangayLoadError = null;
        _availableTeams = user?.team ?? const [];
        // Team assignment does not imply that every member attended this
        // specific activity; selected attendees start empty.
        _selectedTeams.clear();
      });
    }

    try {
      var rows = await _adminService.getBarangays(rhuId: user?.rhuId);
      // Barangay-based staff can only select their assigned barangay. RLS
      // remains the security boundary; this also keeps the form unambiguous.
      if (user?.barangayId != null) {
        rows = rows.where((row) => row['id'] == user!.barangayId).toList();
      }
      if (!mounted) return;
      setState(() {
        _barangays = rows
            .where((row) => row['id'] != null && row['name'] != null)
            .toList();
        if (_barangays.length == 1) {
          _barangayId = _barangays.first['id'].toString();
          _barangayName = _barangays.first['name'].toString();
        }
        _loadingBarangays = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _barangays = [];
        _loadingBarangays = false;
        _barangayLoadError = 'Could not load barangays. Check your connection and retry.';
      });
    }
  }

  @override
  void dispose() {
    _purokController.dispose();
    _householdsController.dispose();
    _areaController.dispose();
    _findingsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _activityDate.isAfter(now) ? now : _activityDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_activityDate),
    );
    if (pickedTime == null || !mounted) return;
    final selectedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    if (selectedDateTime.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activity time cannot be in the future.'.tr())),
      );
      return;
    }
    setState(() => _activityDate = selectedDateTime);
  }

  Future<void> _submitActivity() async {
    if (_saving || _loadingBarangays) return;
    if (!_formKey.currentState!.validate()) return;

    final user = context.read<AuthService>().currentUser;
    if (user == null || _barangayId == null || _barangayName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select a valid barangay before saving.'.tr())),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final activityData = <String, dynamic>{
        'activity_type': _activityType,
        'activity_date': _activityDate.toUtc().toIso8601String(),
        'barangay': _barangayName,
        'barangay_id': _barangayId,
        'purok': _blankToNull(_purokController.text),
        // The database column is text[], not a single text value.
        'team': _selectedTeams.toList(),
        'households_covered': _integerOrNull(_householdsController.text),
        'area_covered_sqm': _decimalOrNull(_areaController.text),
        'findings': _blankToNull(_findingsController.text),
        'notes': _blankToNull(_notesController.text),
        'status': 'completed',
        'created_by': user.id,
      };

      final success = await _dataService.logResponseActivity(activityData);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Response activity saved.'.tr()),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save the activity. Check your access and connection, then try again.'.tr()),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save the activity. Please try again.'.tr()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _blankToNull(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  int? _integerOrNull(String value) =>
      value.trim().isEmpty ? null : int.tryParse(value.trim());

  double? _decimalOrNull(String value) =>
      value.trim().isEmpty ? null : double.tryParse(value.trim());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Response activity'.tr()),
        actions: [
          TextButton(
            onPressed: _saving || _loadingBarangays ? null : _submitActivity,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Save'.tr()),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Text(
              'Record completed dengue prevention and response work.'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _section(
              title: 'Activity details'.tr(),
              icon: Icons.assignment_outlined,
              children: [
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration('Activity type'.tr()),
                  initialValue: _activityType,
                  items: _activityTypes
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.tr()),
                          ))
                      .toList(),
                  validator: (value) =>
                      value == null ? 'Choose an activity type'.tr() : null,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _activityType = value),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _saving ? null : _selectDateTime,
                  child: InputDecorator(
                    decoration: _inputDecoration('Date and time completed'.tr())
                        .copyWith(suffixIcon: const Icon(Icons.event)),
                    child: Text(
                      DateFormat.yMMMd().add_jm().format(_activityDate),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Location and team'.tr(),
              icon: Icons.place_outlined,
              children: [
                _buildBarangayField(),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _purokController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDecoration('Purok / sitio (optional)'.tr()),
                ),
                const SizedBox(height: 16),
                Text('Team members (optional)'.tr(),
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (_availableTeams.isEmpty)
                  Text(
                    'No team members are assigned to your profile. You can still record this activity.'.tr(),
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _availableTeams.map((team) {
                      return FilterChip(
                        label: Text(team),
                        selected: _selectedTeams.contains(team),
                        onSelected: _saving
                            ? null
                            : (selected) => setState(() {
                                  if (selected) {
                                    _selectedTeams.add(team);
                                  } else {
                                    _selectedTeams.remove(team);
                                  }
                                }),
                      );
                    }).toList(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Coverage'.tr(),
              icon: Icons.home_work_outlined,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _householdsController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Households reached'.tr()),
                        validator: (value) => _validateWholeNumber(value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _areaController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration('Area covered (m²)'.tr()),
                        validator: (value) => _validateDecimal(value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Leave a measure blank when it was not recorded.'.tr(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Report'.tr(),
              icon: Icons.notes_outlined,
              children: [
                TextFormField(
                  controller: _findingsController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 3,
                  maxLines: 5,
                  decoration: _inputDecoration('Findings (optional)'.tr())
                      .copyWith(
                    hintText: 'What was observed or completed?'.tr(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _inputDecoration('Additional notes (optional)'.tr())
                      .copyWith(alignLabelWithHint: true),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving || _loadingBarangays ? null : _submitActivity,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Saving…'.tr() : 'Save activity'.tr()),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarangayField() {
    if (_loadingBarangays) {
      return const LinearProgressIndicator();
    }
    if (_barangayLoadError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_barangayLoadError!.tr()),
          TextButton.icon(
            onPressed: _loadBarangays,
            icon: const Icon(Icons.refresh),
            label: Text('Retry'.tr()),
          ),
        ],
      );
    }
    if (_barangays.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No accessible barangays are configured for your account.'.tr(),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton.icon(
            onPressed: _loadBarangays,
            icon: const Icon(Icons.refresh),
            label: Text('Retry'.tr()),
          ),
        ],
      );
    }
    return DropdownButtonFormField<String>(
      decoration: _inputDecoration('Barangay'.tr()),
      initialValue: _barangayId,
      items: _barangays
          .map((row) => DropdownMenuItem<String>(
                value: row['id'].toString(),
                child: Text(row['name'].toString()),
              ))
          .toList(),
      validator: (value) => value == null ? 'Choose a barangay'.tr() : null,
      onChanged: _saving
          ? null
          : (id) {
              final selected = _barangays.firstWhere(
                (row) => row['id'].toString() == id,
              );
              setState(() {
                _barangayId = id;
                _barangayName = selected['name'].toString();
              });
            },
    );
  }

  String? _validateWholeNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final number = int.tryParse(text);
    if (number == null) return 'Enter a whole number'.tr();
    if (number < 0) return 'Enter zero or a positive number'.tr();
    return null;
  }

  String? _validateDecimal(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final number = double.tryParse(text);
    if (number == null || !number.isFinite) {
      return 'Enter a valid number'.tr();
    }
    if (number < 0) return 'Enter zero or a positive number'.tr();
    return null;
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      );

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) =>
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      );
}
