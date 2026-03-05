import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/activity.dart';
import '../models/user.dart';
import '../services/mqtt_service.dart';

// Live GPS Tracking Screen
// Connects to MQTT broker and displays real-time GPS data from hardware
// Hardware payload format: "lat,lng,speed_kmh,totalDistance_km"
class LiveTrackingScreen extends StatefulWidget {
  final AppUser currentUser;
  const LiveTrackingScreen({super.key, required this.currentUser});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with TickerProviderStateMixin {
  final MqttService _mqtt = MqttService();

  // Tracking state
  bool _isTracking = false;
  bool _isPaused = false;
  bool _isConnecting = false;
  MqttConnectionStatus _mqttStatus = MqttConnectionStatus.disconnected;

  // Live data
  double _currentLat = 0;
  double _currentLng = 0;
  double _currentSpeed = 0;
  double _totalDistance = 0;
  int _elapsedSeconds = 0;
  List<GpsPoint> _trackPoints = [];
  List<String> _rawMessages = [];

  // Timer
  Timer? _timer;
  DateTime? _startTime;
  DateTime? _pauseStart;
  int _pausedSeconds = 0;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // MQTT topic config
  final String _mqttTopic = MqttService.gpsTopic;

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

    // Listen to MQTT status changes
    _mqtt.statusStream.listen((status) {
      if (mounted) setState(() => _mqttStatus = status);
    });

    // Listen to GPS points
    _mqtt.gpsStream.listen((point) {
      if (!_isTracking || _isPaused) return;
      setState(() {
        _currentLat = point.lat;
        _currentLng = point.lng;
        _currentSpeed = point.speed;
        _totalDistance = point.totalDistance;
        _trackPoints.add(point);
      });
    });

    // Listen to raw messages (for debug)
    _mqtt.rawMessageStream.listen((msg) {
      if (mounted) {
        setState(() {
          _rawMessages.insert(0, '[${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2,'0')}] $msg');
          if (_rawMessages.length > 20) _rawMessages.removeLast();
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _connectMqtt() async {
    setState(() => _isConnecting = true);
    final success = await _mqtt.connect(widget.currentUser.id);
    setState(() => _isConnecting = false);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not connect to MQTT broker. Check network.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startTracking() {
    if (_mqttStatus != MqttConnectionStatus.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect to MQTT first!')),
      );
      return;
    }
    setState(() {
      _isTracking = true;
      _isPaused = false;
      _elapsedSeconds = 0;
      _trackPoints = [];
      _totalDistance = 0;
      _currentSpeed = 0;
      _startTime = DateTime.now();
      _pausedSeconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  void _pauseTracking() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _pauseStart = DateTime.now();
      } else {
        if (_pauseStart != null) {
          _pausedSeconds += DateTime.now().difference(_pauseStart!).inSeconds;
        }
      }
    });
  }

  void _stopTracking() {
    _timer?.cancel();
    if (_trackPoints.isEmpty) {
      setState(() { _isTracking = false; _isPaused = false; });
      return;
    }
    // Show save dialog
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

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Live Tracking'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        actions: [
          // MQTT connection status
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _MqttStatusBadge(status: _mqttStatus),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---- MQTT Connection Card ----
            _buildMqttCard(isDark),
            const SizedBox(height: 16),

            // ---- Live Stats Card ----
            if (_isTracking || _trackPoints.isNotEmpty)
              _buildLiveStatsCard(isDark),

            // ---- Route Display ----
            if (_isTracking && _trackPoints.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildRouteCard(isDark),
            ],

            const SizedBox(height: 16),
            // ---- Control Buttons ----
            _buildControls(isDark),

            // ---- Raw MQTT Messages ----
            if (_rawMessages.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildRawMessagesCard(isDark),
            ],

            const SizedBox(height: 16),
            // ---- Hardware Info ----
            _buildHardwareInfoCard(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMqttCard(bool isDark) {
    final isConnected = _mqttStatus == MqttConnectionStatus.connected;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected
              ? Colors.green.withOpacity(0.4)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wifi,
                  color: isConnected ? Colors.green : Colors.grey,
                  size: 18),
              const SizedBox(width: 8),
              Text('MQTT Connection',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow('Broker', MqttService.mqttBroker, isDark),
          _infoRow('Topic', MqttService.gpsTopic, isDark),
          _infoRow('Format', MqttService.payloadFormat, isDark),
          _infoRow('Example', MqttService.examplePayload, isDark),
          const SizedBox(height: 12),
          if (!isConnected)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isConnecting ? null : _connectMqtt,
                icon: _isConnecting
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.link, size: 18),
                label: Text(_isConnecting ? 'Connecting...' : 'Connect to Hardware'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Connected - ready to receive GPS data',
                    style: TextStyle(color: Colors.green, fontSize: 13)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLiveStatsCard(bool isDark) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) => Transform.scale(
        scale: _isTracking && !_isPaused ? _pulseAnimation.value * 0.02 + 0.98 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isPaused
                  ? [Colors.grey[800]!, Colors.grey[700]!]
                  : [const Color(0xFFFC5200), const Color(0xFFFF6B35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (_isPaused ? Colors.grey : AppTheme.primaryOrange).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Timer
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
              // Stats grid
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
                        ? '${_currentLat.toStringAsFixed(5)}, ${_currentLng.toStringAsFixed(5)}'
                        : 'Waiting for GPS signal...',
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
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A2A3A), const Color(0xFF0D1B2A)]
                      : [const Color(0xFFE8F4FD), const Color(0xFFD0E8F5)],
                ),
              ),
            ),
            // Route painter
            CustomPaint(
              size: Size.infinite,
              painter: _LiveRoutePainter(_trackPoints),
            ),
            // Info overlay
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
                    Icon(Icons.route, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('Live Route', style: TextStyle(color: Colors.white, fontSize: 11)),
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
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _mqttStatus == MqttConnectionStatus.connected
              ? _startTracking
              : null,
          icon: const Icon(Icons.play_arrow, size: 24),
          label: const Text('Start Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _pauseTracking,
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, size: 20),
            label: Text(_isPaused ? 'Resume' : 'Pause'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isPaused ? Colors.blue : Colors.orange[700],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _stopTracking,
            icon: const Icon(Icons.stop, size: 20),
            label: const Text('Finish'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRawMessagesCard(bool isDark) {
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
              Icon(Icons.terminal, color: Colors.green, size: 14),
              SizedBox(width: 6),
              Text('MQTT Raw Messages',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  )),
            ],
          ),
          const SizedBox(height: 8),
          ...(_rawMessages.take(5).map((msg) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(msg,
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontFamily: 'monospace')),
          ))),
        ],
      ),
    );
  }

