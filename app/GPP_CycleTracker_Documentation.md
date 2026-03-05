# GPP Cycle Tracker — Technical Documentation

**UCL CASA0021 Group Project**
**Version 1.0 | March 2026**

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Technology Stack](#2-technology-stack)
3. [Project Structure](#3-project-structure)
4. [Architecture Overview](#4-architecture-overview)
5. [Screen-by-Screen UI Guide](#5-screen-by-screen-ui-guide)
6. [Navigation Flow](#6-navigation-flow)
7. [Hardware Integration](#7-hardware-integration)
8. [Google Maps API Setup](#8-google-maps-api-setup)
9. [User Guide](#9-user-guide)
10. [Demo Accounts](#10-demo-accounts)
11. [Running the App](#11-running-the-app)

---

## 1. Project Overview

GPP Cycle Tracker is a cross-platform Flutter application designed for the UCL CASA0021 Group Project. It is a cycling-focused GPS activity tracker inspired by Strava, featuring:

- **Live GPS tracking** via hardware sensor data over MQTT
- **Trip goal planning** via Google Maps (search destination → calculate cycling route → set goal)
- **Monthly goal tracking** (distance, rides, calories, active minutes)
- **Friends leaderboard** ranked by monthly distance or total rides
- **Activity history** with route visualisation using CustomPainter

The app uses mock data when no hardware is connected, and seamlessly switches to live MQTT data once the ESP32/Arduino sensor is broadcasting.

---

## 2. Technology Stack

| Layer | Technology | Version |
|---|---|---|
| Framework | Flutter | ≥ 3.0 (Dart ≥ 3.0) |
| GPS Data Transport | MQTT (`mqtt_client`) | ^10.0.0 |
| Maps | Google Maps Flutter | ^2.9.0 |
| Routing API | Google Directions API (REST) | — |
| Places Search | Google Places API (REST) | — |
| HTTP Client | `http` | ^1.2.0 |
| Charts | `fl_chart` | ^0.68.0 |
| Date Formatting | `intl` | ^0.19.0 |
| Local Storage | `shared_preferences` | ^2.2.2 |
| State Management | `provider` | ^6.1.1 |
| Design System | Flutter Material 3 | — |

**MQTT Broker:** `mqtt.cetools.org:1883`
**MQTT Topic:** `student/CASA0021/Group3/device/gps`
**GPS Payload Format:** `"lat,lng,speed_kmh,totalDistance_km"`

---

## 3. Project Structure

```
lib/
├── main.dart                      # App entry, AppTheme colour constants, MaterialApp
├── models/
│   ├── activity.dart              # Activity, GpsPoint models
│   ├── user.dart                  # AppUser, MonthlyGoal, LeaderboardEntry, UserData
│   └── trip_goal.dart             # TripGoal (single-ride destination goal)
├── data/
│   └── mock_data.dart             # London GPS routes, mock activities, leaderboard
├── services/
│   └── mqtt_service.dart          # MqttService singleton, GPS stream
└── screens/
    ├── login_screen.dart          # Login / sign-up UI
    ├── main_nav_screen.dart       # Bottom nav shell (5 tabs)
    ├── home_screen.dart           # Feed, weekly stats, ride cards
    ├── live_tracking_screen.dart  # MQTT live tracking, route painter
    ├── activity_detail_screen.dart# Single activity detail view
    ├── goals_screen.dart          # Two tabs: Today's Ride + Monthly
    ├── map_navigation_screen.dart # Google Maps, destination search, route
    ├── leaderboard_screen.dart    # Rankings podium + full list
    └── profile_screen.dart        # User stats, recent rides, friends
```

---

## 4. Architecture Overview

```
┌─────────────────────────────────────────┐
│              Flutter UI Layer           │
│  (Screens, Widgets, CustomPainters)     │
└───────────────┬─────────────────────────┘
                │
┌───────────────▼─────────────────────────┐
│           State / Models                │
│  AppUser · Activity · MonthlyGoal ·     │
│  TripGoal · LeaderboardEntry            │
└───────────────┬─────────────────────────┘
                │
     ┌──────────┴──────────┐
     │                     │
┌────▼──────┐       ┌──────▼─────────────────┐
│  MockData │       │     MqttService         │
│ (offline) │       │  mqtt.cetools.org:1883   │
└───────────┘       │  topic: …Group3/gps     │
                    │  → Stream<GpsPoint>     │
                    └──────────┬─────────────┘
                               │
                    ┌──────────▼─────────────────┐
                    │  ESP32 / Arduino Hardware   │
                    │  Payload: lat,lng,spd,dist  │
                    └────────────────────────────┘
```

**Google Maps flow:**

```
MapNavigationScreen
  └── TextField (search)
        ├── [Demo mode]  → filters pre-set London destinations
        └── [Live mode]  → Places Autocomplete API
                            → Place Details (geocode)
                            → Directions API (bicycling)
                            → Polyline decode → GoogleMap overlay
                            → "Set as Goal" → TripGoal → GoalsScreen
```

---

## 5. Screen-by-Screen UI Guide

### 5.1 Login Screen

**Purpose:** Authentication entry point.

- Dark background (`#1A1A1A`) with lime-green (`#A8D84A`) accents
- Email + password text fields
- Toggle between Login and Sign Up modes
- Demo credentials displayed in a hint box for easy testing
- Feature chips at bottom previewing the app's capabilities

**Key logic:** Validates email against `UserData.allUsers` list; password must be `casa2025` for all demo accounts.

---

### 5.2 Home Screen

**Purpose:** Activity feed and weekly summary dashboard.

- **Header:** Greeting, date, notification bell
- **Week Stats Row:** Three chips — total distance (km), total riding time (h:mm), number of rides
- **Recent Activity Feed:** Scrollable list of `_RideCard` widgets. Each card shows:
  - Route thumbnail (rendered by `_RoutePainter` CustomPainter)
  - Title, date, distance, duration, speed
  - Kudos ❤️ toggle
  - Tap → `ActivityDetailScreen`
- Tapping "See all" navigates to a full activity list (future feature)

**Data source:** `MockData.getMockActivities(userId)` — 4 London rides per user.

---

### 5.3 Live Tracking Screen

**Purpose:** Real-time GPS recording via MQTT hardware sensor.

**Sections:**

1. **Connection Banner** — shows MQTT status (Disconnected / Connecting / Connected) with a coloured badge
2. **Connect Button** — calls `MqttService.connect()`
3. **Live Stats Card** (active when tracking):
   - Elapsed time (hh:mm:ss)
   - Distance (km), Speed (km/h), GPS coordinates
4. **Route Canvas** — `_LiveRoutePainter` draws accumulated `GpsPoint` list in real time
5. **Controls Row** — Start / Pause / Stop buttons
6. **Debug Console** — last 5 raw MQTT messages displayed
7. **Hardware Instructions** — expandable panel showing Arduino payload format

**MQTT payload parsing:**
```dart
// GpsPoint.fromPayload("51.5246,-0.1340,18.5,3.2")
factory GpsPoint.fromPayload(String payload) {
  final parts = payload.split(',');
  return GpsPoint(
    lat: double.parse(parts[0]),
    lng: double.parse(parts[1]),
    speedKmh: double.parse(parts[2]),
    totalDistanceKm: double.parse(parts[3]),
    timestamp: DateTime.now(),
  );
}
```

When the user stops tracking, a **Save Ride** dialog appears to name and confirm the activity.

---

### 5.4 Goals Screen

**Purpose:** Two-tab goal management.

#### Tab 1 — Today's Ride

- **Empty state:** Bike icon, explanation, "Plan a Ride" CTA button, and "How it works" steps
- **Active state (goal set):**
  - Black destination card with lime progress bar
  - Target km, estimated duration, remaining km stats
  - "Simulate +25% Progress" demo button
  - Completion celebration card when 100% reached

Goals are set by navigating to **Map Navigation Screen** and tapping "Set as Today's Trip Goal".

#### Tab 2 — Monthly

- **Month header card** (black, with elapsed-month progress bar)
- **Four goal cards:** Distance / Rides / Calories / Active Time, each with coloured progress bar and percentage
- **Edit mode:** Tap "Edit" in app bar → inline text fields appear on each card → "Save" to persist
- **Weekly bar chart:** 7-day distance visualisation (today's bar highlighted in black)
- **Goal Tip:** Calculates required km/day to meet distance target

---

### 5.5 Map Navigation Screen

**Purpose:** Search cycling destinations, plan route, set as trip goal.

**Demo mode** (no API key):
- 8 pre-set London cycling destinations (Regent's Park, Hyde Park, Richmond Park, etc.)
- Dashed polyline drawn between UCL start point and destination
- Distance, estimated cycling time, estimated calories shown

**Live mode** (with API key):
- Google Places Autocomplete as user types
- On selection: Places Details API → geocode → Directions API (bicycling mode)
- Decoded polyline overlaid on map
- Bottom sheet: distance, duration, calories estimate
- **"Set as Today's Trip Goal"** → creates `TripGoal`, calls `onGoalSet` callback, navigates back

**UCL start point:** `LatLng(51.5246, -0.1340)`

---

### 5.6 Leaderboard Screen

**Purpose:** Social motivation through friend rankings.

- **Two tabs:** "This Month" (ranked by km) / "All Time" (ranked by total rides)
- **Podium (top 3):** Gold / Silver / Bronze visual with avatar, name, score, animated heights
- **"You" badge:** Highlights current user's row in orange
- **Your Rank Banner:** If outside top 3, a banner with your rank appears above the full list
- **Full list:** All users ranked with avatar, name, activity count, and score

---

### 5.7 Profile Screen

**Purpose:** User stats and social connections.

- **SliverAppBar** with avatar, username, edit profile button
- **Stats row:** Total km, total rides, total hours
- **Activity Type Breakdown:** Cycling % bar
- **Recent Rides:** Last 3 activities with distance + duration
- **Following list:** Friends with their stats
- **Settings bottom sheet:** Theme toggle placeholder, logout

---

## 6. Navigation Flow

```
LoginScreen
    │
    └── MainNavScreen (bottom nav, 5 tabs)
           ├── [0] HomeScreen
           │       └── tap card → ActivityDetailScreen
           │
           ├── [1] LiveTrackingScreen
           │
           ├── [2] GoalsScreen
           │       ├── Tab: Today's Ride
           │       │       └── "Plan a Ride" → MapNavigationScreen
           │       │                               └── "Set Goal" → back + update GoalsScreen
           │       └── Tab: Monthly
           │
           ├── [3] LeaderboardScreen
           │
           └── [4] ProfileScreen
                       └── settings icon → BottomSheet
                                             └── Logout → LoginScreen
```

---

## 7. Hardware Integration

The app is designed to receive GPS data from an **ESP32 or Arduino** with a GPS module publishing to MQTT.

### Arduino Payload Format

```cpp
// Arduino/ESP32 code (hardware side)
String payload = String(gps.location.lat(), 6) + "," +
                 String(gps.location.lng(), 6) + "," +
                 String(speed, 1) + "," +
                 String(totalDistance, 1);

client.publish("student/CASA0021/Group3/device/gps", payload.c_str());
```

**Example payload:** `51.524600,-0.134000,18.5,3.2`

| Field | Example | Unit |
|---|---|---|
| Latitude | `51.524600` | decimal degrees |
| Longitude | `-0.134000` | decimal degrees |
| Speed | `18.5` | km/h |
| Total Distance | `3.2` | km |

### MQTT Connection Settings

| Setting | Value |
|---|---|
| Broker | `mqtt.cetools.org` |
| Port | `1883` |
| Topic | `student/CASA0021/Group3/device/gps` |
| Client ID | `flutter_gpp_${timestamp}` |

### Switching from Mock to Live Data

In `live_tracking_screen.dart`, the app listens to `MqttService().gpsStream`. When the hardware is connected and publishing, this stream receives real `GpsPoint` objects. When no hardware is connected, the mock data in `mock_data.dart` supplies pre-recorded London routes.

---

## 8. Google Maps API Setup

### Step 1 — Get an API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a project → Enable **Maps SDK for Android**, **Maps SDK for iOS**, **Directions API**, **Places API**
3. Create an API key under **Credentials**

### Step 2 — Add the Key to the App

Open `lib/screens/map_navigation_screen.dart` and replace:
```dart
const String _kApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
```
with your actual key:
```dart
const String _kApiKey = 'AIzaSy...your_key_here';
```

### Step 3 — iOS Setup

Edit `ios/Runner/AppDelegate.swift`:
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
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

Edit `ios/Runner/Info.plist` — add inside `<dict>`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to track your cycling route.</string>
```

### Step 4 — Android Setup

Edit `android/app/src/main/AndroidManifest.xml` inside `<application>`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

### Demo Mode (No API Key)

Without a real API key, the map screen operates in **demo mode** automatically:
- 8 London cycling destinations are pre-loaded
- Dashed routes are drawn on the map
- All distance/time/calorie calculations work normally
- The app is fully functional for demonstration purposes

---

## 9. User Guide

### Getting Started

1. Launch the app and log in with a demo account (see Section 10)
2. The **Home** tab shows your recent rides and weekly stats

### Recording a Ride (Simulated)

1. Tap the **Track** tab (GPS icon)
2. Tap **Connect to Sensor** — the status badge turns green when connected
3. Tap **Start** to begin recording
4. GPS data arrives from the hardware and the route is drawn in real time
5. Tap **Stop** → name your ride → **Save**

### Planning a Destination Ride

1. Tap the **Goals** tab → **Today's Ride** tab
2. Tap **Plan a Ride**
3. Type a destination in the search bar (e.g. "Richmond Park")
4. Select from the dropdown suggestions
5. Review the route distance and estimated time
6. Tap **Set as Today's Trip Goal**
7. Back on the Goals screen, your destination card shows progress

### Checking Monthly Goals

1. Tap **Goals** → **Monthly** tab
2. View progress bars for Distance, Rides, Calories, Active Time
3. Tap **Edit** in the top-right to change your targets
4. Tap **Save** to confirm

### Viewing the Leaderboard

1. Tap the **Ranks** tab
2. Switch between "This Month" and "All Time"
3. Your row is highlighted in green

---

## 10. Demo Accounts

All accounts use the same password: **`casa2025`**

| Name | Email | Notes |
|---|---|---|
| Yidan Wei | `yidan@ucl.ac.uk` | Primary test user (you) |
| Alex Chen | `alex@ucl.ac.uk` | Friend 1 |
| Sarah Park | `sarah@ucl.ac.uk` | Friend 2 |
| James Liu | `james@ucl.ac.uk` | Friend 3 |
| Emma Wilson | `emma@ucl.ac.uk` | Friend 4 |

---

## 11. Running the App

### Prerequisites

- Flutter SDK ≥ 3.0 installed
- Xcode installed (for macOS/iOS targets)
- Run `flutter pub get` in the project root

### macOS Desktop (Recommended)

```bash
cd /path/to/GPP_May02
flutter run -d macos
```

> **Note for Xcode 26 (beta) users:** Use `-d macos` to avoid iOS device detection hang. This is a known Flutter/Xcode beta compatibility issue.

### iOS Simulator

```bash
open -a Simulator   # launch iOS Simulator first
flutter run         # then run in terminal
```

### Android

```bash
flutter run -d android
```

### Build Release

```bash
# macOS
flutter build macos

# iOS
flutter build ios

# Android
flutter build apk
```

---

*Document generated for CASA0021 GPP Group Project — UCL, 2026*
