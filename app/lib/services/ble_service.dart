import 'dart:async';
import 'dart:convert'; // For utf8 encoding
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firestore_service.dart'; // Cloud Sync Service

enum BleStatus { disconnected, scanning, connecting, connected, error }

class BleService {
  // ── BLE UUID CONFIGURATION ────────────────────────────────────────────────
  // These UUIDs must match the ones defined in your Arduino/ESP32 sketch
  static const String _serviceUuid  = '19b10000-e8f2-537e-4f6c-d104768a1214';
  static const String _charSpeed    = '19b10001-e8f2-537e-4f6c-d104768a1214';
  static const String _charGoal     = '19b10002-e8f2-537e-4f6c-d104768a1214';
  static const String _charTime     = '19b10003-e8f2-537e-4f6c-d104768a1214';
  static const String _charFriends  = '19b10004-e8f2-537e-4f6c-d104768a1214';
  static const String _charSos      = '19b10005-e8f2-537e-4f6c-d104768a1214';
  static const String _charSocial   = '19b10006-e8f2-537e-4f6c-d104768a1214'; 

  static const String deviceName    = 'BikeTracker_E';

  // ── HARDWARE MAPPING ──────────────────────────────────────────────────────
  // Maps Firebase UIDs to physical ESP32 MAC addresses for specific users
  static const Map<String, String> _userToHardware = {
    'QwTQqMw4D2NaZJqWTgQmHwaSnPe2': '1C:DB:D4:7B:62:B5', // Gilang's ESP32
    '3GfsCbAHgTRZOkC7eTwy30Ao0Eq2': '30:ED:AO:29:9B:21', // Casa's ESP32
  };

  String? _targetMac;

  /// Sets the hardware target based on the currently logged-in user
  void setTargetUser(String userId) {
    _targetMac = _userToHardware[userId];
    _log('Targeting Hardware MAC: $_targetMac for User: $userId');
  }

  // ── STATE MANAGEMENT ──────────────────────────────────────────────────────
  BluetoothDevice? _device;
  BleStatus _status = BleStatus.disconnected;

  // Internal references to BLE Characteristics
  BluetoothCharacteristic? _cSpeed;
  BluetoothCharacteristic? _cGoal;
  BluetoothCharacteristic? _cTime;
  BluetoothCharacteristic? _cFriends;
  BluetoothCharacteristic? _cSos;
  BluetoothCharacteristic? _cSocial;

  // Subscriptions to manage data streams and connection listeners
  StreamSubscription? _scanSub;
  StreamSubscription? _connSub;
  StreamSubscription? _sosSub;

  // Throttling variables to prevent flooding the BLE write buffer
  bool _isWritingSpeed = false; 
  DateTime? _lastSpeedWrite; 

  final FirestoreService _firestore = FirestoreService();

  // Broadcast controllers to push updates to the UI
  final _statusCtrl = StreamController<BleStatus>.broadcast();
  final _sosCtrl    = StreamController<bool>.broadcast();
  final _logCtrl    = StreamController<String>.broadcast();

  // Public Getters for Streams
  Stream<BleStatus> get statusStream => _statusCtrl.stream;
  Stream<bool>      get sosStream     => _sosCtrl.stream;
  Stream<String>    get logStream     => _logCtrl.stream;

  BleStatus get status => _status;
  bool get isConnected => _status == BleStatus.connected;

  // Singleton instance to ensure only one BleService exists in the app
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // ── PERMISSIONS & CONNECTION LOGIC ────────────────────────────────────────

