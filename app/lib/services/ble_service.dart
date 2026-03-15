import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// ============================================================
// Bluetooth LE Service
// Connects to BikeTracker_E device and exchanges data per spec:
//
// Service: 19B10000-E8F2-537E-4F6C-D104768A1214
//
// Phone → Device (Write):
//   19B10001  "speed_kmh,distance_m"  e.g. "15.2,1250.5"
//   19B10002  Float32 LE  goal in metres
//   19B10003  "HH:MM"     current time
//   19B10004  Int32 LE    online-friends count
//
// Device → Phone (Notify):
//   19B10005  0x01 = SOS triggered, 0x00 = SOS cleared
// ============================================================

enum BleStatus { disconnected, scanning, connecting, connected, error }

class BleService {
  // ── UUIDs ──────────────────────────────────────────────────────────────────
  static const String _serviceUuid  = '19b10000-e8f2-537e-4f6c-d104768a1214';
  static const String _charSpeed    = '19b10001-e8f2-537e-4f6c-d104768a1214';
  static const String _charGoal     = '19b10002-e8f2-537e-4f6c-d104768a1214';
  static const String _charTime     = '19b10003-e8f2-537e-4f6c-d104768a1214';
  static const String _charFriends  = '19b10004-e8f2-537e-4f6c-d104768a1214';
  static const String _charSos      = '19b10005-e8f2-537e-4f6c-d104768a1214';

  static const String deviceName    = 'BikeTracker_E';

  // ── State ──────────────────────────────────────────────────────────────────
  BluetoothDevice? _device;
  BleStatus _status = BleStatus.disconnected;

  BluetoothCharacteristic? _cSpeed;
  BluetoothCharacteristic? _cGoal;
  BluetoothCharacteristic? _cTime;
  BluetoothCharacteristic? _cFriends;
  BluetoothCharacteristic? _cSos;

  StreamSubscription? _scanSub;
  StreamSubscription? _connSub;
  StreamSubscription? _sosSub;

  // ── Streams ────────────────────────────────────────────────────────────────
  final _statusCtrl = StreamController<BleStatus>.broadcast();
  final _sosCtrl    = StreamController<bool>.broadcast();
  final _logCtrl    = StreamController<String>.broadcast();

  Stream<BleStatus> get statusStream => _statusCtrl.stream;
  Stream<bool>      get sosStream     => _sosCtrl.stream;
  Stream<String>    get logStream     => _logCtrl.stream;

  BleStatus get status => _status;
  bool get isConnected => _status == BleStatus.connected;

