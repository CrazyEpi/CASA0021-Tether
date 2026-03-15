import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/activity.dart';
import '../widgets/route_map_thumbnail.dart';

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
            backgroundColor: AppTheme.greenDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // Real map background (or green gradient fallback)
                  Positioned.fill(
                    child: RouteMapThumbnail(
                      points: activity.route,
                      height: 200,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  // Green gradient overlay so title text stays readable
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppTheme.greenDark.withOpacity(0.80),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Activity info at the bottom
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
          Icon(icon, size: 16, color: AppTheme.greenDark),
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
                const Icon(Icons.map, size: 16, color: AppTheme.greenDark),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: RouteMapThumbnail(
              points: activity.route,
              isDetailView: true,
              height: 220,
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// Route display is now handled by widgets/route_map_thumbnail.dart

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
              const Icon(Icons.analytics_outlined, size: 16, color: AppTheme.greenDark),
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
              const Icon(Icons.gps_fixed, size: 16, color: AppTheme.greenDark),
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
              const Icon(Icons.notes, size: 16, color: AppTheme.greenDark),
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

