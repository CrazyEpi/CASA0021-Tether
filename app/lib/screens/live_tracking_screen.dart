import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/activity.dart';
import '../models/user.dart';

// ===== BLE UUIDs (match Arduino) =====
final Uuid serviceUuid = Uuid.parse("19B10000-E8F2-537E-4F6C-D104768A1214");
final Map<String, Uuid> charUuids = {
  "lat": Uuid.parse("19B10001-E8F2-537E-4F6C-D104768A1214"),
  "lon": Uuid.parse("19B10002-E8F2-537E-4F6C-D104768A1214"),
  "speed": Uuid.parse("19B10003-E8F2-537E-4F6C-D104768A1214"),
  "distance": Uuid.parse("19B10004-E8F2-537E-4F6C-D104768A1214"),
  "progress": Uuid.parse("19B10005-E8F2-537E-4F6C-D104768A1214"),
  "goal": Uuid.parse("19B10006-E8F2-537E-4F6C-D104768A1214"),
};

class LiveTrackingScreen extends StatefulWidget {
  final AppUser currentUser;
  const LiveTrackingScreen({super.key, required this.currentUser});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  // BLE
  DiscoveredDevice? _device;
  StreamSubscription<ConnectionStateUpdate>? _connection;
  final Map<String, StreamSubscription<List<int>>> _charSubs = {};

  // Tracking state
  bool _isTracking = false;
  bool _isPaused = false;

  // Live Data
  double _lat = 0.0;
  double _lng = 0.0;
  double _speed = 0.0;
  double _distance = 0.0; // meters
  double _goalProgress = 0.0;
  double _goal = 10.0; // meters

  List<GpsPoint> _trackPoints = [];

  // Timer
  Timer? _timer;
  int _elapsedSeconds = 0;

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _realtimeDb = FirebaseDatabase.instance.ref();
  String? _currentActivityId;

  @override
  void initState() {
    super.initState();
    _scanAndConnect();
  }

  @override
  void dispose() {
    _connection?.cancel();
    for (var sub in _charSubs.values) sub.cancel();
    _timer?.cancel();
    super.dispose();
  }

  // ===== BLE scan & connect =====
  void _scanAndConnect() {
    _ble.scanForDevices(withServices: [serviceUuid]).listen((device) {
      if (device.name.contains("BikeTracker")) {
        setState(() => _device = device);
        _ble.scanForDevices(withServices: [serviceUuid]).listen((_) {}).cancel();
        _connectToDevice(device);
      }
    });
  }

  void _connectToDevice(DiscoveredDevice device) async {
    _connection = _ble.connectToDevice(
      id: device.id,
      servicesWithCharacteristicsToDiscover: {serviceUuid: charUuids.values.toList()},
    ).listen((update) {
      if (update.connectionState == DeviceConnectionState.connected) {
        _subscribeToCharacteristics();
      }
    });
  }

  void _subscribeToCharacteristics() {
    charUuids.forEach((key, uuid) {
      final sub = _ble.subscribeToCharacteristic(QualifiedCharacteristic(
        deviceId: _device!.id, serviceId: serviceUuid, characteristicId: uuid,
      )).listen((data) => _updateChar(key, data));
      _charSubs[key] = sub;
    });
  }

  // ===== Update BLE characteristics =====
  void _updateChar(String key, List<int> data) {
    if (data.length < 4) return;

    final bytes = Uint8List.fromList(data.sublist(0, 4));
    final value = ByteData.sublistView(bytes).getFloat32(0, Endian.little);

    setState(() {
      switch (key) {
        case "lat":
          _lat = value;
          break;
        case "lon":
          _lng = value;
          break;
        case "speed":
          _speed = value;
          break;
        case "distance":
          if (value > 0) _distance = value; // meters
          _updateProgress();
          break;
        case "progress":
          _goalProgress = value; // optional, recalculated anyway
          break;
        case "goal":
          if (value > 0) _goal = value; // meters
          _updateProgress();
          break;
      }
    });

    _sendLiveToFirebase();
    _sendLiveToRealtimeDb();

    _trackPoints.add(GpsPoint(
      lat: _lat,
      lng: _lng,
      speed: _speed,
      totalDistance: _distance,
      timestamp: DateTime.now(),
    ));
  }

  // ===== Progress calculation =====
  void _updateProgress() {
    if (_goal <= 0) {
      _goalProgress = 0.0;
      return;
    }
    _goalProgress = _distance / _goal;
    if (_goalProgress > 1.0) _goalProgress = 1.0; // cap at 100%
  }

