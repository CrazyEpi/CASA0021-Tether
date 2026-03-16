#include <Adafruit_NeoPixel.h>

// LED Settings
#define LED_PIN    6   // LED Pin: 6
#define NUMPIXELS  12  // LED numbers
Adafruit_NeoPixel pixels(NUMPIXELS, LED_PIN, NEO_GRB + NEO_KHZ800);

float targetDistance = 100.0;
float currentDistance = 0.0;

void setup() {
  // baud rate: DO NOT SET TO 9600, it wont work
  Serial.begin(115200);
  while (!Serial) { delay(10); }

  // initialize led
  pixels.begin();
  pixels.clear();
  pixels.show();

  Serial.println("\n=================================");
  Serial.println("LED TEST !!!!!!!!");
  Serial.println("=================================");
  Serial.println("Send command to mimic user scene");
  Serial.println("Input: T+Number = target distance (T100 = 100m)");
  Serial.println("Input D+Number = current distance (D80 = now went 80m)");
  Serial.println("=================================\n");
  
  updateLEDProgress();
}

void loop() {
  if (Serial.available() > 0) {
    String input = Serial.readStringUntil('\n');

    if (input.length() > 1) {
      // take command type
      char command = input.charAt(0);
      float value = input.substring(1).toFloat();

      if (command == 'T' || command == 't') {
        if (value <= 0) {
          Serial.println("distance must > 0");
        } else {
          targetDistance = value;
          Serial.print("target update : ");
          Serial.print(targetDistance);
          Serial.println(" m");
        }
      } 
      else if (command == 'D' || command == 'd') {
        currentDistance = value;
        Serial.print("current distance update: ");
        Serial.print(currentDistance);
        Serial.println(" m");
      } 
      else {
        Serial.println("Unknown command ");
      }

      // update led
      updateLEDProgress();
    }
  }
}

// light control
void updateLEDProgress() {
  // percentage
  float progress = currentDistance / targetDistance;
  
  // frame boundries
  if (progress < 0) progress = 0;
  if (progress > 1.0) progress = 1.0; 

  // lighted led numbers
  int ledsToLight = round(progress * NUMPIXELS);

  Serial.print("Current Progress: ");
  Serial.print(progress * 100, 1);
  Serial.print("%  |  Lighted LED Numbers: ");
  Serial.print(ledsToLight);
  Serial.print(" / ");
  Serial.println(NUMPIXELS);
  Serial.println("---------------------------------");

  // update LED
  pixels.clear();
  for (int i = 0; i < NUMPIXELS; i++) {
    if (i < ledsToLight) {
      // Gree: finished parts
      pixels.setPixelColor(i, pixels.Color(0, 100, 0));
    } else {
      // unfinished parts
      pixels.setPixelColor(i, pixels.Color(0, 0, 0)); 
    }
  }
  pixels.show();
}