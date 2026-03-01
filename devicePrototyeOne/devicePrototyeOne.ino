//prototype one: no lighting feature

#include <ArduinoBLE.h>
#include <TinyGPS++.h>

TinyGPSPlus gps;
static const uint32_t GPSBaud = 115200; 

// Bluetooth "Service" and "Characteristic" UUID
// Service ID: bluetooth function id for connection
// Characteristic ID: detailed function id for functions like location update
// Make sure phone and device share same UUID
const char* BLE_SERVICE_UUID = "TBD1"; //!!!!!!!!!!!!!!!!!!!! change TBD
const char* BLE_CHARACTERISTIC_UUID = "TBD2"; //!!!!!!!!!!!!!!!!!!!! change TBD

// Initiate Bluetooth
BLEService bikeService(BLE_SERVICE_UUID);
BLEStringCharacteristic locationChar(BLE_CHARACTERISTIC_UUID, BLERead | BLENotify, 50);

void setup() {
  Serial.begin(115200);
  while (!Serial) { delay(10); }

  Serial.println("Device Activated !!!!!!!!!");

  // gps activate
  Serial1.begin(GPSBaud);
  Serial.println("GPS Activated");

  // bluetooth activate
  if (!BLE.begin()) {
    Serial.println("Error: Bluetooth failure");
    while (1); 
  }

  // bluetooth boardcast
  BLE.setLocalName("Tether_A"); // Bluetooth name
  BLE.setAdvertisedService(bikeService);
  bikeService.addCharacteristic(locationChar);
  BLE.addService(bikeService);
  
  locationChar.writeValue("Waiting for GPS..."); 

  BLE.advertise();
  Serial.println("Bluetooth Activated");
}

void loop() {
  // handling gps data
  while (Serial1.available() > 0) {
    gps.encode(Serial1.read());
  }

  // bluetooth connection
  BLEDevice central = BLE.central();

  // connection cue?
  if (central && central.connected()) {
    // use led to show connection?
  }

  // send location data and speed
  static unsigned long lastUpdate = 0;
  if (millis() - lastUpdate > 2000) {
    lastUpdate = millis();

    if (gps.location.isValid()) {
      float lat = gps.location.lat();
      float lon = gps.location.lng();
      float speed = gps.speed.kmph();

      // // datapack: "51.5385,-0.0131,15.2"
      String payload = String(lat, 6) + "," + String(lon, 6) + "," + String(speed, 1);
      
      Serial.print("GPS good, current data: ");
      Serial.println(payload);

      // Send to app
      if (central && central.connected()) {
        locationChar.writeValue(payload);
        Serial.println("  -> Send to App");
      }
    } else {
      Serial.print("Searching Satellites, Current Satellite Number: "); // need to be >=4
      Serial.println(gps.satellites.value());
    }
  }
}