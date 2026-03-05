import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/activity.dart';

class ActivityDetailScreen extends StatelessWidget {
  final Activity activity;
  final bool isCurrentUser;

  const ActivityDetailScreen({
    super.key,
    required this.activity,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // Hero app bar with gradient
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppTheme.primaryOrange,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFC5200), Color(0xFFFF8C42)],
                  ),
                ),
                child: Stack(
                  children: [
                    // Route mini map
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.3,
                        child: CustomPaint(
                          painter: _RoutePainter(activity.route),
                        ),
                      ),
                    ),
                    // Activity info
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(activity.typeIcon, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  activity.typeLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            activity.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('EEEE, MMMM d · HH:mm').format(activity.startTime),
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primary stats
                  _PrimaryStatsCard(activity: activity, isDark: isDark),
                  const SizedBox(height: 16),

                  // Route map
                  _RouteMapCard(activity: activity, isDark: isDark),
                  const SizedBox(height: 16),

                  // Detailed stats
                  _DetailedStatsCard(activity: activity, isDark: isDark),
                  const SizedBox(height: 16),

                  // GPS Data points
                  _GpsDataCard(activity: activity, isDark: isDark),

                  if (activity.description != null && activity.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _DescriptionCard(activity: activity, isDark: isDark),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryStatsCard extends StatelessWidget {
  final Activity activity;
  final bool isDark;
  const _PrimaryStatsCard({required this.activity, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _bigStat('${activity.distanceKm.toStringAsFixed(2)}', 'km', 'Distance', isDark),
              _vertDivider(isDark),
              _bigStat(activity.formattedDuration, '', 'Duration', isDark),
              _vertDivider(isDark),
              _bigStat(activity.formattedPace, '', 'Avg Pace', isDark),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: isDark ? Colors.white10 : Colors.grey[100], height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              _smallStat(Icons.speed, '${activity.avgSpeedKmh.toStringAsFixed(1)} km/h', 'Avg Speed', isDark),
              _smallStat(Icons.flash_on, '${activity.maxSpeedKmh.toStringAsFixed(1)} km/h', 'Max Speed', isDark),
              _smallStat(Icons.local_fire_department, '${activity.calories} kcal', 'Calories', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bigStat(String value, String unit, String label, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              children: unit.isNotEmpty ? [
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : Colors.grey[500],
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ] : [],
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: isDark ? Colors.white38 : Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _smallStat(IconData icon, String value, String label, bool isDark) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryOrange),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black87,
                    )),
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vertDivider(bool isDark) {
    return Container(
      width: 1,
      height: 40,
      color: isDark ? Colors.white10 : Colors.grey[100],
    );
  }
}

class _RouteMapCard extends StatelessWidget {
  final Activity activity;
  final bool isDark;
  const _RouteMapCard({required this.activity, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.map, size: 16, color: AppTheme.primaryOrange),
                const SizedBox(width: 8),
                Text('Route',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    )),
                const Spacer(),
                Text('${activity.route.length} GPS points',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.grey[500])),
              ],
            ),
          ),
          Container(
            height: 220,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0D1B2A), const Color(0xFF1A2A3A)]
                    : [const Color(0xFFE8F4FD), const Color(0xFFCCE7F5)],
              ),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _FullRoutePainter(activity.route, isDark),
                  ),
                ),
                // Start/End markers
                if (activity.route.isNotEmpty)
                  _RouteMarker(label: 'A', color: Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteMarker extends StatelessWidget {
  final String label;
  final Color color;
  const _RouteMarker({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: Colors.white, size: 12),
            SizedBox(width: 4),
            Text('London, UK', style: TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _DetailedStatsCard extends StatelessWidget {
  final Activity activity;
  final bool isDark;
  const _DetailedStatsCard({required this.activity, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, size: 16, color: AppTheme.primaryOrange),
              const SizedBox(width: 8),
              Text('Detailed Stats',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
            ],
          ),
          const SizedBox(height: 14),
          _detailRow('Start Time', DateFormat('HH:mm:ss').format(activity.startTime), isDark),
          _detailRow('End Time', DateFormat('HH:mm:ss').format(activity.endTime), isDark),
          _detailRow('Duration', activity.formattedDuration, isDark),
          _detailRow('Distance', '${activity.distanceKm.toStringAsFixed(3)} km', isDark),
          _detailRow('Avg Speed', '${activity.avgSpeedKmh.toStringAsFixed(2)} km/h', isDark),
          _detailRow('Max Speed', '${activity.maxSpeedKmh.toStringAsFixed(2)} km/h', isDark),
          _detailRow('Avg Pace', activity.formattedPace, isDark),
          _detailRow('Calories', '${activity.calories} kcal', isDark),
          _detailRow('GPS Points', '${activity.route.length}', isDark),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[500],
                    fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text(value,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                )),
          ),
        ],
      ),
    );
  }
}

