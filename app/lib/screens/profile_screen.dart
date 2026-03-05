import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/activity.dart';
import '../models/user.dart';
import '../data/mock_data.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AppUser currentUser;
  const ProfileScreen({super.key, required this.currentUser});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late List<Activity> _mine;

  @override
  void initState() {
    super.initState();
    _mine = MockData.getMockActivities(widget.currentUser.id)
        .where((a) => a.userId == widget.currentUser.id)
        .toList()..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  double get _dist  => _mine.fold(0.0, (s, a) => s + a.distanceKm);
  int    get _secs  => _mine.fold(0, (s, a)  => s + a.durationSeconds);
  int    get _kcal  => _mine.fold(0, (s, a)  => s + a.calories);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          backgroundColor: AppTheme.white,
          actions: [IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.black),
            onPressed: () => _showSettings(context),
          )],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: AppTheme.white,
              child: SafeArea(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.green, width: 3),
                    ),
                    child: CircleAvatar(radius: 42, backgroundColor: AppTheme.green,
                      child: Text(widget.currentUser.initials,
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w900, fontSize: 26))),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.currentUser.username, style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.black)),
                  const SizedBox(height: 3),
                  Text(widget.currentUser.email,
                      style: const TextStyle(color: AppTheme.grey, fontSize: 12)),
                  if (widget.currentUser.bio != null) ...[
                    const SizedBox(height: 4),
                    Text(widget.currentUser.bio!, textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.grey, fontSize: 12)),
                  ],
                ],
              )),
            ),
          ),
        ),

        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _statsCard(),
            const SizedBox(height: 14),
            _typeBreakdown(),
            const SizedBox(height: 14),
            _recentRides(),
            const SizedBox(height: 14),
            _friends(),
            const SizedBox(height: 24),
          ]),
        )),
      ]),
    );
  }

  Widget _statsCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: _card(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('All-Time Stats', style: TextStyle(fontWeight: FontWeight.w800,
          fontSize: 16, color: AppTheme.black)),
      const SizedBox(height: 16),
      Row(children: [
        _st(Icons.straighten, '${_dist.toStringAsFixed(1)} km', 'Distance', AppTheme.green),
        _st(Icons.bolt, '${_mine.length}', 'Rides', AppTheme.black),
        _st(Icons.local_fire_department, '$_kcal', 'kcal', AppTheme.red),
      ]),
      const Divider(height: 20, color: AppTheme.greyLight),
      Row(children: [
        _st(Icons.timer_outlined, _fmtSecs(_secs), 'Ride Time', Colors.blue),
        _st(Icons.speed, _mine.isNotEmpty
            ? '${(_mine.fold(0.0,(s,a)=>s+a.avgSpeedKmh)/_mine.length).toStringAsFixed(1)} km/h'
            : '--', 'Avg Speed', Colors.purple),
        _st(Icons.trending_up, _mine.isNotEmpty
            ? '${(_dist/_mine.length).toStringAsFixed(1)} km' : '--',
            'Avg Ride', Colors.teal),
      ]),
    ]),
  );

  Widget _st(IconData icon, String val, String lbl, Color c) => Expanded(
    child: Column(children: [
      Icon(icon, color: c, size: 20),
      const SizedBox(height: 4),
      Text(val, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13,
          color: AppTheme.black), textAlign: TextAlign.center),
      Text(lbl, style: const TextStyle(fontSize: 10, color: AppTheme.grey)),
    ]),
  );

  Widget _typeBreakdown() {
    final types = <String, int>{};
    for (final a in _mine) types[a.type] = (types[a.type] ?? 0) + 1;
    final colors = {'run': Colors.orange, 'cycle': AppTheme.green,
        'walk': Colors.teal, 'hike': Colors.brown};
    final icons  = {'run': '🏃', 'cycle': '🚴', 'walk': '🚶', 'hike': '🥾'};
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Activity Types', style: TextStyle(fontWeight: FontWeight.w800,
            fontSize: 16, color: AppTheme.black)),
        const SizedBox(height: 14),
        ...types.entries.map((e) {
          final pct = e.value / _mine.length;
          final c = colors[e.key] ?? AppTheme.green;
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(children: [
            Row(children: [
              Text(icons[e.key] ?? '🚴', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Text(e.key[0].toUpperCase() + e.key.substring(1),
                  style: const TextStyle(color: AppTheme.black, fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${e.value} ride${e.value > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.grey)),
            ]),
            const SizedBox(height: 5),
            ClipRRect(borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: pct, minHeight: 7,
                  backgroundColor: AppTheme.greyLight,
                  valueColor: AlwaysStoppedAnimation<Color>(c))),
          ]));
        }),
      ]),
    );
  }

  Widget _recentRides() => Container(
    decoration: _card(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Text('Recent Rides', style: const TextStyle(fontWeight: FontWeight.w800,
            fontSize: 16, color: AppTheme.black))),
      ..._mine.take(4).map((a) => Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.greenLight,
                borderRadius: BorderRadius.circular(12)),
            child: Text(a.typeIcon, style: const TextStyle(fontSize: 16))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700,
                fontSize: 13, color: AppTheme.black), maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(DateFormat('MMM d · HH:mm').format(a.startTime),
                style: const TextStyle(fontSize: 11, color: AppTheme.grey)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${a.distanceKm.toStringAsFixed(1)} km',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13,
                    color: AppTheme.greenDark)),
            Text(a.formattedDuration,
                style: const TextStyle(fontSize: 11, color: AppTheme.grey)),
          ]),
        ])),
        if (a != _mine.take(4).last) const Divider(height: 1, indent: 16, endIndent: 16,
            color: AppTheme.greyLight),
      ])),
    ]),
  );

  Widget _friends() {
    final friends = widget.currentUser.friendIds
        .map((id) => UserData.getUserById(id))
        .whereType<AppUser>().toList();
    const colors = [Colors.blue, Colors.green, Colors.purple, Colors.teal, Colors.indigo];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Following (${friends.length})', style: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.black)),
        const SizedBox(height: 14),
        SizedBox(height: 70, child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: friends.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(children: [
              CircleAvatar(radius: 22,
                  backgroundColor: colors[i % colors.length],
                  child: Text(friends[i].initials,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 12))),
              const SizedBox(height: 5),
              Text(friends[i].username.split(' ').first,
                  style: const TextStyle(fontSize: 10, color: AppTheme.grey)),
            ]),
          ),
        )),
      ]),
    );
  }

  BoxDecoration _card() => BoxDecoration(
    color: AppTheme.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppTheme.greyLight),
  );

  String _fmtSecs(int s) {
    final h = s ~/ 3600; final m = (s % 3600) ~/ 60;
    return '${h}h ${m}m';
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(context: context,
      backgroundColor: AppTheme.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.greyLight,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ListTile(leading: const Icon(Icons.person_outline, color: AppTheme.green),
              title: const Text('Edit Profile'), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.notifications_outlined, color: AppTheme.green),
              title: const Text('Notifications'), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.info_outline, color: AppTheme.green),
              title: const Text('About GPP Cycling'),
              subtitle: const Text('CASA0021 Group Project · v1.0',
                  style: TextStyle(fontSize: 11)),
              onTap: () => Navigator.pop(context)),
          const Divider(),
          ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.red),
              title: const Text('Log Out', style: TextStyle(color: AppTheme.red)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
              }),
          const SizedBox(height: 12),
        ],
      )),
    );
  }
}
