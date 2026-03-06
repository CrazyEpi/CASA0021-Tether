import 'package:flutter/material.dart';
import '../main.dart';
import '../models/user.dart';
import '../data/mock_data.dart';

class LeaderboardScreen extends StatefulWidget {
  final AppUser currentUser;
  const LeaderboardScreen({super.key, required this.currentUser});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late List<LeaderboardEntry> _entries;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _entries = MockData.getMockLeaderboard(widget.currentUser.id);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Rankings'),
        backgroundColor: AppTheme.white,
        bottom: TabBar(
          controller: _tab,
          labelColor: AppTheme.black,
          unselectedLabelColor: AppTheme.grey,
          indicatorColor: AppTheme.green,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [Tab(text: 'This Month'), Tab(text: 'All Time')],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        _buildTab(monthly: true),
        _buildTab(monthly: false),
      ]),
    );
  }

  Widget _buildTab({required bool monthly}) {
    final sorted = List<LeaderboardEntry>.from(_entries)
      ..sort((a, b) => monthly
          ? b.totalDistanceKm.compareTo(a.totalDistanceKm)
          : b.totalActivities.compareTo(a.totalActivities));

    return SingleChildScrollView(
      child: Column(children: [
        const SizedBox(height: 16),
        if (sorted.length >= 3) _podium(sorted.take(3).toList(), monthly),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.greyLight),
          ),
          child: Column(children: sorted.asMap().entries.map((e) {
            final rank = e.key + 1;
            return _Row(rank: rank, entry: e.value, monthly: monthly,
                isLast: rank == sorted.length);
          }).toList()),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _podium(List<LeaderboardEntry> top3, bool monthly) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: _PodiumCol(entry: top3[1], rank: 2, height: 100, monthly: monthly)),
        const SizedBox(width: 8),
        Expanded(child: _PodiumCol(entry: top3[0], rank: 1, height: 130, monthly: monthly)),
        const SizedBox(width: 8),
        Expanded(child: _PodiumCol(entry: top3[2], rank: 3, height: 80, monthly: monthly)),
      ]),
    );
  }
}

class _PodiumCol extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final double height;
  final bool monthly;
  const _PodiumCol({required this.entry, required this.rank,
      required this.height, required this.monthly});

  @override
  Widget build(BuildContext context) {
    final medals = [AppTheme.green, AppTheme.grey, const Color(0xFFCD7F32)];
    final icons  = ['🥇','🥈','🥉'];
    final c = medals[rank - 1];
    return Column(children: [
      if (entry.isCurrentUser)
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: AppTheme.greenLight, borderRadius: BorderRadius.circular(8)),
          child: const Text('You', style: TextStyle(color: AppTheme.greenDark, fontSize: 9, fontWeight: FontWeight.w800)),
        ),
      CircleAvatar(radius: rank == 1 ? 24 : 20,
          backgroundColor: entry.isCurrentUser ? AppTheme.green : _avatarColor(entry.user.id),
          child: Text(entry.user.initials,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                  fontSize: rank == 1 ? 13 : 11))),
      const SizedBox(height: 4),
      Text(entry.user.username.split(' ').first,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.black),
          maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
      Text(monthly ? '${entry.totalDistanceKm.toStringAsFixed(1)} km' : '${entry.totalActivities}',
          style: const TextStyle(fontSize: 10, color: AppTheme.grey)),
      const SizedBox(height: 4),
      Container(
        height: height,
        decoration: BoxDecoration(
          color: c.withOpacity(0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        ),
        child: Center(child: Text(icons[rank - 1], style: TextStyle(fontSize: rank == 1 ? 22 : 18))),
      ),
    ]);
  }

  Color _avatarColor(String id) {
    const c = [Colors.blue, Colors.purple, Colors.teal, Colors.indigo];
    return c[id.hashCode.abs() % c.length];
  }
}

class _Row extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool monthly, isLast;
  const _Row({required this.rank, required this.entry,
      required this.monthly, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final isMe = entry.isCurrentUser;
    return Container(
      decoration: BoxDecoration(
        color: isMe ? AppTheme.greenLight : Colors.transparent,
        border: isLast ? null : const Border(
            bottom: BorderSide(color: AppTheme.greyLight)),
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(20))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        SizedBox(width: 28, child: Text('$rank',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
                color: rank <= 3
                    ? [AppTheme.green, AppTheme.grey, const Color(0xFFCD7F32)][rank - 1]
                    : AppTheme.grey),
            textAlign: TextAlign.center)),
        const SizedBox(width: 10),
        CircleAvatar(radius: 18,
            backgroundColor: isMe ? AppTheme.green : _avatarColor(entry.user.id),
            child: Text(entry.user.initials,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11))),
        const SizedBox(width: 10),
        Expanded(child: Row(children: [
          Text(entry.user.username, style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.black)),
          if (isMe) ...[const SizedBox(width: 6), _youBadge()],
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(monthly ? '${entry.totalDistanceKm.toStringAsFixed(1)} km'
              : '${entry.totalActivities} rides',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                  color: isMe ? AppTheme.greenDark : AppTheme.black)),
          Text(monthly ? 'distance' : 'total',
              style: const TextStyle(fontSize: 10, color: AppTheme.grey)),
        ]),
      ]),
    );
  }

  Widget _youBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(color: AppTheme.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6)),
    child: const Text('You', style: TextStyle(color: AppTheme.greenDark,
        fontSize: 9, fontWeight: FontWeight.w800)),
  );

  Color _avatarColor(String id) {
    const c = [Colors.blue, Colors.purple, Colors.teal, Colors.indigo, Colors.orange];
    return c[id.hashCode.abs() % c.length];
  }
}
