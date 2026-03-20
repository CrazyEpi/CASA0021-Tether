import 'package:flutter/material.dart';
import 'dart:math'; // [新增] 引入数学库用于生成随机数
import '../services/ble_service.dart';

class DeveloperConsole extends StatefulWidget {
  const DeveloperConsole({super.key});

  @override
  State<DeveloperConsole> createState() => _DeveloperConsoleState();
}

class _DeveloperConsoleState extends State<DeveloperConsole> {
  final BleService _ble = BleService();
  final Random _random = Random(); // [新增] 随机数生成器

  // --- Mock Data States ---
  double simSpeed = 15.0;
  double simMyDist = 0.0;
  double simMyGoal = 10.0;

  int simFriendsCount = 0;
  double simFriendDist = 0.0;
  double simFriendGoal = 10.0;

  // Sync data to ESP32 Hardware
  void _syncToHardware() {
    if (_ble.isConnected) {
      _ble.writeSpeedDistance(
        simSpeed,
        simMyDist,
        goalKm: simMyGoal,
        friendDistKm: simFriendDist,
        friendGoalKm: simFriendGoal,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BLE not connected!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(' Hardware Dev Console', 
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.green),
      ),
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<BleStatus>(
        stream: _ble.statusStream,
        initialData: _ble.status,
        builder: (context, snapshot) {
          final isConnected = snapshot.data == BleStatus.connected;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- BLE Connection Status ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                          color: isConnected ? Colors.green.shade800 : Colors.red.shade800),
                      const SizedBox(width: 12),
                      Text(
                        isConnected ? 'Hardware Connected' : 'Hardware Disconnected',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isConnected ? Colors.green.shade800 : Colors.red.shade800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // --- 1. My Ride Simulation ---
                _buildSectionHeader(' My Ride Simulation'),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Speed Slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Speed (km/h)', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(simSpeed.toStringAsFixed(1), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Slider(
                          value: simSpeed,
                          min: 0.0,
                          max: 40.0,
                          activeColor: Colors.blue,
                          onChanged: (val) {
                            setState(() => simSpeed = val);
                            _syncToHardware();
                          },
                        ),
                        const Divider(),
                        // My Distance Control
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('My Distance', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${simMyDist.toStringAsFixed(1)} / ${simMyGoal.toStringAsFixed(1)} km'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() => simMyDist = 0.0);
                                  _syncToHardware();
                                },
                                child: const Text('Reset'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  // [修改] 增加 1.x km，其中 x 是 0-9 的随机数
                                  double randomDecimal = _random.nextInt(10) / 10.0;
                                  setState(() => simMyDist += (1.0 + randomDecimal));
                                  _syncToHardware();
                                },
                                child: const Text('+ 1.x km'),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // --- 2. Friend / Multiplayer Simulation ---
                _buildSectionHeader(' Multiplayer / Friend Simulation'),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Toggle Friend Online
                        SwitchListTile(
                          title: const Text('Friend Online Status', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(simFriendsCount > 0 ? 'Dual-Ring Mode Active' : 'Single-Ring Mode Active'),
                          activeColor: Colors.purple,
                          value: simFriendsCount > 0,
                          onChanged: (val) {
                            setState(() => simFriendsCount = val ? 1 : 0);
                            _ble.writeOnlineFriends(simFriendsCount);
                            _syncToHardware(); 

                              if (val && _ble.isConnected) {
                                _ble.writeNeoPixelSocialSignal();
                              }
                          },
                        ),
                        const Divider(),
                        // Friend Distance Control
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Friend Distance', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('${simFriendDist.toStringAsFixed(1)} / ${simFriendGoal.toStringAsFixed(1)} km',
                                style: const TextStyle(color: Colors.purple)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade50, foregroundColor: Colors.purple),
                                onPressed: () {
                                  setState(() => simFriendDist = 0.0);
                                  _syncToHardware();
                                },
                                child: const Text('Reset'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                                onPressed: () {
                                  // [修改] 增加 1.x km，其中 x 是 0-9 的随机数
                                  double randomDecimal = _random.nextInt(10) / 10.0;
                                  setState(() => simFriendDist += (1.0 + randomDecimal));
                                  _syncToHardware();
                                  // [已修复] 移除了之前这里的 _ble.writeNeoPixelSocialSignal(); 
                                  // 现在增加距离只会静默更新屏幕和灯环比例，不会触发呼吸灯效
                                },
                                child: const Text('+ 1.x km'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Trigger Social Pulse Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.favorite, color: Colors.cyan),
                            label: const Text('Send Social Pulse (Cyan Effect)'),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.cyan.shade800),
                            onPressed: () {
                              // 这个按钮专门留给你用来测试特效
                              if (_ble.isConnected) _ble.writeNeoPixelSocialSignal();
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
      ),
    );
  }
}