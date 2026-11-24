import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../services/data_service.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

class CaseReportScreen extends StatefulWidget {
  const CaseReportScreen({super.key});

  @override
  State<CaseReportScreen> createState() => _CaseReportScreenState();
}

class _CaseReportScreenState extends State<CaseReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final DataService _dataService = DataService();
  final AdminService _adminService = AdminService();

  // Basic information
  String? _classification;
  DateTime? _reportDate = DateTime.now();
  DateTime? _symptomOnsetDate;
  String? _ageBand;
  String? _sex;
  String? _barangay;
  String? _purok;

  // Location
  double? _latitude;
  double? _longitude;

  // Laboratory
  String? _labTestType;
  String? _labResult;
  DateTime? _labTestDate;

  // Outcome
  String? _outcome;
  DateTime? _outcomeDate;

  // Restricted identity (separate section)
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _guardianController = TextEditingController();

  bool _isSubmitting = false;
  bool _saveAsDraft = false;
  bool _isLoadingBarangays = true;
  List<String> _barangays = [];
  Map<String, String> _barangayIds = {}; // Map barangay name to ID

  final List<String> _classifications = ['suspected', 'probable', 'confirmed'];
  final List<String> _ageBands = [
    '0-4',
    '5-9',
    '10-14',
    '15-19',
    '20-29',
    '30-39',
    '40-49',
    '50-59',
    '60+',
  ];
  final List<String> _sexOptions = ['male', 'female'];
  final List<String> _labResults = [
    'pending',
    'positive',
    'negative',
    'inconclusive',
  ];
  final List<String> _outcomes = ['recovered', 'death', 'unknown', 'ongoing'];

  @override
  void initState() {
    super.initState();
    _loadBarangays();
  }

  Future<void> _loadBarangays() async {
    setState(() => _isLoadingBarangays = true);

    try {
      // Get current user's RHU assignment
      final authService = context.read<AuthService>();
      final user = authService.currentUser;

      // Fetch barangays from database, filtered by user's RHU
      final barangayData = await _adminService.getBarangays(rhuId: user?.rhuId);

      if (mounted) {
        setState(() {
          _barangays = barangayData
              .map((b) => b['name'] as String)
              .where((name) => name.isNotEmpty)
              .toList();
          // Create a mapping of barangay names to IDs
          _barangayIds = {
            for (var b in barangayData) b['name'] as String: b['id'] as String,
          };
          _isLoadingBarangays = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _barangays = [];
          _barangayIds = {};
          _isLoadingBarangays = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _guardianController.dispose();
    super.dispose();
  }

  Future<DateTime?> _selectDate(
    BuildContext context,
    DateTime? initialDate,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    return picked;
  }

  Future<void> _submitCase() async {
    if (!_formKey.currentState!.validate()) return;

    // For submitted cases, enforce required fields for animation and mapping
    if (!_saveAsDraft) {
      if (_reportDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report date is required to submit'.tr()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_symptomOnsetDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Symptom onset date is required to submit'.tr()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_latitude == null || _longitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location is required to submit (use map picker)'.tr(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authService = context.read<AuthService>();

      final caseData = {
        'classification': _classification,
        'report_date': _reportDate?.toIso8601String(),
        'symptom_onset_date': _symptomOnsetDate?.toIso8601String(),
        'status': 'pending',
        'age_band': _ageBand,
        'sex': _sex,
        'barangay': _barangay,
        'barangay_id': _barangayIds[_barangay], // Include barangay ID for RLS
        'purok': _purok,
        'latitude': _latitude,
        'longitude': _longitude,
        'lab_test_type': _labTestType,
        'lab_result': _labResult,
        'lab_test_date': _labTestDate?.toIso8601String(),
        'outcome': _outcome,
        'outcome_date': _outcomeDate?.toIso8601String(),
        'assigned_worker_id': authService.currentUser?.id,
        'created_by': authService.currentUser?.id,
        'is_submitted': !_saveAsDraft,
      };

      final success = await _dataService.submitCase(caseData);

      if (success && mounted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _saveAsDraft ? 'Draft saved'.tr() : 'Case submitted'.tr(),
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit case'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Case Report'.tr()),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => _submitCase(),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('Submit'.tr()),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Basic Information'.tr()),
            const SizedBox(height: 12),
            _buildClassificationField(),
            const SizedBox(height: 12),
            _buildReportDateField(),
            const SizedBox(height: 12),
            _buildSymptomOnsetField(),
            const SizedBox(height: 12),
            _buildDemographicsFields(),
            const SizedBox(height: 12),
            _buildLocationFields(),
            const SizedBox(height: 24),

            _buildSectionHeader('Laboratory Information'.tr()),
            const SizedBox(height: 12),
            _buildLabFields(),
            const SizedBox(height: 24),

            _buildSectionHeader('Clinical Outcome'.tr()),
            const SizedBox(height: 12),
            _buildOutcomeFields(),
            const SizedBox(height: 24),

            _buildSectionHeader('Restricted Identity'.tr()),
            const SizedBox(height: 8),
            _buildPrivacyWarning(),
            const SizedBox(height: 12),
            _buildIdentityFields(),
            const SizedBox(height: 24),

            _buildDraftButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.green,
      ),
    );
  }

  Widget _buildClassificationField() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Classification'.tr(),
        border: const OutlineInputBorder(),
      ),
      initialValue: _classification,
      items: _classifications
          .map((c) => DropdownMenuItem(value: c, child: Text(c.tr())))
          .toList(),
      validator: (value) => value == null ? 'Required'.tr() : null,
      onChanged: (value) => setState(() => _classification = value),
    );
  }

  Widget _buildReportDateField() {
    return InkWell(
      onTap: () async {
        final date = await _selectDate(context, _reportDate);
        if (date != null) {
          setState(() => _reportDate = date);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Report Date * (Required)'.tr(),
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
          errorText: _reportDate == null
              ? 'Required for submission'.tr()
              : null,
        ),
        child: Text(
          _reportDate != null
              ? '${_reportDate!.day}/${_reportDate!.month}/${_reportDate!.year}'
              : 'Select date'.tr(),
        ),
      ),
    );
  }

  Widget _buildSymptomOnsetField() {
    return InkWell(
      onTap: () async {
        final date = await _selectDate(context, _symptomOnsetDate);
        if (date != null) {
          setState(() => _symptomOnsetDate = date);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Symptom Onset Date * (Required)'.tr(),
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
          errorText: _symptomOnsetDate == null
              ? 'Required for submission'.tr()
              : null,
        ),
        child: Text(
          _symptomOnsetDate != null
              ? '${_symptomOnsetDate!.day}/${_symptomOnsetDate!.month}/${_symptomOnsetDate!.year}'
              : 'Select date'.tr(),
        ),
      ),
    );
  }

  Widget _buildDemographicsFields() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Age Band'.tr(),
              border: const OutlineInputBorder(),
            ),
            initialValue: _ageBand,
            items: _ageBands
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (value) => setState(() => _ageBand = value),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Sex'.tr(),
              border: const OutlineInputBorder(),
            ),
            initialValue: _sex,
            items: _sexOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s.tr())))
                .toList(),
            onChanged: (value) => setState(() => _sex = value),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationFields() {
    return Column(
      children: [
        if (_isLoadingBarangays)
          const Center(child: CircularProgressIndicator())
        else if (_barangays.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No barangays configured. Please contact the administrator.',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Barangay'.tr(),
              border: const OutlineInputBorder(),
            ),
            initialValue: _barangay,
            items: _barangays
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            validator: (value) => value == null ? 'Required'.tr() : null,
            onChanged: (value) => setState(() => _barangay = value),
          ),
        const SizedBox(height: 12),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Purok/Grid'.tr(),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _purok = value),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Location is required for case submission and map animation.'
                      .tr(),
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                final picked = await showDialog<LatLng?>(
                  context: context,
                  builder: (ctx) => _MapPickerDialog(
                    initialLatitude: _latitude,
                    initialLongitude: _longitude,
                  ),
                );
                if (picked != null) {
                  setState(() {
                    _latitude = picked.latitude;
                    _longitude = picked.longitude;
                  });
                }
              },
              icon: const Icon(Icons.map),
              label: Text('Pick on Map * (Required)'.tr()),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: (_latitude != null && _longitude != null)
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  border: Border.all(
                    color: (_latitude != null && _longitude != null)
                        ? Colors.green
                        : Colors.red,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _latitude != null && _longitude != null
                      ? '✓ ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}'
                      : '✗ No coordinates selected'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: (_latitude != null && _longitude != null)
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Latitude'.tr(),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) =>
                    setState(() => _latitude = double.tryParse(value)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Longitude'.tr(),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) =>
                    setState(() => _longitude = double.tryParse(value)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLabFields() {
    return Column(
      children: [
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Lab Test Type'.tr(),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _labTestType = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Lab Result'.tr(),
            border: const OutlineInputBorder(),
          ),
          initialValue: _labResult,
          items: _labResults
              .map((r) => DropdownMenuItem(value: r, child: Text(r.tr())))
              .toList(),
          onChanged: (value) => setState(() => _labResult = value),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final date = await _selectDate(context, _labTestDate);
            if (date != null) {
              setState(() => _labTestDate = date);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Lab Test Date'.tr(),
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            child: Text(
              _labTestDate != null
                  ? '${_labTestDate!.day}/${_labTestDate!.month}/${_labTestDate!.year}'
                  : 'Select date'.tr(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutcomeFields() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: 'Outcome'.tr(),
            border: const OutlineInputBorder(),
          ),
          initialValue: _outcome,
          items: _outcomes
              .map((o) => DropdownMenuItem(value: o, child: Text(o.tr())))
              .toList(),
          onChanged: (value) => setState(() => _outcome = value),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final date = await _selectDate(context, _outcomeDate);
            if (date != null) {
              setState(() => _outcomeDate = date);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Outcome Date'.tr(),
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            child: Text(
              _outcomeDate != null
                  ? '${_outcomeDate!.day}/${_outcomeDate!.month}/${_outcomeDate!.year}'
                  : 'Select date'.tr(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This information is restricted to authorized staff only and will never appear on public screens.'
                  .tr(),
              style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityFields() {
    return Column(
      children: [
        TextFormField(
          controller: _fullNameController,
          decoration: InputDecoration(
            labelText: 'Full Name'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: 'Phone Number'.tr(),
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _addressController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Address'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _guardianController,
          decoration: InputDecoration(
            labelText: 'Guardian/Contact Person'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildDraftButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isSubmitting
            ? null
            : () {
                setState(() {
                  _saveAsDraft = true;
                });
                _submitCase();
              },
        icon: const Icon(Icons.save),
        label: Text('Save as Draft'.tr()),
        style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700),
      ),
    );
  }
}

class LatLng {
  final double latitude;
  final double longitude;
  LatLng(this.latitude, this.longitude);
}

class _MapPickerDialog extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  const _MapPickerDialog({this.initialLatitude, this.initialLongitude});

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  late ll.LatLng _center;
  ll.LatLng? _picked;

  @override
  void initState() {
    super.initState();
    // Default center coordinates (will be replaced with actual Salcedo coordinates when available)
    _center = ll.LatLng(
      widget.initialLatitude ?? 11.14922,
      widget.initialLongitude ?? 125.66287,
    );
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _picked = ll.LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 13.0,
              onTap: (tapPosition, point) {
                setState(() => _picked = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.salcedo_dengue_watch',
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: _picked == null
              ? null
              : () => Navigator.pop(
                  context,
                  LatLng(_picked!.latitude, _picked!.longitude),
                ),
          child: const Text('Use location'),
        ),
      ],
    );
  }
}
