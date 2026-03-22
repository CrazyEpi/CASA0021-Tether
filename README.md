# CASA0021-Tether
### Ride together. Stay aware. Stay safe.

Tether is a smart cycling companion system designed to bring **real-time awareness**, **social connection**, and **safety feedback** into the riding experience.  
By combining a mobile app, Bluetooth Low Energy (BLE) communication, and a custom ESP32-based hardware interface, Tether transforms ride data into simple, glanceable signals that support cyclists on the move.

---

## ✦ Project Vision

Cycling information is often fragmented across phones, apps, and small on-screen notifications. Tether was developed to make this experience more immediate and intuitive by turning ride data into a physical, glanceable interface mounted directly on the bike.

Rather than focusing only on navigation, Tether explores how cyclists can remain aware of:

- their own ride progress  
- their friends’ progress  
- connection status  
- emergency conditions  
- battery and device state  

The goal is to create a cycling companion that is not only practical, but also more social, supportive, and safety-oriented.

---

## ✦ What Tether Does

Tether combines hardware and software into one connected cycling experience.

### Mobile app as the control layer
The phone acts as the **GPS and cloud gateway**, processing ride information, helping reduce GPS drift, and managing updates between the rider, the cloud, and the physical device.

### BLE as the communication layer
The system uses **Bluetooth Low Energy (BLE)** to transfer ride data efficiently from the mobile app to the handlebar-mounted device.

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
Emergency signalling and status indicators help communicate urgent situations more clearly during use.

---

# ✦ Getting Started

To begin using Tether, users will need:

- a compatible smartphone  
- the Tether mobile application  
- the Tether hardware device  
- Bluetooth enabled on the phone  
- the required hardware components assembled and powered  

### Setup
### Setup

Getting Tether up and running requires assembling the hardware, flashing the firmware to the ESP32-S3, and deploying the Flutter mobile app.

#### Phase 1: Hardware Assembly
1. Connect the **24-LED NeoPixel Ring** to the ESP32-S3 board (Data pin mapped to `GPIO 16`, with 3.3V/5V and GND connected appropriately).
2. Connect the Battery to the board using the 1.25mm pitch 2-pin cable.
3. Secure the components properly mounted inside the 3D-printed enclosure.

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
- **Haoyu Hu** — Hardware
- **Yidan Gao** — Frontend
- **Yifei Huang** — 3D Print



## ✦ Components Used

1. Waveshare ESP32-S3-Touch-AMOLED-1.75 
2. NeoPixel Ring - 24 x 5050 RGB LED with Integrated Drivers
3. 1000mAh 3.7V LiPo Battery
4. 1.25mm Ultra-Slim Pitch 2-pin Cable Matching Pair 
5. 3D print 
