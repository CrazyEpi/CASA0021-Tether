import 'dart:async';
import 'dart:convert'; // 用于 utf8 编码
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'firestore_service.dart'; // [ADD] Cloud Sync Service

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

  // [修复] 防止高频 GPS 更新导致 BLE 写入通道堵塞的锁
  bool _isWritingSpeed = false; 

  // [ADD] Firestore Instance
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
    final allGranted = statuses.values.every(
        (s) => s == PermissionStatus.granted || s == PermissionStatus.limited);
    if (!allGranted) _log('Bluetooth/location permissions denied');
    return allGranted;
  }

Future<bool> connectToDevice() async {
  if (_status == BleStatus.connected) return true;

  if (await FlutterBluePlus.isSupported == false) {
    _log('⚠️ 致命错误：这台手机不支持蓝牙！');
    _updateStatus(BleStatus.error);
    return false;
  }

  if (Platform.isAndroid) {
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      await FlutterBluePlus.turnOn();
    }
  }

  final granted = await requestPermissions();
  if (!granted) {
    _log('⚠️ 权限被拒绝');
    _updateStatus(BleStatus.error);
    return false;
  }

  _updateStatus(BleStatus.scanning);
  _log('🔍 正在扫描: $deviceName (UUID: $_serviceUuid)');

  await FlutterBluePlus.stopScan();

  final completer = Completer<BluetoothDevice?>();
  
  // 1. 设置一个手动定时器，防止逻辑跑飞
  Timer? timeoutTimer;

  // 2. 监听扫描结果
  _scanSub = FlutterBluePlus.onScanResults.listen((results) {
    for (final r in results) {
      // 调试：打印所有搜到的设备名称，看看它到底叫什么
      _log('Found: ${r.device.platformName} | ${r.advertisementData.localName}');

      bool matchName = r.device.advName == deviceName || 
                       r.device.platformName == deviceName ||
                       r.advertisementData.localName == deviceName;
      
      // 检查 UUID（最稳的方法）
      bool matchUuid = r.advertisementData.serviceUuids
          .map((e) => e.toString().toLowerCase())
          .contains(_serviceUuid.toLowerCase());

      if (matchName || matchUuid) {
        _log('✅ 成功匹配设备！正在连接...');
        timeoutTimer?.cancel();
        FlutterBluePlus.stopScan();
        if (!completer.isCompleted) completer.complete(r.device);
        return;
      }
    }
  });

  // 3. 启动扫描
  try {
    // 这里使用 withServices 可以极大提高安卓下的成功率
    await FlutterBluePlus.startScan(
      withServices: [Guid(_serviceUuid)], 
      timeout: const Duration(seconds: 10),
    );
  } catch (e) {
    _log('❌ 扫描启动失败: $e');
  }

  // 4. 设置 10 秒后自动结束（如果没有搜到）
  timeoutTimer = Timer(const Duration(seconds: 10), () {
    if (!completer.isCompleted) {
      _log('⏱️ 扫描真正超时：未发现目标设备');
      FlutterBluePlus.stopScan();
      completer.complete(null);
    }
  });

  final device = await completer.future;
  _scanSub?.cancel(); // 只有在 Completer 完成后才取消订阅

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

    // [修复 1] Android 蓝牙底层需要喘息时间，必须加延时！
    await Future.delayed(const Duration(milliseconds: 600));

    // [修复 2] 强制协商 MTU 大小，这是 nRF Connect 能通信的秘密
    if (Platform.isAndroid) {
      try {
        await device.requestMtu(251);
        _log('MTU requested successfully');
      } catch (e) {
        _log('MTU request failed (ignoring): $e');
      }
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
        // [修复] 使用 toString() 防止某些版本中 str128 报错
        if (svc.uuid.toString().toLowerCase() == _serviceUuid) {
          _log('GPP service found');
          for (final c in svc.characteristics) {
            final uuid = c.uuid.toString().toLowerCase();
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

    if (_cSos != null) {
      try {
        await _cSos!.setNotifyValue(true);
        _sosSub = _cSos!.onValueReceived.listen((value) {
          if (value.isNotEmpty) {
            final triggered = value[0] == 0x01;
            _log(triggered ? '🚨 SOS ALERT!' : 'SOS cleared');
            _sosCtrl.add(triggered);

            // [ADD] Sync SOS Alert to Cloud
            _firestore.logSosAlert(triggered);
          }
        });
        _log('SOS notify enabled');
      } catch (e) {
        _log('SOS notify error: $e');
      }
    }

    _updateStatus(BleStatus.connected);
    _log('Connected to $deviceName');

    // [修复] 延时同步时间，确保 Notify 通道彻底建立
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

  Future<void> writeSpeedDistance(double speedKmh, double distanceM) async {
    if (_cSpeed == null || !isConnected) return;
    
    // [修复 3] 防止 GPS 高频刷新把通道堵死
    if (_isWritingSpeed) return; 
    _isWritingSpeed = true;

    // [ADD] Sync Speed/Distance to Cloud
    _firestore.updateRideMetrics(speedKmh, distanceM);

    final payload = '${speedKmh.toStringAsFixed(1)},${distanceM.toStringAsFixed(1)}';
    try {
      // [修复 4] 使用 utf8.encode 保证绝对安全的纯净 Byte 数组
      await _cSpeed!.write(utf8.encode(payload), withoutResponse: false);
    } catch (e) {
      _log('writeSpeedDistance error: $e');
    } finally {
      _isWritingSpeed = false;
    }
  }

  Future<void> writeGoalMetres(double metres) async {
    if (_cGoal == null || !isConnected) return;
    try {
      final bd = ByteData(4)..setFloat32(0, metres, Endian.little);
      // [修复] .toList() 强制转换，防止 MethodChannel 类型报错
      await _cGoal!.write(bd.buffer.asUint8List().toList(), withoutResponse: false);
      _log('Goal sent: ${metres.toStringAsFixed(0)} m');
    } catch (e) {
      _log('writeGoal error: $e');
    }
  }

  Future<void> syncTime() async {
    if (_cTime == null || !isConnected) return;
    try {
      final now = DateTime.now();
      final t = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await _cTime!.write(utf8.encode(t), withoutResponse: false);
      _log('Time synced: $t');
    } catch (e) {
      _log('syncTime error: $e');
    }
  }

  Future<void> writeOnlineFriends(int count) async {
    if (_cFriends == null || !isConnected) return;
    try {
      final bd = ByteData(4)..setInt32(0, count, Endian.little);
      await _cFriends!.write(bd.buffer.asUint8List().toList(), withoutResponse: false);
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