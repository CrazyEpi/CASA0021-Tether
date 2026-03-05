# GPP Fitness Tracker
**CASA0021 Group Project – Sport Activity Tracking App**

A Strava-inspired Flutter mobile app that receives live GPS data from ESP32 hardware via MQTT, and lets users track activities, set monthly goals, and compete with friends on a leaderboard.

---

## Features

| Screen | Description |
|--------|-------------|
| **Login** | Secure login with demo accounts |
| **Home Feed** | Activity feed (yours + friends), kudos system |
| **Live Tracking** | Real-time GPS via MQTT, start/pause/stop, route visualisation |
| **Monthly Goals** | Set distance, activity, calorie, and time targets |
| **Leaderboard** | Friend rankings by distance (monthly & all-time) |
| **Profile** | Stats summary, activity history, friends |

---

## Hardware Integration

Your ESP32 publishes GPS data to MQTT in this format:

```cpp
// Arduino payload format
String payload = String(gps.location.lat(), 6) + "," +
                 String(gps.location.lng(), 6) + "," +
                 String(speed, 1) + "," +
                 String(totalDistance, 1);

client.publish("student/CASA0021/Group3/device/gps", payload.c_str());
```

**MQTT Config** (in `lib/services/mqtt_service.dart`):
- Broker: `mqtt.cetools.org:1883`
- Topic: `student/CASA0021/Group3/device/gps`
- Payload: `lat,lng,speed_kmh,totalDistance_km`

> ⚠️ **Change the topic** to your actual group number before connecting hardware.

---

## Getting Started

### Prerequisites
- Flutter SDK ≥ 3.0.0
- Android Studio or VS Code with Flutter plugin
- An Android or iOS device (or emulator)

### Install & Run

```bash
cd GPP_May02
flutter pub get
flutter run
```

### Demo Login
- Email: `yidan@ucl.ac.uk`
- Password: `casa2025`

Other test accounts: `alex@ucl.ac.uk`, `sarah@ucl.ac.uk`, `james@ucl.ac.uk`, `emma@ucl.ac.uk` (same password)

---

## Project Structure

```
lib/
├── main.dart                    # App entry + theme config
├── models/
│   ├── activity.dart            # Activity & GpsPoint models
│   └── user.dart                # User, MonthlyGoal, LeaderboardEntry
├── data/
│   └── mock_data.dart           # Test data (replace with real MQTT data)
├── services/
│   └── mqtt_service.dart        # MQTT connection & GPS parsing
└── screens/
    ├── login_screen.dart        # Login/signup page
    ├── main_nav_screen.dart     # Bottom navigation shell
    ├── home_screen.dart         # Activity feed & dashboard
    ├── live_tracking_screen.dart # Real-time GPS tracking
    ├── activity_detail_screen.dart # Activity detail view
    ├── goals_screen.dart        # Monthly goals & progress
    ├── leaderboard_screen.dart  # Friend rankings
    └── profile_screen.dart      # User profile & stats
```

---

## Test Data Location

All mock/test data is in `lib/data/mock_data.dart`:
- Sample GPS routes (Regent's Park, Hyde Park, UCL campus)
- 8 sample activities (4 from current user, 4 from friends)
- Monthly goal progress
- Leaderboard entries

When real hardware is connected, GPS points are received live via MQTT and stored in-memory during a session.

---

## Dependencies

```yaml
mqtt_client: ^10.0.0     # MQTT broker communication
fl_chart: ^0.68.0        # Charts (weekly activity bar chart)
intl: ^0.19.0            # Date/time formatting
provider: ^6.1.1         # State management
shared_preferences: ^2.2.2 # Local storage
```

---

## CASA0021 Group Project
UCL Bartlett Centre for Advanced Spatial Analysis
