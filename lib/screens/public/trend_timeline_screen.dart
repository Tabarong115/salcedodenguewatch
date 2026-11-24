import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../services/data_service.dart';

class TrendTimelineScreen extends StatefulWidget {
  const TrendTimelineScreen({super.key});

  @override
  State<TrendTimelineScreen> createState() => _TrendTimelineScreenState();
}

class _TrendTimelineScreenState extends State<TrendTimelineScreen> {
  final DataService _dataService = DataService();
  Timer? _playbackTimer;
  bool _isLoading = true;
  String? _error;
  String? _selectedBarangay;
  List<Map<String, dynamic>> _weeklyRows = [];
  List<String> _barangays = [];
  List<_WeekPoint> _points = [];
  int _visibleIndex = 0;

  static const _green = Color(0xFF087F5B);
  static const _darkGreen = Color(0xFF075B45);
  static const _paleGreen = Color(0xFFEAF6F0);

  @override
  void initState() {
    super.initState();
    _loadTrendData();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTrendData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final weeklyRows = await _dataService
          .getPublicWeeklyCaseSummary()
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      final barangays = weeklyRows
          .map((row) => row['barangay']?.toString())
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();
      setState(() {
        _weeklyRows = weeklyRows;
        _barangays = barangays;
        _isLoading = false;
        _error = null;
        _rebuildPoints(reset: true);
      });
    } on TimeoutException catch (error, stackTrace) {
      _showLoadError(error, stackTrace);
    } catch (error, stackTrace) {
      _showLoadError(error, stackTrace);
    }
  }

  void _showLoadError(Object error, StackTrace stackTrace) {
    debugPrint('Unable to load public dengue timeline: $error\n$stackTrace');
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _error = 'Unable to load public trend data. Check your connection or Supabase setup, then try again.';
    });
  }

  DateTime _weekStart(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  void _rebuildPoints({bool reset = false}) {
    final filtered = _weeklyRows.where((row) =>
        _selectedBarangay == null || row['barangay'] == _selectedBarangay);
    final counts = <DateTime, int>{};
    for (final row in filtered) {
      final date = DateTime.tryParse(row['week_starting']?.toString() ?? '');
      if (date == null) continue;
      final week = _weekStart(date.toUtc());
      counts[week] = (counts[week] ?? 0) + ((row['case_count'] as num?)?.toInt() ?? 0);
    }

    final nowWeek = _weekStart(DateTime.now().toUtc());
    final start = counts.keys.isEmpty
        ? nowWeek
        : counts.keys.reduce((a, b) => a.isBefore(b) ? a : b);
    final weeks = <_WeekPoint>[];
    for (var date = start; !date.isAfter(nowWeek); date = date.add(const Duration(days: 7))) {
      weeks.add(_WeekPoint(date, counts[date] ?? 0));
    }
    _points = weeks;
    _visibleIndex = reset ? math.max(0, weeks.length - 1).toInt() : _visibleIndex.clamp(0, math.max(0, weeks.length - 1)).toInt();
    if (reset) _playbackTimer?.cancel();
  }

  void _togglePlayback() {
    if (_points.length < 2) return;
    if (_playbackTimer != null) {
      _playbackTimer!.cancel();
      _playbackTimer = null;
      setState(() {});
      return;
    }
    if (_visibleIndex >= _points.length - 1) {
      setState(() => _visibleIndex = 0);
    }
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _visibleIndex >= _points.length - 1) {
        timer.cancel();
        _playbackTimer = null;
        if (mounted) setState(() {});
        return;
      }
      setState(() => _visibleIndex++);
    });
    setState(() {});
  }

  void _seek(double value) {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    setState(() => _visibleIndex = value.round().clamp(0, math.max(0, _points.length - 1)).toInt());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      appBar: AppBar(
        title: Text('Trends & Timeline'.tr()),
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(tooltip: 'Refresh'.tr(), icon: const Icon(Icons.refresh), onPressed: _isLoading ? null : _loadTrendData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _messageState(Icons.wifi_off_rounded, _error!, action: _loadTrendData)
              : _points.isEmpty || _weeklyRows.isEmpty
                  ? _messageState(Icons.show_chart_rounded, 'No reportable weekly trend data is available yet.')
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final current = _points[_visibleIndex];
    final visible = _points.take(_visibleIndex + 1).toList();
    final peak = visible.fold<int>(
      0,
      (maximum, point) => math.max(maximum, point.count).toInt(),
    );
    final total = visible.fold<int>(0, (sum, point) => sum + point.count);
    final previous = _visibleIndex > 0 ? _points[_visibleIndex - 1].count : 0;
    final delta = current.count - previous;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _buildIntro(),
        const SizedBox(height: 14),
        _buildChartCard(current, visible, peak),
        const SizedBox(height: 14),
        _buildPlaybackCard(),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _metricCard('Cases shown'.tr(), '$total', Icons.coronavirus_outlined)),
          const SizedBox(width: 10),
          Expanded(child: _metricCard('Selected week'.tr(), '${current.count}', Icons.calendar_today_outlined)),
          const SizedBox(width: 10),
          Expanded(child: _metricCard('Change'.tr(), delta > 0 ? '+$delta' : '$delta', delta > 0 ? Icons.trending_up : Icons.trending_down, color: delta > 0 ? Colors.deepOrange : _green)),
        ]),
        const SizedBox(height: 14),
        _buildBarangaySummary(),
        const SizedBox(height: 12),
        _buildPrivacyNote(),
      ],
    );
  }

  Widget _buildIntro() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_darkGreen, _green], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.insights_rounded, color: Colors.white, size: 28)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Weekly dengue activity'.tr(), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('One second of playback advances one week.'.tr(), style: TextStyle(color: Colors.white.withValues(alpha: .86), fontSize: 13)),
          ])),
        ]),
      );

  Widget _buildChartCard(_WeekPoint current, List<_WeekPoint> visible, int peak) => Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cases over time'.tr(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(_selectedBarangay ?? 'All barangays'.tr(), style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13)),
              ])),
              DropdownButtonHideUnderline(child: DropdownButton<String?>(
                value: _selectedBarangay,
                borderRadius: BorderRadius.circular(12),
                items: [DropdownMenuItem<String?>(value: null, child: Text('Municipality'.tr())), ..._barangays.map((name) => DropdownMenuItem<String?>(value: name, child: Text(name, overflow: TextOverflow.ellipsis)))],
                onChanged: (value) => setState(() { _selectedBarangay = value; _rebuildPoints(reset: true); }),
              )),
            ]),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${current.count}', style: const TextStyle(fontSize: 34, height: 1, color: _darkGreen, fontWeight: FontWeight.w800)),
              const SizedBox(width: 9),
              Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('reportable cases'.tr(), style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade600))),
              const Spacer(),
              Text(DateFormat('MMM d, yyyy').format(current.start), style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600)),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 310,
              width: double.infinity,
              child: Semantics(
                label: 'Weekly dengue case trend chart'.tr(),
                child: CustomPaint(painter: _TrendChartPainter(points: visible, maxValue: peak, color: _green, gridColor: const Color(0xFFE7EEEA), textDirection: Directionality.of(context))),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_points.isEmpty ? '' : DateFormat('MMM yyyy').format(_points.first.start), style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade500)),
              Text('Week ${_visibleIndex + 1} of ${_points.length}', style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade500)),
              Text(DateFormat('MMM yyyy').format(_points.last.start), style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade500)),
            ]),
          ]),
        ),
      );

  Widget _buildPlaybackCard() => Card(
        margin: EdgeInsets.zero,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(children: [
            Row(children: [
              IconButton.filled(icon: Icon(_playbackTimer == null ? Icons.play_arrow_rounded : Icons.pause_rounded), style: IconButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white), tooltip: _playbackTimer == null ? 'Play'.tr() : 'Pause'.tr(), onPressed: _togglePlayback),
              const SizedBox(width: 6),
              Expanded(child: Text(_playbackTimer == null ? 'Play timeline'.tr() : 'Playing · 1 week/second'.tr(), style: const TextStyle(fontWeight: FontWeight.w600))),
              IconButton(tooltip: 'Restart'.tr(), onPressed: () { _playbackTimer?.cancel(); _playbackTimer = null; setState(() => _visibleIndex = 0); }, icon: const Icon(Icons.replay_rounded)),
              IconButton(tooltip: 'Show latest'.tr(), onPressed: () { _playbackTimer?.cancel(); _playbackTimer = null; setState(() => _visibleIndex = math.max(0, _points.length - 1).toInt()); }, icon: const Icon(Icons.last_page_rounded)),
            ]),
            Slider(value: _visibleIndex.toDouble(), min: 0, max: math.max(1, _points.length - 1).toDouble(), divisions: _points.length > 1 ? _points.length - 1 : null, activeColor: _green, onChanged: _points.length > 1 ? _seek : null),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_points.isEmpty ? '' : DateFormat('MMM d, yyyy').format(_points.first.start), style: const TextStyle(fontSize: 11)),
              Text(_points.isEmpty ? '' : DateFormat('MMM d, yyyy').format(_points[_visibleIndex].start), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _darkGreen)),
              Text(_points.isEmpty ? '' : 'Present'.tr(), style: const TextStyle(fontSize: 11)),
            ]),
          ]),
        ),
      );

  Widget _metricCard(String label, String value, IconData icon, {Color color = _green}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5ECE8))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color))),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade600)),
        ]),
      );

  Widget _buildBarangaySummary() {
    final latest = _points.take(_visibleIndex + 1).toList();
    final totals = <String, int>{};
    for (final row in _weeklyRows) {
      final name = row['barangay']?.toString();
      final date = DateTime.tryParse(row['week_starting']?.toString() ?? '');
      if (name == null || date == null || date.isAfter(latest.last.start)) continue;
      totals[name] = (totals[name] ?? 0) + ((row['case_count'] as num?)?.toInt() ?? 0);
    }
    final ranked = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (_selectedBarangay != null || ranked.isEmpty) return const SizedBox.shrink();
    final maxCount = ranked.first.value;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Barangay totals through selected week'.tr(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        ...ranked.take(6).map((entry) => Padding(padding: const EdgeInsets.only(bottom: 11), child: Column(children: [
          Row(children: [Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 13))), Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.w700))]),
          const SizedBox(height: 5),
          ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: entry.value / maxCount, minHeight: 7, backgroundColor: _paleGreen, color: _green)),
        ]))),
      ])),
    );
  }

  Widget _buildPrivacyNote() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _paleGreen, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, color: _darkGreen, size: 19),
          const SizedBox(width: 9),
          Expanded(child: Text('Public chart counts use submitted, dated, non-duplicate cases. Barangay-week groups below three cases are suppressed, so totals show reportable activity only. The timeline begins at the earliest reportable week.'.tr(), style: const TextStyle(fontSize: 12, height: 1.4, color: _darkGreen))),
        ]),
      );

  Widget _messageState(IconData icon, String message, {VoidCallback? action}) => Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 58, color: Colors.blueGrey.shade300),
        const SizedBox(height: 16),
        Text(message.tr(), textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 15)),
        if (action != null) ...[const SizedBox(height: 16), FilledButton.icon(onPressed: action, icon: const Icon(Icons.refresh), label: Text('Try again'.tr()))],
      ])));
}

