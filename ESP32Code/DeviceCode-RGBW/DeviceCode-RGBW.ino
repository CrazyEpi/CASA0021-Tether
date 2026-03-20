#include <ArduinoBLE.h>
#include <Adafruit_NeoPixel.h>
#include <lvgl.h>
#include "Arduino_GFX_Library.h"
#include "pin_config.h" 
#include <Wire.h>
#include "XPowersLib.h"
#include "TouchDrvCSTXXX.hpp" 

// Pin Config
#define LED_PIN    16   
#define NUMPIXELS  24   // 24 LED Ring
#define BOOT_PIN   0

// RGBW LED Ring
Adafruit_NeoPixel pixels(NUMPIXELS, LED_PIN, NEO_GRBW + NEO_KHZ800);
XPowersPMU power;
TouchDrvCST92xx touch;

Arduino_DataBus *bus = new Arduino_ESP32QSPI(LCD_CS, LCD_SCLK, LCD_SDIO0, LCD_SDIO1, LCD_SDIO2, LCD_SDIO3);
Arduino_CO5300 *gfx = new Arduino_CO5300(bus, LCD_RESET, 0, LCD_WIDTH, LCD_HEIGHT, 6, 0, 0, 0);

static lv_disp_draw_buf_t draw_buf;
static lv_color_t buf[LCD_WIDTH * LCD_HEIGHT / 10];

// Bluetooth "Service" and "Characteristic" UUID
// Service ID: bluetooth function id for connection
// Characteristic ID: detailed function id for functions like location update
const char* BLE_SERVICE_UUID       = "19B10000-E8F2-537E-4F6C-D104768A1214";
const char* BLE_LOCATION_CHAR_UUID = "19B10001-E8F2-537E-4F6C-D104768A1214"; 
const char* BLE_GOAL_CHAR_UUID     = "19B10002-E8F2-537E-4F6C-D104768A1214"; 
const char* BLE_TIME_CHAR_UUID     = "19B10003-E8F2-537E-4F6C-D104768A1214"; 
const char* BLE_FRIEND_CHAR_UUID   = "19B10004-E8F2-537E-4F6C-D104768A1214"; 
const char* BLE_SOS_CHAR_UUID      = "19B10005-E8F2-537E-4F6C-D104768A1214";
const char* BLE_SOCIAL_CHAR_UUID   = "19B10006-E8F2-537E-4F6C-D104768A1214"; 

BLEService bikeService(BLE_SERVICE_UUID);
BLEStringCharacteristic locationChar(BLE_LOCATION_CHAR_UUID, BLERead | BLEWrite, 64); 
BLEFloatCharacteristic goalChar(BLE_GOAL_CHAR_UUID, BLERead | BLEWrite); 
BLEStringCharacteristic timeChar(BLE_TIME_CHAR_UUID, BLERead | BLEWrite, 10);
BLEIntCharacteristic friendChar(BLE_FRIEND_CHAR_UUID, BLERead | BLEWrite);
BLEByteCharacteristic sosChar(BLE_SOS_CHAR_UUID, BLERead | BLENotify);
BLEByteCharacteristic socialChar(BLE_SOCIAL_CHAR_UUID, BLERead | BLEWrite); 

// default datas
double totalDistanceKm = 0.0;
double targetDistanceKm = 10.0; 
float currentSpeed = 0.0;

double friendDistanceKm = 0.0; 
double friendGoalKm = 10.0;     
float friendProgress = 0.0;     

int onlineFriends = 0;
char currentTime[16] = "--:--"; 
bool isPhoneConnected = false;
unsigned long connectionTimestamp = 0;

bool isScreenOn = true;
bool isEmergency = false;
uint8_t currentScreenBrightness = 90;
int16_t touch_x[5], touch_y[5];

bool isSocialPulsing = false;
unsigned long socialPulseTimestamp = 0;

// LVGL UI Stuff
lv_obj_t *label_speed, *label_dist, *label_gps, *label_friends, *label_battery, *sos_container;

// Screen Renderer
void my_disp_flush(lv_disp_drv_t *disp, const lv_area_t *area, lv_color_t *color_p) {
  uint32_t w = (area->x2 - area->x1 + 1); uint32_t h = (area->y2 - area->y1 + 1);
#if (LV_COLOR_16_SWAP != 0)
  gfx->draw16bitBeRGBBitmap(area->x1, area->y1, (uint16_t *)&color_p->full, w, h);
#else
  gfx->draw16bitRGBBitmap(area->x1, area->y1, (uint16_t *)&color_p->full, w, h);
#endif
  lv_disp_flush_ready(disp);
}

