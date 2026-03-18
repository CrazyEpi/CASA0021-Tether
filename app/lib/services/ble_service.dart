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
  // ── UUIDs ──────────────────────────────────────────────────────────────────
  static const String _serviceUuid  = '19b10000-e8f2-537e-4f6c-d104768a1214';
  static const String _charSpeed    = '19b10001-e8f2-537e-4f6c-d104768a1214';
  static const String _charGoal     = '19b10002-e8f2-537e-4f6c-d104768a1214';
  static const String _charTime     = '19b10003-e8f2-537e-4f6c-d104768a1214';
  static const String _charFriends  = '19b10004-e8f2-537e-4f6c-d104768a1214';
  static const String _charSos      = '19b10005-e8f2-537e-4f6c-d104768a1214';
  static const String _charSocial   = '19b10006-e8f2-537e-4f6c-d104768a1214'; 

  static const String deviceName    = 'BikeTracker_E';

  // ── MANUAL HARDWARE MAPPING ────────────────────────────────────────────────
  // Map your Firebase UIDs to the physical MAC address of the ESP32s
  static const Map<String, String> _userToHardware = {
    'QwTQqMw4D2NaZJqWTgQmHwaSnPe2': '1C:DB:D4:7B:62:B5', // Your ESP32 MAC
    '3GfsCbAHgTRZOkC7eTwy30Ao0Eq2': '30:ED:AO:29:9B:21', // Casa's ESP32 MAC
  };



  String? _targetMac;

  // Call this from initState in your screen: _ble.setTargetUser(widget.currentUser.id);
  void setTargetUser(String userId) {
    _targetMac = _userToHardware[userId];
    _log('Targeting Hardware MAC: $_targetMac for User: $userId');
  }

  // ── State ──────────────────────────────────────────────────────────────────
  BluetoothDevice? _device;
  BleStatus _status = BleStatus.disconnected;

  BluetoothCharacteristic? _cSpeed;
  BluetoothCharacteristic? _cGoal;
  BluetoothCharacteristic? _cTime;
  BluetoothCharacteristic? _cFriends;
  BluetoothCharacteristic? _cSos;
  BluetoothCharacteristic? _cSocial;

  StreamSubscription? _scanSub;
  StreamSubscription? _connSub;
  StreamSubscription? _sosSub;

  bool _isWritingSpeed = false; 
  DateTime? _lastSpeedWrite; // [NEW] Stability throttle

  final FirestoreService _firestore = FirestoreService();

  final _statusCtrl = StreamController<BleStatus>.broadcast();
  final _sosCtrl    = StreamController<bool>.broadcast();
  final _logCtrl    = StreamController<String>.broadcast();

  Stream<BleStatus> get statusStream => _statusCtrl.stream;
  Stream<bool>      get sosStream     => _sosCtrl.stream;
  Stream<String>    get logStream     => _logCtrl.stream;

  BleStatus get status => _status;
  bool get isConnected => _status == BleStatus.connected;

  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }

  Future<bool> connectToDevice() async {
    if (_status == BleStatus.connected) return true;

    if (await FlutterBluePlus.isSupported == false) {
      _log('⚠️ Hardware does not support Bluetooth');
      _updateStatus(BleStatus.error);
      return false;
    }

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

    if (Platform.isAndroid) {
      try { await device.requestMtu(251); } catch (_) {}
    }

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

  Future<void> writeNeoPixelSocialSignal() async {
  if (!isConnected) {
    _log('⚠️ Social signal failed: Not connected');
    return;
  }
  if (_cSocial == null) {
    _log('⚠️ Social signal failed: Characteristic _cSocial not found');
    return;
  }

  try {
    // Send 0x01 to trigger the "Pulse" animation on the Arduino
    await _cSocial!.write([0x01], withoutResponse: false);
    _log('🚀 Social pulse command sent to bike hardware!');
  } catch (e) {
    _log('❌ Social signal error: $e');
  }
}

  Future<void> writeSpeedDistance(double speedKmh, double distanceM) async {
    if (_cSpeed == null || !isConnected) return;
    if (_isWritingSpeed) return; 

    // Throttle: Don't spam the Arduino (max 2 updates per second)
    final now = DateTime.now();
    if (_lastSpeedWrite != null && now.difference(_lastSpeedWrite!) < const Duration(milliseconds: 500)) {
      return; 
    }

    _isWritingSpeed = true;
    _lastSpeedWrite = now;

    // Updates Firebase
    _firestore.updateRideMetrics(speedKmh, distanceM);

    final payload = '${speedKmh.toStringAsFixed(1)},${distanceM.toStringAsFixed(1)}';
    try {
      // REVISED: Changed to false to fix the "Property not supported" error
      await _cSpeed!.write(utf8.encode(payload), withoutResponse: false);
    } catch (e) {
      _log('[BLE] writeSpeedDistance error: $e');
    } finally {
      _isWritingSpeed = false;
    }
  }

  // NEW: This function triggers the NeoPixel pulse on the bike
  

  Future<void> writeGoalMetres(double metres) async {
    if (_cGoal == null || !isConnected) return;
    try {
      final bd = ByteData(4)..setFloat32(0, metres, Endian.little);
      await _cGoal!.write(bd.buffer.asUint8List(), withoutResponse: false);
      _log('Goal sent: ${metres.toStringAsFixed(0)} m');
    } catch (e) { _log('writeGoal error: $e'); }
  }

  Future<void> syncTime() async {
    if (_cTime == null || !isConnected) return;
    try {
      final now = DateTime.now();
      final t = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await _cTime!.write(utf8.encode(t), withoutResponse: false);
      _log('Time synced: $t');
    } catch (e) { _log('syncTime error: $e'); }
  }

  Future<void> writeOnlineFriends(int count) async {
    if (_cFriends == null || !isConnected) return;
    try {
      final bd = ByteData(4)..setInt32(0, count, Endian.little);
      await _cFriends!.write(bd.buffer.asUint8List(), withoutResponse: false);
      _log('Friends online: $count');
    } catch (e) { _log('writeFriends error: $e'); }
  }
  // ── Internals ──────────────────────────────────────────────────────────────
  void _updateStatus(BleStatus s) {
    _status = s;
    _statusCtrl.add(s);
  }

  void _clearCharacteristics() {
    _cSpeed = null; _cGoal = null; _cTime = null;
    _cFriends = null; _cSos = null; _cSocial = null;
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