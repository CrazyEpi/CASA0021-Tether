import '../models/activity.dart';
import '../models/user.dart';

// ============================================================
// MOCK DATA - Replace with real MQTT data when hardware ready
// All GPS routes are around UCL/Bloomsbury area, London
// ============================================================

class MockData {
  // Sample GPS route around Regent's Park, London
  static List<GpsPoint> _generateRegentsParkRoute() {
    // Clockwise loop around Regent's Park inner circle
    final basePoints = [
      [51.531100, -0.159200],
      [51.531500, -0.157800],
      [51.532200, -0.156200],
      [51.533100, -0.154800],
      [51.534200, -0.153900],
      [51.535300, -0.153500],
      [51.536200, -0.153800],
      [51.537000, -0.154500],
      [51.537500, -0.155600],
      [51.537800, -0.157000],
      [51.537600, -0.158500],
      [51.537000, -0.159800],
      [51.536200, -0.160500],
      [51.535100, -0.160800],
      [51.534000, -0.160500],
      [51.533000, -0.159800],
      [51.532000, -0.159200],
      [51.531100, -0.159200],
    ];
    final now = DateTime.now().subtract(const Duration(hours: 2));
    double cumulativeDistance = 0;
    List<GpsPoint> points = [];
    for (int i = 0; i < basePoints.length; i++) {
      if (i > 0) {
        final dlat = (basePoints[i][0] - basePoints[i - 1][0]).abs();
        final dlng = (basePoints[i][1] - basePoints[i - 1][1]).abs();
        cumulativeDistance += (dlat * 111 + dlng * 72);
      }
      final speed = 10.0 + (i % 3) * 1.5;
      points.add(GpsPoint(
        lat: basePoints[i][0],
        lng: basePoints[i][1],
        speed: speed,
        totalDistance: cumulativeDistance,
        timestamp: now.add(Duration(minutes: i * 3)),
      ));
    }
    return points;
  }

  // Route around Hyde Park
  static List<GpsPoint> _generateHydeParkRoute() {
    final basePoints = [
      [51.506200, -0.165800],
      [51.507100, -0.163200],
      [51.508300, -0.160800],
      [51.509600, -0.158500],
      [51.510800, -0.156400],
      [51.511500, -0.158200],
      [51.512000, -0.160500],
      [51.511500, -0.163000],
      [51.510800, -0.165200],
      [51.509500, -0.166800],
      [51.508200, -0.167200],
      [51.507000, -0.166800],
      [51.506200, -0.165800],
    ];
    final now = DateTime.now().subtract(const Duration(days: 1, hours: 6));
    double cumulativeDistance = 0;
    List<GpsPoint> points = [];
    for (int i = 0; i < basePoints.length; i++) {
      if (i > 0) {
        final dlat = (basePoints[i][0] - basePoints[i - 1][0]).abs();
        final dlng = (basePoints[i][1] - basePoints[i - 1][1]).abs();
        cumulativeDistance += (dlat * 111 + dlng * 72);
      }
      final speed = 12.0 + (i % 4) * 2.0;
      points.add(GpsPoint(
        lat: basePoints[i][0],
        lng: basePoints[i][1],
        speed: speed,
        totalDistance: cumulativeDistance,
        timestamp: now.add(Duration(minutes: i * 4)),
      ));
    }
    return points;
  }

  // Route around UCL campus
  static List<GpsPoint> _generateUCLRoute() {
    final basePoints = [
      [51.524900, -0.134500],
      [51.524200, -0.133200],
      [51.523500, -0.132000],
      [51.522800, -0.131200],
      [51.522100, -0.132400],
      [51.521800, -0.133900],
      [51.522400, -0.135000],
      [51.523200, -0.135800],
      [51.524100, -0.135500],
      [51.524900, -0.134500],
    ];
    final now = DateTime.now().subtract(const Duration(days: 3));
    double cumulativeDistance = 0;
    List<GpsPoint> points = [];
    for (int i = 0; i < basePoints.length; i++) {
      if (i > 0) {
        final dlat = (basePoints[i][0] - basePoints[i - 1][0]).abs();
        final dlng = (basePoints[i][1] - basePoints[i - 1][1]).abs();
        cumulativeDistance += (dlat * 111 + dlng * 72);
      }
      points.add(GpsPoint(
        lat: basePoints[i][0],
        lng: basePoints[i][1],
        speed: 8.0,
        totalDistance: cumulativeDistance,
        timestamp: now.add(Duration(minutes: i * 5)),
      ));
    }
    return points;
  }