class _GpsDataCard extends StatelessWidget {
  final Activity activity;
  final bool isDark;
  const _GpsDataCard({required this.activity, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final points = activity.route.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gps_fixed, size: 16, color: AppTheme.primaryOrange),
              const SizedBox(width: 8),
              Text('GPS Data Sample',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
              const Spacer(),
              Text('(first 5 of ${activity.route.length})',
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 12),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _headerCell('Lat', isDark),
                _headerCell('Lng', isDark),
                _headerCell('Speed', isDark),
                _headerCell('Dist', isDark),
              ],
            ),
          ),
          ...points.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                _dataCell(e.value.lat.toStringAsFixed(5), isDark),
                _dataCell(e.value.lng.toStringAsFixed(5), isDark),
                _dataCell('${e.value.speed.toStringAsFixed(1)} km/h', isDark),
                _dataCell('${e.value.totalDistance.toStringAsFixed(2)} km', isDark),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _headerCell(String text, bool isDark) {
    return Expanded(
      child: Text(text,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : Colors.grey[500])),
    );
  }

  Widget _dataCell(String text, bool isDark) {
    return Expanded(
      child: Text(text,
          style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white70 : Colors.black87,
              fontFamily: 'monospace')),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  final Activity activity;
  final bool isDark;
  const _DescriptionCard({required this.activity, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes, size: 16, color: AppTheme.primaryOrange),
              const SizedBox(width: 8),
              Text('Notes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          Text(activity.description ?? '',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
                height: 1.5,
              )),
        ],
      ),
    );
  }
}

// Route painters
class _RoutePainter extends CustomPainter {
  final List<GpsPoint> points;
  _RoutePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    double minLat = points.map((p) => p.lat).reduce((a, b) => a < b ? a : b);
    double maxLat = points.map((p) => p.lat).reduce((a, b) => a > b ? a : b);
    double minLng = points.map((p) => p.lng).reduce((a, b) => a < b ? a : b);
    double maxLng = points.map((p) => p.lng).reduce((a, b) => a > b ? a : b);
    double latRange = (maxLat - minLat == 0) ? 0.001 : maxLat - minLat;
    double lngRange = (maxLng - minLng == 0) ? 0.001 : maxLng - minLng;

    final pad = 20.0;
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = pad + ((points[i].lng - minLng) / lngRange) * (size.width - pad * 2);
      final y = pad + (1 - (points[i].lat - minLat) / latRange) * (size.height - pad * 2);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FullRoutePainter extends CustomPainter {
  final List<GpsPoint> points;
  final bool isDark;
  _FullRoutePainter(this.points, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final trackPaint = Paint()
      ..color = AppTheme.primaryOrange
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    double minLat = points.map((p) => p.lat).reduce((a, b) => a < b ? a : b);
    double maxLat = points.map((p) => p.lat).reduce((a, b) => a > b ? a : b);
    double minLng = points.map((p) => p.lng).reduce((a, b) => a < b ? a : b);
    double maxLng = points.map((p) => p.lng).reduce((a, b) => a > b ? a : b);
    double latRange = (maxLat - minLat == 0) ? 0.001 : maxLat - minLat;
    double lngRange = (maxLng - minLng == 0) ? 0.001 : maxLng - minLng;

    final pad = 24.0;
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = pad + ((points[i].lng - minLng) / lngRange) * (size.width - pad * 2);
      final y = pad + (1 - (points[i].lat - minLat) / latRange) * (size.height - pad * 2);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    canvas.drawPath(path, trackPaint);

    // Start point
    final startPt = points.first;
    final sx = pad + ((startPt.lng - minLng) / lngRange) * (size.width - pad * 2);
    final sy = pad + (1 - (startPt.lat - minLat) / latRange) * (size.height - pad * 2);
    canvas.drawCircle(Offset(sx, sy), 7, Paint()..color = Colors.green..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(sx, sy), 7, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);

    // End point
    final endPt = points.last;
    final ex = pad + ((endPt.lng - minLng) / lngRange) * (size.width - pad * 2);
    final ey = pad + (1 - (endPt.lat - minLat) / latRange) * (size.height - pad * 2);
    canvas.drawCircle(Offset(ex, ey), 7, Paint()..color = Colors.red..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(ex, ey), 7, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
