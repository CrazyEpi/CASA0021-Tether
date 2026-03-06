#include <ArduinoBLE.h>
#include <TinyGPS++.h>
#include <Adafruit_NeoPixel.h>

// ===== GPS Setup =====
TinyGPSPlus gps;
static const uint32_t GPSBaud = 115200;

// ===== LED / NeoPixel Setup =====
#define LED_PIN    6
#define NUMPIXELS  12
Adafruit_NeoPixel pixels(NUMPIXELS, LED_PIN, NEO_GRB + NEO_KHZ800);

// ===== BLE Setup =====
const char* BLE_SERVICE_UUID = "19B10000-E8F2-537E-4F6C-D104768A1214";
const char* BLE_LOCATION_CHAR_UUID = "19B10001-E8F2-537E-4F6C-D104768A1214";
const char* BLE_GOAL_CHAR_UUID = "19B10002-E8F2-537E-4F6C-D104768A1214";

BLEService bikeService(BLE_SERVICE_UUID);
BLEStringCharacteristic locationChar(BLE_LOCATION_CHAR_UUID, BLERead | BLENotify, 250);
BLEFloatCharacteristic goalChar(BLE_GOAL_CHAR_UUID, BLERead | BLEWrite);

// ===== Variables =====
double totalDistance = 0.0;
double targetDistance = 10.0; // default goal
double lastLat = 0.0;
double lastLon = 0.0;
float goalProgress = 0.0;

// ===== Setup =====
void setup() {
  Serial.begin(115200);
  while (!Serial) { delay(10); }

  Serial1.begin(GPSBaud);

  // LED setup
  pixels.begin();
  pixels.clear();
  pixels.show();

  // BLE setup
  if (!BLE.begin()) {
    Serial.println("BLUETOOTH FAILURE!");
    while (1);
  }

  BLE.setLocalName("BikeTracker_E"); 
  BLE.setAdvertisedService(bikeService);

  bikeService.addCharacteristic(locationChar);
  bikeService.addCharacteristic(goalChar);
  BLE.addService(bikeService);

  locationChar.writeValue("Waiting for GPS...");
  goalChar.writeValue(targetDistance);

  BLE.advertise();
  Serial.println("Device Activated! Waiting for Bluetooth and GPS...");
}

// ===== Loop =====
void loop() {
  BLEDevice central = BLE.central();

  // Update cycling goal via BLE
  if (central && central.connected()) {
    if (goalChar.written()) {
      targetDistance = goalChar.value();
      Serial.print("New Cycling Goal: ");
      Serial.println(targetDistance);
      updateLEDProgress();
    }
  }

  // Handle GPS data
  while (Serial1.available() > 0) {
    if (gps.encode(Serial1.read())) {
      if (gps.location.isValid() && gps.location.isUpdated()) {

        double currentLat = gps.location.lat();
        double currentLon = gps.location.lng();
        float speedKmph = gps.speed.kmph();

        // Distance calculation
        if (lastLat != 0.0 || lastLon != 0.0) {
          double stepDistance = TinyGPSPlus::distanceBetween(currentLat, currentLon, lastLat, lastLon);
          if (stepDistance > 2.0) { // filter out <2m
            totalDistance += stepDistance;
            lastLat = currentLat;
            lastLon = currentLon;
            updateLEDProgress();
          }
        } else {
          lastLat = currentLat;
          lastLon = currentLon;
        }

        // Moving detection
        goalProgress = totalDistance / targetDistance;
        if (goalProgress > 1.0) goalProgress = 1.0;
      }
    }
  }

  // Send GPS + extra data every 2s
  static unsigned long lastUpdate = 0;
  if (millis() - lastUpdate > 2000) {
    lastUpdate = millis();

    if (gps.location.isValid()) {
      float speed = gps.speed.kmph();
      float course = gps.course.deg();
      float altitude = gps.altitude.meters();
      int satellites = gps.satellites.value();
      float hdop = gps.hdop.hdop();

      // Approximate fix type
      int fixType = 0; // 0=no fix
      if (gps.location.isValid() && gps.altitude.isValid()) fixType = 3; // 3D fix
      else if (gps.location.isValid()) fixType = 2; // 2D fix
      else fixType = 1; // no fix

      String utcTime = gps.time.isValid() ?
                       String(gps.time.hour()) + ":" + String(gps.time.minute()) + ":" + String(gps.time.second()) :
                       "N/A";

      String date = gps.date.isValid() ?
                    String(gps.date.day()) + "/" + String(gps.date.month()) + "/" + String(gps.date.year()) :
                    "N/A";

      // Compose JSON payload
      String payload = String("{") +
                       "\"lat\":" + String(gps.location.lat(), 6) + "," +
                       "\"lon\":" + String(gps.location.lng(), 6) + "," +
                       "\"speed\":" + String(speed, 1) + "," +
                       "\"course\":" + String(course, 1) + "," +
                       "\"altitude\":" + String(altitude, 1) + "," +
                       "\"distance\":" + String(totalDistance, 1) + "," +
                       "\"satellites\":" + String(satellites) + "," +
                       "\"hdop\":" + String(hdop, 2) + "," +
                       "\"fixType\":" + String(fixType) + "," +
                       "\"moving\":" + String(speed > 0.5 ? "true" : "false") + "," +
                       "\"goalProgress\":" + String(goalProgress, 2) + "," +
                       "\"utcTime\":\"" + utcTime + "\"," +
                       "\"date\":\"" + date + "\"" +
                       "}";

      if (central && central.connected()) {
        locationChar.writeValue(payload);
      }

      Serial.println("Send: " + payload + " | Progress: " + String(totalDistance) + "/" + String(targetDistance));
    }
  }
}

// ===== LED progress =====
void updateLEDProgress() {
  int ledsToLight = round(goalProgress * NUMPIXELS);
  pixels.clear();
  for (int i = 0; i < NUMPIXELS; i++) {
    pixels.setPixelColor(i, i < ledsToLight ? pixels.Color(0, 150, 0) : pixels.Color(0, 0, 0));
  }
  pixels.show();
}