  // ============================================================
  // MOCK ACTIVITIES
  // ============================================================
  static List<Activity> getMockActivities(String currentUserId) {
    return [
      // --- Current user (Yidan) ---
      Activity(
        id: 'act_001',
        userId: 'user_001',
        userName: 'Yidan',
        type: 'run',
        startTime: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
        endTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
        distanceKm: 6.8,
        avgSpeedKmh: 10.5,
        maxSpeedKmh: 13.2,
        durationSeconds: 75 * 60,
        route: _generateRegentsParkRoute(),
        calories: 480,
        title: "Regent's Park Morning Run",
        description: 'Great weather today! 🌞 Felt strong throughout.',
        kudos: 12,
      ),
      Activity(
        id: 'act_002',
        userId: 'user_001',
        userName: 'Yidan',
        type: 'cycle',
        startTime: DateTime.now().subtract(const Duration(days: 1, hours: 7)),
        endTime: DateTime.now().subtract(const Duration(days: 1, hours: 5, minutes: 30)),
        distanceKm: 18.4,
        avgSpeedKmh: 22.1,
        maxSpeedKmh: 31.5,
        durationSeconds: 90 * 60,
        route: _generateHydeParkRoute(),
        calories: 620,
        title: 'Hyde Park Cycling',
        description: 'Testing the new GPS sensor on the bike.',
        kudos: 8,
      ),
      Activity(
        id: 'act_003',
        userId: 'user_001',
        userName: 'Yidan',
        type: 'run',
        startTime: DateTime.now().subtract(const Duration(days: 3)),
        endTime: DateTime.now().subtract(const Duration(days: 2, hours: 22, minutes: 30)),
        distanceKm: 4.2,
        avgSpeedKmh: 9.2,
        maxSpeedKmh: 11.8,
        durationSeconds: 45 * 60,
        route: _generateUCLRoute(),
        calories: 290,
        title: 'UCL Campus Jog',
        kudos: 5,
      ),
      Activity(
        id: 'act_004',
        userId: 'user_001',
        userName: 'Yidan',
        type: 'walk',
        startTime: DateTime.now().subtract(const Duration(days: 5)),
        endTime: DateTime.now().subtract(const Duration(days: 4, hours: 21)),
        distanceKm: 3.1,
        avgSpeedKmh: 5.2,
        maxSpeedKmh: 6.8,
        durationSeconds: 36 * 60,
        route: _generateUCLRoute(),
        calories: 180,
        title: 'Evening Walk',
        kudos: 3,
      ),

      // --- Friends' activities (shown in feed) ---
      Activity(
        id: 'act_005',
        userId: 'user_002',
        userName: 'Alex Chen',
        type: 'cycle',
        startTime: DateTime.now().subtract(const Duration(hours: 5)),
        endTime: DateTime.now().subtract(const Duration(hours: 3, minutes: 30)),
        distanceKm: 25.3,
        avgSpeedKmh: 24.8,
        maxSpeedKmh: 38.2,
        durationSeconds: 91 * 60,
        route: _generateHydeParkRoute(),
        calories: 780,
        title: 'Long Ride to Richmond Park',
        kudos: 21,
      ),
      Activity(
        id: 'act_006',
        userId: 'user_003',
        userName: 'Sarah Kim',
        type: 'run',
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        endTime: DateTime.now().subtract(const Duration(hours: 22)),
        distanceKm: 10.0,
        avgSpeedKmh: 11.2,
        maxSpeedKmh: 14.5,
        durationSeconds: 53 * 60 + 30,
        route: _generateRegentsParkRoute(),
        calories: 650,
        title: '10K Personal Best! 🎉',
        description: 'New PB! 53:30 for 10K. The GPS device really helped me pace correctly.',
        kudos: 34,
      ),
      Activity(
        id: 'act_007',
        userId: 'user_004',
        userName: 'James Liu',
        type: 'run',
        startTime: DateTime.now().subtract(const Duration(days: 2, hours: 6)),
        endTime: DateTime.now().subtract(const Duration(days: 2, hours: 3, minutes: 45)),
        distanceKm: 15.0,
        avgSpeedKmh: 10.9,
        maxSpeedKmh: 13.8,
        durationSeconds: 82 * 60 + 20,
        route: _generateRegentsParkRoute(),
        calories: 920,
        title: 'Long Run - Marathon Training',
        kudos: 18,
      ),
      Activity(
        id: 'act_008',
        userId: 'user_005',
        userName: 'Emma Park',
        type: 'walk',
        startTime: DateTime.now().subtract(const Duration(hours: 8)),
        endTime: DateTime.now().subtract(const Duration(hours: 7, minutes: 10)),
        distanceKm: 4.5,
        avgSpeedKmh: 5.4,
        maxSpeedKmh: 7.2,
        durationSeconds: 50 * 60,
        route: _generateUCLRoute(),
        calories: 260,
        title: 'Morning Walk in Bloomsbury',
        kudos: 9,
      ),
    ];
  }

