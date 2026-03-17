import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:cloud_firestore/cloud_firestore.dart'; // [NEW] Added for Data Sharing
import '../main.dart';
import '../models/activity.dart';
import '../data/mock_data.dart';
import '../models/user.dart';
import '../services/ble_service.dart';
import '../services/location_service.dart';

// ============================================================
// Live GPS Tracking Screen (Android)
//
// GPS source  : Phone's own GPS (geolocator)
// BLE output  : BikeTracker_E device
//               char 19B10001 ← speed + distance every second
//               char 19B10003 ← time sync on connect
//               char 19B10004 ← online friends count on connect
//               char 19B10005 → SOS alert (notify, phone ← device)
// Demo mode   : Simulates Regent's Park route (no hardware needed)
// Firebase    : Pushes real-time speed/pos to users/{id}/live_stats
// ============================================================

class LiveTrackingScreen extends StatefulWidget {
  final AppUser currentUser;
  const LiveTrackingScreen({super.key, required this.currentUser});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with TickerProviderStateMixin {
  final _ble = BleService();
  final _loc = LocationService();
  final _db  = FirebaseFirestore.instance; // [NEW] Database instance

  // ── Tracking state ────────────────────────────────────────────────────────
  bool _isTracking   = false;
  bool _isPaused     = false;
  bool _isConnecting = false;
  BleStatus _bleStatus = BleStatus.disconnected;

  // Live data
  double _currentLat = 0;
  double _currentLng = 0;
  double _currentSpeed = 0;
  double _totalDistance = 0; // km
  int _elapsedSeconds = 0;
  List<GpsPoint> _trackPoints = [];

  // BLE log lines
  final List<String> _bleLog = [];

  // Timer
  Timer? _timer;
  Timer? _bleWriteTimer; // write BLE every second
  DateTime? _startTime;
  DateTime? _pauseStart;
  int _pausedSeconds = 0;

  // Social Listener [NEW]
  StreamSubscription? _friendsSub;

  // Demo / simulation mode (no hardware)
  bool _isSimulating = false;
  Timer? _simTimer;
  int _simPointIndex = 0;
  static final List<GpsPoint> _simRoute = MockData.getSimRoute();

  // Subscriptions
  StreamSubscription? _bleStatusSub;
  StreamSubscription? _bleLogSub;
  StreamSubscription? _sosSub;
  StreamSubscription? _gpsSub;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // flutter_map controller
  final MapController _mapController = MapController();

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // BLE status updates
    _bleStatusSub = _ble.statusStream.listen((s) {
      if (mounted) {
        setState(() => _bleStatus = s);
        // [NEW] Restart listener if BLE reconnected
        if (s == BleStatus.connected) {
          _startFriendListener();
        }
      }
    });

    // BLE log
    _bleLogSub = _ble.logStream.listen((msg) {
      if (mounted) {
        setState(() {
          _bleLog.insert(0, '[${_ts()}] $msg');
          if (_bleLog.length > 20) _bleLog.removeLast();
        });
      }
    });

    // SOS alert from device
    _sosSub = _ble.sosStream.listen((triggered) {
      if (!mounted) return;
      if (triggered) _showSosDialog();
    });

    // Phone GPS stream
    _gpsSub = _loc.gpsStream.listen((point) {
      if (!_isTracking || _isPaused) return;
      setState(() {
        _currentLat = point.lat;
        _currentLng = point.lng;
        _currentSpeed = point.speed;
        _totalDistance = point.totalDistance / 1000.0; // m → km
        _trackPoints.add(point);
      });
      _followPosition();
    });

    // [NEW] Initialize Friend Listener on start
    _startFriendListener();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _simTimer?.cancel();
    _bleWriteTimer?.cancel();
    _friendsSub?.cancel(); // [NEW]
    _mapController.dispose();
    _bleStatusSub?.cancel();
    _bleLogSub?.cancel();
    _sosSub?.cancel();
    _gpsSub?.cancel();
    _loc.stopTracking();
    _updateFirebaseStatus(false); // [NEW] Set offline on exit
    super.dispose();
  }