// Touchpad read
void my_touchpad_read(lv_indev_drv_t *indev_driver, lv_indev_data_t *data) {
  uint8_t touched = touch.getPoint(touch_x, touch_y, touch.getSupportTouchPoint());
  if (touched > 0) {
    data->state = LV_INDEV_STATE_PR;
    data->point.x = touch_x[0]; data->point.y = touch_y[0];
  } else {
    data->state = LV_INDEV_STATE_REL;
  }
}

// timer for LVGL refresh
void example_increase_lvgl_tick(void *arg) { lv_tick_inc(2); }

// SOS long press cancel
void sos_clear_event_cb(lv_event_t * e) {
  if (isEmergency) {
    isEmergency = false;
    lv_obj_add_flag(sos_container, LV_OBJ_FLAG_HIDDEN);
    sosChar.writeValue((uint8_t)0);
  }
}

// Initialize UI components
void init_bike_dashboard() {
  lv_obj_set_style_bg_color(lv_scr_act(), lv_color_hex(0x000000), LV_PART_MAIN);

  // speed
  label_speed = lv_label_create(lv_scr_act());
  lv_obj_set_width(label_speed, 300); 
  lv_obj_set_style_text_color(label_speed, lv_color_hex(0xFFFFFF), LV_PART_MAIN);
  lv_obj_set_style_text_font(label_speed, &lv_font_montserrat_48, LV_PART_MAIN); 
  lv_label_set_text(label_speed, "0.0\nkm/h");
  lv_obj_set_style_text_align(label_speed, LV_TEXT_ALIGN_CENTER, LV_PART_MAIN);
  lv_obj_align(label_speed, LV_ALIGN_CENTER, 0, -35); 

  // distance multi-color
  label_dist = lv_label_create(lv_scr_act());
  lv_obj_set_width(label_dist, 300); 
  lv_label_set_recolor(label_dist, true); 
  lv_obj_set_style_text_font(label_dist, &lv_font_montserrat_24, LV_PART_MAIN); 
  lv_label_set_text(label_dist, "#4A90E2 0.0 / 0.0 km#"); 
  lv_obj_set_style_text_align(label_dist, LV_TEXT_ALIGN_CENTER, LV_PART_MAIN);
  lv_obj_align(label_dist, LV_ALIGN_CENTER, 0, 45); 

  // Time + App Status
  label_gps = lv_label_create(lv_scr_act());
  lv_obj_set_width(label_gps, 300); 
  lv_obj_set_style_text_color(label_gps, lv_color_hex(0xAAAAAA), LV_PART_MAIN);
  lv_obj_set_style_text_font(label_gps, &lv_font_montserrat_24, LV_PART_MAIN);
  lv_label_set_text(label_gps, "--:-- | Waiting...");
  lv_obj_set_style_text_align(label_gps, LV_TEXT_ALIGN_CENTER, LV_PART_MAIN);
  lv_obj_align(label_gps, LV_ALIGN_TOP_MID, 0, 30); 

  // Friend Status
  label_friends = lv_label_create(lv_scr_act());
  lv_obj_set_width(label_friends, 300); 
  lv_obj_set_style_text_color(label_friends, lv_color_hex(0x00FFFF), LV_PART_MAIN);
  lv_obj_set_style_text_font(label_friends, &lv_font_montserrat_24, LV_PART_MAIN);
  lv_label_set_text(label_friends, ""); 
  lv_obj_set_style_text_align(label_friends, LV_TEXT_ALIGN_CENTER, LV_PART_MAIN);
  lv_obj_align(label_friends, LV_ALIGN_BOTTOM_MID, 0, -80);
  
  // Battery Info
  label_battery = lv_label_create(lv_scr_act());
  lv_obj_set_width(label_battery, 200); 
  lv_obj_set_style_text_color(label_battery, lv_color_hex(0x00FF00), LV_PART_MAIN);
  lv_obj_set_style_text_font(label_battery, &lv_font_montserrat_24, LV_PART_MAIN);
  lv_label_set_text(label_battery, LV_SYMBOL_BATTERY_FULL " --%");
  lv_obj_set_style_text_align(label_battery, LV_TEXT_ALIGN_CENTER, LV_PART_MAIN);
  lv_obj_align(label_battery, LV_ALIGN_BOTTOM_MID, 0, -40);

  // SOS Red Screen
  sos_container = lv_obj_create(lv_scr_act());
  lv_obj_set_size(sos_container, LCD_WIDTH, LCD_HEIGHT);
  lv_obj_set_style_bg_color(sos_container, lv_color_hex(0xAA0000), 0);
  lv_obj_set_style_border_width(sos_container, 0, 0);
  lv_obj_align(sos_container, LV_ALIGN_CENTER, 0, 0);
  lv_obj_add_flag(sos_container, LV_OBJ_FLAG_CLICKABLE);
  lv_obj_add_flag(sos_container, LV_OBJ_FLAG_HIDDEN);
  lv_obj_add_event_cb(sos_container, sos_clear_event_cb, LV_EVENT_LONG_PRESSED, NULL);

  lv_obj_t *sos_label = lv_label_create(sos_container);
  lv_obj_set_style_text_color(sos_label, lv_color_hex(0xFFFFFF), 0);
  lv_obj_set_style_text_font(sos_label, &lv_font_montserrat_48, 0);
  lv_label_set_text(sos_label, LV_SYMBOL_WARNING "\nSOS");
  lv_obj_set_style_text_align(sos_label, LV_TEXT_ALIGN_CENTER, 0);
  lv_obj_align(sos_label, LV_ALIGN_CENTER, 0, 0);
}