  // ============================================================
  // MOCK MONTHLY GOALS - for current user (Yidan)
  // ============================================================
  static MonthlyGoal getMockGoal(String userId) {
    final now = DateTime.now();
    return MonthlyGoal(
      userId: userId,
      year: now.year,
      month: now.month,
      targetDistanceKm: 60.0,
      targetActivities: 16,
      targetCalories: 8000,
      targetActiveMinutes: 900,
      // Current progress (based on mock activities above)
      currentDistanceKm: 32.5,
      currentActivities: 9,
      currentCalories: 4380,
      currentActiveMinutes: 428,
    );
  }

  // ============================================================
  // MOCK LEADERBOARD - monthly distance ranking among friends
  // ============================================================
  static List<LeaderboardEntry> getMockLeaderboard(String currentUserId) {
    final entries = [
      LeaderboardEntry(
        user: UserData.getUserById('user_004')!,
        totalDistanceKm: 78.5,
        totalActivities: 14,
        rank: 1,
      ),
      LeaderboardEntry(
        user: UserData.getUserById('user_002')!,
        totalDistanceKm: 65.3,
        totalActivities: 11,
        rank: 2,
      ),
      LeaderboardEntry(
        user: UserData.getUserById('user_003')!,
        totalDistanceKm: 48.8,
        totalActivities: 12,
        rank: 3,
      ),
      LeaderboardEntry(
        user: UserData.getUserById('user_001')!,
        totalDistanceKm: 32.5,
        totalActivities: 9,
        rank: 4,
        isCurrentUser: true,
      ),
      LeaderboardEntry(
        user: UserData.getUserById('user_005')!,
        totalDistanceKm: 21.2,
        totalActivities: 7,
        rank: 5,
      ),
    ];
    return entries;
  }

  // ============================================================
  // SIMULATION ROUTE - for Demo Mode in Live Tracking (no hardware)
  // Returns an expanded Regent's Park route with more points & realistic speeds
  // ============================================================
  static List<GpsPoint> getSimRoute() {
    final basePoints = [
      [51.531100, -0.159200],
      [51.531400, -0.158500],
      [51.531700, -0.157600],
      [51.532200, -0.156500],
      [51.532900, -0.155300],
      [51.533600, -0.154400],
      [51.534400, -0.153800],
      [51.535300, -0.153500],
      [51.536100, -0.153700],
      [51.536800, -0.154200],
      [51.537300, -0.155000],
      [51.537700, -0.156200],
      [51.537900, -0.157500],
      [51.537700, -0.158800],
      [51.537200, -0.159900],
      [51.536500, -0.160600],
      [51.535600, -0.161000],
      [51.534500, -0.160800],
      [51.533400, -0.160200],
      [51.532400, -0.159500],
      [51.531600, -0.159300],
      [51.531100, -0.159200],
    ];
    double cumulativeDistance = 0;
    final List<GpsPoint> points = [];
    final speeds = [10.2, 11.5, 13.1, 14.8, 15.2, 14.6, 13.9, 14.0, 15.5,
                    16.2, 15.8, 14.5, 13.2, 12.8, 13.5, 14.1, 13.6, 12.9,
                    12.4, 11.8, 11.2, 10.5];
    for (int i = 0; i < basePoints.length; i++) {
      if (i > 0) {
        final dlat = (basePoints[i][0] - basePoints[i - 1][0]).abs();
        final dlng = (basePoints[i][1] - basePoints[i - 1][1]).abs();
        cumulativeDistance += (dlat * 111.0 + dlng * 72.0);
      }
      points.add(GpsPoint(
        lat: basePoints[i][0],
        lng: basePoints[i][1],
        speed: speeds[i],
        totalDistance: cumulativeDistance,
        timestamp: DateTime.now(),
      ));
    }
    return points;
  }

  // ============================================================
  // Weekly distance data (last 7 days) - for charts
  // ============================================================
  static List<Map<String, dynamic>> getWeeklyData() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dayValues = [0.0, 4.2, 0.0, 6.8, 18.4, 0.0, 3.1];
      return {
        'day': dayNames[day.weekday - 1],
        'distance': dayValues[i],
      };
    });
  }
}
