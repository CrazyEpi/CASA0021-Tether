#include <TinyGPS++.h>

TinyGPSPlus gps;

// baud rate: DO NOT SET TO 9600, it wont work
static const uint32_t GPSBaud = 115200; 

// true: program will print original data with no translate
const bool DEBUG_MODE = false; 

void setup() {
  Serial.begin(115200);
  while (!Serial) { delay(10); } // wait for serial connection

  Serial.println("\n=================================");
  Serial.println("GPS TEST !!!!!!!!");
  Serial.println("=================================");

  Serial1.begin(GPSBaud);
  Serial.print("Current Baud Rate: ");
  Serial.println(GPSBaud);
  Serial.println("Listening...\n");
}

void loop() {
  // Debug Mode
  if (DEBUG_MODE) {
    if (Serial1.available()) {
      Serial.write(Serial1.read());
    }
    return; // Skip loop
  }

  // Normal Mode
  while (Serial1.available() > 0) {
    gps.encode(Serial1.read());
  }

  // Print Status every 2 seconds
  static unsigned long lastPrintTime = 0;
  if (millis() - lastPrintTime > 2000) {
    lastPrintTime = millis();

    if (gps.location.isValid()) {
      Serial.print("GPS Connected");
      Serial.print("Satellite Number: ");
      Serial.print(gps.satellites.value());
      Serial.print(" Latitude: ");
      Serial.print(gps.location.lat(), 6);
      Serial.print(" Longitude: ");
      Serial.println(gps.location.lng(), 6);
    } else {
      // GPS Receive Status
      Serial.print("Received Characters: ");
      Serial.print(gps.charsProcessed());
      Serial.print(" | Check Failures: ");
      Serial.println(gps.failedChecksum());
      
      // data received, but all wrong
      if (gps.charsProcessed() > 0 && gps.failedChecksum() > 10) {
         Serial.println("  Waring: Received data but all wrong");
      }
    }
  }

  // Connection Check
  if (millis() > 5000 && gps.charsProcessed() < 10) {
    Serial.println("\n Warning: No data received");
    while(true); 
  }
}