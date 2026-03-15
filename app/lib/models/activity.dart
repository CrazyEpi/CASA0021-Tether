// Activity model - represents a single exercise session
class Activity {
  final String id;
  final String userId;
  final String userName;
  final String type; // 'run', 'cycle', 'walk', 'hike'
  final DateTime startTime;
  final DateTime endTime;
  final double distanceKm;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final int durationSeconds;
  final List<GpsPoint> route;
  final int calories;
  final String title;
  final String? description;
  final int kudos; // like on Strava

  Activity({
    required this.id,
    required this.userId,
    required this.userName,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.distanceKm,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.durationSeconds,
    required this.route,
    required this.calories,
    required this.title,
    this.description,
    this.kudos = 0,
  });

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  String get formattedPace {
    // minutes per km
    if (distanceKm == 0) return '--:--';
    final paceSeconds = (durationSeconds / distanceKm).round();
    final paceMin = paceSeconds ~/ 60;
    final paceSec = paceSeconds % 60;
    return '$paceMin:${paceSec.toString().padLeft(2, '0')} /km';
  }

  String get typeIcon {
    switch (type) {
      case 'run': return '🏃';
      case 'cycle': return '🚴';
      case 'walk': return '🚶';
      case 'hike': return '🥾';
      default: return '🏃';
    }
  }

  String get typeLabel {
    switch (type) {
      case 'run': return 'Run';
      case 'cycle': return 'Cycling';
      case 'walk': return 'Walk';
      case 'hike': return 'Hike';
      default: return 'Activity';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'type': type,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'distanceKm': distanceKm,
      'avgSpeedKmh': avgSpeedKmh,
      'maxSpeedKmh': maxSpeedKmh,
      'durationSeconds': durationSeconds,
      'calories': calories,
      'title': title,
      'description': description,
      'kudos': kudos,
    };
  }
}

class GpsPoint {
  final double lat;
  final double lng;
  final double speed;
  final double totalDistance;
  final DateTime timestamp;

  GpsPoint({
    required this.lat,
    required this.lng,
    required this.speed,
    required this.totalDistance,
    required this.timestamp,
  });

  // Parse from hardware payload: "lat,lng,speed,totalDistance"
  factory GpsPoint.fromPayload(String payload) {
    final parts = payload.split(',');
    if (parts.length < 4) throw FormatException('Invalid payload: $payload');
    return GpsPoint(
      lat: double.parse(parts[0]),
      lng: double.parse(parts[1]),
      speed: double.parse(parts[2]),
      totalDistance: double.parse(parts[3]),
      timestamp: DateTime.now(),
    );
  }

  String toPayload() {
    return '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)},${speed.toStringAsFixed(1)},${totalDistance.toStringAsFixed(1)}';
  }
}