  // ===== Timer & tracking =====
  void _startTracking() {
    if (_device == null) return;
    setState(() {
      _isTracking = true;
      _isPaused = false;
      _elapsedSeconds = 0;
      _trackPoints = [];
      _currentActivityId = _firestore.collection('activities').doc().id;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) setState(() => _elapsedSeconds++);
    });
  }

  void _pauseTracking() => setState(() => _isPaused = !_isPaused);

  void _stopTracking() {
    _timer?.cancel();
    if (_trackPoints.isEmpty) {
      setState(() => _isTracking = false);
      return;
    }
    showDialog(
      context: context,
      builder: (_) => _SaveActivityDialog(
        distance: _distance,
        duration: _elapsedSeconds,
        points: _trackPoints,
        userId: widget.currentUser.id,
        userName: widget.currentUser.username,
        onSave: (title, type) async {
          Navigator.pop(context);
          await _firestore.collection('activities').doc(_currentActivityId).set({
            'title': title,
            'type': type,
            'userId': widget.currentUser.id,
            'distance': _distance,
            'duration': _elapsedSeconds,
            'track': _trackPoints.map((p) => p.toMap()).toList(),
            'timestamp': FieldValue.serverTimestamp(),
          });
          setState(() => _isTracking = false);
        },
        onDiscard: () => setState(() => _isTracking = false),
      ),
    );
  }

  // ===== Firestore Live Update =====
  Future<void> _sendLiveToFirebase() async {
    if (_currentActivityId == null || !_isTracking || _isPaused) return;
    await _firestore.collection('activities').doc(_currentActivityId).set({
      'lat': _lat,
      'lng': _lng,
      'speed': _speed,
      'distance': _distance,
      'progress': _goalProgress,
      'goal': _goal,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ===== Realtime Database Live Update =====
  Future<void> _sendLiveToRealtimeDb() async {
    if (!_isTracking || _isPaused) return;
    await _realtimeDb.child('bike_tracker').set({
      'lat': _lat,
      'lng': _lng,
      'speed': _speed,
      'distance': _distance,
      'progress': _goalProgress,
      'goal': _goal,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // ===== BLE write for goal =====
  Future<void> _writeGoalToBle(double newGoal) async {
    if (_device == null) return;
    final charId = charUuids["goal"]!;
    final characteristic = QualifiedCharacteristic(
      deviceId: _device!.id,
      serviceId: serviceUuid,
      characteristicId: charId,
    );
    final bytes = ByteData(4)..setFloat32(0, newGoal, Endian.little);
    try {
      await _ble.writeCharacteristicWithResponse(characteristic, value: bytes.buffer.asUint8List());
      setState(() => _goal = newGoal);
      _updateProgress();
      _sendLiveToFirebase();
      _sendLiveToRealtimeDb();
    } catch (e) {
      print("❌ Failed to write goal to BLE: $e");
    }
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Tracking')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Device: ${_device?.name ?? 'Scanning...'}"),
            Text("Lat: $_lat, Lng: $_lng"),
            Text("Speed: $_speed km/h"),
            Text("Distance: ${_distance.toStringAsFixed(2)} m"),
            Text("Progress: ${(_goalProgress * 100).toStringAsFixed(1)} %"),
            Text("Goal: $_goal m"),
            const SizedBox(height: 12),
            if (_isTracking)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _pauseTracking,
                      child: Text(_isPaused ? "Resume" : "Pause"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _stopTracking,
                      child: const Text("Finish"),
                    ),
                  ),
                ],
              )
            else
              ElevatedButton(onPressed: _startTracking, child: const Text("Start Activity")),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTracking ? () => _writeGoalToBle(_goal + 10) : null,
                    child: const Text("Increase Goal"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isTracking
                        ? () {
                            final controller = TextEditingController();
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("Set Custom Goal"),
                                content: TextField(
                                  controller: controller,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: "Goal (m)"),
                                ),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Cancel")),
                                  ElevatedButton(
                                    onPressed: () {
                                      final val = double.tryParse(controller.text);
                                      if (val != null && val > 0) _writeGoalToBle(val);
                                      Navigator.pop(context);
                                    },
                                    child: const Text("Set"),
                                  ),
                                ],
                              ),
                            );
                          }
                        : null,
                    child: const Text("Set Goal"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Save Activity Dialog =====
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
    super.key,
  });

  @override
  State<_SaveActivityDialog> createState() => _SaveActivityDialogState();
}

class _SaveActivityDialogState extends State<_SaveActivityDialog> {
  final _titleController = TextEditingController();
  String _selectedType = 'run';
  final List<String> _types = ['run', 'cycle', 'walk', 'hike'];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Save Activity"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedType,
            items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t.capitalize()))).toList(),
            onChanged: (v) { if (v != null) setState(() => _selectedType = v); },
            decoration: const InputDecoration(labelText: 'Activity Type'),
          ),
          const SizedBox(height: 12),
          Text('Distance: ${widget.distance.toStringAsFixed(2)} m'),
          Text('Duration: ${widget.duration}s'),
        ],
      ),
      actions: [
        TextButton(onPressed: widget.onDiscard, child: const Text("Discard")),
        ElevatedButton(onPressed: () { 
          final title = _titleController.text.trim(); 
          if (title.isEmpty) return; 
          widget.onSave(title, _selectedType); 
        }, child: const Text("Save")),
      ],
    );
  }
}

// ===== String extension =====
extension StringCap on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}