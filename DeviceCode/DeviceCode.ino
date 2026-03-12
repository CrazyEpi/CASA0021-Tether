#include <ArduinoBLE.h>
#include <TinyGPS++.h>
#include <Adafruit_NeoPixel.h>
#include <lvgl.h>
#include "Arduino_GFX_Library.h"
#include "pin_config.h" 
#include <Wire.h>
#include "XPowersLib.h"

// LED configures
#define LED_PIN    16   
#define NUMPIXELS  24   // 24 LED Ring
#define GPS_RXD    44   
#define GPS_TXD    43   

Adafruit_NeoPixel pixels(NUMPIXELS, LED_PIN, NEO_GRB + NEO_KHZ800);
TinyGPSPlus gps;
XPowersPMU power;

Arduino_DataBus *bus = new Arduino_ESP32QSPI(LCD_CS, LCD_SCLK, LCD_SDIO0, LCD_SDIO1, LCD_SDIO2, LCD_SDIO3);
Arduino_CO5300 *gfx = new Arduino_CO5300(bus, LCD_RESET, 0, LCD_WIDTH, LCD_HEIGHT, 6, 0, 0, 0);

static lv_disp_draw_buf_t draw_buf;
static lv_color_t buf[LCD_WIDTH * LCD_HEIGHT / 10];

// Bluetooth "Service" and "Characteristic" UUID
// Service ID: bluetooth function id for connection
// Characteristic ID: detailed function id for functions like location update
// Make sure phone and device share same UUID
const char* BLE_SERVICE_UUID = "19B10000-E8F2-537E-4F6C-D104768A1214";
const char* BLE_LOCATION_CHAR_UUID = "19B10001-E8F2-537E-4F6C-D104768A1214"; 
const char* BLE_GOAL_CHAR_UUID     = "19B10002-E8F2-537E-4F6C-D104768A1214"; 
const char* BLE_TIME_CHAR_UUID     = "19B10003-E8F2-537E-4F6C-D104768A1214"; 
const char* BLE_FRIEND_CHAR_UUID   = "19B10004-E8F2-537E-4F6C-D104768A1214"; 

BLEService bikeService(BLE_SERVICE_UUID);
BLEStringCharacteristic locationChar(BLE_LOCATION_CHAR_UUID, BLERead | BLENotify, 50);
BLEFloatCharacteristic goalChar(BLE_GOAL_CHAR_UUID, BLERead | BLEWrite); 
BLEStringCharacteristic timeChar(BLE_TIME_CHAR_UUID, BLERead | BLEWrite, 10);
BLEIntCharacteristic friendChar(BLE_FRIEND_CHAR_UUID, BLERead | BLEWrite);

// default datas
double totalDistance = 0.0;
double targetDistance = 5000.0;
double lastLat = 0.0, lastLon = 0.0;
int onlineFriends = 0;
char currentTime[16] = "--:--"; 
bool hasGPSFixed = false;
unsigned long gpsFixedTimestamp = 0;

//LVGL UI Stuff
lv_obj_t *label_speed;    
lv_obj_t *label_gps;      
lv_obj_t *label_friends;  
lv_obj_t *label_battery;  

// Screen Renderer
void my_disp_flush(lv_disp_drv_t *disp, const lv_area_t *area, lv_color_t *color_p) {
  uint32_t w = (area->x2 - area->x1 + 1);
  uint32_t h = (area->y2 - area->y1 + 1);
#if (LV_COLOR_16_SWAP != 0)
  gfx->draw16bitBeRGBBitmap(area->x1, area->y1, (uint16_t *)&color_p->full, w, h);
#else
  gfx->draw16bitRGBBitmap(area->x1, area->y1, (uint16_t *)&color_p->full, w, h);
#endif
  lv_disp_flush_ready(disp);
}

//timer for LVGL refresh
void example_increase_lvgl_tick(void *arg) {
  lv_tick_inc(2); 
}