class _WeekPoint {
  const _WeekPoint(this.start, this.count);
  final DateTime start;
  final int count;
}

class _TrendChartPainter extends CustomPainter {
  const _TrendChartPainter({required this.points, required this.maxValue, required this.color, required this.gridColor, required this.textDirection});
  final List<_WeekPoint> points;
  final int maxValue;
  final Color color;
  final Color gridColor;
  final ui.TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 38.0;
    const right = 8.0;
    const top = 12.0;
    const bottom = 28.0;
    final chart = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final high = math.max(1, maxValue);
    final gridPaint = Paint()..color = gridColor..strokeWidth = 1;
    final labelStyle = TextStyle(color: Colors.blueGrey.shade400, fontSize: 10);
    for (var i = 0; i <= 4; i++) {
      final y = chart.bottom - chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final label = TextPainter(text: TextSpan(text: '${(high * i / 4).round()}', style: labelStyle), textDirection: textDirection)..layout();
      label.paint(canvas, Offset(0, y - label.height / 2));
    }
    if (points.isEmpty) return;
    final dx = points.length <= 1 ? 0.0 : chart.width / (points.length - 1);
    final path = Path();
    final fill = Path();
    for (var i = 0; i < points.length; i++) {
      final x = chart.left + dx * i;
      final y = chart.bottom - (points[i].count / high) * chart.height;
      if (i == 0) { path.moveTo(x, y); fill.moveTo(x, chart.bottom); fill.lineTo(x, y); }
      else { path.lineTo(x, y); fill.lineTo(x, y); }
    }
    fill.lineTo(chart.left + dx * (points.length - 1), chart.bottom);
    fill.close();
    canvas.drawPath(fill, Paint()..shader = LinearGradient(colors: [color.withValues(alpha: .27), color.withValues(alpha: .015)], begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(chart));
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 3..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round);
    final lastX = chart.left + dx * (points.length - 1);
    final lastY = chart.bottom - (points.last.count / high) * chart.height;
    canvas.drawCircle(Offset(lastX, lastY), 7, Paint()..color = color.withValues(alpha: .16));
    canvas.drawCircle(Offset(lastX, lastY), 4, Paint()..color = color);
    final dates = <int>{0, points.length ~/ 2, points.length - 1};
    for (final index in dates) {
      final date = points[index].start;
      final text = TextPainter(text: TextSpan(text: DateFormat('MMM yy').format(date), style: labelStyle), textDirection: textDirection)..layout();
      final x = (chart.left + dx * index - text.width / 2).clamp(chart.left, chart.right - text.width).toDouble();
      text.paint(canvas, Offset(x, chart.bottom + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) => oldDelegate.points != points || oldDelegate.maxValue != maxValue || oldDelegate.color != color;
}