  /// Requests Android-specific BLE and Location permissions
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }

  /// Scans for and establishes a connection with the bike hardware
  Future<bool> connectToDevice() async {
    if (_status == BleStatus.connected) return true;

    // Check if Bluetooth is available on the hardware
    if (await FlutterBluePlus.isSupported == false) {
      _log('⚠️ Hardware does not support Bluetooth');
      _updateStatus(BleStatus.error);
      return false;
    }

    // Automatically turn on Bluetooth for Android users
    if (Platform.isAndroid && FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
    }

    final granted = await requestPermissions();
    if (!granted) {
      _log('⚠️ Permissions denied');
      _updateStatus(BleStatus.error);
      return false;
    }

    _updateStatus(BleStatus.scanning);
    _log('🔍 Scanning for: $deviceName');

    await FlutterBluePlus.stopScan();

    final completer = Completer<BluetoothDevice?>();
    Timer? timeoutTimer;

    // Listen for scan results and match by name or Service UUID
    _scanSub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        bool matchName = r.device.advName == deviceName || 
                         r.device.platformName == deviceName ||
                         r.advertisementData.localName == deviceName;
        
        bool matchUuid = r.advertisementData.serviceUuids
            .map((e) => e.toString().toLowerCase())
            .contains(_serviceUuid.toLowerCase());

        if (matchName || matchUuid) {
          _log('✅ Device Matched! Connecting...');
          timeoutTimer?.cancel();
          FlutterBluePlus.stopScan();
          if (!completer.isCompleted) completer.complete(r.device);
          return;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(_serviceUuid)], 
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      _log('❌ Scan failed: $e');
    }

    // Set 10-second timeout for scanning
    timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        _log('⏱️ Scan timeout');
        FlutterBluePlus.stopScan();
        completer.complete(null);
      }
    });

    final device = await completer.future;
    _scanSub?.cancel();

    if (device == null) {
      _updateStatus(BleStatus.error);
      return false;
    }

    return await _connect(device);
  }

  /// Internal connection handler for a specific Bluetooth device
  Future<bool> _connect(BluetoothDevice device) async {
    _updateStatus(BleStatus.connecting);
    _device = device;

    try {
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
    } catch (e) {
      _log('Connect error: $e');
      _updateStatus(BleStatus.error);
      return false;
    }

    await Future.delayed(const Duration(milliseconds: 600));

    // Request higher MTU for faster data transfer on Android
    if (Platform.isAndroid) {
      try { await device.requestMtu(251); } catch (_) {}
    }

    // Monitor connection state for unexpected disconnects
    _connSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _log('Device disconnected');
        _updateStatus(BleStatus.disconnected);
        _clearCharacteristics();
      }
    });

    return await _discoverServices(device);
  }

  /// Discovers GATT services and assigns relevant characteristics
  Future<bool> _discoverServices(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      for (final svc in services) {
        if (svc.uuid.toString().toLowerCase() == _serviceUuid) {
          _log('GPP service found');
          for (final c in svc.characteristics) {
            final uuid = c.uuid.toString().toLowerCase();
            if (uuid == _charSpeed)   _cSpeed   = c;
            if (uuid == _charGoal)    _cGoal    = c;
            if (uuid == _charTime)    _cTime    = c;
            if (uuid == _charFriends) _cFriends = c;
            if (uuid == _charSos)     _cSos     = c;
            if (uuid == _charSocial)  _cSocial  = c;
          }
          break;
        }
      }
    } catch (e) {
      _log('Service discovery error: $e');
      _updateStatus(BleStatus.error);
      return false;
    }

    if (_cSpeed == null) {
      _log('Required characteristics not found');
      _updateStatus(BleStatus.error);
      return false;
    }

    // Setup listener for hardware-triggered SOS alerts
    if (_cSos != null) {
      try {
        await _cSos!.setNotifyValue(true);
        _sosSub = _cSos!.onValueReceived.listen((value) {
          if (value.isNotEmpty) {
            final triggered = value[0] == 0x01;
            _log(triggered ? '🚨 SOS ALERT!' : 'SOS cleared');
            _sosCtrl.add(triggered);
            _firestore.logSosAlert(triggered);
          }
        });
      } catch (e) { _log('SOS notify error: $e'); }
    }

    _updateStatus(BleStatus.connected);
    _log('Connected to $deviceName');

    await Future.delayed(const Duration(milliseconds: 200));
    await syncTime(); // Sync phone clock to bike display

    return true;
  }

  /// Fully terminates the connection and clears resources
  void disconnect() {
    _sosSub?.cancel();
    _connSub?.cancel();
    _scanSub?.cancel();
    _device?.disconnect();
    _clearCharacteristics();
    _updateStatus(BleStatus.disconnected);
    _log('Disconnected');
  }

  // ── DATA TRANSMISSION HELPERS (WRITE) ─────────────────────────────────────

  /// Triggers a social notification pulse on the bike hardware
  Future<void> writeNeoPixelSocialSignal() async {
    if (!isConnected || _cSocial == null) {
      _log('⚠️ Social signal failed: Not connected or characteristic missing');
      return;
    }

    try {
      // 0x01 command triggers the pre-defined animation in ESP32
      await _cSocial!.write([0x01], withoutResponse: false);
      _log('🚀 Social pulse command sent to bike hardware!');
    } catch (e) {
      _log('❌ Social signal error: $e');
    }
  }

  /// Syncs speed and distance metrics to both Firebase and the bike hardware
  /// [goalM] is optional (defaults to 10km) to ensure backward compatibility with the UI
  Future<void> writeSpeedDistance(double speedKmh, double distanceM, [double goalM = 10000.0]) async {
    if (_cSpeed == null || !isConnected) return;
    if (_isWritingSpeed) return; 

    // Throttling: Prevents updates faster than twice per second (500ms)
    final now = DateTime.now();
    if (_lastSpeedWrite != null && now.difference(_lastSpeedWrite!) < const Duration(milliseconds: 500)) {
      return; 
    }

    _isWritingSpeed = true;
    _lastSpeedWrite = now;

    // 1. Synchronize data to Firestore Cloud
    _firestore.updateRideMetrics(speedKmh, distanceM, goalM);

    // 2. Synchronize data to the Physical Bike Dashboard
    final payload = '${speedKmh.toStringAsFixed(1)},${distanceM.toStringAsFixed(1)}';
    try {
      await _cSpeed!.write(utf8.encode(payload), withoutResponse: false);
    } catch (e) {
      _log('[BLE] writeSpeedDistance error: $e');
    } finally {
      _isWritingSpeed = false;
    }
  }

  /// Updates the ride goal (meters) on the hardware
  Future<void> writeGoalMetres(double metres) async {
    if (_cGoal == null || !isConnected) return;
    try {
      final bd = ByteData(4)..setFloat32(0, metres, Endian.little);
      await _cGoal!.write(bd.buffer.asUint8List(), withoutResponse: false);
      _log('Goal sent: ${metres.toStringAsFixed(0)} m');
    } catch (e) { _log('writeGoal error: $e'); }
  }

  /// Synchronizes smartphone system time to the bike display clock
  Future<void> syncTime() async {
    if (_cTime == null || !isConnected) return;
    try {
      final now = DateTime.now();
      final t = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await _cTime!.write(utf8.encode(t), withoutResponse: false);
      _log('Time synced: $t');
    } catch (e) { _log('syncTime error: $e'); }
  }

  /// Sends the number of online friends to the bike hardware dashboard
  Future<void> writeOnlineFriends(int count) async {
    if (_cFriends == null || !isConnected) return;
    try {
      final bd = ByteData(4)..setInt32(0, count, Endian.little);
      await _cFriends!.write(bd.buffer.asUint8List(), withoutResponse: false);
      _log('Friends online: $count');
    } catch (e) { _log('writeFriends error: $e'); }
  }

  // ── INTERNAL UTILITY METHODS ──────────────────────────────────────────────

  /// Updates local status and broadcasts it to UI listeners
  void _updateStatus(BleStatus s) {
    _status = s;
    _statusCtrl.add(s);
  }

  /// Resets all characteristic references on disconnect
  void _clearCharacteristics() {
    _cSpeed = null; _cGoal = null; _cTime = null;
    _cFriends = null; _cSos = null; _cSocial = null;
  }

  /// Centralized logging for debugging
  void _log(String msg) {
    debugPrint('[BLE] $msg');
    _logCtrl.add(msg);
  }

  /// Resource cleanup for when the service is destroyed
  void dispose() {
    disconnect();
    _statusCtrl.close();
    _sosCtrl.close();
    _logCtrl.close();
  }
}