//Initialize UI components
void init_bike_dashboard() {
  lv_obj_set_style_bg_color(lv_scr_act(), lv_color_hex(0x000000), LV_PART_MAIN);

  //speed
  label_speed = lv_label_create(lv_scr_act());
  lv_obj_set_style_text_color(label_speed, lv_color_hex(0xFFFFFF), LV_PART_MAIN);
  lv_obj_set_style_text_font(label_speed, &lv_font_montserrat_48, LV_PART_MAIN); 
  lv_label_set_text(label_speed, "0.0\nkm/h");
  lv_obj_set_style_text_align(label_speed, LV_TEXT_ALIGN_CENTER, LV_PART_MAIN);
  lv_obj_align(label_speed, LV_ALIGN_CENTER, 0, -10);

  //Time + GPS Status
  label_gps = lv_label_create(lv_scr_act());
  lv_obj_set_style_text_color(label_gps, lv_color_hex(0xAAAAAA), LV_PART_MAIN);
  lv_obj_set_style_text_font(label_gps, &lv_font_montserrat_24, LV_PART_MAIN);
  lv_label_set_text(label_gps, "--:-- | Searching...");
  lv_obj_align(label_gps, LV_ALIGN_TOP_MID, 0, 40); 

  //Friend Status
  label_friends = lv_label_create(lv_scr_act());
  lv_obj_set_style_text_color(label_friends, lv_color_hex(0x00FFFF), LV_PART_MAIN);
  lv_obj_set_style_text_font(label_friends, &lv_font_montserrat_24, LV_PART_MAIN);
  lv_label_set_text(label_friends, ""); 
  lv_obj_align(label_friends, LV_ALIGN_BOTTOM_MID, 0, -80);

  //Battery Info
  label_battery = lv_label_create(lv_scr_act());
  lv_obj_set_style_text_color(label_battery, lv_color_hex(0x00FF00), LV_PART_MAIN);
  lv_obj_set_style_text_font(label_battery, &lv_font_montserrat_24, LV_PART_MAIN);
  lv_label_set_text(label_battery, "BAT: --%");
  lv_obj_align(label_battery, LV_ALIGN_BOTTOM_MID, 0, -40);
}

void setup() {
  Serial.begin(115200);
  unsigned long startWait = millis();
  while (!Serial && millis() - startWait < 3000) { delay(10); }

  Serial.println("\n Device Activated !!!!!!!!!!!!!");

  Serial1.begin(115200, SERIAL_8N1, GPS_RXD, GPS_TXD);

  Wire.begin(IIC_SDA, IIC_SCL);
  if(power.begin(Wire, AXP2101_SLAVE_ADDRESS, IIC_SDA, IIC_SCL)) {
    //Initialize Battery Control
    power.clearIrqStatus(); 
    power.enableBattVoltageMeasure();
  }

  // Display Setups
  gfx->begin();
  gfx->setBrightness(90);
  lv_init();

  //Initialize LVGL Library
  lv_disp_draw_buf_init(&draw_buf, buf, NULL, LCD_WIDTH * LCD_HEIGHT / 10);
  static lv_disp_drv_t disp_drv;
  lv_disp_drv_init(&disp_drv);
  disp_drv.hor_res = LCD_WIDTH; disp_drv.ver_res = LCD_HEIGHT;
  disp_drv.flush_cb = my_disp_flush; disp_drv.draw_buf = &draw_buf;
  lv_disp_drv_register(&disp_drv);

  //Start the timer
  const esp_timer_create_args_t lvgl_tick_timer_args = { .callback = &example_increase_lvgl_tick, .name = "lvgl_tick" };
  esp_timer_handle_t lvgl_tick_timer = NULL;
  esp_timer_create(&lvgl_tick_timer_args, &lvgl_tick_timer);
  esp_timer_start_periodic(lvgl_tick_timer, 2000); //2ms tick

  init_bike_dashboard();

  //NeoPixel Settings
  pixels.begin();
  pixels.setBrightness(50); //Brightness
  pixels.clear(); 
  pixels.show();

  //Delay for battery then start bluetooth
  delay(300); 

  if (!BLE.begin()) { Serial.println("BLE Failed!"); while (1); }
  BLE.setLocalName("BikeTracker_E"); 
  BLE.setAdvertisedService(bikeService);
  bikeService.addCharacteristic(locationChar);
  bikeService.addCharacteristic(goalChar);
  bikeService.addCharacteristic(timeChar);
  bikeService.addCharacteristic(friendChar);
  BLE.addService(bikeService);
  
  BLE.advertise();
  Serial.println("System Ready. Advertising BLE...");
}

