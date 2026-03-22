import 'dart:async';
import 'dart:convert'; 
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firestore_service.dart';

enum BleStatus { disconnected, scanning, connecting, connected, error }

class BleService {
  static const String _serviceUuid  = '19b10000-e8f2-537e-4f6c-d104768a1214';
  static const String _charSpeed    = '19b10001-e8f2-537e-4f6c-d104768a1214';
  static const String _charGoal     = '19b10002-e8f2-537e-4f6c-d104768a1214';
  static const String _charTime     = '19b10003-e8f2-537e-4f6c-d104768a1214';
  static const String _charFriends  = '19b10004-e8f2-537e-4f6c-d104768a1214';
  static const String _charSos      = '19b10005-e8f2-537e-4f6c-d104768a1214';
  static const String _charSocial   = '19b10006-e8f2-537e-4f6c-d104768a1214'; 

  static const String deviceName    = 'BikeTracker_E';

  // developer override mode for testing without another device, will stop firebase data download
  bool devModeOverride = false;

  BluetoothDevice? _device;
  BleStatus _status = BleStatus.disconnected;

  // BLE Characteristics
  BluetoothCharacteristic? _cSpeed;
  BluetoothCharacteristic? _cGoal;
  BluetoothCharacteristic? _cTime;
  BluetoothCharacteristic? _cFriends;
  BluetoothCharacteristic? _cSos;
  BluetoothCharacteristic? _cSocial;

  // Data Subscriptions
  StreamSubscription? _scanSub;
  StreamSubscription? _connSub;
  StreamSubscription? _sosSub;

  bool _isWritingSpeed = false; 
  DateTime? _lastSpeedWrite; 

  // timer for time sync
  Timer? _timeSyncTimer;
  String _lastSyncedTime = '';

  final FirestoreService _firestore = FirestoreService();

  // Streams for UI updates
  final _statusCtrl = StreamController<BleStatus>.broadcast();
  final _sosCtrl    = StreamController<bool>.broadcast();
  final _logCtrl    = StreamController<String>.broadcast();

  Stream<BleStatus> get statusStream => _statusCtrl.stream;
  Stream<bool>      get sosStream    => _sosCtrl.stream;
  Stream<String>    get logStream    => _logCtrl.stream;

  BleStatus get status => _status;
  bool get isConnected => _status == BleStatus.connected;

  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    return statuses.values.every((s) => s.isGranted || s.isLimited);
  }

  // Scan and connect to the target device
  Future<bool> connectToDevice() async {
    if (_status == BleStatus.connected) return true;

    if (await FlutterBluePlus.isSupported == false) return false;

    if (Platform.isAndroid && FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
    }

    final granted = await requestPermissions();
    if (!granted) return false;

    _updateStatus(BleStatus.scanning);
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
    } catch (e) { _log(' Scan failed: $e'); }

    timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
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

  // Establish connection
  Future<bool> _connect(BluetoothDevice device) async {
    _updateStatus(BleStatus.connecting);
    _device = device;

    try {
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 15));
    } catch (e) {
      _updateStatus(BleStatus.error);
      return false;
    }

    // Delay required for Android BLE stack stability
    await Future.delayed(const Duration(milliseconds: 600));

    // Request higher MTU for larger payload handling
    if (Platform.isAndroid) {
      try { await device.requestMtu(251); } catch (_) {}
    }

    _connSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _updateStatus(BleStatus.disconnected);
        _clearCharacteristics();
      }
    });

    return await _discoverServices(device);
  }

  // Discover and assign characteristics
  Future<bool> _discoverServices(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      for (final svc in services) {
        if (svc.uuid.toString().toLowerCase() == _serviceUuid) {
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
      _updateStatus(BleStatus.error);
      return false;
    }

    // Subscribe to hardware SOS alerts
    if (_cSos != null) {
      try {
        await _cSos!.setNotifyValue(true);
        _sosSub = _cSos!.onValueReceived.listen((value) {
          if (value.isNotEmpty) {
            final triggered = value[0] == 0x01;
            _sosCtrl.add(triggered);
            _firestore.logSosAlert(triggered);
          }
        });
      } catch (e) {}
    }

    _updateStatus(BleStatus.connected);
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Initial time sync and background periodic check
    _timeSyncTimer?.cancel();
    _timeSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) => syncTime());

    return true;
  }

  // Disconnect and clean up resources
  void disconnect() {
    _sosSub?.cancel();
    _connSub?.cancel();
    _scanSub?.cancel();
    
    _timeSyncTimer?.cancel();
    _timeSyncTimer = null;
    _lastSyncedTime = '';

    _device?.disconnect();
    _clearCharacteristics();
    _updateStatus(BleStatus.disconnected);
  }

  // Trigger social LED pulse animation on hardware
  Future<void> writeNeoPixelSocialSignal() async {
    if (!isConnected || _cSocial == null) return;
    try { await _cSocial!.write([0x01], withoutResponse: false); } catch (e) {}
  }

  // Sync ride data payload: "Speed, MyDist, FriendDist, FriendGoal"
  Future<void> writeSpeedDistance(double speedKmh, double distanceKm, 
      {double goalKm = 10.0, double friendDistKm = 0.0, double friendGoalKm = 0.0}) async {
    if (_cSpeed == null || !isConnected) return;
    if (_isWritingSpeed) return; 

    final now = DateTime.now();
    if (_lastSpeedWrite != null && now.difference(_lastSpeedWrite!) < const Duration(milliseconds: 500)) return; 

    _isWritingSpeed = true;
    _lastSpeedWrite = now;
    _firestore.updateRideMetrics(speedKmh, distanceKm, goalKm);

    final payload = '${speedKmh.toStringAsFixed(1)},${distanceKm.toStringAsFixed(2)},${friendDistKm.toStringAsFixed(2)},${friendGoalKm.toStringAsFixed(2)}';
    try {
      await _cSpeed!.write(utf8.encode(payload), withoutResponse: false);
    } catch (e) {} finally {
      _isWritingSpeed = false;
    }
  }

  // Sync target goal distance
  Future<void> writeGoalKm(double km) async {
    if (_cGoal == null || !isConnected) return;
    try {
      final bd = ByteData(4)..setFloat32(0, km, Endian.little);
      await _cGoal!.write(bd.buffer.asUint8List(), withoutResponse: false);
    } catch (e) {}
  }

  // Sync time only when the minute changes
  Future<void> syncTime() async {
    if (_cTime == null || !isConnected) return;
    try {
      final now = DateTime.now();
      final currentMinuteStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      if (currentMinuteStr != _lastSyncedTime) {
        await _cTime!.write(utf8.encode(currentMinuteStr), withoutResponse: false);
        _lastSyncedTime = currentMinuteStr;
      }
    } catch (e) {}
  }

  // Sync online friends count
  Future<void> writeOnlineFriends(int count) async {
    if (_cFriends == null || !isConnected) return;
    try {
      final bd = ByteData(4)..setInt32(0, count, Endian.little);
      await _cFriends!.write(bd.buffer.asUint8List(), withoutResponse: false);
    } catch (e) {}
  }

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