  Widget _buildHardwareInfoCard(bool isDark) {
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
          Row(
            children: [
              const Icon(Icons.memory, size: 16, color: AppTheme.primaryOrange),
              const SizedBox(width: 8),
              Text('Hardware Setup',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Your ESP32/Arduino should publish GPS data to:\n'
            '  Topic: ${MqttService.gpsTopic}\n'
            '  Format: ${MqttService.payloadFormat}\n'
            '  Example: ${MqttService.examplePayload}\n\n'
            'Arduino code example:\n'
            '  String payload = String(gps.location.lat(), 6) + "," +\n'
            '                   String(gps.location.lng(), 6) + "," +\n'
            '                   String(speed, 1) + "," +\n'
            '                   String(totalDistance, 1);\n'
            '  client.publish(topic, payload);',
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
                  color: isDark ? Colors.white38 : Colors.grey[500],
                )),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontFamily: 'monospace',
                )),
          ),
        ],
      ),
    );
  }
}

// MQTT Status Badge Widget
class _MqttStatusBadge extends StatelessWidget {
  final MqttConnectionStatus status;
  const _MqttStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case MqttConnectionStatus.connected:
        color = Colors.green; label = 'Connected'; break;
      case MqttConnectionStatus.connecting:
        color = Colors.orange; label = 'Connecting'; break;
      case MqttConnectionStatus.error:
        color = Colors.red; label = 'Error'; break;
      default:
        color = Colors.grey; label = 'Offline';
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
          Container(width: 6, height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// Save Activity Dialog
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
  final _titleController = TextEditingController(text: 'Morning Activity');
  String _selectedType = 'run';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save Activity'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Distance: ${widget.distance.toStringAsFixed(2)} km'),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Activity Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Activity Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'run', child: Text('Run')),
              DropdownMenuItem(value: 'cycle', child: Text('Cycling')),
              DropdownMenuItem(value: 'walk', child: Text('Walk')),
              DropdownMenuItem(value: 'hike', child: Text('Hike')),
            ],
            onChanged: (v) => setState(() => _selectedType = v!),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: widget.onDiscard, child: const Text('Discard')),
        ElevatedButton(
          onPressed: () => widget.onSave(_titleController.text, _selectedType),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Live route painter
class _LiveRoutePainter extends CustomPainter {
  final List<GpsPoint> points;
  _LiveRoutePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = AppTheme.primaryOrange
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    double minLat = points.map((p) => p.lat).reduce((a, b) => a < b ? a : b);
    double maxLat = points.map((p) => p.lat).reduce((a, b) => a > b ? a : b);
    double minLng = points.map((p) => p.lng).reduce((a, b) => a < b ? a : b);
    double maxLng = points.map((p) => p.lng).reduce((a, b) => a > b ? a : b);

    double latRange = (maxLat - minLat).abs();
    double lngRange = (maxLng - minLng).abs();
    if (latRange < 0.0001) latRange = 0.001;
    if (lngRange < 0.0001) lngRange = 0.001;

    final pad = 20.0;
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = pad + ((points[i].lng - minLng) / lngRange) * (size.width - pad * 2);
      final y = pad + (1 - (points[i].lat - minLat) / latRange) * (size.height - pad * 2);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);

    // Current position dot
    if (points.isNotEmpty) {
      final last = points.last;
      final x = pad + ((last.lng - minLng) / lngRange) * (size.width - pad * 2);
      final y = pad + (1 - (last.lat - minLat) / latRange) * (size.height - pad * 2);
      canvas.drawCircle(Offset(x, y), 6,
          Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(x, y), 6,
          Paint()..color = AppTheme.primaryOrange..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
