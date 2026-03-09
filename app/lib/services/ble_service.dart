import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_options.dart';

class BLEService extends ChangeNotifier {
  // ===== BLE & Firebase =====
  final flutterReactiveBle = FlutterReactiveBle();
  DiscoveredDevice? device;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  final Map<String, StreamSubscription<List<int>>> _charSubscriptions = {};
  final DatabaseReference database =
      FirebaseDatabase.instance.ref("bike_tracker");

  String status = "Idle";
  double latitude = 0.0;
  double longitude = 0.0;
  double speed = 0.0;
  double distance = 0.0;
  double progress = 0.0;

  double targetDistance = 10.0; // Default goal

  final String serviceUuid = "19B10000-E8F2-537E-4F6C-D104768A1214";
  final Map<String, String> characteristicUuids = {
    "Latitude": "19B10001-E8F2-537E-4F6C-D104768A1214",
    "Longitude": "19B10002-E8F2-537E-4F6C-D104768A1214",
    "Speed": "19B10003-E8F2-537E-4F6C-D104768A1214",
    "Distance": "19B10004-E8F2-537E-4F6C-D104768A1214",
    "Progress": "19B10005-E8F2-537E-4F6C-D104768A1214",
  };

  // ===== BLE Values =====
  final Map<String, double> bleValues = {
    "Latitude": 0.0,
    "Longitude": 0.0,
    "Speed": 0.0,
    "Distance": 0.0,
    "Progress": 0.0,
  };

  Timer? uploadTimer;

  double lastLat = 0.0;
  double lastLon = 0.0;

  // ================= INIT =================
  Future<void> initialize() async {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    // Sign in anonymously
    await FirebaseAuth.instance.signInAnonymously();

    // Request permissions
    final granted = await _requestPermissions();
    if (!granted) {
      status = "❌ Permissions denied";
      notifyListeners();
      return;
    }

    // Start BLE scan
    _startScan();

    // Upload to Firebase every 3 seconds
    uploadTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _uploadToFirebase();
    });
  }

  Future<bool> _requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();

    final locService = Location();
    bool serviceEnabled = await locService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await locService.requestService();
    }

    return statuses.values.every((status) => status.isGranted) && serviceEnabled;
  }

  // ================= SCAN =================
  void _startScan() {
    status = "Scanning for BLE devices...";
    notifyListeners();

    _scanSubscription?.cancel();
    _scanSubscription =
        flutterReactiveBle.scanForDevices(withServices: []).listen((scanResult) {
      if (scanResult.name.contains("BikeTracker_E") && device == null) {
        device = scanResult;
        status = "✅ Found ${device!.name}";
        notifyListeners();
        _scanSubscription?.cancel();
        _connectToDevice();
      }
    }, onError: (e) {
      status = "❌ Scan error: $e";
      notifyListeners();
    });

    // Timeout
    Future.delayed(const Duration(seconds: 15), () {
      if (device == null) {
        _scanSubscription?.cancel();
        status = "❌ Device not found after 15s";
        notifyListeners();
      }
    });
  }

  // ================= CONNECT =================
  void _connectToDevice() {
    if (device == null) return;

    status = "Connecting to ${device!.name}...";
    notifyListeners();

    _connectionSubscription?.cancel();
    _connectionSubscription = flutterReactiveBle
        .connectToDevice(
      id: device!.id,
      servicesWithCharacteristicsToDiscover: {
        Uuid.parse(serviceUuid):
            characteristicUuids.values.map((e) => Uuid.parse(e)).toList()
      },
    )
        .listen((connectionState) {
      status = "Connection: ${connectionState.connectionState}";
      notifyListeners();

      if (connectionState.connectionState ==
          DeviceConnectionState.connected) {
        Future.delayed(const Duration(milliseconds: 200), _subscribeToAllCharacteristics);
      }
    }, onError: (e) {
      status = "❌ Connection error: $e";
      notifyListeners();
      Future.delayed(const Duration(seconds: 2), _connectToDevice);
    });
  }

  // ================= SUBSCRIBE =================
  void _subscribeToAllCharacteristics() {
    if (device == null) return;

    characteristicUuids.forEach((label, charUuid) {
      final characteristic = QualifiedCharacteristic(
        deviceId: device!.id,
        serviceId: Uuid.parse(serviceUuid),
        characteristicId: Uuid.parse(charUuid),
      );

      _charSubscriptions[label]?.cancel();
      _charSubscriptions[label] =
          flutterReactiveBle.subscribeToCharacteristic(characteristic).listen(
        (data) {
          if (data.length >= 4) {
            final byteData = ByteData.sublistView(Uint8List.fromList(data));
            final value = byteData.getFloat32(0, Endian.little);

            switch (label) {
              case "Latitude":
                latitude = value;
                break;
              case "Longitude":
                longitude = value;
                break;
              case "Speed":
                speed = value;
                break;
              case "Distance":
                distance = value;
                break;
              case "Progress":
                progress = value;
                break;
            }
            bleValues[label] = value;
            notifyListeners();
          }
        },
        onError: (e) => print("Subscription error $label: $e"),
      );
    });
  }

  // ================= FIREBASE UPLOAD =================
  Future<void> _uploadToFirebase() async {
    try {
      await database.update({
        "Latitude": latitude,
        "Longitude": longitude,
        "Speed": speed,
        "Distance": distance,
        "Progress": progress,
        "TargetDistance": targetDistance,
        "timestamp": DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print("Firebase upload error: $e");
    }
  }

  // ================= SET TARGET DISTANCE =================
  void setTargetDistance(double newTarget) {
    targetDistance = newTarget;
    notifyListeners();
  }

  @override
  void dispose() {
    uploadTimer?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _charSubscriptions.forEach((_, sub) => sub.cancel());
    super.dispose();
  }
}