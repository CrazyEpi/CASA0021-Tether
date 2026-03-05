# GPP 骑行追踪器 — 技术文档（中文版）

**UCL CASA0021 小组项目**
**版本 1.0 | 2026年3月**

---

## 目录

1. [项目简介](#1-项目简介)
2. [技术栈](#2-技术栈)
3. [项目结构](#3-项目结构)
4. [架构概览](#4-架构概览)
5. [界面逻辑说明](#5-界面逻辑说明)
6. [页面导航流程](#6-页面导航流程)
7. [硬件接入说明](#7-硬件接入说明)
8. [谷歌地图 API 配置](#8-谷歌地图-api-配置)
9. [用户使用指南](#9-用户使用指南)
10. [测试账号](#10-测试账号)
11. [运行方式](#11-运行方式)

---

## 1. 项目简介

GPP 骑行追踪器是一款基于 Flutter 开发的跨平台移动应用，专为 UCL CASA0021 小组项目设计。它是一款以骑行为核心的 GPS 运动追踪 App，主要功能包括：

- **实时 GPS 追踪**：通过 MQTT 协议接收硬件传感器数据
- **骑行目标规划**：接入谷歌地图，搜索目的地 → 计算骑行路线距离 → 设为当日骑行目标
- **每月目标追踪**：距离、骑行次数、卡路里、活动时长
- **好友排行榜**：按月度距离或总骑行次数排名
- **活动历史记录**：包含路线可视化（使用 CustomPainter 绘制）

应用内置伦敦骑行模拟数据，无需硬件也能完整演示所有功能；连接 ESP32/Arduino 硬件后自动切换为实时数据。

---

## 2. 技术栈

| 层级 | 技术 | 版本 |
|---|---|---|
| 开发框架 | Flutter | ≥ 3.0（Dart ≥ 3.0） |
| GPS 数据传输 | MQTT（`mqtt_client` 包） | ^10.0.0 |
| 地图 | Google Maps Flutter | ^2.9.0 |
| 路线规划 API | Google Directions API（REST） | — |
| 地点搜索 | Google Places API（REST） | — |
| HTTP 请求 | `http` | ^1.2.0 |
| 图表 | `fl_chart` | ^0.68.0 |
| 日期格式化 | `intl` | ^0.19.0 |
| 本地存储 | `shared_preferences` | ^2.2.2 |
| 状态管理 | `provider` | ^6.1.1 |
| UI 设计系统 | Flutter Material 3 | — |

**MQTT 服务器：** `mqtt.cetools.org:1883`
**MQTT 主题：** `student/CASA0021/Group3/device/gps`
**GPS 数据格式：** `"纬度,经度,速度_kmh,总距离_km"`

---

## 3. 项目结构

```
lib/
├── main.dart                        # 入口文件、AppTheme 颜色常量、MaterialApp
├── models/
│   ├── activity.dart                # Activity（活动）、GpsPoint（GPS点）数据模型
│   ├── user.dart                    # AppUser、MonthlyGoal、LeaderboardEntry、UserData
│   └── trip_goal.dart               # TripGoal（单次骑行目标）
├── data/
│   └── mock_data.dart               # 伦敦 GPS 路线、模拟活动数据、排行榜数据
├── services/
│   └── mqtt_service.dart            # MqttService 单例，GPS 数据流
└── screens/
    ├── login_screen.dart            # 登录 / 注册页面
    ├── main_nav_screen.dart         # 底部导航栏（5 个标签）
    ├── home_screen.dart             # 首页：动态 Feed、周统计
    ├── live_tracking_screen.dart    # 实时 MQTT 追踪、路线绘制
    ├── activity_detail_screen.dart  # 单次活动详情
    ├── goals_screen.dart            # 两个标签：今日骑行 + 每月目标
    ├── map_navigation_screen.dart   # 谷歌地图、目的地搜索、路线规划
    ├── leaderboard_screen.dart      # 好友排行榜（领奖台 + 完整列表）
    └── profile_screen.dart          # 个人主页：统计、骑行记录、好友列表
```

---

## 4. 架构概览

```
┌─────────────────────────────────────────┐
│            Flutter UI 层                │
│   （页面、组件、CustomPainter 路线图）    │
└───────────────┬─────────────────────────┘
                │
┌───────────────▼─────────────────────────┐
│          数据模型层（State/Models）       │
│  AppUser · Activity · MonthlyGoal ·      │
│  TripGoal · LeaderboardEntry             │
└───────────────┬─────────────────────────┘
                │
     ┌──────────┴──────────┐
     │                     │
┌────▼────────┐     ┌──────▼──────────────────┐
│  MockData   │     │      MqttService         │
│ （离线模式） │     │  mqtt.cetools.org:1883   │
└─────────────┘     │  topic: …Group3/gps      │
                    │  → Stream<GpsPoint>      │
                    └──────────┬──────────────┘
                               │
                    ┌──────────▼──────────────────┐
                    │   ESP32 / Arduino 硬件端     │
                    │  数据格式: 纬度,经度,速度,距离 │
                    └─────────────────────────────┘
```

**谷歌地图数据流：**

```
MapNavigationScreen（地图页面）
  └── 搜索框（TextField）
        ├── [演示模式]  → 筛选预设的 8 个伦敦骑行目的地
        └── [正式模式]  → Places Autocomplete API（地点自动补全）
                          → Place Details API（获取坐标）
                          → Directions API（骑行模式）
                          → 解码折线 → 显示在 GoogleMap 上
                          → "设为今日目标" → TripGoal → GoalsScreen
```

---

## 5. 界面逻辑说明

### 5.1 登录页（Login Screen）

**功能：** 用户身份验证入口。

- 深色背景（`#1A1A1A`）+ 石灰绿（`#A8D84A`）强调色
- 邮箱 + 密码输入框
- 支持登录 / 注册模式切换
- 底部有测试账号提示框，方便直接使用
- 底部功能预览芯片，展示应用的主要功能

**验证逻辑：** 对比 `UserData.allUsers` 列表中的邮箱，密码统一为 `casa2025`。

---

### 5.2 首页（Home Screen）

**功能：** 活动动态流 + 周运动数据总览。

- **顶部问候语**：显示用户名和当前日期
- **周统计行**：本周总距离（km）/ 骑行时长 / 骑行次数
- **活动动态 Feed**：可滚动的 `_RideCard` 列表，每张卡片包含：
  - 路线缩略图（由 `_RoutePainter` CustomPainter 绘制）
  - 标题、日期、距离、时长、速度
  - 点赞 ❤️ 切换按钮
  - 点击跳转 → 活动详情页

**数据来源：** `MockData.getMockActivities(userId)` — 每个用户 4 条伦敦骑行记录。

---

### 5.3 实时追踪页（Live Tracking Screen）

**功能：** 通过 MQTT 接收硬件 GPS 数据并实时记录。

**页面结构：**

1. **连接状态横幅** — 显示 MQTT 状态（未连接 / 连接中 / 已连接），颜色徽标标识
2. **连接按钮** — 调用 `MqttService.connect()`
3. **实时数据卡片**（追踪中显示）：
   - 计时器（时:分:秒）
   - 距离（km）、速度（km/h）、当前 GPS 坐标
4. **路线画布** — `_LiveRoutePainter` 实时绘制累积的 `GpsPoint` 点列表
5. **控制按钮** — 开始 / 暂停 / 停止
6. **调试控制台** — 显示最近 5 条原始 MQTT 消息
7. **硬件说明面板** — 可展开，显示 Arduino 端数据格式

**GPS 数据解析：**
```dart
// 解析格式："51.5246,-0.1340,18.5,3.2"
factory GpsPoint.fromPayload(String payload) {
  final parts = payload.split(',');
  return GpsPoint(
    lat: double.parse(parts[0]),       // 纬度
    lng: double.parse(parts[1]),       // 经度
    speedKmh: double.parse(parts[2]), // 速度 km/h
    totalDistanceKm: double.parse(parts[3]), // 累计距离 km
    timestamp: DateTime.now(),
  );
}
```

停止追踪后弹出 **保存骑行** 对话框，可命名并确认保存。

---

### 5.4 目标页（Goals Screen）

**功能：** 两标签式目标管理。

#### 标签 1 — 今日骑行

- **无目标状态：** 自行车图标 + 说明文字 + "规划骑行"按钮 + "操作步骤"说明
- **已设置目标状态：**
  - 黑色目的地卡片（带石灰绿进度条）
  - 目标距离 / 预计时长 / 剩余距离 三个统计芯片
  - 演示用"+25% 进度"按钮
  - 到达 100% 时显示完成庆祝卡片

目标通过 **地图导航页** 的"设为今日目标"按钮来设置。

#### 标签 2 — 每月目标

- **月份标题卡**（黑色背景，显示月份进度条）
- **四个目标卡片：** 距离 / 骑行次数 / 卡路里 / 活动时长，每项有彩色进度条和百分比
- **编辑模式：** 点击右上角"编辑" → 每个卡片内联出现输入框 → 点击"保存"生效
- **本周柱状图：** 7 天距离可视化（今日柱状高亮为黑色）
- **目标提示：** 自动计算"每天需骑行 X km 才能完成月度距离目标"

---

### 5.5 地图导航页（Map Navigation Screen）

**功能：** 搜索骑行目的地、规划路线、设为今日骑行目标。

**演示模式**（无 API Key 时自动启用）：
- 预设 8 个伦敦骑行目的地（摄政公园、海德公园、里士满公园等）
- 从 UCL 出发，用虚线折线连接目的地
- 显示距离、预计骑行时间、预计消耗卡路里

**正式模式**（有 API Key 时）：
- 输入时调用 Google Places Autocomplete
- 选择后：Places Details API → 获取坐标 → Directions API（骑行模式）→ 解码折线并显示
- 底部弹出面板：距离、时长、卡路里
- **"设为今日骑行目标"** → 创建 `TripGoal`，回调给目标页，返回

**UCL 出发点坐标：** `LatLng(51.5246, -0.1340)`

---

### 5.6 排行榜页（Leaderboard Screen）

**功能：** 通过好友排名激发骑行动力。

- **两个标签：** "本月"（按 km 排名）/ "全部时间"（按总骑行次数排名）
- **领奖台（前 3 名）：** 金 / 银 / 铜视觉效果，显示头像、姓名、成绩
- **"你"徽标：** 当前用户行用绿色高亮显示
- **你的排名横幅：** 若不在前 3，在完整列表上方显示你的排名
- **完整列表：** 所有用户按排名显示头像、姓名、活动次数、成绩

---

### 5.7 个人主页（Profile Screen）

**功能：** 个人数据统计 + 社交连接。

- **可滚动头部（SliverAppBar）：** 头像、用户名、编辑资料按钮
- **统计行：** 总 km / 总骑行次数 / 总小时数
- **活动类型分布：** 骑行占比进度条
- **最近骑行：** 最近 3 条活动（距离 + 时长）
- **关注的好友列表：** 好友头像、姓名、统计数据
- **设置底部弹窗：** 主题切换（预留）、退出登录

---

## 6. 页面导航流程

```
登录页（LoginScreen）
    │
    └── 主导航页（MainNavScreen，底部5标签）
           ├── [0] 首页（HomeScreen）
           │       └── 点击活动卡片 → 活动详情页（ActivityDetailScreen）
           │
           ├── [1] 实时追踪页（LiveTrackingScreen）
           │
           ├── [2] 目标页（GoalsScreen）
           │       ├── 标签：今日骑行
           │       │       └── "规划骑行" → 地图导航页（MapNavigationScreen）
           │       │                           └── "设为目标" → 返回并更新目标页
           │       └── 标签：每月目标
           │
           ├── [3] 排行榜页（LeaderboardScreen）
           │
           └── [4] 个人主页（ProfileScreen）
                       └── 设置图标 → 底部弹窗
                                         └── 退出登录 → 登录页
```

---

## 7. 硬件接入说明

本应用设计为接收来自 **ESP32 或 Arduino**（带 GPS 模块）通过 MQTT 发布的实时数据。

### Arduino 端数据格式

```cpp
// Arduino/ESP32 硬件端代码
String payload = String(gps.location.lat(), 6) + "," +
                 String(gps.location.lng(), 6) + "," +
                 String(speed, 1) + "," +
                 String(totalDistance, 1);

client.publish("student/CASA0021/Group3/device/gps", payload.c_str());
```

**示例数据：** `51.524600,-0.134000,18.5,3.2`

| 字段 | 示例 | 单位 |
|---|---|---|
| 纬度 | `51.524600` | 十进制度 |
| 经度 | `-0.134000` | 十进制度 |
| 速度 | `18.5` | km/h |
| 累计距离 | `3.2` | km |

### MQTT 连接参数

| 参数 | 值 |
|---|---|
| 服务器地址 | `mqtt.cetools.org` |
| 端口 | `1883` |
| 主题 | `student/CASA0021/Group3/device/gps` |
| 客户端 ID | `flutter_gpp_${时间戳}` |

### 从模拟数据切换到实时数据

在 `live_tracking_screen.dart` 中，应用监听 `MqttService().gpsStream`。当硬件正常连接并发布数据时，该 Stream 会接收到真实的 `GpsPoint` 对象；未连接硬件时，`mock_data.dart` 中预录制的伦敦路线数据会自动填充。

---

## 8. 谷歌地图 API 配置

### 第一步 — 获取 API Key

1. 打开 [Google Cloud Console](https://console.cloud.google.com)
2. 创建项目 → 启用 **Maps SDK for Android**、**Maps SDK for iOS**、**Directions API**、**Places API**
3. 在"凭据"页面创建 API Key

### 第二步 — 填入 App

打开 `lib/screens/map_navigation_screen.dart`，将：
```dart
const String _kApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
```
替换为你的实际 Key：
```dart
const String _kApiKey = 'AIzaSy...你的key';
```

### 第三步 — iOS 配置

编辑 `ios/Runner/AppDelegate.swift`：
```swift
import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("你的API_KEY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

编辑 `ios/Runner/Info.plist`，在 `<dict>` 内添加：
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>此应用需要位置权限以追踪您的骑行路线。</string>
```

### 第四步 — Android 配置

编辑 `android/app/src/main/AndroidManifest.xml`，在 `<application>` 内添加：
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="你的API_KEY"/>
```

### 演示模式（无 API Key）

没有真实 API Key 时，地图页面会**自动进入演示模式**：
- 预加载 8 个伦敦骑行目的地
- 虚线路线绘制在地图上
- 距离、时间、卡路里计算正常工作
- 应用可完整演示所有功能

---

## 9. 用户使用指南

### 登录

1. 启动应用，使用下方任意测试账号登录
2. **首页**标签显示你的近期骑行记录和本周统计

### 记录一次骑行（模拟）

1. 点击底部 **追踪（Track）** 标签
2. 点击 **连接传感器** — 状态徽标变绿表示连接成功
3. 点击 **开始** 开始记录
4. 硬件端发来的 GPS 数据会实时绘制路线
5. 点击 **停止** → 输入骑行名称 → **保存**

### 规划目的地骑行

1. 点击 **目标（Goals）** 标签 → **今日骑行** 子标签
2. 点击 **规划骑行**
3. 在搜索框输入目的地（例如：Richmond Park）
4. 从下拉建议中选择
5. 查看路线距离和预计用时
6. 点击 **设为今日骑行目标**
7. 返回目标页，目的地卡片显示实时进度

### 查看每月目标

1. 点击 **目标** → **每月目标** 子标签
2. 查看距离、骑行次数、卡路里、活动时长的进度条
3. 点击右上角 **编辑** 修改目标数值
4. 点击 **保存** 确认

### 查看排行榜

1. 点击 **排名（Ranks）** 标签
2. 切换"本月"和"全部时间"
3. 你的记录行用绿色高亮显示

---

## 10. 测试账号

所有账号密码统一为：**`casa2025`**

| 姓名 | 邮箱 | 说明 |
|---|---|---|
| Yidan Wei | `yidan@ucl.ac.uk` | 主测试账号（你） |
| Alex Chen | `alex@ucl.ac.uk` | 好友 1 |
| Sarah Park | `sarah@ucl.ac.uk` | 好友 2 |
| James Liu | `james@ucl.ac.uk` | 好友 3 |
| Emma Wilson | `emma@ucl.ac.uk` | 好友 4 |

---

## 11. 运行方式

### 前置要求

- 已安装 Flutter SDK ≥ 3.0
- 已安装 Xcode（用于 macOS/iOS）
- 在项目根目录运行 `flutter pub get`

### macOS 桌面端（推荐）

```bash
cd /path/to/GPP_May02
flutter run -d macos
```

> **Xcode 26 (beta) 用户注意：** 使用 `-d macos` 参数，可避免 iOS 设备检测卡住的问题。这是已知的 Flutter 与 Xcode beta 的兼容性问题。

### iOS 模拟器

```bash
open -a Simulator   # 先打开 iOS 模拟器
flutter run         # 然后在终端运行
```

### Android

```bash
flutter run -d android
```

### 构建发布版本

```bash
# macOS
flutter build macos

# iOS
flutter build ios

# Android APK
flutter build apk
```

---

*本文档由 UCL CASA0021 GPP 小组项目自动生成 — 2026*
