#include <ArduinoBLE.h>
#include <TinyGPS++.h>
#include <Adafruit_NeoPixel.h>

TinyGPSPlus gps;
static const uint32_t GPSBaud = 115200; 

// LED configures
#define LED_PIN    6
#define NUMPIXELS  12  // LED pixel number
Adafruit_NeoPixel pixels(NUMPIXELS, LED_PIN, NEO_GRB + NEO_KHZ800);

// Bluetooth "Service" and "Characteristic" UUID
// Service ID: bluetooth function id for connection
// Characteristic ID: detailed function id for functions like location update
// Make sure phone and device share same UUID
const char* BLE_SERVICE_UUID = "19B10000-E8F2-537E-4F6C-D104768A1214"; //!!!!!!!!!!!!!!!!!!!! change TBD
const char* BLE_LOCATION_CHAR_UUID = "19B10001-E8F2-537E-4F6C-D104768A1214"; //!!!!!!!!!!!!!!!!!!!! change TBD (upload location)
const char* BLE_GOAL_CHAR_UUID = "19B10002-E8F2-537E-4F6C-D104768A1214"; // //!!!!!!!!!!!!!!!!!!!! change TBD (goal data from app)

BLEService bikeService(BLE_SERVICE_UUID);
BLEStringCharacteristic locationChar(BLE_LOCATION_CHAR_UUID, BLERead | BLENotify, 50);
BLEFloatCharacteristic goalChar(BLE_GOAL_CHAR_UUID, BLERead | BLEWrite); 

// default datas
double totalDistance = 0.0;
double targetDistance = 10.0; // default goal
double lastLat = 0.0;
double lastLon = 0.0;

void setup() {
  Serial.begin(115200);
  while (!Serial) { delay(10); }

  Serial1.begin(GPSBaud);
  
  // LED stuff
  pixels.begin();
  pixels.clear();
  pixels.show(); // off

  // bluetooth
  if (!BLE.begin()) {
    Serial.println("BLUETOOTH FAILURE!!!!!!!！");
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
  Serial.println("Device Activated !!!!!!!!!, Wating for Bluetooth and GPS update...");
}

void loop() {
  BLEDevice central = BLE.central();

  // Update cycling goal via bluetooth
  if (central && central.connected()) {
    if (goalChar.written()) {
      targetDistance = goalChar.value();
      Serial.print("New Cycling Goal: ");
      Serial.println(targetDistance);
      updateLEDProgress(); // update led
    }
  }

  // Handling GPS
  while (Serial1.available() > 0) {
    if (gps.encode(Serial1.read())) {
      if (gps.location.isValid() && gps.location.isUpdated()) {
        
        double currentLat = gps.location.lat();
        double currentLon = gps.location.lng();

        // first positioning
        if (lastLat == 0.0 && lastLon == 0.0) {
          lastLat = currentLat;
          lastLon = currentLon;
        } else {
          // distance calculation
          double stepDistance = TinyGPSPlus::distanceBetween(currentLat, currentLon, lastLat, lastLon);
          
          // 2m filter: filter out all movements <2m
          if (stepDistance > 2.0) { 
            totalDistance += stepDistance;
            lastLat = currentLat;
            lastLon = currentLon;
            
            // update led
            updateLEDProgress();
          }
        }
      }
    }
  }

  // Update current status to app (2s per)
  static unsigned long lastUpdate = 0;
  if (millis() - lastUpdate > 2000) {
    lastUpdate = millis();

    if (gps.location.isValid()) {
      float speed = gps.speed.kmph();
      // datapack: latitude, longtitude, speed, total distance
      String payload = String(gps.location.lat(), 6) + "," + 
                       String(gps.location.lng(), 6) + "," + 
                       String(speed, 1) + "," + 
                       String(totalDistance, 1);
                       
      if (central && central.connected()) {
        locationChar.writeValue(payload);
      }
      Serial.println("Send: " + payload + " | Progress: " + String(totalDistance) + "/" + String(targetDistance));
    }
  }
}

// Light Control
void updateLEDProgress() {
  // calculate percentage
  float progress = totalDistance / targetDistance;
  if (progress > 1.0) progress = 1.0; 

  // calculate led pixel numbers
  int ledsToLight = round(progress * NUMPIXELS);

  pixels.clear();
  for (int i = 0; i < NUMPIXELS; i++) {
    if (i < ledsToLight) {
      // color for finished parts
      pixels.setPixelColor(i, pixels.Color(0, 150, 0));
    } else {
      // color for unfinished parts
      pixels.setPixelColor(i, pixels.Color(0, 0, 0));
    }
  }
  pixels.show(); // update led
}