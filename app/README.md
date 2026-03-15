# 🚴 GPP Cycling Tracker

**UCL CASA0021 — Group 3 · Flutter App (Software)**

一款灵感来源于 Strava 的骑行追踪 App。通过 MQTT 接收车载 ESP32 的实时 GPS 数据，记录骑行轨迹，管理目标，与好友竞速排名。

---

## 功能一览 Features

| Tab | 页面 | Key Feature |
|-----|------|-------------|
| 🏠 Home | 活动动态 | 本周统计 + 好友动态 + 点赞 |
| 📍 Track | 实时追踪 | MQTT 硬件 GPS **或 Demo 模式**（无需硬件）|
| 🎯 Goals | 目标管理 | 今日骑行目标 + 每月目标 |
| 🏆 Ranks | 排行榜 | 月度 / 全部 好友排名 |
| 👤 Profile | 个人主页 | 累计数据 + 历史骑行 + 好友 |

---

## 🚀 运行步骤 How to Run

### 1 — 环境准备

```bash
flutter --version   # Flutter ≥ 3.0.0
flutter doctor      # 检查所有依赖是否正常
```

### 2 — 安装依赖

```bash
cd app_GPP_May02
flutter pub get
```

### 3 — 运行 App（macOS 桌面端）

```bash
flutter run -d macos
```

> **Xcode 26 beta 用户**：必须指定 `-d macos`，否则设备检测会卡住

### 4 — 登录

| 邮箱 | 密码 | 备注 |
|------|------|------|
| `yidan@ucl.ac.uk` | `casa2025` | 主账号（Yidan 的数据）|
| `alex@ucl.ac.uk` | `casa2025` | 好友账号 |
| `sarah@ucl.ac.uk` | `casa2025` | 好友账号 |

---

## 🧪 测试 Demo Mode（无需硬件）

Track 页面内置了 **Demo 模式**，不需要 ESP32 硬件就能完整测试实时追踪流程：

1. 进入 **Track** 标签页
2. 点击 **"Demo Mode (No Hardware)"** 按钮
3. App 自动模拟一段 Regent's Park 骑行路线，每 1.5 秒推送一个 GPS 点
4. 可以看到：计时器计数、路线实时绘制、速度和距离更新
5. 点击 **Finish → 输入名称 → Save**
6. 返回 Home 页面，查看刚保存的骑行记录

---

## 🔌 连接真实硬件 Connect to Hardware

等硬件组同学提供 MQTT 数据接口后，按以下步骤完成对接：

### Step 1 — 确认 MQTT Topic

打开 `lib/services/mqtt_service.dart`，确认第 17-20 行的 topic 与硬件端一致：

```dart
static const String _baseTopic   = 'student/CASA0021/Group3';
static const String _deviceTopic = '$_baseTopic/device/gps';
```

如果硬件组使用不同的 topic，只需修改 `_baseTopic` 或 `_deviceTopic`。

### Step 2 — 确认数据格式

硬件端应该发送如下格式的 MQTT payload：

```
纬度,经度,速度(km/h),累计距离(km)
```

示例：`51.531100,-0.159200,14.5,2.3`

硬件端 Arduino 参考代码：
```cpp
String payload = String(gps.location.lat(), 6) + "," +
                 String(gps.location.lng(), 6) + "," +
                 String(gps.speed.kmph(), 1) + "," +
                 String(totalDistanceKm, 2);
client.publish("student/CASA0021/Group3/device/gps", payload.c_str());
```

### Step 3 — App 内连接

1. 打开 **Track** 页面
2. 点击 **"Connect to Hardware"** 按钮
3. 等待右上角出现绿色 **"Connected"** 标志
4. 点击 **"Start with Hardware"** 开始骑行记录

---

## ❗ 常见问题 Troubleshooting

| 问题 | 解决方案 |
|------|---------|
| `flutter pub get` 报错 | 运行 `flutter doctor` 检查环境 |
| 地图显示灰色 | 需要在 `macos/Runner/AppDelegate.swift` 添加 Google Maps API Key |
| MQTT 连接失败 | 需要连接 UCL 校园网或 VPN（mqtt.cetools.org 限内网） |
| App 闪退 | `flutter clean && flutter pub get` 后重新运行 |

---

## 文件结构 Project Structure

```
app_GPP_May02/
├── lib/
│   ├── main.dart                      # 入口 + AppTheme（绿/黑/白配色）
│   ├── models/
│   │   ├── activity.dart              # Activity + GpsPoint 数据模型
│   │   ├── user.dart                  # 用户 + 月度目标 + 排行榜条目
│   │   └── trip_goal.dart             # 单次骑行目标
│   ├── data/mock_data.dart            # 模拟数据（含 Demo Mode GPS 路线）
│   ├── services/mqtt_service.dart     # MQTT 连接 + GPS 数据流
│   └── screens/
│       ├── login_screen.dart
│       ├── main_nav_screen.dart       # 底部导航
│       ├── home_screen.dart           # 活动动态
│       ├── live_tracking_screen.dart  # 实时追踪 + Demo Mode ⭐
│       ├── goals_screen.dart          # 目标管理
│       ├── map_navigation_screen.dart # 谷歌地图路线规划
│       ├── leaderboard_screen.dart    # 排行榜
│       ├── activity_detail_screen.dart
│       └── profile_screen.dart
├── macos/                             # macOS 平台配置（Xcode 项目）
├── pubspec.yaml                       # Flutter 依赖
├── README.md                          # 本文件：简介 + 运行指南
└── GPP_骑行追踪器_技术文档.md          # 完整技术文档（架构 + API + 开发说明）
```

---

## 技术依赖

```yaml
mqtt_client:          ^10.0.0  # MQTT 实时通信
google_maps_flutter:  ^2.9.0   # 地图展示与路线规划
http:                 ^1.2.0   # Google Places/Directions API
fl_chart:             ^0.68.0  # 图表（每周骑行柱状图）
provider:             ^6.1.1   # 状态管理
intl:                 ^0.19.0  # 时间日期格式化
shared_preferences:   ^2.2.2   # 本地设置存储
```

---

*UCL Bartlett Centre for Advanced Spatial Analysis · CASA0021 GPP · Group 3 · 2026*
