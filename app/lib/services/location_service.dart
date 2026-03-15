import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/activity.dart';

// ============================================================
// LocationService – uses the phone's GPS to get real-time
// position and converts it to GpsPoint for route recording.
// ============================================================

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionSub;

  final _gpsController   = StreamController<GpsPoint>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<GpsPoint> get gpsStream   => _gpsController.stream;
  Stream<String>   get errorStream => _errorController.stream;

  bool _active = false;
  bool get isActive => _active;

  // Accumulate distance across samples
  Position? _lastPosition;
  double _totalDistanceM = 0;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Request location permission. Returns true if granted.
  Future<bool> requestPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      _errorController.add('Location permission denied permanently. Please enable in Settings.');
      return false;
    }
    return perm == LocationPermission.always ||
           perm == LocationPermission.whileInUse;
  }

  /// Check if GPS hardware is enabled.
  Future<bool> isGpsEnabled() => Geolocator.isLocationServiceEnabled();

  /// Start streaming GPS positions.
  Future<bool> startTracking() async {
    if (_active) return true;

    final serviceEnabled = await isGpsEnabled();
    if (!serviceEnabled) {
      _errorController.add('GPS is disabled. Please enable Location Services.');
      return false;
    }

    final granted = await requestPermission();
    if (!granted) return false;

    _totalDistanceM = 0;
    _lastPosition   = null;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5, // emit every 5 m moved
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition, onError: _onError);

    _active = true;
    debugPrint('[GPS] Tracking started');
    return true;
  }

  /// Stop streaming and reset accumulated distance.
  void stopTracking() {
    _positionSub?.cancel();
    _positionSub   = null;
    _active        = false;
    _lastPosition  = null;
    _totalDistanceM = 0;
    debugPrint('[GPS] Tracking stopped');
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  void _onPosition(Position pos) {
    if (_lastPosition != null) {
      final delta = Geolocator.distanceBetween(
        _lastPosition!.latitude, _lastPosition!.longitude,
        pos.latitude, pos.longitude,
      );
      _totalDistanceM += delta;
    }
    _lastPosition = pos;

    final point = GpsPoint(
      lat: pos.latitude,
      lng: pos.longitude,
      speed: pos.speed * 3.6, // m/s → km/h
      totalDistance: _totalDistanceM,
      timestamp: pos.timestamp,
    );

    _gpsController.add(point);
  }

  void _onError(Object err) {
    debugPrint('[GPS] Error: $err');
    _errorController.add('GPS error: $err');
  }

  void dispose() {
    stopTracking();
    _gpsController.close();
    _errorController.close();
  }
}