void setup() {
  Serial.begin(115200);
  unsigned long startWait = millis();
  while (!Serial && millis() - startWait < 3000) { delay(10); }

  pinMode(BOOT_PIN, INPUT_PULLUP);

  Wire.begin(IIC_SDA, IIC_SCL);
  if(power.begin(Wire, AXP2101_SLAVE_ADDRESS, IIC_SDA, IIC_SCL)) {
    // Initialize Battery Control
    power.clearIrqStatus(); 
    power.enableBattVoltageMeasure();
    power.enableVbusVoltageMeasure(); 
    power.enableIRQ(XPOWERS_AXP2101_PKEY_SHORT_IRQ); 
  }

  touch.setPins(TP_RESET, TP_INT);
  touch.begin(Wire, 0x5A, IIC_SDA, IIC_SCL);
  touch.setMaxCoordinates(LCD_WIDTH, LCD_HEIGHT);
  touch.setMirrorXY(true, true);

  // Display Setups
  gfx->begin();
  gfx->setBrightness(currentScreenBrightness);
  lv_init();
  lv_disp_draw_buf_init(&draw_buf, buf, NULL, LCD_WIDTH * LCD_HEIGHT / 10);
  
  static lv_disp_drv_t disp_drv;
  lv_disp_drv_init(&disp_drv);
  disp_drv.hor_res = LCD_WIDTH; disp_drv.ver_res = LCD_HEIGHT;
  disp_drv.flush_cb = my_disp_flush; disp_drv.draw_buf = &draw_buf;
  lv_disp_drv_register(&disp_drv);

  static lv_indev_drv_t indev_drv;
  lv_indev_drv_init(&indev_drv);
  indev_drv.type = LV_INDEV_TYPE_POINTER;
  indev_drv.read_cb = my_touchpad_read;
  lv_indev_drv_register(&indev_drv);

  // Start the timer
  const esp_timer_create_args_t lvgl_tick_timer_args = { .callback = &example_increase_lvgl_tick, .name = "lvgl_tick" };
  esp_timer_handle_t lvgl_tick_timer = NULL;
  esp_timer_create(&lvgl_tick_timer_args, &lvgl_tick_timer);
  esp_timer_start_periodic(lvgl_tick_timer, 2000); // 2ms tick

  init_bike_dashboard();
  
  // NeoPixel Settings
  pixels.begin(); pixels.setBrightness(25); pixels.clear(); pixels.show();
  
  // Delay for battery then start bluetooth
  delay(300); 

  if (!BLE.begin()) { while (1); }
  BLE.setLocalName("BikeTracker_E"); 
  BLE.setAdvertisedService(bikeService);
  bikeService.addCharacteristic(locationChar);
  bikeService.addCharacteristic(goalChar);
  bikeService.addCharacteristic(timeChar);
  bikeService.addCharacteristic(friendChar);
  bikeService.addCharacteristic(sosChar); 
  bikeService.addCharacteristic(socialChar);
  BLE.addService(bikeService);
  
  sosChar.writeValue((uint8_t)0); 
  BLE.advertise();
}