  String _ts() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2,'0')}:${n.minute.toString().padLeft(2,'0')}';
  }

  // ── Firebase Sync & Listener Logic ─────────────────────────────────────────
  
  /// [NEW] Social Listener: Watches for friends riding to trigger NeoPixels
  void _startFriendListener() {
    _friendsSub?.cancel();
    if (widget.currentUser.friendIds.isEmpty) return;

    debugPrint("DEBUG: Starting listener for ${widget.currentUser.friendIds.length} friends.");
    
    _friendsSub = _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: widget.currentUser.friendIds)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        // Only react to updates, not initial loads
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data();
          final bool isFriendRiding = data?['isRiding'] ?? false;
          
          if (isFriendRiding && _ble.isConnected) {
            debugPrint("SOCIAL: Friend ${data?['username']} started riding. Pulsing bike!");
            _ble.writeNeoPixelSocialSignal(); 
          }
        }
      }
    });
  }

  /// [NEW] Push real-time data so friends can see speed and trigger NeoPixels
  Future<void> _updateFirebaseStatus(bool isLive) async {
    try {
      await _db.collection('users').doc(widget.currentUser.id).set({ 
        'isRiding': isLive,
        'live_stats': isLive ? {
          'speed': _currentSpeed,
          'lat': _currentLat,
          'lng': _currentLng,
          'dist': _totalDistance,
          'lastUpdate': FieldValue.serverTimestamp(),
        } : null,
      }, SetOptions(merge: true)); 
      
      debugPrint("✅ Data sent! Check Firebase now.");
    } catch (e) {
      debugPrint("❌ Error: $e");
    }
  }

  // ── BLE ──────────────────────────────────────────────────────────────────
  Future<void> _connectBle() async {
    setState(() => _isConnecting = true);
    final ok = await _ble.connectToDevice();
    setState(() => _isConnecting = false);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not find ${BleService.deviceName}. Make sure it is powered on and nearby.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } else if (ok) {
      // Send initial data
      await _ble.writeOnlineFriends(widget.currentUser.friendIds.length);
    }
  }

  void _disconnectBle() {
    _ble.disconnect();
  }

  /// Periodically write speed+distance to the BLE device AND Firebase while tracking.
  void _startBleWriteTimer() {
    _bleWriteTimer?.cancel();
    _bleWriteTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_isTracking || _isPaused) return;
      
      // 1. Send to Local Hardware
      if (_ble.isConnected) {
        await _ble.writeSpeedDistance(
          _currentSpeed,
          _totalDistance * 1000, // km → m
        );
      }

      // 2. [NEW] Send to Cloud (Firebase) for Data Sharing
      _updateFirebaseStatus(true);
    });
  }

  void _stopBleWriteTimer() {
    _bleWriteTimer?.cancel();
    _bleWriteTimer = null;
    _updateFirebaseStatus(false); // [NEW] Mark session as ended
  }

  // ── SOS ──────────────────────────────────────────────────────────────────
  void _showSosDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.red[900],
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
            SizedBox(width: 10),
            Text('SOS ALERT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Emergency signal received from BikeTracker device!\n\nCheck the rider immediately.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Demo / Simulation ─────────────────────────────────────────────────────
  void _startSimulation() {
    setState(() {
      _isSimulating = true;
      _isTracking   = true;
      _isPaused     = false;
      _elapsedSeconds = 0;
      _trackPoints  = [];
      _totalDistance = 0;
      _currentSpeed  = 0;
      _simPointIndex = 0;
      _startTime     = DateTime.now();
      _pausedSeconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) setState(() => _elapsedSeconds++);
    });
    _simTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_isPaused || _simPointIndex >= _simRoute.length) {
        if (_simPointIndex >= _simRoute.length) _stopTracking();
        return;
      }
      final point = _simRoute[_simPointIndex++];
      setState(() {
        _currentLat    = point.lat;
        _currentLng    = point.lng;
        _currentSpeed  = point.speed;
        _totalDistance = point.totalDistance / 1000.0;
        _trackPoints.add(point);
      });
      _followPosition();

      // [NEW] Sync simulated data to Firebase too
      _updateFirebaseStatus(true);

      if (_ble.isConnected) {
        _ble.writeSpeedDistance(point.speed, point.totalDistance);
      }
    });
  }

  void _stopSimulation() {
    _simTimer?.cancel();
    setState(() => _isSimulating = false);
  }

  // ── Tracking lifecycle ────────────────────────────────────────────────────
  Future<void> _startTracking() async {

    print("DEBUG: _startTracking button was pressed!");
    try {
      await FirebaseFirestore.instance.collection('test').doc('ping').set({'status': 'Online'});
      print("DEBUG: Firebase write sent successfully!");
    } catch (e) { print("DEBUG: Firebase ERROR: $e"); }

    // Start phone GPS
    final started = await _loc.startTracking();
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot start GPS. Check location permissions.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      _isTracking    = true;
      _isPaused      = false;
      _elapsedSeconds = 0;
      _trackPoints   = [];
      _totalDistance = 0;
      _currentSpeed  = 0;
      _startTime     = DateTime.now();
      _pausedSeconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) setState(() => _elapsedSeconds++);
    });
    _startBleWriteTimer();
  }

  void _pauseTracking() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _pauseStart = DateTime.now();
        _updateFirebaseStatus(false); // [NEW] Stop pulses when paused
      } else {
        if (_pauseStart != null) {
          _pausedSeconds += DateTime.now().difference(_pauseStart!).inSeconds;
        }
      }
    });
  }

  void _stopTracking() {
    _timer?.cancel();
    _stopBleWriteTimer();
    _stopSimulation();
    _loc.stopTracking();

    if (_trackPoints.isEmpty) {
      setState(() { _isTracking = false; _isPaused = false; });
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _SaveActivityDialog(
        distance: _totalDistance,
        duration: _elapsedSeconds,
        points: _trackPoints,
        userId: widget.currentUser.id,
        userName: widget.currentUser.username,
        onSave: (title, type) {
          Navigator.pop(context);
          setState(() { _isTracking = false; _isPaused = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Activity "$title" saved!'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onDiscard: () {
          Navigator.pop(context);
          setState(() { _isTracking = false; _isPaused = false; });
        },
      ),
    );
  }

  String _formatTime(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${sec.toString().padLeft(2,'0')}';
  }

  void _followPosition() {
    if (_currentLat == 0 && _currentLng == 0) return;
    _mapController.move(LatLng(_currentLat, _currentLng), 15);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Live Tracking'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _BleStatusBadge(status: _bleStatus),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // BLE Connection card
            _buildBleCard(isDark),
            const SizedBox(height: 16),

            // Live stats
            if (_isTracking || _trackPoints.isNotEmpty)
              _buildLiveStatsCard(isDark),

            // Route map
            if (_isTracking && _trackPoints.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildRouteCard(isDark),
            ],

            const SizedBox(height: 16),
            // Control buttons
            _buildControls(isDark),

            // BLE log (visible while connected or after connect attempt)
            if (_bleLog.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildBleLogCard(isDark),
            ],

            const SizedBox(height: 16),
            _buildDeviceInfoCard(isDark),
          ],
        ),
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildBleCard(bool isDark) {
    final isConn = _bleStatus == BleStatus.connected;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConn
              ? Colors.green.withOpacity(0.4)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bluetooth,
                  color: isConn ? Colors.blue : Colors.grey, size: 18),
              const SizedBox(width: 8),
              Text('BikeTracker Bluetooth',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow('Device', BleService.deviceName, isDark),
          _infoRow('Service', '19B10000-…-1214', isDark),
          _infoRow('Write', 'Speed + Distance → 19B10001', isDark),
          _infoRow('Notify', 'SOS alert ← 19B10005', isDark),
          const SizedBox(height: 12),
          if (!isConn)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isConnecting ? null : _connectBle,
                icon: _isConnecting
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.bluetooth_searching, size: 18),
                label: Text(_isConnecting ? 'Scanning…' : 'Connect to BikeTracker'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else
            Row(
              children: [
                const Icon(Icons.bluetooth_connected, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('Connected — data is being sent to device',
                        style: TextStyle(color: Colors.blue, fontSize: 13))),
                TextButton(
                  onPressed: _disconnectBle,
                  child: const Text('Disconnect',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLiveStatsCard(bool isDark) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) => Transform.scale(
        scale: _isTracking && !_isPaused ? _pulseAnimation.value * 0.02 + 0.98 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isPaused
                  ? [const Color(0xFF3A3A3A), const Color(0xFF2A2A2A)]
                  : [AppTheme.greenDark, AppTheme.green],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (_isPaused ? Colors.grey : AppTheme.greenDark)
                    .withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isPaused)
                    const Icon(Icons.pause, color: Colors.white70, size: 20),
                  Text(
                    _formatTime(_elapsedSeconds),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w200,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _liveStatBox('Distance', '${_totalDistance.toStringAsFixed(2)} km'),
                  _liveStatBox('Speed', '${_currentSpeed.toStringAsFixed(1)} km/h'),
                  _liveStatBox('Points', '${_trackPoints.length}'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gps_fixed, color: Colors.white70, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    _currentLat != 0
                        ? '${_currentLat.toStringAsFixed(5)}, '
                          '${_currentLng.toStringAsFixed(5)}'
                        : 'Waiting for GPS signal…',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteCard(bool isDark) {
    final hasPos = _currentLat != 0 && _currentLng != 0;
    final centre = hasPos
        ? LatLng(_currentLat, _currentLng)
        : const LatLng(51.5246, -0.1340);

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: centre,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.gpp.cycling_tracker',
                ),
                if (_trackPoints.length >= 2)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: _trackPoints
                          .map((p) => LatLng(p.lat, p.lng))
                          .toList(),
                      color: AppTheme.greenDark,
                      strokeWidth: 4,
                    ),
                  ]),
                if (hasPos)
                  MarkerLayer(markers: [
                    Marker(
                      point: centre,
                      width: 18,
                      height: 18,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.greenDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                      ),
                    ),
                  ]),
              ],
            ),
            Positioned(
              top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.map, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('Live Map',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(bool isDark) {
    if (!_isTracking) {
      return Column(
        children: [
          // GPS + BLE tracking
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _startTracking,
              icon: const Icon(Icons.play_arrow, size: 22),
              label: const Text('Start GPS Ride',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.green,
                foregroundColor: AppTheme.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Demo mode
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _startSimulation,
              icon: const Icon(Icons.science_outlined, size: 20),
              label: const Text('Demo Mode (No Hardware)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.greenDark,
                side: const BorderSide(color: AppTheme.green, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _bleStatus == BleStatus.connected
                  ? 'Bluetooth connected — speed & distance will be sent to device.'
                  : 'Connect Bluetooth above to send data to BikeTracker device.',
              style: TextStyle(fontSize: 11, color: AppTheme.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (_isSimulating)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.greenLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.green),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.science_outlined, size: 14, color: AppTheme.greenDark),
                SizedBox(width: 6),
                Text("Demo Mode — simulating Regent's Park route",
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.greenDark,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pauseTracking,
                icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, size: 20),
                label: Text(_isPaused ? 'Resume' : 'Pause'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPaused ? Colors.blue[600] : AppTheme.grey,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _stopTracking,
                icon: const Icon(Icons.stop_circle_outlined, size: 20),
                label: const Text('Finish'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBleLogCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bluetooth, color: Colors.blue, size: 14),
              SizedBox(width: 6),
              Text('BLE Log',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  )),
            ],
          ),
          const SizedBox(height: 8),
          ...(_bleLog.take(6).map((msg) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(msg,
                    style: const TextStyle(
                        color: Colors.lightBlueAccent,
                        fontSize: 11,
                        fontFamily: 'monospace')),
              ))),
        ],
      ),
    );
  }

  Widget _buildDeviceInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bluetooth, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Text('BikeTracker BLE Protocol',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Device name : ${BleService.deviceName}\n'
            'Service     : 19B10000-E8F2-537E-4F6C-D104768A1214\n\n'
            'Phone → Device (Write)\n'
            '  19B10001  "speed_kmh,distance_m"\n'
            '  19B10002  Float32 LE — goal metres\n'
            '  19B10003  "HH:MM" — time sync\n'
            '  19B10004  Int32 LE — online friends\n\n'
            'Device → Phone (Notify)\n'
            '  19B10005  0x01 = SOS triggered',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.grey[600],
              fontFamily: 'monospace',
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ── Small helper widgets ──────────────────────────────────────────────────

  Widget _liveStatBox(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey[500])),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}

// ── BLE Status Badge ─────────────────────────────────────────────────────────
class _BleStatusBadge extends StatelessWidget {
  final BleStatus status;
  const _BleStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    late Color color;
    late String label;
    switch (status) {
      case BleStatus.connected:  color = Colors.blue;   label = 'BLE Connected'; break;
      case BleStatus.scanning:   color = Colors.orange; label = 'Scanning';      break;
      case BleStatus.connecting: color = Colors.orange; label = 'Connecting';    break;
      case BleStatus.error:      color = Colors.red;    label = 'BLE Error';     break;
      default:                   color = Colors.grey;   label = 'BLE Off';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Save Activity Dialog ──────────────────────────────────────────────────────
class _SaveActivityDialog extends StatefulWidget {
  final double distance;
  final int duration;
  final List<GpsPoint> points;
  final String userId;
  final String userName;
  final Function(String title, String type) onSave;
  final VoidCallback onDiscard;

  const _SaveActivityDialog({
    required this.distance,
    required this.duration,
    required this.points,
    required this.userId,
    required this.userName,
    required this.onSave,
    required this.onDiscard,
  });

  @override
  State<_SaveActivityDialog> createState() => _SaveActivityDialogState();
}

class _SaveActivityDialogState extends State<_SaveActivityDialog> {
  final _titleController = TextEditingController();
  String _selectedType = 'cycle';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _titleController.text = 'Ride on ${now.day}/${now.month}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Finish Activity'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Activity Title'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Type:'),
              DropdownButton<String>(
                value: _selectedType,
                onChanged: (v) => setState(() => _selectedType = v!),
                items: const [
                  DropdownMenuItem(value: 'cycle', child: Text('Cycling')),
                  DropdownMenuItem(value: 'run', child: Text('Running')),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: widget.onDiscard, child: const Text('Discard')),
        ElevatedButton(
          onPressed: () => widget.onSave(_titleController.text, _selectedType),
          child: const Text('Save Activity'),
        ),
      ],
    );
  }
}