# Tether 🚴

**A connected cycling companion for motivation, awareness and safety.**

Tether combines a handlebar-mounted ambient device with a companion mobile app to deliver real-time ride feedback, social comparison, and emergency signalling — without requiring cyclists to look at their phone.

<figure>
  <img src="img/Tether.jpg" alt="Final Tether prototype mounted on handlebars" width="100%">
  <figcaption><strong>Figure 1.</strong> Final prototype mounted on handlebars, showing the 1.75" AMOLED display and 24-LED NeoPixel ring.</figcaption>
</figure>

---

## What does Tether do?

Tether solves a simple but important problem: cyclists need information that is easy to understand without becoming distracted. Existing apps like Strava require you to look at your phone. Cycling computers still demand focused attention. Tether moves that information to your handlebars in a form you can read in a glance.

The system has three core functions:

**Ride awareness** — The 24-LED NeoPixel ring fills progressively as you approach your distance goal. Speed, time, connection status and battery are shown on the AMOLED display. All feedback is designed to be readable peripherally, without stopping your ride.

**Social connection** — In friend mode, the LED ring splits into two arcs: blue for your progress, purple for your friend's. Both arcs update in real time via Firebase cloud sync, so you can feel connected to a riding partner even when riding separately.

**Safety signalling** — A three-second physical hold on the device button sends an SOS alert via BLE to the app and onwards to the cloud, notifying your contacts without you needing to unlock your phone.

---

## Why is Tether useful?

Most cycling technology is built around screen interaction — which is incompatible with the physical demands of riding. Tether is the only system we are aware of that combines ambient ride feedback, concurrent social presence, and physical emergency signalling in a single handlebar-mounted device.

Compared to the Beeline Velo 2 (£99.99) — the closest commercial comparator — Tether adds real-time friend comparison and active SOS signalling at a similar price point. The honest gap is battery durability and weather sealing, which are the primary targets for the next development cycle.

---

## Getting started

You will need:
- A compatible Android or iOS smartphone
- The Tether mobile app (Flutter)
- The assembled Tether hardware device
- Bluetooth enabled on your phone

### Phase 1 — Hardware assembly

**Components required:**

| Component | Purpose |
|---|---|
| Waveshare ESP32-S3-Touch-AMOLED-1.75 | Main controller + display |
| NeoPixel Ring — 24 x 5050 RGB LED | Ambient progress ring |
| 1000mAh 3.7V LiPo Battery | Power supply |
| 1.25mm Ultra-Slim 2-pin Cable | Battery connector |
| 3D-printed enclosure | Handlebar housing |

**3D-printed enclosure:**

The enclosure design file is included in the `/3dprint/` directory of this repository as a Fusion 360 file (`.f3d`). Open it in Autodesk Fusion 360 to export as STL before slicing. Print settings that worked for us:

- Material: PLA
- Layer height: 0.2mm
- Infill: 20%
- Supports: required for the internal nut holders

The enclosure went through four revision cycles. The current version (v4) includes a rotary interlock for handlebar attachment, a friction-based screen locker to prevent display rotation under vibration, and a diffuser cover over the LED ring. The handlebar mount uses rubber bands for rapid field adjustment during the prototype phase — loop them through the two side slots and around your handlebar.

**Assembly steps:**

1. Connect the 24-LED NeoPixel Ring to the ESP32-S3 board — Data pin to GPIO 16, with 3.3V/5V and GND connected appropriately.
2. Connect the battery to the board using the 1.25mm pitch 2-pin cable.
3. Seat all components inside the 3D-printed enclosure, matching the three copper nuts to the three holders. Insert the Dupont connector into the rectangular slot.
4. Attach the diffuser cover over the LED ring — press firmly to seat it evenly around the full circumference to minimise light bleed in direct sunlight.
5. Mount the enclosure to your handlebar using rubber bands through the side slots, or use the rotary interlock if your handlebar diameter is compatible.

> **Note:** The diffuser cover fit is intentionally tight — uneven seating causes light bleed between LED segments in bright conditions. This is a known limitation being addressed in the next enclosure revision.

### Phase 2 — ESP32 firmware setup (Arduino IDE)

**Board configuration:**

- Board: `ESP32S3 Dev Module`
- PSRAM: `OPI PSRAM` (enable in Tools menu if required by your board variant)

**Required libraries:**

| Library | Purpose |
|---|---|
| GFX_Library_for_Arduino | Graphics driver for the CO5300 display |
| ESP32_IO_Expander | Driver for the TCA9554 IO expansion chip |
| lvgl (v8.4.0) | Core LVGL graphics library |
| SensorLib | Driver for PCF85063, QMI8658, and CST9217 sensors |
| XPowersLib | Driver for the AXP2101 power management chip |
| Mylibrary | Custom macro definitions for development board pins |
| lv_conf.h | LVGL configuration file |

