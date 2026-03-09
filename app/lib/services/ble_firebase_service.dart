import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class BLEFirebaseDebugScreen extends StatefulWidget {
  final String? targetDeviceName;
  const BLEFirebaseDebugScreen({super.key, this.targetDeviceName});

  @override
  State<BLEFirebaseDebugScreen> createState() => _BLEFirebaseDebugScreenState();
}

class _BLEFirebaseDebugScreenState extends State<BLEFirebaseDebugScreen> {
  final flutterReactiveBle = FlutterReactiveBle();
  final database = FirebaseDatabase.instance.ref();

  DiscoveredDevice? device;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  final List<StreamSubscription<List<int>>> _charSubscriptions = [];

  String status = "Idle";

  // BLE UUIDs
  final String serviceUuid = "19B10000-E8F2-537E-4F6C-D104768A1214";
  final Map<String, String> charUuids = {
    "lat": "19B10001-E8F2-537E-4F6C-D104768A1214",
    "lon": "19B10002-E8F2-537E-4F6C-D104768A1214",
    "speed": "19B10003-E8F2-537E-4F6C-D104768A1214",
    "distance": "19B10004-E8F2-537E-4F6C-D104768A1214",
    "progress": "19B10005-E8F2-537E-4F6C-D104768A1214",
    "goal": "19B10006-E8F2-537E-4F6C-D104768A1214",
  };

  // Latest values
  double lat = 0, lon = 0, speed = 0, distance = 0, progress = 0, goal = 0;

  @override
  void initState() {
    super.initState();
    _initBLEFlow();
  }

  /// Step 1: Request runtime permissions & check location services
  Future<bool> _checkPermissionsAndLocation() async {
    setState(() => status = "Requesting permissions...");

    final perms = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();

    final allGranted = perms.values.every((p) => p.isGranted);
    if (!allGranted) {
      setState(() => status = "❌ Permissions denied");
      return false;
    }

    final locationEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationEnabled) {
      setState(() => status = "❌ Location services are OFF. Please enable GPS.");
      return false;
    }

    print("✅ Permissions & location OK");
    return true;
  }

  /// Step 2: Initialize BLE scan flow
  Future<void> _initBLEFlow() async {
    final ok = await _checkPermissionsAndLocation();
    if (!ok) return;

    _startScanAndConnect(targetName: widget.targetDeviceName);
  }

  /// Step 3: Start scanning & connect
  void _startScanAndConnect({String? targetName}) {
    setState(() => status = "Scanning for BLE devices...");
    print("🔍 Starting BLE scan...");

    _scanSubscription = flutterReactiveBle
        .scanForDevices(
          withServices: [Uuid.parse(serviceUuid)],
          scanMode: ScanMode.lowLatency,
        )
        .listen((scanResult) {
      print("📡 Found device: ${scanResult.name} | id=${scanResult.id}");
      print("Service UUIDs: ${scanResult.serviceUuids}");

      // Optional: connect only to target name, but for debugging connect to first matching service
      // if (targetName != null && scanResult.name != targetName) return;

      if (!scanResult.serviceUuids.contains(serviceUuid)) {
        print("⚠️ Device ${scanResult.name} does not advertise our target service UUID");
        return;
      }

      if (device == null) {
        device = scanResult;
        setState(() => status = "✅ Found device: ${device!.name}");
        print("📌 Connecting to device ${device!.id} ...");
        _scanSubscription?.cancel();
        _connectToDevice();
      }
    }, onError: (e) {
      setState(() => status = "❌ Scan error: $e");
      print("Scan error: $e");
    });
  }

  /// Step 4: Connect to BLE device
  void _connectToDevice() {
    if (device == null) return;
    setState(() => status = "Connecting to device...");

    _connectionSubscription = flutterReactiveBle
        .connectToDevice(
          id: device!.id,
          servicesWithCharacteristicsToDiscover: {
            Uuid.parse(serviceUuid):
                charUuids.values.map((c) => Uuid.parse(c)).toList(),
          },
          connectionTimeout: const Duration(seconds: 10),
        )
        .listen((state) {
      setState(() => status = "Connection state: ${state.connectionState}");
      print("🔗 Connection state: ${state.connectionState}");

      if (state.connectionState == DeviceConnectionState.connected) {
        _subscribeToAllCharacteristics(device!.id);
      } else if (state.connectionState == DeviceConnectionState.disconnected) {
        Future.delayed(const Duration(seconds: 2), _connectToDevice);
      }
    }, onError: (e) {
      setState(() => status = "❌ Connection error: $e");
      print("Connection error: $e");
      Future.delayed(const Duration(seconds: 2), _connectToDevice);
    });
  }

  /// Step 5: Subscribe to all BLE characteristics
  void _subscribeToAllCharacteristics(String deviceId) {
    for (var entry in charUuids.entries) {
      final characteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse(serviceUuid),
        characteristicId: Uuid.parse(entry.value),
        deviceId: deviceId,
      );

      final sub = flutterReactiveBle
          .subscribeToCharacteristic(characteristic)
          .listen((data) async {
        print("📥 RAW BLE DATA (${entry.key}): $data");

        double value = _bytesToFloat(data);
        switch (entry.key) {
          case "lat":
            lat = value;
            break;
          case "lon":
            lon = value;
            break;
          case "speed":
            speed = value;
            break;
          case "distance":
            distance = value;
            break;
          case "progress":
            progress = value;
            break;
          case "goal":
            goal = value;
            break;
        }

        setState(() {}); // Update UI

        try {
          await database.child('bike_tracker/latest').set({
            "lat": lat,
            "lon": lon,
            "speed": speed,
            "distance": distance,
            "progress": progress,
            "goal": goal,
            "timestamp": DateTime.now().toIso8601String(),
          });
        } catch (e) {
          print("Firebase write error: $e");
        }
      }, onError: (e) => print("❌ Subscription error (${entry.key}): $e"));

      _charSubscriptions.add(sub);
    }
  }

  double _bytesToFloat(List<int> bytes) {
    if (bytes.length != 4) return 0.0;
    return ByteData.sublistView(Uint8List.fromList(bytes)).getFloat32(0, Endian.little);
  }

  Future<void> writeGoal(double newGoal) async {
    if (device == null) return;
    final characteristic = QualifiedCharacteristic(
      serviceId: Uuid.parse(serviceUuid),
      characteristicId: Uuid.parse(charUuids["goal"]!),
      deviceId: device!.id,
    );
    await flutterReactiveBle.writeCharacteristicWithResponse(
      characteristic,
      value: _floatToBytes(newGoal),
    );
    goal = newGoal;
    setState(() {});
  }

  List<int> _floatToBytes(double value) {
    final buffer = ByteData(4);
    buffer.setFloat32(0, value.toDouble(), Endian.little);
    return buffer.buffer.asUint8List();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    for (var sub in _charSubscriptions) sub.cancel();
    _charSubscriptions.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BLE + Firebase Debug")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Status: $status", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            Text("Lat: $lat", style: const TextStyle(fontSize: 16)),
            Text("Lon: $lon", style: const TextStyle(fontSize: 16)),
            Text("Speed: $speed km/h", style: const TextStyle(fontSize: 16)),
            Text("Distance: $distance m", style: const TextStyle(fontSize: 16)),
            Text("Progress: ${(progress * 100).toStringAsFixed(1)}%", style: const TextStyle(fontSize: 16)),
            Text("Goal: $goal", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => writeGoal(goal + 1),
              child: const Text("Increase Goal"),
            ),
          ],
        ),
      ),
    );
  }
}