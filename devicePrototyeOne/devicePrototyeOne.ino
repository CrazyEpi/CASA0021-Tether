#include <ArduinoBLE.h>
#include <TinyGPS++.h>
#include <Adafruit_NeoPixel.h>

// ===== GPS Setup =====
TinyGPSPlus gps;
static const uint32_t GPSBaud = 115200;

// ===== LED / NeoPixel Setup =====
#define LED_PIN    6
#define NUMPIXELS  8
Adafruit_NeoPixel pixels(NUMPIXELS, LED_PIN, NEO_GRB + NEO_KHZ800);

// ===== BLE Setup =====
const char* BLE_SERVICE_UUID = "19B10000-E8F2-537E-4F6C-D104768A1214";
BLEService bikeService(BLE_SERVICE_UUID);

// Sensor Characteristics
BLEFloatCharacteristic latChar("19B10001-E8F2-537E-4F6C-D104768A1214", BLERead | BLENotify);
BLEFloatCharacteristic lonChar("19B10002-E8F2-537E-4F6C-D104768A1214", BLERead | BLENotify);
BLEFloatCharacteristic speedChar("19B10003-E8F2-537E-4F6C-D104768A1214", BLERead | BLENotify);
BLEFloatCharacteristic distanceChar("19B10004-E8F2-537E-4F6C-D104768A1214", BLERead | BLENotify);
BLEFloatCharacteristic progressChar("19B10005-E8F2-537E-4F6C-D104768A1214", BLERead | BLENotify);
BLEFloatCharacteristic goalChar("19B10006-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite);

// ===== Variables =====
double totalDistance = 0.0;       // meters
double targetDistance = 10000.0;  // default 10,000 m = 10 km
double lastLat = 0.0;
double lastLon = 0.0;
float goalProgress = 0.0;

// ===== Last sent values (event-driven BLE) =====
float lastLatSent = 0.0;
float lastLonSent = 0.0;
float lastSpeedSent = 0.0;
float lastDistanceSent = 0.0;
float lastProgressSent = 0.0;
int lastLedCount = -1;

// ===== Periodic BLE timing =====
unsigned long lastBleUpdateTime = 0;
const unsigned long BLE_UPDATE_INTERVAL = 5000; // send BLE data every 5 seconds

// ===== Setup =====
void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);

  Serial1.begin(GPSBaud);

  // LED setup
  pixels.begin();
  pixels.clear();
  pixels.show();

  // BLE setup
  if (!BLE.begin()) {
    Serial.println("BLE FAILED");
    while (1);
  }

  BLE.setLocalName("BikeTracker_E");
  BLE.setAdvertisedService(bikeService);

  bikeService.addCharacteristic(latChar);
  bikeService.addCharacteristic(lonChar);
  bikeService.addCharacteristic(speedChar);
  bikeService.addCharacteristic(distanceChar);
  bikeService.addCharacteristic(progressChar);
  bikeService.addCharacteristic(goalChar);

  BLE.addService(bikeService);

  // Initial values
  latChar.writeValue(0.0f);
  lonChar.writeValue(0.0f);
  speedChar.writeValue(0.0f);
  distanceChar.writeValue(0.0f);
  progressChar.writeValue(0.0f);
  goalChar.writeValue((float)targetDistance); // send in meters

  BLE.advertise();
  Serial.println("Bike Tracker Ready");
}

// ===== Main Loop =====
void loop() {
  BLEDevice central = BLE.central();

  // ===== Goal update from app (meters now) =====
  if (central && central.connected() && goalChar.written()) {
    targetDistance = goalChar.value(); // already in meters

    Serial.print("New Goal: ");
    Serial.print(targetDistance);
    Serial.println(" m");

    goalProgress = totalDistance / targetDistance;
    if (goalProgress > 1.0) goalProgress = 1.0;

    updateLEDProgress();
  }

  // ===== GPS Handling =====
  while (Serial1.available()) {
    if (gps.encode(Serial1.read())) {
      if (gps.location.isValid() && gps.location.isUpdated()) {
        double currentLat = gps.location.lat();
        double currentLon = gps.location.lng();
        float speedKmph = gps.speed.kmph();

        // ===== Distance Calculation =====
        if (lastLat != 0.0 && lastLon != 0.0) {
          double stepDistance = TinyGPSPlus::distanceBetween(currentLat, currentLon, lastLat, lastLon);
          if (stepDistance > 2.0) { // ignore GPS jitter
            totalDistance += stepDistance;
          }
        }

        lastLat = currentLat;
        lastLon = currentLon;

        // ===== Progress =====
        goalProgress = totalDistance / targetDistance;
        if (goalProgress > 1.0) goalProgress = 1.0;

        updateLEDProgress();

        // ===== Convert to float for BLE =====
        float latF = (float)currentLat;
        float lonF = (float)currentLon;
        float distF = (float)totalDistance;
        float progF = (float)goalProgress;

        // ===== BLE Notifications (event-driven or periodic) =====
        unsigned long now = millis();
        if (central && central.connected() &&
           (abs(latF - lastLatSent) > 0.00001 ||
            abs(lonF - lastLonSent) > 0.00001 ||
            abs(speedKmph - lastSpeedSent) > 0.1 ||
            abs(distF - lastDistanceSent) > 0.1 ||
            abs(progF - lastProgressSent) > 0.01 ||
            now - lastBleUpdateTime > BLE_UPDATE_INTERVAL)) {

          latChar.writeValue(latF); lastLatSent = latF;
          lonChar.writeValue(lonF); lastLonSent = lonF;
          speedChar.writeValue(speedKmph); lastSpeedSent = speedKmph;
          distanceChar.writeValue(distF); lastDistanceSent = distF;
          progressChar.writeValue(progF); lastProgressSent = progF;

          lastBleUpdateTime = now;
        }

        // ===== Serial Debug =====
        Serial.print("Lat: "); Serial.print(currentLat, 6);
        Serial.print("  Lon: "); Serial.print(currentLon, 6);
        Serial.print("  Speed: "); Serial.print(speedKmph, 1);
        Serial.print(" km/h  Dist: "); Serial.print(totalDistance, 1);
        Serial.print(" m  Progress: "); Serial.println(goalProgress, 2);
      }
    }
  }
}

// ===== LED Progress =====
void updateLEDProgress() {
  int ledsToLight = round(goalProgress * NUMPIXELS);
  if (ledsToLight != lastLedCount) {
    pixels.clear();
    for (int i = 0; i < ledsToLight; i++) {
      pixels.setPixelColor(i, pixels.Color(0, 150, 0));
    }
    pixels.show();
    lastLedCount = ledsToLight;
  }
}