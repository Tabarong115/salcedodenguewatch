import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';

class PreventionGuideScreen extends StatefulWidget {
  const PreventionGuideScreen({super.key});

  @override
  State<PreventionGuideScreen> createState() => _PreventionGuideScreenState();
}

class _PreventionGuideScreenState extends State<PreventionGuideScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prevention Guide'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _build4SIntroduction(),
            const SizedBox(height: 24),
            _build4SStrategy(),
            const SizedBox(height: 24),
            _build4OclockReminder(),
            const SizedBox(height: 24),
            _buildWarningSigns(),
            const SizedBox(height: 24),
            _buildContactRHU(appState),
          ],
        ),
      ),
    );
  }

  Widget _build4SIntroduction() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.health_and_safety,
                  color: Colors.green.shade700,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'DOH 4S Strategy',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'The Department of Health recommends the 4S strategy to prevent dengue:',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build4SStrategy() {
    return Column(
      children: [
        _build4SCard(
          icon: Icons.search,
          title: 'Search & Destroy',
          description: 'Cover water containers, clean surroundings, and destroy mosquito breeding places.',
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        _build4SCard(
          icon: Icons.shield,
          title: 'Self-Protection',
          description: 'Wear protective clothing, use mosquito repellent, and sleep under mosquito nets.',
          color: Colors.blue,
        ),
        const SizedBox(height: 12),
        _build4SCard(
          icon: Icons.local_hospital,
          title: 'Seek Early Consultation',
          description: 'Consult a doctor immediately if you have fever for 2 or more days.',
          color: Colors.orange,
        ),
        const SizedBox(height: 12),
        _build4SCard(
          icon: Icons.cloud,
          title: 'Support Fogging/Spraying',
          description: 'Support fogging/spraying only in hotspot areas to kill adult mosquitoes.',
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _build4SCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
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
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build4OclockReminder() {
    return Card(
      color: Colors.yellow.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: Colors.orange.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  '4 O\'clock Habit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Every day at 4:00 PM, spend a few minutes to:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            _buildHabitItem('Check and clean water containers'),
            _buildHabitItem('Remove standing water around your home'),
            _buildHabitItem(
              'Cover or empty drums, pails, and other containers',
            ),
            _buildHabitItem('Clean gutters to ensure water flow'),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildWarningSigns() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Warning Signs - Seek Immediate Care',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildWarningItem('Severe abdominal pain'),
            _buildWarningItem('Persistent vomiting'),
            _buildWarningItem('Bleeding from gums or nose'),
            _buildWarningItem('Blood in stool or urine'),
            _buildWarningItem('Difficulty breathing'),
            _buildWarningItem('Cold or clammy skin'),
            _buildWarningItem('Weakness or restlessness'),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildContactRHU(AppState appState) {
    final configuredPhone = appState.getSetting(
      'rhu_contact_phone',
      'RHU contact number not configured',
    );
    final rhuPhone =
        configuredPhone.isEmpty ||
            configuredPhone.toUpperCase() == 'PLACEHOLDER_PHONE' ||
            configuredPhone.toUpperCase() == 'RHU CONTACT NUMBER NOT CONFIGURED'
        ? 'Contact your barangay health worker or visit the RHU for its current contact number.'
        : configuredPhone;
    final configuredHours = appState.getSetting(
      'rhu_contact_hours',
      'Operating hours to be set by administrator',
    );
    final rhuHours = configuredHours.toUpperCase() == 'PLACEHOLDER_HOURS'
        ? 'Please contact the RHU for current operating hours.'
        : configuredHours;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_hospital,
                  color: Colors.green.shade700,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Contact RHU',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildContactItem(Icons.phone, rhuPhone),
            const SizedBox(height: 8),
            _buildContactItem(Icons.schedule, rhuHours),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Call functionality coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.call),
                label: const Text('Call RHU'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.green.shade700, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}