void loop() {
  BLEDevice central = BLE.central();
  
  // power button screen off
  power.getIrqStatus();
  if (power.isPekeyShortPressIrq()) {
    isScreenOn = !isScreenOn;
    gfx->setBrightness(isScreenOn ? currentScreenBrightness : 0);
    power.clearIrqStatus();
  }

  // Boot long press SOS
  static unsigned long bootPressTime = 0;
  static bool bootPressed = false;
  
  if (digitalRead(BOOT_PIN) == LOW) {
    if (!bootPressed) {
      bootPressed = true;
      bootPressTime = millis();
    } else {
      if (millis() - bootPressTime > 3000 && !isEmergency) {
        isEmergency = true;
        lv_obj_clear_flag(sos_container, LV_OBJ_FLAG_HIDDEN);
        sosChar.writeValue((uint8_t)1); 
        if (!isScreenOn) { isScreenOn = true; gfx->setBrightness(currentScreenBrightness); }
      }
    }
  } else {
    if (bootPressed) {
      unsigned long pressDuration = millis() - bootPressTime;
      if (isEmergency && pressDuration < 1000) {
        isEmergency = false;
        lv_obj_add_flag(sos_container, LV_OBJ_FLAG_HIDDEN);
        sosChar.writeValue((uint8_t)0);
      }
      bootPressed = false;
    }
  }

  // handle data from app
  if (central && central.connected()) {
    if (!isPhoneConnected) {
      isPhoneConnected = true;
      connectionTimestamp = millis();
    }

    // Sync Distance
    if (goalChar.written()) targetDistanceKm = goalChar.value();
    
    // Sync Time
    if (timeChar.written()) {
      String tStr = timeChar.value(); tStr.trim(); 
      strncpy(currentTime, tStr.c_str(), sizeof(currentTime) - 1);
      currentTime[sizeof(currentTime) - 1] = '\0'; 
    }
    
    // Sync friend number
    if (friendChar.written()) {
      onlineFriends = friendChar.value();
      if (onlineFriends > 0) {
        static char friends_buf[32]; 
        snprintf(friends_buf, sizeof(friends_buf), "👥 %d Online", onlineFriends);
        lv_label_set_text(label_friends, friends_buf);
      } else {
        lv_label_set_text(label_friends, ""); 
      }
    }

    // Parse riding data
    if (locationChar.written()) {
      String locStr = locationChar.value();
      locStr.trim(); 
      
      int c1 = locStr.indexOf(',');
      int c2 = locStr.indexOf(',', c1 + 1);
      int c3 = locStr.indexOf(',', c2 + 1);
      
      if (c1 > 0) {
        currentSpeed = locStr.substring(0, c1).toFloat();
        if (c2 > 0) {
           if (c3 > 0) {
               totalDistanceKm = locStr.substring(c1 + 1, c2).toFloat();
               friendDistanceKm = locStr.substring(c2 + 1, c3).toFloat();
               friendGoalKm = locStr.substring(c3 + 1).toFloat();
               if(friendGoalKm <= 0.1) friendGoalKm = 10.0; 
               friendProgress = friendDistanceKm / friendGoalKm;
           } else {
               totalDistanceKm = locStr.substring(c1 + 1, c2).toFloat();
               friendProgress = locStr.substring(c2 + 1).toFloat();
           }
        } else {
           totalDistanceKm = locStr.substring(c1 + 1).toFloat();
        }
      }
    }

    // Sync social pulse
    if (socialChar.written()) {
      if (socialChar.value() == 0x01) {
        isSocialPulsing = true;
        socialPulseTimestamp = millis();
      }
    }

  } else {
    isPhoneConnected = false;
    currentSpeed = 0.0;
  }

  // UI refresh 10hz
  static unsigned long lastUIUpdate = 0;
  if (millis() - lastUIUpdate > 100) {
    lastUIUpdate = millis();

    static char bat_buf[32];
    static char gps_buf[32];
    static char speed_buf[16];
    static char dist_buf[128]; 

    // Auto brightness
    uint8_t targetBrightness = (currentSpeed >= 10.0) ? 200 : 40; 
    uint8_t ledBrightness = (currentSpeed >= 10.0) ? 50 : 20; 

    if (isScreenOn && currentScreenBrightness != targetBrightness) {
      currentScreenBrightness = targetBrightness;
      gfx->setBrightness(currentScreenBrightness);
    }
    pixels.setBrightness(ledBrightness);

    // Update Battery Percentage
    const char* pwr_icon = LV_SYMBOL_BATTERY_FULL; 
    if (power.isVbusIn()) {
      pwr_icon = power.isCharging() ? LV_SYMBOL_CHARGE : LV_SYMBOL_USB; 
    }

    if (power.isBatteryConnect()) {
      snprintf(bat_buf, sizeof(bat_buf), "%s %d%%", pwr_icon, power.getBatteryPercent());
    } else {
      snprintf(bat_buf, sizeof(bat_buf), "%s NO BAT", pwr_icon);
    }
    lv_label_set_text(label_battery, bat_buf);

    if (isPhoneConnected) {
      snprintf(gps_buf, sizeof(gps_buf), "%s | App Connected", currentTime);
      lv_label_set_text(label_gps, gps_buf);
      
      snprintf(speed_buf, sizeof(speed_buf), "%.1f\nkm/h", currentSpeed);
      lv_label_set_text(label_speed, speed_buf);

      if (onlineFriends == 0) {
        snprintf(dist_buf, sizeof(dist_buf), "#4A90E2 %.1f / %.1f km#", totalDistanceKm, targetDistanceKm);
      } else {
        snprintf(dist_buf, sizeof(dist_buf), "#4A90E2 %.1f / %.1f km#\n#D142F5 %.1f / %.1f km#", 
                 totalDistanceKm, targetDistanceKm, friendDistanceKm, friendGoalKm);
      }
      lv_label_set_text(label_dist, dist_buf);

    } else {
      snprintf(gps_buf, sizeof(gps_buf), "%s | Waiting App...", currentTime);
      lv_label_set_text(label_gps, gps_buf);
      lv_label_set_text(label_speed, "0.0\nkm/h");
      lv_label_set_text(label_dist, "#4A90E2 0.0 / 0.0 km#");
    }
    
    // Light Control Router
    if (isEmergency) {
       if ((millis() / 300) % 2 == 0) pixels.fill(pixels.Color(200, 0, 0, 0));
       else pixels.clear();
       pixels.show();
    } 
    else if (isSocialPulsing) {
       if (millis() - socialPulseTimestamp < 2000) updateLED_Social_Pulse();
       else isSocialPulsing = false; 
    }
    else if (isPhoneConnected) {
       if (millis() - connectionTimestamp < 3000) {
         pixels.fill(pixels.Color(0, 150, 0, 0)); pixels.show();
       } else {
         updateLED_SmartProgress(); 
       }
    } 
    else {
       updateLED_Searching_Yellow();
    }
  }

  lv_timer_handler(); 
  delay(5);
}

