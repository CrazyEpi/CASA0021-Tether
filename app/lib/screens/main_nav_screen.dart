import 'package:flutter/material.dart';
import '../main.dart'; // For BLEFirebaseService and AppTheme
import '../models/user.dart';
import 'home_screen.dart';
import 'live_tracking_screen.dart';
import 'goals_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import '../services/ble_service.dart';

class MainNavScreen extends StatefulWidget {
  final AppUser currentUser;
  const MainNavScreen({super.key, required this.currentUser});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _idx = 0;
  late final List<Widget> _pages;

  // BLE service
  late final BLEService _bleService;

@override
void initState() {
  super.initState();
  _bleService = BLEService();
  _startBLE();
}

void _startBLE() async {
  await _bleService.initialize();


    _pages = [
      HomeScreen(currentUser: widget.currentUser),
      LiveTrackingScreen(currentUser: widget.currentUser),
      GoalsScreen(currentUser: widget.currentUser),
      LeaderboardScreen(currentUser: widget.currentUser),
      ProfileScreen(currentUser: widget.currentUser),
    ];
  }

  @override
  void dispose() {
    // Stop BLE service and cancel streams when screen is disposed
    _bleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.white,
          border: const Border(top: BorderSide(color: AppTheme.greyLight)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.home_outlined, Icons.home, 'Home'),
                _navItem(1, Icons.gps_not_fixed, Icons.gps_fixed, 'Track'),
                _navItem(2, Icons.flag_outlined, Icons.flag, 'Goals'),
                _navItem(3, Icons.leaderboard_outlined, Icons.leaderboard, 'Ranks'),
                _navItem(4, Icons.person_outline, Icons.person, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData off, IconData on, String label) {
    final active = _idx == i;
    return GestureDetector(
      onTap: () => setState(() => _idx = i),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(active ? on : off,
              color: active ? AppTheme.greenDark : AppTheme.grey,
              size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.normal,
              color: active ? AppTheme.greenDark : AppTheme.grey,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: active ? 16 : 0,
            height: 3,
            decoration: BoxDecoration(
              color: AppTheme.green,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ]),
      ),
    );
  }
}