void loop() {
  BLEDevice central = BLE.central();
  
  // handle data from app
  if (central && central.connected()) {
    //Sync Distance
    if (goalChar.written()) targetDistance = goalChar.value();
    
    //Sync Time
    if (timeChar.written()) {
      String tStr = timeChar.value();
      strncpy(currentTime, tStr.c_str(), sizeof(currentTime) - 1);
      currentTime[sizeof(currentTime) - 1] = '\0'; 
    }
    
    //Sync friend number
    if (friendChar.written()) {
      onlineFriends = friendChar.value();
      if (onlineFriends > 0) {
        lv_label_set_text_fmt(label_friends, "👥 %d Online", onlineFriends);
      } else {
        lv_label_set_text(label_friends, ""); 
      }
    }
  }

  //Update gps and calculate distance
  while (Serial1.available() > 0) {
    if (gps.encode(Serial1.read())) {
      if (gps.location.isValid() && gps.location.isUpdated()) {
        double currentLat = gps.location.lat();
        double currentLon = gps.location.lng();
        if (lastLat == 0.0 && lastLon == 0.0) {
          lastLat = currentLat; lastLon = currentLon;
        } else {
          double stepDistance = TinyGPSPlus::distanceBetween(currentLat, currentLon, lastLat, lastLon);
          if (stepDistance > 2.0) { 
            totalDistance += stepDistance;
            lastLat = currentLat; lastLon = currentLon;
          }
        }
      }
    }
  }


  //UI refresh 10hz
  static unsigned long lastUIUpdate = 0;
  if (millis() - lastUIUpdate > 100) {
    lastUIUpdate = millis();

    //Update Battery Percentage
    if (power.isBatteryConnect()) {
      lv_label_set_text_fmt(label_battery, "BAT: %d%%", power.getBatteryPercent());
    }

    //Update GPS, Speed, LED
    if (gps.location.isValid()) {
      if (!hasGPSFixed) {
        hasGPSFixed = true;
        gpsFixedTimestamp = millis(); //record timestamp for first recorded location
      }

      lv_label_set_text_fmt(label_gps, "%s | 3D Fix", currentTime);
      lv_label_set_text_fmt(label_speed, "%.1f\nkm/h", gps.speed.kmph());

      //all good all green for 3s
      if (millis() - gpsFixedTimestamp < 3000) {
        pixels.fill(pixels.Color(0, 150, 0)); 
        pixels.show();
      } else {
        updateLEDProgress_Blue(); //blue ring for distance
      }
    } else {
      //searching for gps satellites
      hasGPSFixed = false;
      lv_label_set_text_fmt(label_gps, "%s | Searching...", currentTime);
      lv_label_set_text(label_speed, "0.0\nkm/h");
      updateLED_Searching_Yellow();
    }
    
    //Serial Output
    Serial.printf("[Update] GPS: %s | Goal: %.1fm | Progress: %.1fm\n", 
                  hasGPSFixed ? "Locating Success" : "Searching", targetDistance, totalDistance);
  }

  // 2s update to mobile app
  static unsigned long lastBLEPush = 0;
  if (millis() - lastBLEPush > 2000) {
    lastBLEPush = millis();
    if (gps.location.isValid() && central && central.connected()) {
      char payload[64];
      snprintf(payload, sizeof(payload), "%.6f,%.6f,%.1f,%.1f", 
               gps.location.lat(), gps.location.lng(), gps.speed.kmph(), totalDistance);
      locationChar.writeValue(payload);
    }
  }

  lv_timer_handler(); 
  delay(5);
}

// Light Control
void updateLEDProgress_Blue() {
  float progress = totalDistance / targetDistance;
  if (progress < 0) progress = 0;
  if (progress > 1.0) progress = 1.0; 

  int ledsToLight = round(progress * NUMPIXELS);
  pixels.clear();
  for (int i = 0; i < NUMPIXELS; i++) {
    if (i < ledsToLight) {
      pixels.setPixelColor(i, pixels.Color(0, 0, 150)); // Blue color
    } else {
      pixels.setPixelColor(i, pixels.Color(0, 0, 0));
    }
  }
  pixels.show(); 
}

void updateLED_Searching_Yellow() {
  // Searching = Yellow Light
  pixels.fill(pixels.Color(100, 100, 0)); 
  pixels.show();
}