// Light Control
void updateLED_SmartProgress() {
  float myProg = totalDistanceKm / targetDistanceKm;
  if (myProg > 1.0) myProg = 1.0;
  if (myProg < 0.0) myProg = 0.0;

  pixels.clear();

  if (onlineFriends == 0) {
    int ledsToLight = round(myProg * NUMPIXELS);
    for (int i = 0; i < NUMPIXELS; i++) {
      if (i < ledsToLight) pixels.setPixelColor(i, pixels.Color(0, 0, 150, 0));
    }
  } else {
    float frProg = friendProgress;
    if (frProg > 1.0) frProg = 1.0;
    if (frProg < 0.0) frProg = 0.0;

    int halfLeds = NUMPIXELS / 2; // 12
    int myLedsToLight = round(myProg * halfLeds);
    int frLedsToLight = round(frProg * halfLeds);

    for (int i = 0; i < halfLeds; i++) {
      if (i < myLedsToLight) pixels.setPixelColor(i, pixels.Color(0, 0, 150, 0));
    }
    for (int i = 0; i < halfLeds; i++) {
      if (i < frLedsToLight) pixels.setPixelColor(i + halfLeds, pixels.Color(150, 0, 150, 0));
    }
  }
  
  pixels.show(); 
}

void updateLED_Searching_Yellow() {
  pixels.fill(pixels.Color(100, 100, 0, 0)); pixels.show();
}

void updateLED_Social_Pulse() {
  unsigned long t = millis() - socialPulseTimestamp;
  float breath = (sin(t / 150.0) + 1.0) / 2.0; 
  uint8_t brightness = 20 + (breath * 80);
  int offset = (t / 50) % NUMPIXELS;

  pixels.clear();
  for (int i = 0; i < NUMPIXELS; i++) {
    if (i == offset || i == (offset + NUMPIXELS/2) % NUMPIXELS) {
      pixels.setPixelColor(i, pixels.Color(0, 0, 0, 0));
    } else {
      pixels.setPixelColor(i, pixels.Color(0, brightness, brightness, 0));
    }
  }
  pixels.show();
}