Install all libraries via Arduino IDE Library Manager or place them in your Arduino `libraries` folder. Flash the firmware to the ESP32-S3 via USB.

### Phase 3 — Mobile app setup (Flutter)

1. Ensure the Flutter SDK is installed on your machine ([flutter.dev](https://flutter.dev)).
2. Clone this repository and navigate to the `/app` directory.
3. Run `flutter pub get` to fetch all Dart package dependencies.
4. Connect your Android or iOS device and run `flutter run`.

The app will scan for the BLE device named `BikeTracker_E` automatically when you start a ride.

### Phase 4 — Firebase backend setup

Tether uses Firebase for three functions: user authentication, real-time ride data sync between riders, and managing each user's friend circle for social comparison and SOS contact routing.

**Services used:**
- **Firebase Authentication** — email/password sign-in for all app users
- **Cloud Firestore** — real-time database storing user profiles, ride data, and live ride state; used by the app's `onSnapshot` listeners to push a friend's updated distance to the handlebar device within seconds
- **Friend circle management** — each user document in Firestore stores a list of followed friends; the app queries this to populate the leaderboard, social feed, and live split-ring comparison

**Setup steps:**

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com).
2. Enable **Firebase Authentication** (email/password provider).
3. Enable **Cloud Firestore** — select region `europe-west2`.
4. Download the `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) from your Firebase project settings and place it in:
   - Android: `/app/android/app/google-services.json`
   - iOS: `/app/ios/Runner/GoogleService-Info.plist`
5. Apply the following Firestore security rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
      match /{document=**} {
        allow read: if request.auth != null;
        allow write: if request.auth.uid == userId;
      }
    }
    match /rides/{rideId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

6. Run `flutter pub get` after placing the config files, then rebuild the app.

> **Note:** The friend circle is managed through Firestore — users follow each other by storing friend UIDs in their user document. The app resolves friend live-ride state from Firestore in real time and writes it to the handlebar device via BLE on each update.

---

## BLE communication reference

The device and app communicate over a single BLE service.

**Device name:** `BikeTracker_E`  
**Primary service UUID:** `19B10000-E8F2-537E-4F6C-D104768A1214`

| Characteristic | UUID Suffix | Direction | Data type | Payload |
|---|---|---|---|---|
| Live Metrics | `...0001` | App → ESP32 | String (UTF-8) | `"Speed,MyDist,FriendDist,FriendGoal"` e.g. `15.5,2.5,3.1,10.0` |
| Target Goal | `...0002` | App → ESP32 | Float32 (LE) | Absolute target distance in km |
| Time Sync | `...0003` | App → ESP32 | String (UTF-8) | `"HH:MM"` — syncs phone time to display |
| Social State | `...0004` | App → ESP32 | Int32 (LE) | Number of online friends; triggers split-ring mode if > 0 |
| SOS Alert | `...0005` | ESP32 → App | Byte (Notify) | `0x01` triggered / `0x00` cleared |
| Social Pulse | `...0006` | App → ESP32 | Byte | `0x01` — triggers 2-second cyan breathing animation |

The SOS characteristic uses BLE Notify (device pushes to app) rather than polling, ensuring zero-latency emergency broadcast regardless of app foreground state.

---

## LED states reference

| Mode | Colour | Trigger |
|---|---|---|
| Solo riding | Single blue arc | No friends online |
| Friend mode | Split blue/purple arc | Friend online and riding |
| SOS emergency | Full ring solid red | SOS button held 3 seconds |
| Social pulse | Cyan breathing | Friend milestone event |
| Low speed | Dimmed display | Speed below threshold |

---

## App screens

The Flutter app covers the full ride lifecycle across 8 screens:

- **Home & feed** — activity feed, weekly stats, kudos
- **Live tracking** — real-time GPS map with BLE device connection
- **Goals & route planner** — set distance goals, plan route via Google Maps API
- **Leaderboard** — monthly and all-time rankings with friends
- **Profile** — ride history, stats, follow friends
- **Developer console** — simulate hardware LED states for testing without the physical device

---

## Where to get help

- **GitHub Issues** — [open an issue](../../issues) for bugs or technical problems
- **GitHub Discussions** — [start a discussion](../../discussions) for questions or ideas
- **Email** — contact the team directly at [ucfnuaw@ucl.ac.uk](mailto:ucfnuaw@ucl.ac.uk)

---

## Who maintains and contributes to this project

**Four Gods — Group 4, CASA0021, UCL Bartlett CASA 2025–26**

| Name | Role |
|---|---|
| Gilang Pamungkas | Backend & cloud infrastructure |
| Haoyu Hu | Hardware development, app improvement, testing, video |
| Yidan Gao | Frontend & mobile application |
| Yifei Huang | 3D print & enclosure design |

**Public repository:** [https://github.com/CrazyEpi/CASA0021-Tether](https://github.com/CrazyEpi/CASA0021-Tether)