  // ── Singleton ──────────────────────────────────────────────────────────────
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Request all required Bluetooth + Location permissions (Android only).
  /// Returns true if all granted.
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    final allGranted = statuses.values.every(
        (s) => s == PermissionStatus.granted || s == PermissionStatus.limited);
    if (!allGranted) {
      _log('Bluetooth or location permissions denied');
    }
    return allGranted;
  }

  /// Scan for BikeTracker_E and connect. Returns true on success.
  Future<bool> connectToDevice() async {
    if (_status == BleStatus.connected) return true;

    // Request permissions first on Android
    final granted = await requestPermissions();
    if (!granted) {
      _updateStatus(BleStatus.error);
      return false;
    }

    _updateStatus(BleStatus.scanning);
    _log('Scanning for $deviceName…');

    // Cancel any leftover scan
    await FlutterBluePlus.stopScan();

    final completer = Completer<BluetoothDevice?>();

    _scanSub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        if (r.device.advName == deviceName || r.device.platformName == deviceName) {
          _log('Found $deviceName');
          FlutterBluePlus.stopScan();
          if (!completer.isCompleted) completer.complete(r.device);
          return;
        }
      }
    });

    await FlutterBluePlus.startScan(
      withNames: [deviceName],
      timeout: const Duration(seconds: 10),
    );

    // If scan ends without finding the device
    _scanSub?.cancel();
    if (!completer.isCompleted) completer.complete(null);

    final device = await completer.future;
    if (device == null) {
      _log('Device not found');
      _updateStatus(BleStatus.error);
      return false;
    }

    return await _connect(device);
  }

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

    // Watch for disconnection
    _connSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _log('Device disconnected');
        _updateStatus(BleStatus.disconnected);
        _clearCharacteristics();
      }
    });

    return await _discoverServices(device);
  }

  Future<bool> _discoverServices(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      for (final svc in services) {
        if (svc.uuid.str128.toLowerCase() == _serviceUuid) {
          _log('GPP service found');
          for (final c in svc.characteristics) {
            final uuid = c.uuid.str128.toLowerCase();
            if (uuid == _charSpeed)   _cSpeed   = c;
            if (uuid == _charGoal)    _cGoal    = c;
            if (uuid == _charTime)    _cTime    = c;
            if (uuid == _charFriends) _cFriends = c;
            if (uuid == _charSos)     _cSos     = c;
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

    // Subscribe to SOS notifications
    if (_cSos != null) {
      try {
        await _cSos!.setNotifyValue(true);
        _sosSub = _cSos!.onValueReceived.listen((value) {
          if (value.isNotEmpty) {
            final triggered = value[0] == 0x01;
            _log(triggered ? '🚨 SOS ALERT!' : 'SOS cleared');
            _sosCtrl.add(triggered);
          }
        });
        _log('SOS notify enabled');
      } catch (e) {
        _log('SOS notify error: $e');
      }
    }

    _updateStatus(BleStatus.connected);
    _log('Connected to $deviceName');

    // Initial sync: send current time
    await syncTime();

    return true;
  }

  void disconnect() {
    _sosSub?.cancel();
    _connSub?.cancel();
    _scanSub?.cancel();
    _device?.disconnect();
    _clearCharacteristics();
    _updateStatus(BleStatus.disconnected);
    _log('Disconnected');
  }

  // ── Write helpers ──────────────────────────────────────────────────────────

  /// Write speed (km/h) and accumulated distance (metres) to device.
  /// Format: "15.2,1250.5"
  Future<void> writeSpeedDistance(double speedKmh, double distanceM) async {
    if (_cSpeed == null || !isConnected) return;
    final payload = '${speedKmh.toStringAsFixed(1)},${distanceM.toStringAsFixed(1)}';
    try {
      await _cSpeed!.write(payload.codeUnits, withoutResponse: false);
    } catch (e) {
      _log('writeSpeedDistance error: $e');
    }
  }

  /// Write cycling goal to device. Value is in metres (Float32 LE).
  Future<void> writeGoalMetres(double metres) async {
    if (_cGoal == null || !isConnected) return;
    try {
      final bd = ByteData(4)..setFloat32(0, metres, Endian.little);
      await _cGoal!.write(bd.buffer.asUint8List());
      _log('Goal sent: ${metres.toStringAsFixed(0)} m');
    } catch (e) {
      _log('writeGoal error: $e');
    }
  }

  /// Write current time "HH:MM" to device for display sync.
  Future<void> syncTime() async {
    if (_cTime == null || !isConnected) return;
    try {
      final now = DateTime.now();
      final t = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await _cTime!.write(t.codeUnits);
      _log('Time synced: $t');
    } catch (e) {
      _log('syncTime error: $e');
    }
  }

  /// Write online friends count to device (Int32 LE).
  Future<void> writeOnlineFriends(int count) async {
    if (_cFriends == null || !isConnected) return;
    try {
      final bd = ByteData(4)..setInt32(0, count, Endian.little);
      await _cFriends!.write(bd.buffer.asUint8List());
      _log('Friends online: $count');
    } catch (e) {
      _log('writeFriends error: $e');
    }
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  void _updateStatus(BleStatus s) {
    _status = s;
    _statusCtrl.add(s);
  }

  void _clearCharacteristics() {
    _cSpeed = null; _cGoal = null; _cTime = null;
    _cFriends = null; _cSos = null;
  }

  void _log(String msg) {
    debugPrint('[BLE] $msg');
    _logCtrl.add(msg);
  }

  void dispose() {
    disconnect();
    _statusCtrl.close();
    _sosCtrl.close();
    _logCtrl.close();
  }
}
