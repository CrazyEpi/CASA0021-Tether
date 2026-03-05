import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/activity.dart';
import '../models/user.dart';
import '../data/mock_data.dart';
import 'activity_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppUser currentUser;
  const HomeScreen({super.key, required this.currentUser});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<Activity> _activities;
  final Set<String> _kudosed = {};

  @override
  void initState() {
    super.initState();
    _activities = MockData.getMockActivities(widget.currentUser.id)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final myWeek = _activities.where((a) =>
        a.userId == widget.currentUser.id &&
        a.startTime.isAfter(weekStart)).toList();
    final weekDist = myWeek.fold(0.0, (s, a) => s + a.distanceKm);
    final weekTime = myWeek.fold(0, (s, a) => s + a.durationSeconds);

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: CustomScrollView(slivers: [
        // ── Header ──
        SliverToBoxAdapter(child: Container(
          color: AppTheme.white,
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_greeting(), style: const TextStyle(color: AppTheme.grey, fontSize: 13)),
                const SizedBox(height: 2),
                Text(widget.currentUser.username.split(' ').first,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                        color: AppTheme.black, letterSpacing: -0.5)),
              ])),
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: AppTheme.green, borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text(widget.currentUser.initials,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))),
              ),
            ]),
            const SizedBox(height: 16),
            // ── Week stats row ──
            Row(children: [
              _weekStat('${weekDist.toStringAsFixed(1)} km', 'This week', AppTheme.green),
              const SizedBox(width: 10),
              _weekStat(_fmtDuration(weekTime), 'Ride time', AppTheme.black),
              const SizedBox(width: 10),
              _weekStat('${myWeek.length}', 'Rides', Colors.blue),
            ]),
          ]),
        )),

        // ── Feed label ──
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(children: [
            const Text('Activity Feed', style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.w800, color: AppTheme.black, letterSpacing: -0.3)),
            const Spacer(),
            Text('You + friends', style: TextStyle(fontSize: 12, color: AppTheme.grey)),
          ]),
        )),

        // ── Activity cards ──
        SliverList(delegate: SliverChildBuilderDelegate(
          (ctx, i) => _RideCard(
            activity: _activities[i],
            isMe: _activities[i].userId == widget.currentUser.id,
            kudosed: _kudosed.contains(_activities[i].id),
            onKudos: () => setState(() {
              _kudosed.contains(_activities[i].id)
                  ? _kudosed.remove(_activities[i].id)
                  : _kudosed.add(_activities[i].id);
            }),
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ActivityDetailScreen(
                    activity: _activities[i],
                    isCurrentUser: _activities[i].userId == widget.currentUser.id))),
          ),
          childCount: _activities.length,
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ]),
    );
  }

  Widget _weekStat(String value, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
        const SizedBox(height: 1),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.grey)),
      ]),
    ),
  );

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning 🌅';
    if (h < 17) return 'Good afternoon ☀️';
    return 'Good evening 🌙';
  }

  String _fmtDuration(int s) {
    final h = s ~/ 3600; final m = (s % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

// ── Ride Card ──
class _RideCard extends StatelessWidget {
  final Activity activity;
  final bool isMe, kudosed;
  final VoidCallback onKudos, onTap;
  const _RideCard({required this.activity, required this.isMe,
      required this.kudosed, required this.onKudos, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isMe ? AppTheme.green.withOpacity(0.4) : AppTheme.greyLight),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 0), child: Row(children: [
            _avatar(activity.userName, activity.userId, isMe),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(activity.userName, style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.black)),
                if (isMe) ...[const SizedBox(width: 6), _youBadge()],
              ]),
              Text(_timeAgo(activity.startTime),
                  style: const TextStyle(color: AppTheme.grey, fontSize: 11)),
            ])),
            _typeBadge(activity),
          ])),

          // Title
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(activity.title, style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.black,
                letterSpacing: -0.3))),

          if (activity.description != null && activity.description!.isNotEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(activity.description!,
                  style: const TextStyle(fontSize: 13, color: AppTheme.grey),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),

          // Stats
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Row(children: [
            _statBox('${activity.distanceKm.toStringAsFixed(1)} km', 'Distance'),
            _divider(), _statBox(activity.formattedDuration, 'Duration'),
            _divider(), _statBox('${activity.avgSpeedKmh.toStringAsFixed(1)} km/h', 'Avg Speed'),
            _divider(), _statBox('${activity.calories}', 'kcal'),
          ])),

          // Route sketch
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.greenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(size: Size.infinite,
                  painter: _RoutePainter(activity.route)),
            ),
          ),

          // Footer
          Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 14), child: Row(children: [
            GestureDetector(
              onTap: isMe ? null : onKudos,
              child: Row(children: [
                Icon(kudosed ? Icons.thumb_up : Icons.thumb_up_outlined,
                    size: 17,
                    color: kudosed ? AppTheme.greenDark : AppTheme.grey),
                const SizedBox(width: 5),
                Text('${activity.kudos + (kudosed ? 1 : 0)}',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: kudosed ? AppTheme.greenDark : AppTheme.grey)),
              ]),
            ),
            const Spacer(),
            Text(DateFormat('MMM d').format(activity.startTime),
                style: const TextStyle(fontSize: 11, color: AppTheme.grey)),
          ])),
        ]),
      ),
    );
  }

  Widget _avatar(String name, String id, bool isMe) {
    final colors = [Colors.blue, Colors.purple, Colors.teal, Colors.indigo, Colors.orange];
    final color = isMe ? AppTheme.green : colors[id.hashCode.abs() % colors.length];
    final parts = name.split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.substring(0, 2).toUpperCase();
    return CircleAvatar(radius: 18, backgroundColor: color,
        child: Text(initials, style: const TextStyle(color: Colors.white,
            fontWeight: FontWeight.w700, fontSize: 11)));
  }

  Widget _youBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: AppTheme.greenLight, borderRadius: BorderRadius.circular(6)),
    child: const Text('You', style: TextStyle(color: AppTheme.greenDark, fontSize: 10,
        fontWeight: FontWeight.w700)),
  );

  Widget _typeBadge(Activity a) {
    final colors = {'run': Colors.orange, 'cycle': AppTheme.green, 'walk': Colors.teal, 'hike': Colors.brown};
    final c = colors[a.type] ?? AppTheme.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(a.typeIcon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(a.typeLabel, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _statBox(String val, String lbl) => Expanded(child: Column(children: [
    Text(val, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.black)),
    Text(lbl, style: const TextStyle(fontSize: 9, color: AppTheme.grey)),
  ]));

  Widget _divider() => Container(width: 1, height: 22, color: AppTheme.greyLight);

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays == 1) return 'Yesterday';
    return '${d.inDays}d ago';
  }
}

class _RoutePainter extends CustomPainter {
  final List<GpsPoint> pts;
  _RoutePainter(this.pts);
  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final paint = Paint()..color = AppTheme.greenDark..strokeWidth = 2.5
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    double minLat = pts.map((p) => p.lat).reduce((a, b) => a < b ? a : b);
    double maxLat = pts.map((p) => p.lat).reduce((a, b) => a > b ? a : b);
    double minLng = pts.map((p) => p.lng).reduce((a, b) => a < b ? a : b);
    double maxLng = pts.map((p) => p.lng).reduce((a, b) => a > b ? a : b);
    double lR = (maxLat - minLat).abs(); if (lR < 0.0001) lR = 0.001;
    double gR = (maxLng - minLng).abs(); if (gR < 0.0001) gR = 0.001;
    const pad = 10.0;
    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final x = pad + ((pts[i].lng - minLng) / gR) * (size.width - pad * 2);
      final y = pad + (1 - (pts[i].lat - minLat) / lR) * (size.height - pad * 2);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(_) => false;
}
