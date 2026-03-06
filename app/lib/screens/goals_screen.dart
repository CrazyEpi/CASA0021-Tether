import 'package:flutter/material.dart';
import '../main.dart';
import '../models/user.dart';
import '../models/trip_goal.dart';
import '../data/mock_data.dart';
import 'map_navigation_screen.dart';

class GoalsScreen extends StatefulWidget {
  final AppUser currentUser;
  const GoalsScreen({super.key, required this.currentUser});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MonthlyGoal _monthlyGoal;
  TripGoal? _tripGoal;

  // Edit monthly goals
  bool _isEditing = false;
  final _distanceCtrl  = TextEditingController();
  final _ridesCtrl     = TextEditingController();
  final _caloriesCtrl  = TextEditingController();
  final _minutesCtrl   = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _monthlyGoal = MockData.getMockGoal(widget.currentUser.id);
    _distanceCtrl.text  = _monthlyGoal.targetDistanceKm.toStringAsFixed(0);
    _ridesCtrl.text     = _monthlyGoal.targetActivities.toString();
    _caloriesCtrl.text  = _monthlyGoal.targetCalories.toString();
    _minutesCtrl.text   = _monthlyGoal.targetActiveMinutes.toString();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _distanceCtrl.dispose();
    _ridesCtrl.dispose();
    _caloriesCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  void _saveMonthlyGoals() {
    setState(() {
      _monthlyGoal.targetDistanceKm =
          double.tryParse(_distanceCtrl.text) ?? _monthlyGoal.targetDistanceKm;
      _monthlyGoal.targetActivities =
          int.tryParse(_ridesCtrl.text) ?? _monthlyGoal.targetActivities;
      _monthlyGoal.targetCalories =
          int.tryParse(_caloriesCtrl.text) ?? _monthlyGoal.targetCalories;
      _monthlyGoal.targetActiveMinutes =
          int.tryParse(_minutesCtrl.text) ?? _monthlyGoal.targetActiveMinutes;
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Monthly goals saved!'),
        backgroundColor: AppTheme.greenDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _openMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapNavigationScreen(
          currentUser: widget.currentUser,
          onGoalSet: (TripGoal goal) {
            setState(() => _tripGoal = goal);
            _tabController.animateTo(0);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Trip goal set: ${goal.destinationName}"),
                backgroundColor: AppTheme.greenDark,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        title: const Text('Goals',
            style: TextStyle(
                color: AppTheme.black,
                fontWeight: FontWeight.w800,
                fontSize: 22)),
        actions: [
          // Edit button only shown on Monthly tab
          AnimatedBuilder(
            animation: _tabController,
            builder: (_, __) {
              if (_tabController.index != 1) return const SizedBox.shrink();
              return TextButton(
                onPressed: () {
                  if (_isEditing) {
                    _saveMonthlyGoals();
                  } else {
                    setState(() => _isEditing = true);
                  }
                },
                child: Text(
                  _isEditing ? 'Save' : 'Edit',
                  style: const TextStyle(
                      color: AppTheme.green, fontWeight: FontWeight.w700),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          labelColor: AppTheme.black,
          unselectedLabelColor: AppTheme.grey,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          indicatorColor: AppTheme.green,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Today's Ride"),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TodayRideTab(
            tripGoal: _tripGoal,
            onPlanRide: _openMap,
            onSimulateProgress: () {
              if (_tripGoal != null) {
                setState(() {
                  _tripGoal!.currentDistanceKm =
                      (_tripGoal!.currentDistanceKm + _tripGoal!.targetDistanceKm * 0.25)
                          .clamp(0.0, _tripGoal!.targetDistanceKm);
                  if (_tripGoal!.currentDistanceKm >= _tripGoal!.targetDistanceKm) {
                    _tripGoal!.completed = true;
                  }
                });
              }
            },
          ),
          _MonthlyTab(
            goal: _monthlyGoal,
            isEditing: _isEditing,
            distanceCtrl: _distanceCtrl,
            ridesCtrl: _ridesCtrl,
            caloriesCtrl: _caloriesCtrl,
            minutesCtrl: _minutesCtrl,
          ),
        ],
      ),
    );
  }
}

// ─── TODAY'S RIDE TAB ─────────────────────────────────────────────────────────

class _TodayRideTab extends StatelessWidget {
  final TripGoal? tripGoal;
  final VoidCallback onPlanRide;
  final VoidCallback onSimulateProgress;

  const _TodayRideTab({
    required this.tripGoal,
    required this.onPlanRide,
    required this.onSimulateProgress,
  });

  @override
  Widget build(BuildContext context) {
    if (tripGoal == null) {
      return _buildNoGoalState(context);
    }
    return _buildActiveGoal(context, tripGoal!);
  }

  Widget _buildNoGoalState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Illustration card
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.greenLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.directions_bike,
                      size: 44, color: AppTheme.greenDark),
                ),
                const SizedBox(height: 20),
                const Text(
                  "No ride planned yet",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.black),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Use the map to search for a destination, calculate the cycling route distance, and set it as today's ride goal.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.grey,
                      height: 1.5),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onPlanRide,
                    icon: const Icon(Icons.map_outlined, size: 20),
                    label: const Text("Plan a Ride",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.black,
                      foregroundColor: AppTheme.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // How it works
          const Text('How it works',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTheme.black)),
          const SizedBox(height: 12),
          _HowItWorksStep(
              number: '1',
              icon: Icons.search,
              title: 'Search destination',
              desc: 'Type any location on the map'),
          _HowItWorksStep(
              number: '2',
              icon: Icons.route,
              title: 'Get cycling route',
              desc: 'Distance is calculated via Google Maps'),
          _HowItWorksStep(
              number: '3',
              icon: Icons.flag,
              title: 'Set as today\'s goal',
              desc: 'Track your live progress while riding'),
        ],
      ),
    );
  }

  Widget _buildActiveGoal(BuildContext context, TripGoal goal) {
    final progress = goal.progress;
    final pct = (progress * 100).toInt();
    final isComplete = goal.completed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main goal card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isComplete ? AppTheme.greenDark : AppTheme.black,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_bike,
                        color: AppTheme.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isComplete ? 'Ride Complete! 🎉' : "Today's Ride",
                      style: const TextStyle(
                          color: AppTheme.green,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onPlanRide,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Change',
                            style: TextStyle(
                                color: AppTheme.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  goal.destinationName,
                  style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.white.withOpacity(0.15),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.green),
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(goal.progressLabel,
                        style: const TextStyle(
                            color: AppTheme.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text('$pct%',
                        style: TextStyle(
                            color: isComplete
                                ? AppTheme.green
                                : AppTheme.white.withOpacity(0.6),
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  icon: Icons.straighten,
                  label: 'Target',
                  value: '${goal.targetDistanceKm.toStringAsFixed(1)} km',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatChip(
                  icon: Icons.timer_outlined,
                  label: 'Est. Time',
                  value: goal.estimatedDuration,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatChip(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Remaining',
                  value: '${goal.remainingKm.toStringAsFixed(1)} km',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Simulate progress (demo button)
          if (!isComplete)
            OutlinedButton.icon(
              onPressed: onSimulateProgress,
              icon: const Icon(Icons.add_road, size: 18),
              label: const Text('Simulate +25% Progress (Demo)',
                  style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.greenDark,
                side: const BorderSide(color: AppTheme.green, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),

          if (isComplete) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.greenLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: const [
                  Text('🏆', style: TextStyle(fontSize: 28)),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Destination reached!',
                            style: TextStyle(
                                color: AppTheme.greenDark,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                        SizedBox(height: 4),
                        Text("Great job! Go to Track tab to save your ride.",
                            style: TextStyle(
                                color: AppTheme.greenDark, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          // Plan new ride button
          TextButton.icon(
            onPressed: onPlanRide,
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Plan a different ride'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.grey),
          ),
        ],
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String desc;

  const _HowItWorksStep(
      {required this.number,
      required this.icon,
      required this.title,
      required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.greenLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: AppTheme.greenDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.black,
                        fontSize: 13)),
                Text(desc,
                    style: const TextStyle(
                        color: AppTheme.grey, fontSize: 12)),
              ],
            ),
          ),
          Icon(icon, color: AppTheme.green, size: 20),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.green, size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppTheme.black)),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.grey)),
        ],
      ),
    );
  }
}

// ─── MONTHLY TAB ─────────────────────────────────────────────────────────────

class _MonthlyTab extends StatelessWidget {
  final MonthlyGoal goal;
  final bool isEditing;
  final TextEditingController distanceCtrl;
  final TextEditingController ridesCtrl;
  final TextEditingController caloriesCtrl;
  final TextEditingController minutesCtrl;

  const _MonthlyTab({
    required this.goal,
    required this.isEditing,
    required this.distanceCtrl,
    required this.ridesCtrl,
    required this.caloriesCtrl,
    required this.minutesCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = daysInMonth - now.day;
    final monthProgress = (daysInMonth - daysRemaining) / daysInMonth;
    final weeklyData = MockData.getWeeklyData();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Month header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month,
                        color: AppTheme.green, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '${goal.monthName} ${goal.year}',
                      style: const TextStyle(
                          color: AppTheme.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text('$daysRemaining days left',
                        style: const TextStyle(
                            color: AppTheme.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: monthProgress,
                    backgroundColor: AppTheme.white.withOpacity(0.1),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.green),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(monthProgress * 100).toInt()}% of month elapsed',
                  style: const TextStyle(color: AppTheme.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Goal cards
          _GoalCard(
            icon: Icons.straighten,
            title: 'Distance',
            current: goal.currentDistanceKm,
            target: goal.targetDistanceKm,
            unit: 'km',
            color: AppTheme.green,
            isEditing: isEditing,
            controller: distanceCtrl,
            decimals: 1,
          ),
          const SizedBox(height: 10),
          _GoalCard(
            icon: Icons.directions_bike,
            title: 'Rides',
            current: goal.currentActivities.toDouble(),
            target: goal.targetActivities.toDouble(),
            unit: 'rides',
            color: const Color(0xFF5B8DEF),
            isEditing: isEditing,
            controller: ridesCtrl,
            decimals: 0,
          ),
          const SizedBox(height: 10),
          _GoalCard(
            icon: Icons.local_fire_department,
            title: 'Calories',
            current: goal.currentCalories.toDouble(),
            target: goal.targetCalories.toDouble(),
            unit: 'kcal',
            color: const Color(0xFFE05252),
            isEditing: isEditing,
            controller: caloriesCtrl,
            decimals: 0,
          ),
          const SizedBox(height: 10),
          _GoalCard(
            icon: Icons.timer_outlined,
            title: 'Active Time',
            current: goal.currentActiveMinutes.toDouble(),
            target: goal.targetActiveMinutes.toDouble(),
            unit: 'min',
            color: const Color(0xFF9B6BFF),
            isEditing: isEditing,
            controller: minutesCtrl,
            decimals: 0,
          ),
          const SizedBox(height: 20),

          // Weekly bar chart
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This Week',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppTheme.black)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  child: _WeeklyBarChart(data: weeklyData),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tip
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.greenLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Goal Tip',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.greenDark,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      Builder(builder: (_) {
                        final distLeft = (goal.targetDistanceKm -
                                goal.currentDistanceKm)
                            .clamp(0.0, double.infinity);
                        final perDay = daysRemaining > 0
                            ? distLeft / daysRemaining
                            : 0.0;
                        return Text(
                          distLeft <= 0
                              ? 'Distance goal complete! Great month. 🎯'
                              : 'Ride ${perDay.toStringAsFixed(1)} km/day to hit your distance goal.',
                          style: const TextStyle(
                              color: AppTheme.greenDark,
                              fontSize: 12,
                              height: 1.4),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final double current;
  final double target;
  final String unit;
  final Color color;
  final bool isEditing;
  final TextEditingController controller;
  final int decimals;

  const _GoalCard({
    required this.icon,
    required this.title,
    required this.current,
    required this.target,
    required this.unit,
    required this.color,
    required this.isEditing,
    required this.controller,
    required this.decimals,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (current / target).clamp(0.0, 1.0);
    final pct = (progress * 100).toInt();
    final done = progress >= 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: done
            ? Border.all(color: AppTheme.green.withOpacity(0.5), width: 1.5)
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.black,
                                fontSize: 14)),
                        if (done) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle,
                              color: AppTheme.green, size: 15),
                        ],
                      ],
                    ),
                    Text(
                      '${current.toStringAsFixed(decimals)} / ${target.toStringAsFixed(decimals)} $unit',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.grey),
                    ),
                  ],
                ),
              ),
              if (isEditing)
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.black,
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      hintText: 'Target',
                      hintStyle: const TextStyle(
                          color: AppTheme.grey, fontSize: 11),
                      filled: true,
                      fillColor: AppTheme.offWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: color.withOpacity(0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: color.withOpacity(0.25)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: color, width: 1.5),
                      ),
                    ),
                  ),
                )
              else
                Text(
                  '$pct%',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: done ? AppTheme.green : color),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.greyLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                  done ? AppTheme.green : color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _WeeklyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxDist = data
        .map((d) => d['distance'] as double)
        .fold(0.0, (a, b) => a > b ? a : b);
    final todayAbbrev = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        [DateTime.now().weekday - 1];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((d) {
        final dist = d['distance'] as double;
        final day = d['day'] as String;
        final barH = maxDist > 0 ? (dist / maxDist) * 72 : 0.0;
        final isToday = day == todayAbbrev;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (dist > 0)
                  Text('${dist.toStringAsFixed(1)}',
                      style: const TextStyle(
                          fontSize: 8, color: AppTheme.grey)),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: barH.clamp(4.0, 72.0),
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppTheme.black
                        : (dist > 0 ? AppTheme.green : AppTheme.greyLight),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(height: 5),
                Text(day,
                    style: TextStyle(
                        fontSize: 10,
                        color: isToday ? AppTheme.black : AppTheme.grey,
                        fontWeight: isToday
                            ? FontWeight.w800
                            : FontWeight.normal)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
