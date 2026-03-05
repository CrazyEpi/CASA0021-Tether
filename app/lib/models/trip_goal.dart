// TripGoal — Single-ride destination goal (set from Map screen)
class TripGoal {
  final String userId;
  final String destinationName;
  final double targetDistanceKm;
  final String estimatedDuration;
  final DateTime date;
  double currentDistanceKm;
  bool completed;

  TripGoal({
    required this.userId,
    required this.destinationName,
    required this.targetDistanceKm,
    required this.estimatedDuration,
    required this.date,
    this.currentDistanceKm = 0.0,
    this.completed = false,
  });

  double get progress =>
      (currentDistanceKm / targetDistanceKm).clamp(0.0, 1.0);
  double get remainingKm =>
      (targetDistanceKm - currentDistanceKm).clamp(0.0, double.infinity);
  String get progressLabel =>
      '${currentDistanceKm.toStringAsFixed(1)} / ${targetDistanceKm.toStringAsFixed(1)} km';
}
