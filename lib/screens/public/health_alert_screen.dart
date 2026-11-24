import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../services/admin_service.dart';
import '../../services/data_service.dart';

class HealthAlertScreen extends StatefulWidget {
  const HealthAlertScreen({super.key});

  @override
  State<HealthAlertScreen> createState() => _HealthAlertScreenState();
}

class _HealthAlertScreenState extends State<HealthAlertScreen> {
  final _formKey = GlobalKey<FormState>();
  final DataService _dataService = DataService();
  final AdminService _adminService = AdminService();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedBarangay;
  String? _selectedSex;
  final List<String> _selectedSymptoms = [];
  DateTime? _onsetDate;
  bool _isSubmitting = false;
  bool _isLoadingBarangays = true;
  String? _referenceNumber;
  List<Map<String, String>> _barangays = [];

  static const _symptomOptions = [
    'Fever',
    'Headache',
    'Joint/Muscle pain',
    'Rash',
    'Nausea/Vomiting',
    'Eye pain',
    'Bleeding',
  ];

  @override
  void initState() {
    super.initState();
    _loadBarangays();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadBarangays() async {
    try {
      final rows = await _adminService.getBarangays();
      if (!mounted) return;
      setState(() {
        _barangays = rows
            .where((row) => row['id'] != null && row['name'] != null)
            .map(
              (row) => {
                'id': row['id'].toString(),
                'name': row['name'].toString(),
              },
            )
            .toList();
        _isLoadingBarangays = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingBarangays = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _onsetDate = picked);
  }

  Future<void> _submitAlert() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSymptoms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select at least one symptom.'.tr())),
      );
      return;
    }
    if (_onsetDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select the symptom onset date.'.tr())),
      );
      return;
    }
    if (_selectedSex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complete the required selections.'.tr())),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final referenceNumber =
        'ALT-${DateTime.now().millisecondsSinceEpoch.toString()}';
    final barangay = _barangays.firstWhere(
      (item) => item['name'] == _selectedBarangay,
    );
    final alertData = {
      'barangay': _selectedBarangay,
      'barangay_id': barangay['id'],
      'reporter_name': _nameController.text.trim(),
      'reporter_address': _addressController.text.trim(),
      'reporter_age': int.tryParse(_ageController.text.trim()),
      'reporter_sex': _selectedSex,
      'contact_value': _phoneController.text.trim(),
      'symptoms': _selectedSymptoms,
      'onset_date': _onsetDate!.toIso8601String(),
      'note': _noteController.text.trim(),
      'submitted_at': DateTime.now().toIso8601String(),
      'urgency_flag': _selectedSymptoms.contains('Bleeding'),
      'reference_number': referenceNumber,
    };

    final success = await _dataService.submitHealthAlert(alertData);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      setState(() => _referenceNumber = referenceNumber);
      _showSuccessDialog();
    } else {
      _showErrorDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(child: Text('Alert submitted'.tr())),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Keep this reference number:'.tr()),
              SelectableText(
                _referenceNumber ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your report is available to authorized RHU staff and health workers with access to your barangay. A BHW/BSI serving your barangay should verify it and update its follow-up status. This report is not a confirmed dengue case.'
                    .tr(),
              ),
              const SizedBox(height: 12),
              _buildRhuContactInfo(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: Text('Done'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildRhuContactInfo() {
    final value = context
        .read<AppState>()
        .getSetting('rhu_contact_phone', 'RHU contact number not configured')
        .trim();
    final isPhone =
        value.isNotEmpty &&
        value.toUpperCase() != 'PLACEHOLDER_PHONE' &&
        value.toUpperCase() != 'RHU CONTACT NUMBER NOT CONFIGURED';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RHU contact'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            isPhone
                ? value
                : 'Contact your barangay health worker or visit the RHU for its current contact number.'
                      .tr(),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Could not submit report'.tr()),
        content: Text('Please check your connection and try again.'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('OK'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Health alert'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildEmergencyWarning(),
                const SizedBox(height: 12),
                _buildPrankWarning(),
                const SizedBox(height: 12),
                _buildPrivacyNotice(),
                const SizedBox(height: 20),
                _buildSectionTitle(
                  'Your details (person reporting)'.tr(),
                  Icons.person_outline,
                ),
                const SizedBox(height: 12),
                _textField(
                  _nameController,
                  'Your full name'.tr(),
                  Icons.badge_outlined,
                ),
                const SizedBox(height: 12),
                _textField(
                  _addressController,
                  'Home address / purok'.tr(),
                  Icons.home_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _textField(
                        _ageController,
                        'Age'.tr(),
                        Icons.cake_outlined,
                        keyboardType: TextInputType.number,
                        validator: _validateAge,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSex,
                        decoration: InputDecoration(
                          labelText: 'Sex'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('Female'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'male',
                            child: Text('Male'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Other'.tr()),
                          ),
                          DropdownMenuItem(
                            value: 'prefer_not_to_say',
                            child: Text('Prefer not to say'.tr()),
                          ),
                        ],
                        validator: (value) =>
                            value == null ? 'Select an option'.tr() : null,
                        onChanged: (value) =>
                            setState(() => _selectedSex = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _textField(
                  _phoneController,
                  'Contact number'.tr(),
                  Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: _validatePhone,
                ),
                const SizedBox(height: 20),
                _buildSectionTitle(
                  'Report location'.tr(),
                  Icons.location_on_outlined,
                ),
                const SizedBox(height: 12),
                _buildBarangayField(),
                const SizedBox(height: 20),
                _buildSymptomsField(),
                const SizedBox(height: 16),
                _buildOnsetDateField(),
                const SizedBox(height: 16),
                _textField(
                  _noteController,
                  'Additional notes (optional)'.tr(),
                  Icons.notes_outlined,
                  maxLines: 3,
                  required: false,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting || _barangays.isEmpty
                        ? null
                        : _submitAlert,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      _isSubmitting ? 'Submitting…'.tr() : 'Submit report'.tr(),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateAge(String? value) {
    final age = int.tryParse(value?.trim() ?? '');
    if (age == null || age < 1 || age > 120)
      return 'Enter an age from 1 to 120'.tr();
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.length < 7 || !RegExp(r'^[0-9+()\-\s]+$').hasMatch(phone)) {
      return 'Enter a valid contact number'.tr();
    }
    return null;
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool required = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: keyboardType == TextInputType.phone
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
      validator:
          validator ??
          (required
              ? (value) => (value?.trim().isEmpty ?? true)
                    ? 'This field is required'.tr()
                    : null
              : null),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) => Row(
    children: [
      Icon(icon, color: Colors.green.shade700),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
    ],
  );

  Widget _buildEmergencyWarning() => _notice(
    color: Colors.red,
    icon: Icons.emergency_outlined,
    title: 'Emergency'.tr(),
    message: 'This form is not an emergency service or a diagnosis. If symptoms are severe, go to the RHU or nearest hospital immediately.'
        .tr(),
  );

  Widget _buildPrankWarning() => _notice(
    color: Colors.deepOrange,
    icon: Icons.report_gmailerrorred_outlined,
    title: 'Please report truthfully'.tr(),
    message: 'Do not use this alert as a prank or joke. False reports can waste health workers’ time and delay help for people who need it.'
        .tr(),
  );

  Widget _buildPrivacyNotice() => _notice(
    color: Colors.blue,
    icon: Icons.shield_outlined,
    title: 'Who can see this report?'.tr(),
    message: 'Your name, contact, address, age, sex and symptom details are shared with authorized RHU staff and health workers assigned to your barangay so they can follow up.'
        .tr(),
  );

  Widget _notice({
    required MaterialColor color,
    required IconData icon,
    required String title,
    required String message,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.shade50,
      border: Border.all(color: color.shade200),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color.shade800),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color.shade900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: TextStyle(color: color.shade900, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildBarangayField() {
    if (_isLoadingBarangays)
      return const Center(child: CircularProgressIndicator());
    if (_barangays.isEmpty) {
      return _notice(
        color: Colors.orange,
        icon: Icons.warning_amber,
        title: 'Barangays unavailable'.tr(),
        message: 'Please try again later or contact the RHU administrator.'
            .tr(),
      );
    }
    return DropdownButtonFormField<String>(
      value: _selectedBarangay,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Barangay'.tr(),
        prefixIcon: const Icon(Icons.map_outlined),
        border: const OutlineInputBorder(),
      ),
      items: _barangays
          .map(
            (item) => DropdownMenuItem(
              value: item['name'],
              child: Text(item['name']!),
            ),
          )
          .toList(),
      validator: (value) => value == null ? 'Select your barangay'.tr() : null,
      onChanged: (value) => setState(() => _selectedBarangay = value),
    );
  }

  Widget _buildSymptomsField() => FormField<bool>(
    validator: (_) =>
        _selectedSymptoms.isEmpty ? 'Select at least one symptom'.tr() : null,
    builder: (field) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Symptoms'.tr(), Icons.health_and_safety_outlined),
        const SizedBox(height: 4),
        Text(
          'Select all that apply.'.tr(),
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _symptomOptions.map((symptom) {
            final selected = _selectedSymptoms.contains(symptom);
            return FilterChip(
              label: Text(symptom.tr()),
              selected: selected,
              onSelected: (value) => setState(() {
                if (value) {
                  _selectedSymptoms.add(symptom);
                } else {
                  _selectedSymptoms.remove(symptom);
                }
                field.didChange(_selectedSymptoms.isNotEmpty);
              }),
            );
          }).toList(),
        ),
        if (field.hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              field.errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _buildOnsetDateField() => FormField<DateTime>(
    validator: (_) =>
        _onsetDate == null ? 'Select the symptom onset date'.tr() : null,
    builder: (field) => InkWell(
      onTap: () async {
        await _selectDate();
        field.didChange(_onsetDate);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Symptom onset date'.tr(),
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_month_outlined),
          errorText: field.errorText,
        ),
        child: Text(
          _onsetDate == null
              ? 'Select date'.tr()
              : DateFormat.yMMMd().format(_onsetDate!),
        ),
      ),
    ),
  );
}
