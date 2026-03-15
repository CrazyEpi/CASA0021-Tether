// User model
class AppUser {
  final String id;
  final String username;
  final String email;
  final String? avatarUrl;
  final String? bio;
  final DateTime joinDate;
  final List<String> friendIds;

  AppUser({
    required this.id,
    required this.username,
    required this.email,
    this.avatarUrl,
    this.bio,
    required this.joinDate,
    this.friendIds = const [],
  });

  String get initials {
    final parts = username.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return username.substring(0, 2).toUpperCase();
  }
}

// Monthly goals model
class MonthlyGoal {
  final String userId;
  final int year;
  final int month;

  // Goal targets
  double targetDistanceKm;
  int targetActivities;
  int targetCalories;
  int targetActiveMinutes;

  // Actual progress
  double currentDistanceKm;
  int currentActivities;
  int currentCalories;
  int currentActiveMinutes;

  MonthlyGoal({
    required this.userId,
    required this.year,
    required this.month,
    this.targetDistanceKm = 50.0,
    this.targetActivities = 12,
    this.targetCalories = 5000,
    this.targetActiveMinutes = 600,
    this.currentDistanceKm = 0.0,
    this.currentActivities = 0,
    this.currentCalories = 0,
    this.currentActiveMinutes = 0,
  });

  double get distanceProgress => currentDistanceKm / targetDistanceKm;
  double get activitiesProgress => currentActivities / targetActivities;
  double get caloriesProgress => currentCalories / targetCalories;
  double get activeMinutesProgress => currentActiveMinutes / targetActiveMinutes;

  String get monthName {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }
}

// Leaderboard entry
class LeaderboardEntry {
  final AppUser user;
  final double totalDistanceKm;
  final int totalActivities;
  final int rank;
  final bool isCurrentUser;

  LeaderboardEntry({
    required this.user,
    required this.totalDistanceKm,
    required this.totalActivities,
    required this.rank,
    this.isCurrentUser = false,
  });
}

// Predefined users for login
class UserData {
  static final List<AppUser> _users = [
    AppUser(
      id: 'user_001',
      username: 'Yidan',
      email: 'yidan@ucl.ac.uk',
      bio: 'CASA MSc student | Running enthusiast',
      joinDate: DateTime(2024, 9, 1),
      friendIds: ['user_002', 'user_003', 'user_004', 'user_005'],
    ),
    AppUser(
      id: 'user_002',
      username: 'Alex Chen',
      email: 'alex@ucl.ac.uk',
      bio: 'Cycling & running 🚴',
      joinDate: DateTime(2024, 9, 1),
      friendIds: ['user_001'],
    ),
    AppUser(
      id: 'user_003',
      username: 'Sarah Kim',
      email: 'sarah@ucl.ac.uk',
      bio: 'Trail runner',
      joinDate: DateTime(2024, 10, 1),
      friendIds: ['user_001'],
    ),
    AppUser(
      id: 'user_004',
      username: 'James Liu',
      email: 'james@ucl.ac.uk',
      bio: 'Marathoner in training',
      joinDate: DateTime(2024, 9, 15),
      friendIds: ['user_001'],
    ),
    AppUser(
      id: 'user_005',
      username: 'Emma Park',
      email: 'emma@ucl.ac.uk',
      bio: 'Morning jog crew 🌅',
      joinDate: DateTime(2024, 11, 1),
      friendIds: ['user_001'],
    ),
  ];

  // Demo password for all users
  static const String _demoPassword = 'casa2025';

  static bool isEmailRegistered(String email) {
    return _users.any((u) => u.email.toLowerCase() == email.toLowerCase());
  }

  static bool verifyUser(String email, String password) {
    return isEmailRegistered(email) && password == _demoPassword;
  }

  static AppUser? getUserByEmail(String email) {
    try {
      return _users.firstWhere(
        (u) => u.email.toLowerCase() == email.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  static AppUser? getUserById(String id) {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<AppUser> getAllUsers() => List.unmodifiable(_users);
}
