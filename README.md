# CASA0021-Tether
# Tether: Designing a Connected Cycling Companion for Motivation, Awareness and Safety


## 1. Introduction

![_DSC6421](https://github.com/user-attachments/assets/64856135-aaba-4be1-903a-0eef8439fd08)


Tether is a connected cycling system designed to support riders through a combination of a mobile application and a handlebar-mounted ambient device. The system provides real-time ride feedback, goal tracking, social comparison, and emergency communication in a way that reduces the need for continuous smartphone interaction during cycling.

Unlike traditional cycling applications that rely heavily on screen-based interaction, Tether shifts key information into an ambient physical interface mounted on the bicycle. This allows riders to remain aware of their performance and social context while maintaining focus on the riding environment.

The system uses Bluetooth Low Energy (BLE) to synchronise data between the mobile app and the ESP32-based device, enabling real-time updates for speed, distance, friend progress, and system status.

---

## 2. Why is the project useful?

Mobile technologies have become central to cycling practice through applications such as Strava, enabling performance tracking, goal setting, and social comparison. However, these systems are designed around sustained visual and manual engagement with a smartphone, which conflicts with the embodied and attention-split nature of cycling, where users must simultaneously manage movement, environmental awareness, and system interaction.

Alternative tools such as bike computers and smartwatches partially reduce phone dependence but retain similar limitations. Bike computers require repeated visual diversion from the road, while smartwatches constrain interaction to small displays that still demand focused attention. Across these systems, the dominant design priority remains information richness rather than attentional safety, creating a structural mismatch with in-motion activity.

Tether addresses this limitation by shifting interaction from screen-based engagement to ambient, handlebar-mounted feedback. Instead of requiring active attention, ride data is externalised into peripheral visual cues, allowing cyclists to maintain situational awareness while still receiving meaningful feedback. This reduces cognitive switching between environment and interface, supporting safer in-motion interaction.

Beyond functional limitations, existing systems also underrepresent the social and affective dimensions of cycling. Riders often seek lightweight forms of connection, progress comparison, and reassurance during activity, yet these are typically secondary to performance tracking.

Tether reframes cycling interaction by integrating awareness, motivation, safety, and social connection into a unified ambient system. This aligns with Connected Environments research and ubiquitous computing principles (Weiser, 1991), which advocate for systems that operate seamlessly within everyday activity rather than demanding attention.

### Problem Statement

Current cycling technologies rely on attention-heavy interaction models that assume sustained visual engagement, which is incompatible with the cognitive and physical demands of cycling. Existing systems prioritise performance tracking and screen-based interaction but fail to support low-attention awareness, situational safety, and lightweight social connection during motion, resulting in increased cognitive load and a disconnect between digital systems and embodied activity.


### Target Users and Scenarios

Tether is aimed at everyday cyclists, especially:
- commuters who need quick ride information,
- recreational riders who want visual motivation,
- friends who want to compare progress,
- and riders who may need a more visible emergency communication system.

The main user scenarios are:
1. **Individual riding**, where the rider sets a distance goal and tracks progress during the ride.
2. **Shared riding**, where two riders compare progress in real time even when cycling separately.
3. **Emergency situations**, where one rider can send an alert directly from the device.

### Project Objectives

The main objectives of Tether were:
- to reduce dependence on the smartphone during cycling,
- to provide low-distraction ride feedback,
- to support motivation through visible goal progress,
- to strengthen social connection between riders,
- and to create a more immediate emergency alert mechanism.

---

## ✦ What Tether Does

Tether combines hardware and software into one connected cycling experience.

### Mobile app as the control layer
The phone acts as the **GPS and cloud gateway**, processing ride information, helping reduce GPS drift, and managing updates between the rider, the cloud, and the physical device.

### BLE as the communication layer
The system uses **Bluetooth Low Energy (BLE)** to transfer ride data efficiently from the mobile app to the handlebar-mounted device.

**Device Name:** `BikeTracker_E`  
**Primary Service UUID:** `19B10000-E8F2-537E-4F6C-D104768A1214`

| Characteristic | UUID Suffix | Direction | Data Type | Payload Format & Description |
| :--- | :--- | :--- | :--- | :--- |
| **Live Metrics** | `...0001` | App → ESP32 | String (UTF-8) | `"Speed,MyDist,FriendDist,FriendGoal"`<br>*(e.g., `15.5,2.5,3.1,10.0`)*. Drives the speedometer and the dual-progress LED ring computations. |
| **Target Goal** | `...0002` | App → ESP32 | Float32 (LE) | Absolute target distance in kilometers. |
| **Time Sync** | `...0003` | App → ESP32 | String (UTF-8) | `"HH:MM"` format. Syncs phone system time to the dashboard. |
| **Social State** | `...0004` | App → ESP32 | Int32 (LE) | Number of online friends. Triggers the split-ring (Blue/Purple) UI mode if `> 0`. |
| **SOS Alert** | `...0005` | ESP32 → App | Byte (Notify) | `0x01` (Triggered) / `0x00` (Cleared). Uses BLE Notifications for zero-latency emergency broadcasting to the cloud. |
| **Social Pulse** | `...0006` | App → ESP32 | Byte | `0x01`. An event trigger that interrupts the default LED loop to play a 2-second cyan breathing animation. |

### ESP32 device as the feedback layer
A custom **ESP32-based device** with an AMOLED screen and LED ring renders ride information in real time.  
The device can display:

- current time  
- connection status  
- speed  
- rider progress  
- friend progress  
- battery status  

The lighting system also communicates different ride states through visual cues, including solo riding mode, friend comparison mode, and emergency alerts.

---

## ✦ Why It Matters

Tether was created to address a simple but important problem: cyclists need information that is easy to understand **without becoming distracted**.

This project is useful because it:

- reduces the need to constantly check a phone while riding  
- makes ride feedback more glanceable and immediate  
- introduces stronger social motivation through shared progress visibility  
- supports safety with emergency-focused visual feedback  
- brings together app intelligence and physical interaction in one system  

In this way, Tether moves beyond being just a cycling display. It becomes a connected riding companion designed around awareness, feedback, and human-centred interaction.

---

## ✦ Core Experience

Tether is built around three connected ideas:

### 1. Ride awareness
The rider can instantly understand personal progress, speed, and system state from the bike-mounted interface.

### 2. Social connection
The system makes shared riding more visible by showing comparative progress between riders.

### 3. Safety support
The SOS function enables user to send out emergency signal fast and easy.

---

# ✦ Getting Started

To begin using Tether, users will need:

- a compatible smartphone  
- the Tether mobile application  
- the Tether hardware device  
- Bluetooth enabled on the phone  
- the required hardware components assembled and powered  

### Setup

Getting Tether up and running requires assembling the hardware, flashing the firmware to the ESP32-S3, and deploying the Flutter mobile app.

<img width="9198" height="3292" alt="_DSC6442-pic" src="https://github.com/user-attachments/assets/bcb2bc7e-c273-43fe-8f79-da14caafdbfc" />


#### Phase 1: Hardware Assembly
1. Connect the **24-LED NeoPixel Ring** to the ESP32-S3 board (Data pin mapped to `GPIO 16`, with 3.3V/5V and GND connected appropriately).
2. Connect the Battery to the board using the 1.25mm pitch 2-pin cable.
3. Secure the components properly mounted inside the 3D-printed enclosure by matching numbers shown in above picture. Specifically, you need to match the three copper nuts with three holder, and then put the dupont connector in the rectangular slot.

#### Phase 2: ESP32 Firmware Setup (Arduino IDE)
The Waveshare ESP32-S3-Touch-AMOLED-1.75 requires specific libraries and configurations to drive the screen, touch interface, and power management correctly. 

**1. Board Manager:**
Ensure you have the ESP32 board package installed in your Arduino IDE. Select **ESP32S3 Dev Module** as your target board. Enable "PSRAM: OPI PSRAM" in the tools menu if required by your specific board variant.

| Library / File | Purpose |
| :--- | :--- |
| `GFX_Library_for_Arduino` | GFX graphics library adapted for the CO5300 display |
| `ESP32_IO_Expander` | Driver library for the TCA9554 IO expansion chip |
| `lvgl` | Core LVGL graphics library (v8.4.0) |
| `SensorLib` | Driver library for PCF85063, QMI8658, and CST9217 sensors |
| `XPowersLib` | Driver library for the AXP2101 power management chip |
| `Mylibrary` | Custom macro definitions for development board pins |
| `lv_conf.h` | Configuration file for the LVGL library |

#### Software Environment (Flutter App)
1. Ensure you have the Flutter SDK installed on your machine.
2. Clone the repository and navigate to the app directory.
3. Run `flutter pub get` to fetch all necessary Dart packages and dependencies.
4. Build and run the app on your compatible iOS or Android device.

## ✦ Need Help?

If you have questions, suggestions, or technical issues, support is available through the following channels:

open an issue in this GitHub repository
start a discussion on GitHub
contact the team directly by email

Contact email: [ucfnuaw@ucl.ac.uk]



## ✦ Team and Contributions

This project is maintained and developed by the Tether team.

**Maintainers / Contributors**

- **Gilang Pamungkas** — Backend
- **Haoyu Hu** — Hardware Development + App Improvement + Overall Testing + Video Recording and Editing
- **Yidan Gao** — Frontend
- **Yifei Huang** — 3D Print



## ✦ Components Used

1. Waveshare ESP32-S3-Touch-AMOLED-1.75 
2. NeoPixel Ring - 24 x 5050 RGB LED with Integrated Drivers
3. 1000mAh 3.7V LiPo Battery
4. 1.25mm Ultra-Slim Pitch 2-pin Cable Matching Pair 
5. 3D print

## ✦ Vedio
[Watch the video](https://youtu.be/pJ0elN8aA2U)
