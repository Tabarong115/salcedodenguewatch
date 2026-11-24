import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/data_service.dart';

enum _MapPeriod { allTime, day, week, month, year }

class ActivityMapScreen extends StatefulWidget {
  const ActivityMapScreen({super.key, this.staffMode = false});

  /// Exact coordinates are requested only by authenticated staff routes;
  /// public entry points always use the aggregated database function.
  final bool staffMode;

  @override
  State<ActivityMapScreen> createState() => _ActivityMapScreenState();
}

class _ActivityMapScreenState extends State<ActivityMapScreen> {
  final DataService _dataService = DataService();
  final MapController _mapController = MapController();
  _MapPeriod _period = _MapPeriod.allTime;
  DateTime _anchor = DateTime.now();
  String? _selectedBarangay;
  bool _showDetails = true;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _clusters = [];
  List<String> _barangayNames = [];

  DateTime? get _rangeStart {
    if (_period == _MapPeriod.allTime) return null;
    final day = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_period) {
      case _MapPeriod.allTime:
        return null;
      case _MapPeriod.day:
        return day;
      case _MapPeriod.week:
        return day.subtract(Duration(days: day.weekday - 1));
      case _MapPeriod.month:
        return DateTime(day.year, day.month);
      case _MapPeriod.year:
        return DateTime(day.year);
    }
  }

  DateTime? get _rangeEnd {
    if (_period == _MapPeriod.allTime) return null;
    final start = _rangeStart!;
    switch (_period) {
      case _MapPeriod.allTime:
        return null;
      case _MapPeriod.day:
        return start.add(const Duration(days: 1));
      case _MapPeriod.week:
        return start.add(const Duration(days: 7));
      case _MapPeriod.month:
        return DateTime(start.year, start.month + 1);
      case _MapPeriod.year:
        return DateTime(start.year + 1);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBarangayNames();
    _loadClusters();
  }

  Future<void> _loadBarangayNames() async {
    try {
      final staffUser = widget.staffMode
          ? context.read<AuthService>().currentUser
          : null;
      final assignedBarangayId = staffUser != null &&
              const {'encoder', 'bhw', 'bsi'}.contains(staffUser.role)
          ? staffUser.barangayId
          : null;
      final names = widget.staffMode
          ? await _dataService.getScopedBarangayNames(
              assignedBarangayId: assignedBarangayId,
            )
          : await _dataService.getPublicBarangayNames();
      if (!mounted) return;
      setState(() => _barangayNames = names);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Barangay list is unavailable. Refresh to retry.',
      );
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadBarangayNames(), _loadClusters()]);
  }

  Future<void> _loadClusters() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final staffUser = widget.staffMode
          ? context.read<AuthService>().currentUser
          : null;
      if (widget.staffMode && staffUser == null) {
        throw StateError(
          'A signed-in staff account is required for exact locations.',
        );
      }
      final rows = widget.staffMode
          ? await _dataService.getScopedCaseMapData(
              startDate: _rangeStart,
              endDate: _rangeEnd,
              barangay: _selectedBarangay,
            )
          : await _dataService.getPublicCaseMapData(
              startDate: _rangeStart,
              endDate: _rangeEnd,
              barangay: _selectedBarangay,
            );
      final grouped = <String, Map<String, dynamic>>{};
      var staffMarkerIndex = 0;
      for (final row in rows) {
        if (widget.staffMode) {
          grouped['case-${staffMarkerIndex++}'] = Map<String, dynamic>.from(
            row,
          );
          continue;
        }
        final lat = (row['latitude'] as num).toDouble();
        final lng = (row['longitude'] as num).toDouble();
        final category = row['map_category'] as String;
        final barangay = row['barangay'] as String;
        final key = '$lat|$lng|$category|$barangay';
        final item = grouped.putIfAbsent(
          key,
          () => {
            'lat': lat,
            'lng': lng,
            'category': category,
            'barangay': barangay,
            'count': 0,
          },
        );
        item['count'] =
            (item['count'] as int) + (row['case_count'] as num).toInt();
      }
      if (!mounted) return;
      final clusters = grouped.values.toList();
      setState(() {
        _clusters = clusters;
        _isLoading = false;
      });
      if (clusters.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final points = clusters
              .map(
                (cluster) =>
                    LatLng(cluster['lat'] as double, cluster['lng'] as double),
              )
              .toList();
          if (points.length == 1) {
            _mapController.move(points.single, 14);
          } else {
            _mapController.fitCamera(
              CameraFit.coordinates(
                coordinates: points,
                padding: const EdgeInsets.all(72),
              ),
            );
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _clusters = [];
        _isLoading = false;
        _error = 'Map data is unavailable. Check your connection and refresh.';
      });
    }
  }

  void _changePeriod(_MapPeriod period) {
    setState(() => _period = period);
    _loadClusters();
  }

  void _moveWindow(int amount) {
    if (_period == _MapPeriod.allTime) return;
    setState(() {
      switch (_period) {
        case _MapPeriod.day:
          _anchor = _anchor.add(Duration(days: amount));
          break;
        case _MapPeriod.week:
          _anchor = _anchor.add(Duration(days: 7 * amount));
          break;
        case _MapPeriod.month:
          _anchor = DateTime(_anchor.year, _anchor.month + amount, 1);
          break;
        case _MapPeriod.year:
          _anchor = DateTime(_anchor.year + amount, _anchor.month, 1);
          break;
        case _MapPeriod.allTime:
          break;
      }
    });
    _loadClusters();
  }

  Color _colorFor(String category) => switch (category) {
    'death' => Colors.black,
    'recovered' || 'resolved' => const Color(0xFF219653),
    'probable' => const Color(0xFFF28C28),
    _ => const Color(0xFFD93636),
  };

  String get _rangeLabel {
    if (_period == _MapPeriod.allTime) return 'All dates';
    final start = _rangeStart!;
    final end = _rangeEnd!.subtract(const Duration(days: 1));
    if (_period == _MapPeriod.day) {
      return '${start.day}/${start.month}/${start.year}';
    }
    if (_period == _MapPeriod.month) {
      return '${start.month}/${start.year}';
    }
    if (_period == _MapPeriod.year) return '${start.year}';
    return '${start.day}/${start.month} – ${end.day}/${end.month}/${end.year}';
  }

  int get _totalCases =>
      _clusters.fold(0, (sum, c) => sum + (c['count'] as int));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _showDetails
          ? AppBar(
              title: Text(
                widget.staffMode ? 'Staff Case Map' : 'Dengue Activity Map',
              ),
              backgroundColor: const Color(0xFF0D6658),
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  tooltip: 'Refresh map',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Map only',
                  onPressed: () => setState(() => _showDetails = false),
                  icon: const Icon(Icons.fullscreen),
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          _buildMap(),
          if (_showDetails) ...[
            _buildFilterPanel(),
            _buildLegend(),
            _buildSummary(),
          ] else
            Positioned(
              top: 16,
              right: 16,
              child: _MapButton(
                icon: Icons.fullscreen_exit,
                label: 'Show controls',
                onPressed: () => setState(() => _showDetails = true),
              ),
            ),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (!_isLoading &&
              _clusters.isEmpty &&
              _error == null &&
              _showDetails)
            Positioned(
              left: 24,
              right: 24,
              top: MediaQuery.sizeOf(context).height * 0.43,
              child: _Panel(
                child: Text(
                  widget.staffMode
                      ? 'No accessible cases match this filter. Staff map dots require a submitted case with a report date and coordinates.'
                      : 'No barangay groups meet this filter. The public map needs at least three submitted, dated, non-duplicate cases in a barangay and a barangay map point or case coordinates.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
          if (_error != null && _showDetails)
            Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: Material(
                elevation: 5,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  leading: const Icon(Icons.cloud_off, color: Colors.red),
                  title: Text(_error!),
                  trailing: IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap() => FlutterMap(
    mapController: _mapController,
    options: const MapOptions(
      initialCenter: LatLng(11.14922, 125.66287),
      initialZoom: 13,
      interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
    ),
    children: [
      TileLayer(
        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
        subdomains: const ['a', 'b', 'c'],
        userAgentPackageName: 'com.example.salcedo_dengue_watch',
      ),
      MarkerLayer(
        markers: _clusters.map((cluster) {
          final color = _colorFor(cluster['category'] as String);
          final count = cluster['count'] as int;
          final size = count >= 20
              ? 32.0
              : count >= 10
              ? 27.0
              : 22.0;
          return Marker(
            point: LatLng(cluster['lat'] as double, cluster['lng'] as double),
            width: size + 12,
            height: size + 12,
            child: GestureDetector(
              onTap: () => _showCluster(cluster),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 5),
                    ],
                  ),
                  child: count >= 5
                      ? Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          );
        }).toList(),
      ),
      RichAttributionWidget(
        attributions: [TextSourceAttribution('OpenStreetMap contributors')],
      ),
    ],
  );

  Widget _buildFilterPanel() => Positioned(
    top: 12,
    left: 12,
    right: 12,
    child: _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month, color: Color(0xFF0D6658)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<_MapPeriod>(
                    value: _period,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: _MapPeriod.allTime,
                        child: Text('All time'),
                      ),
                      DropdownMenuItem(
                        value: _MapPeriod.day,
                        child: Text('Day'),
                      ),
                      DropdownMenuItem(
                        value: _MapPeriod.week,
                        child: Text('Week'),
                      ),
                      DropdownMenuItem(
                        value: _MapPeriod.month,
                        child: Text('Month'),
                      ),
                      DropdownMenuItem(
                        value: _MapPeriod.year,
                        child: Text('Year'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) _changePeriod(v);
                    },
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Previous ${_period.name}',
                onPressed: _period == _MapPeriod.allTime
                    ? null
                    : () => _moveWindow(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                _rangeLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              IconButton(
                tooltip: 'Next ${_period.name}',
                onPressed:
                    _rangeEnd == null || _rangeEnd!.isAfter(DateTime.now())
                    ? null
                    : () => _moveWindow(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const Divider(height: 1),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                size: 20,
                color: Color(0xFF0D6658),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedBarangay,
                    isExpanded: true,
                    hint: const Text('All barangays'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All barangays'),
                      ),
                      ...(_barangayNames.toList()..sort()).map(
                        (name) => DropdownMenuItem<String?>(
                          value: name,
                          child: Text(name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedBarangay = value);
                      _loadClusters();
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _buildLegend() => Positioned(
    right: 12,
    bottom: 94,
    child: _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.staffMode ? 'CASE LOCATIONS' : 'BARANGAY CASE GROUPS',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.staffMode) ...[
            _LegendDot(
              color: const Color(0xFFD93636),
              label: 'Current / confirmed',
            ),
            _LegendDot(
              color: const Color(0xFFF28C28),
              label: 'Probable / suspected',
            ),
            _LegendDot(
              color: const Color(0xFF219653),
              label: 'Recovered / resolved',
            ),
            _LegendDot(color: Colors.black, label: 'Deaths'),
          ] else
            _LegendDot(
              color: _colorFor('public_cluster'),
              label: 'Barangays with 3+ reportable cases',
            ),
        ],
      ),
    ),
  );

  Widget _buildSummary() => Positioned(
    bottom: 12,
    left: 12,
    right: 12,
    child: _Panel(
      child: Row(
        children: [
          const Icon(
            Icons.health_and_safety_outlined,
            color: Color(0xFF0D6658),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.staffMode
                  ? '$_totalCases accessible cases  ·  $_rangeLabel'
                  : '$_totalCases cases shown  ·  $_rangeLabel',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(
            Icons.privacy_tip_outlined,
            size: 17,
            color: Colors.black54,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              widget.staffMode
                  ? 'Exact locations shown to authorized staff'
                  : 'One grouped marker per barangay; no individual case locations',
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ),
        ],
      ),
    ),
  );

  void _showCluster(Map<String, dynamic> cluster) {
    final category = cluster['category'] as String;
    final label = switch (category) {
      'public_cluster' => 'Reportable',
      'death' => 'Deaths',
      'recovered' => 'Recovered',
      'resolved' => 'Closed / resolved',
      'probable' => 'Probable / suspected',
      _ => 'Current / confirmed',
    };
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.circle, color: _colorFor(category), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${cluster['count']} $label cases\n${cluster['barangay']} · ${widget.staffMode ? 'exact case location' : 'grouped barangay location'}',
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 6,
    color: Colors.white.withValues(alpha: 0.97),
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: child,
    ),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 6,
    color: Colors.white,
    borderRadius: BorderRadius.circular(28),
    child: IconButton(tooltip: label, onPressed: onPressed, icon: Icon(icon)),
  );
}
