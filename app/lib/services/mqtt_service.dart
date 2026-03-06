import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/activity.dart';

// ============================================================
// MQTT Service - handles connection to MQTT broker
// Hardware sends: "lat,lng,speed,totalDistance"
// Topic: student/CASA0021/Group3/device/gps
// ============================================================

enum MqttConnectionStatus { disconnected, connecting, connected, error }

class MqttService {
  static const String _brokerUrl = 'mqtt.cetools.org';
  static const int _brokerPort = 1883;
  static const String _baseTopic = 'student/CASA0021/Group3';

  // Update this with your group/device number
  static const String _deviceTopic = '$_baseTopic/device/gps';
  static const String _speedTopic = '$_baseTopic/device/speed';
  static const String _distanceTopic = '$_baseTopic/device/distance';

  late MqttServerClient _client;
  MqttConnectionStatus _status = MqttConnectionStatus.disconnected;

  // Stream controllers
  final _gpsController = StreamController<GpsPoint>.broadcast();
  final _statusController = StreamController<MqttConnectionStatus>.broadcast();
  final _rawMessageController = StreamController<String>.broadcast();

  Stream<GpsPoint> get gpsStream => _gpsController.stream;
  Stream<MqttConnectionStatus> get statusStream => _statusController.stream;
  Stream<String> get rawMessageStream => _rawMessageController.stream;

  MqttConnectionStatus get status => _status;

  // Singleton
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  Future<bool> connect(String clientId) async {
    _updateStatus(MqttConnectionStatus.connecting);

    _client = MqttServerClient(_brokerUrl, 'GPP_Fitness_${clientId}_${DateTime.now().millisecondsSinceEpoch}');
    _client.port = _brokerPort;
    _client.keepAlivePeriod = 30;
    _client.setProtocolV311();
    _client.logging(on: false);

    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;
    _client.onSubscribed = _onSubscribed;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(_client.clientIdentifier)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    _client.connectionMessage = connMessage;

    try {
      await _client.connect();
    } catch (e) {
      print('[MQTT] Connection error: $e');
      _updateStatus(MqttConnectionStatus.error);
      _client.disconnect();
      return false;
    }

    if (_client.connectionStatus!.state == MqttConnectionState.connected) {
      _subscribeToTopics();
      _setupMessageListener();
      return true;
    } else {
      _updateStatus(MqttConnectionStatus.error);
      return false;
    }
  }

  void _subscribeToTopics() {
    // Subscribe to the main GPS payload topic
    _client.subscribe(_deviceTopic, MqttQos.atMostOnce);
    print('[MQTT] Subscribed to $_deviceTopic');
  }

  void _setupMessageListener() {
    _client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? messages) {
      if (messages == null || messages.isEmpty) return;

      for (final msg in messages) {
        final recMsg = msg.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(
          recMsg.payload.message,
        );
        final topic = msg.topic;

        print('[MQTT] Received on $topic: $payload');
        _rawMessageController.add('[$topic]: $payload');

        // Parse GPS payload: "lat,lng,speed,totalDistance"
        if (topic == _deviceTopic) {
          try {
            final gpsPoint = GpsPoint.fromPayload(payload);
            _gpsController.add(gpsPoint);
          } catch (e) {
            print('[MQTT] GPS parse error: $e (payload: $payload)');
          }
        }
      }
    });
  }

  // Publish a message (e.g., to set a goal from app to device)
  void publish(String topic, String message) {
    if (_status != MqttConnectionStatus.connected) return;
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    _client.publishMessage(
      '$_baseTopic/$topic',
      MqttQos.atMostOnce,
      builder.payload!,
    );
  }

  void disconnect() {
    _client.disconnect();
    _updateStatus(MqttConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _gpsController.close();
    _statusController.close();
    _rawMessageController.close();
  }

  void _onConnected() {
    print('[MQTT] Connected to broker');
    _updateStatus(MqttConnectionStatus.connected);
  }

  void _onDisconnected() {
    print('[MQTT] Disconnected from broker');
    _updateStatus(MqttConnectionStatus.disconnected);
  }

  void _onSubscribed(String topic) {
    print('[MQTT] Subscribed: $topic');
  }

  void _updateStatus(MqttConnectionStatus status) {
    _status = status;
    _statusController.add(status);
  }

  // ============================================================
  // MQTT TOPIC CONFIGURATION
  // Change these when your hardware setup is confirmed
  // ============================================================
  static String get mqttBroker => _brokerUrl;
  static String get gpsTopic => _deviceTopic;
  static String get payloadFormat => 'lat,lng,speed_kmh,totalDistance_km';
  static String get examplePayload => '51.531100,-0.159200,10.5,2.3';
}
