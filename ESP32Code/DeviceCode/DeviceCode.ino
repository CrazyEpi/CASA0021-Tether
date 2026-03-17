#include <ArduinoBLE.h>
#include <Adafruit_NeoPixel.h>
#include <lvgl.h>
#include "Arduino_GFX_Library.h"
#include "pin_config.h" 
#include <Wire.h>
#include "XPowersLib.h"
#include "TouchDrvCSTXXX.hpp" 

// --- Pin Configuration ---
#define LED_PIN    16   
#define NUMPIXELS  24   
#define BOOT_PIN   0

// --- Hardware Objects ---
Adafruit_NeoPixel pixels(NUMPIXELS, LED_PIN, NEO_GRB + NEO_KHZ800);
XPowersPMU power;
TouchDrvCST92xx touch;

// --- Display Setup ---
Arduino_DataBus *bus = new Arduino_ESP32QSPI(LCD_CS, LCD_SCLK, LCD_SDIO0, LCD_SDIO1, LCD_SDIO2, LCD_SDIO3);
Arduino_CO5300 *gfx = new Arduino_CO5300(bus, LCD_RESET, 0, LCD_WIDTH, LCD_HEIGHT, 6, 0, 0, 0);

static lv_disp_draw_buf_t draw_buf;
static lv_color_t buf[LCD_WIDTH * LCD_HEIGHT / 10];

// --- BLE UUIDs ---
const char* BLE_SERVICE_UUID       = "19B10000-E8F2-537E-4F6C-D104768A1214";
const char* BLE_LOCATION_CHAR_UUID = "19B10001-E8F2-537E-4F6C-D104768A1214"; 
const char* BLE_GOAL_CHAR_UUID     = "19B10002-E8F2-537E-4F6C-D104768A1214"; 
const char* BLE_TIME_CHAR_UUID     = "19B10003-E8F2-537E-4F6C-D104768A1214"; 
const char* BLE_FRIEND_CHAR_UUID   = "19B10004-E8F2-537E-4F6C-D104768A1214"; 
const char* BLE_SOS_CHAR_UUID      = "19B10005-E8F2-537E-4F6C-D104768A1214";

// --- BLE Characteristics ---
BLEService bikeService(BLE_SERVICE_UUID);
BLEStringCharacteristic locationChar(BLE_LOCATION_CHAR_UUID, BLERead | BLEWrite, 50);
BLEFloatCharacteristic goalChar(BLE_GOAL_CHAR_UUID, BLERead | BLEWrite); 
BLEStringCharacteristic timeChar(BLE_TIME_CHAR_UUID, BLERead | BLEWrite, 10);
BLEIntCharacteristic friendChar(BLE_FRIEND_CHAR_UUID, BLERead | BLEWrite);
BLEByteCharacteristic sosChar(BLE_SOS_CHAR_UUID, BLERead | BLENotify);

// --- Global Variables ---
double totalDistance = 0.0, targetDistance = 5000.0;
float currentSpeed = 0.0;
int onlineFriends = 0;
char currentTime[16] = "--:--"; 
bool isPhoneConnected = false;
unsigned long connectionTimestamp = 0;

// --- System States ---
bool isScreenOn = true;
bool isEmergency = false;
uint8_t currentScreenBrightness = 90;
int16_t touch_x[5], touch_y[5];

// --- LVGL UI Elements ---
lv_obj_t *label_speed;    
lv_obj_t *label_gps;      
lv_obj_t *label_friends;  
lv_obj_t *label_battery;  
lv_obj_t *sos_container;

// --- Display Flush Callback ---
// Renders LVGL graphics to the screen
void my_disp_flush(lv_disp_drv_t *disp, const lv_area_t *area, lv_color_t *color_p) {
  uint32_t w = (area->x2 - area->x1 + 1); uint32_t h = (area->y2 - area->y1 + 1);
#if (LV_COLOR_16_SWAP != 0)
  gfx->draw16bitBeRGBBitmap(area->x1, area->y1, (uint16_t *)&color_p->full, w, h);
#else
  gfx->draw16bitRGBBitmap(area->x1, area->y1, (uint16_t *)&color_p->full, w, h);
#endif
  lv_disp_flush_ready(disp);
}

// --- Touchpad Read Callback ---
// Gets touch coordinates and state
void my_touchpad_read(lv_indev_drv_t *indev_driver, lv_indev_data_t *data) {
  uint8_t touched = touch.getPoint(touch_x, touch_y, touch.getSupportTouchPoint());
  if (touched > 0) {
    data->state = LV_INDEV_STATE_PR; // Pressed
    data->point.x = touch_x[0];
    data->point.y = touch_y[0];
  } else {
    data->state = LV_INDEV_STATE_REL; // Released
  }
}

// Increases LVGL internal timer
void example_increase_lvgl_tick(void *arg) { lv_tick_inc(2); }

// --- SOS Event Callback ---
// Cancels SOS mode when the screen is long-pressed
void sos_clear_event_cb(lv_event_t * e) {
  if (isEmergency) {
    isEmergency = false;
    lv_obj_add_flag(sos_container, LV_OBJ_FLAG_HIDDEN); // Hide SOS screen
    sosChar.writeValue((uint8_t)0); // Update BLE
    Serial.println("Emergency Canceled!");
  }
}

// --- Initialize UI Components ---
void init_bike_dashboard() {
  lv_obj_set_style_bg_color(lv_scr_act(), lv_color_hex(0x000000), LV_PART_MAIN);

  // Anti-tearing tweak: Set fixed width for labels to lock refresh area
  label_speed = lv_label_create(lv_scr_act());
  lv_obj_set_width(label_speed, 300); 
  lv_obj_set_style_text_color(label_speed, lv_color_hex(0xFFFFFF), LV_PART_MAIN);
  lv_obj_set_style_text_font(label_speed, &lv_font_montserrat_48, LV_PART_MAIN); 
  lv_label_set_text(label_speed, "0.0\nkm/h");
  lv_obj_set_style_text_align(label_speed, LV_TEXT_ALIGN_CENTER, LV_PART_MAIN);
  lv_obj_align(label_speed, LV_ALIGN_CENTER, 0, -10);

  label_gps = lv_label_create(lv_scr_act());
  lv_obj_set_width(label_gps, 300); 
  lv_obj_set_style_text_color(label_gps, lv_color_hex(0xAAAAAA), LV_PART_MAIN);
  lv_obj_set_style_text_font(label_gps, &lv_font_montserrat_24, LV_PART_MAIN);
  lv_label_set_text(label_gps, "--:-- | Waiting App...");
  lv_obj_set_style_text_align(label_gps, LV_TEXT_ALIGN_CENTER, LV_PART_MAIN);
  lv_obj_align(label_gps, LV_ALIGN_TOP_MID, 0, 40); 

  label_friends = lv_label_create(lv_scr_act());
  lv_obj_set_width(label_friends, 300); 
  lv_obj_set_style_text_color(label_friends, lv_color_hex(0x00FFFF), LV_PART_MAIN);
  lv_obj_set_style_text_font(label_friends, &lv_font_montserrat_24, LV_PART_MAIN);
  lv_label_set_text(label_friends, ""); 
  lv_obj_set_style_text_align(label_friends, LV_TEXT_ALIGN_CENTER, LV_PART_MAIN);
  lv_obj_align(label_friends, LV_ALIGN_BOTTOM_MID, 0, -80);
  
  label_battery = lv_label_create(lv_scr_act());
  lv_obj_set_width(label_battery, 200); 
  lv_obj_set_style_text_color(label_battery, lv_color_hex(0x00FF00), LV_PART_MAIN);
  lv_obj_set_style_text_font(label_battery, &lv_font_montserrat_24, LV_PART_MAIN);
  lv_label_set_text(label_battery, LV_SYMBOL_BATTERY_FULL " --%");
  lv_obj_set_style_text_align(label_battery, LV_TEXT_ALIGN_CENTER, LV_PART_MAIN);
  lv_obj_align(label_battery, LV_ALIGN_BOTTOM_MID, 0, -40);

  // SOS Red Screen Container (Hidden by default)
  sos_container = lv_obj_create(lv_scr_act());
  lv_obj_set_size(sos_container, LCD_WIDTH, LCD_HEIGHT);
  lv_obj_set_style_bg_color(sos_container, lv_color_hex(0xAA0000), 0);
  lv_obj_set_style_border_width(sos_container, 0, 0);
  lv_obj_align(sos_container, LV_ALIGN_CENTER, 0, 0);
  lv_obj_add_flag(sos_container, LV_OBJ_FLAG_CLICKABLE);
  lv_obj_add_flag(sos_container, LV_OBJ_FLAG_HIDDEN);
  
  // Attach long-press event to cancel SOS
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

  Serial.println("\n--- Bike Tracker Started (Phone GPS Mode - Anti-Tear V6) ---");

  pinMode(BOOT_PIN, INPUT_PULLUP);

  // Init Power Management Unit (PMU)
  Wire.begin(IIC_SDA, IIC_SCL);
  if(power.begin(Wire, AXP2101_SLAVE_ADDRESS, IIC_SDA, IIC_SCL)) {
    power.clearIrqStatus(); 
    power.enableBattVoltageMeasure();
    power.enableVbusVoltageMeasure(); 
    power.enableIRQ(XPOWERS_AXP2101_PKEY_SHORT_IRQ); // Enable power button interrupt
  }

  // Init Touchpad
  touch.setPins(TP_RESET, TP_INT);
  if(!touch.begin(Wire, 0x5A, IIC_SDA, IIC_SCL)) {
     Serial.println("Warning: Touch not found!");
  } else {
     touch.setMaxCoordinates(LCD_WIDTH, LCD_HEIGHT);
     touch.setMirrorXY(true, true);
  }

  // Init Display & LVGL
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

  // Setup LVGL tick timer
  const esp_timer_create_args_t lvgl_tick_timer_args = { .callback = &example_increase_lvgl_tick, .name = "lvgl_tick" };
  esp_timer_handle_t lvgl_tick_timer = NULL;
  esp_timer_create(&lvgl_tick_timer_args, &lvgl_tick_timer);
  esp_timer_start_periodic(lvgl_tick_timer, 2000); 

  init_bike_dashboard();
  
  // Init LEDs
  pixels.begin();
  pixels.setBrightness(50); 
  pixels.clear(); 
  pixels.show();
  
  delay(300); 

  // Init BLE
  if (!BLE.begin()) { Serial.println("BLE Failed!"); while (1); }
  BLE.setLocalName("BikeTracker_E"); 
  BLE.setAdvertisedService(bikeService);
  bikeService.addCharacteristic(locationChar);
  bikeService.addCharacteristic(goalChar);
  bikeService.addCharacteristic(timeChar);
  bikeService.addCharacteristic(friendChar);
  bikeService.addCharacteristic(sosChar); 
  BLE.addService(bikeService);
  
  sosChar.writeValue((uint8_t)0); 
  BLE.advertise();
  Serial.println("System Ready. Waiting for App to connect...");
}

void loop() {
  BLEDevice central = BLE.central();
  
  // 1. Power Button: Toggle Screen On/Off
  power.getIrqStatus();
  if (power.isPekeyShortPressIrq()) {
    isScreenOn = !isScreenOn;
    gfx->setBrightness(isScreenOn ? currentScreenBrightness : 0);
    power.clearIrqStatus();
  }

  // 2. BOOT Button: Long Press for SOS
  static unsigned long bootPressTime = 0;
  static bool bootPressed = false;
  
  if (digitalRead(BOOT_PIN) == LOW) {
    if (!bootPressed) {
      bootPressed = true;
      bootPressTime = millis();
    } else if (millis() - bootPressTime > 3000 && !isEmergency) {
      // Trigger SOS after 3 seconds
      isEmergency = true;
      lv_obj_clear_flag(sos_container, LV_OBJ_FLAG_HIDDEN); // Show red screen
      sosChar.writeValue((uint8_t)1); // Notify App
      if (!isScreenOn) {
        isScreenOn = true;
        gfx->setBrightness(currentScreenBrightness);
      }
      Serial.println("SOS Alert Sent to App!");
    }
  } else {
    bootPressed = false;
  }

  // 3. Parse BLE Data
  if (central && central.connected()) {
    
    if (!isPhoneConnected) {
      isPhoneConnected = true;
      connectionTimestamp = millis();
    }

    // Update goal distance
    if (goalChar.written()) targetDistance = goalChar.value();
    
    // Update time
    if (timeChar.written()) {
      String tStr = timeChar.value();
      tStr.trim(); // Remove hidden newline chars from testing apps (like nRF Connect)
      strncpy(currentTime, tStr.c_str(), sizeof(currentTime) - 1);
      currentTime[sizeof(currentTime) - 1] = '\0'; 
    }
    
    // Update online friends
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

    // Update speed and location (Format expected: "Speed,Distance")
    if (locationChar.written()) {
      String locStr = locationChar.value();
      locStr.trim(); // Trim to prevent parsing errors
      int commaIndex = locStr.indexOf(',');
      if (commaIndex > 0) {
        currentSpeed = locStr.substring(0, commaIndex).toFloat();
        totalDistance = locStr.substring(commaIndex + 1).toFloat();
      }
    }
  } else {
    // Phone disconnected
    isPhoneConnected = false;
    currentSpeed = 0.0;
  }

  // 4. Update UI and LED Lights (Runs every 100ms)
  static unsigned long lastUIUpdate = 0;
  if (millis() - lastUIUpdate > 100) {
    lastUIUpdate = millis();

    static char bat_buf[32];
    static char gps_buf[32];
    static char speed_buf[16];

    // --- Auto Brightness Control ---
    uint8_t targetBrightness = (currentSpeed >= 10.0) ? 200 : 40; 
    if (isScreenOn && currentScreenBrightness != targetBrightness) {
      currentScreenBrightness = targetBrightness;
      gfx->setBrightness(currentScreenBrightness);
    }

    // --- Battery & Power UI ---
    const char* pwr_icon = LV_SYMBOL_BATTERY_FULL; 
    
    // Check USB connection
    if (power.isVbusIn()) {
      if (power.isCharging()) {
        pwr_icon = LV_SYMBOL_CHARGE; 
      } else {
        pwr_icon = LV_SYMBOL_USB;    
      }
    }

    // Update battery percentage
    if (power.isBatteryConnect()) {
      snprintf(bat_buf, sizeof(bat_buf), "%s %d%%", pwr_icon, power.getBatteryPercent());
    } else {
      snprintf(bat_buf, sizeof(bat_buf), "%s NO BAT", pwr_icon);
    }
    lv_label_set_text(label_battery, bat_buf);

    // --- Update Speed & Status Text ---
    if (isPhoneConnected) {
      snprintf(gps_buf, sizeof(gps_buf), "%s | App Connected", currentTime);
      lv_label_set_text(label_gps, gps_buf);

      snprintf(speed_buf, sizeof(speed_buf), "%.1f\nkm/h", currentSpeed);
      lv_label_set_text(label_speed, speed_buf);

      // Light logic when connected
      if (!isEmergency) {
        if (millis() - connectionTimestamp < 3000) {
          pixels.fill(pixels.Color(0, 150, 0)); // Green flash on successful connection
          pixels.show();
        } else {
          updateLEDProgress_Blue(); // Normal progress bar
        }
      }
    } else {
      snprintf(gps_buf, sizeof(gps_buf), "%s | Waiting App...", currentTime);
      lv_label_set_text(label_gps, gps_buf);
      
      snprintf(speed_buf, sizeof(speed_buf), "0.0\nkm/h");
      lv_label_set_text(label_speed, speed_buf);

      if (!isEmergency) updateLED_Searching_Yellow(); // Yellow light while searching
    }
    
    // --- Blink red LED during SOS emergency ---
    if (isEmergency) {
       if ((millis() / 300) % 2 == 0) {
          pixels.fill(pixels.Color(200, 0, 0));
       } else {
          pixels.clear();
       }
       pixels.show();
    }
  }

  // Handle LVGL background tasks
  lv_timer_handler(); 
  delay(5);
}

// --- LED Control Functions ---

// Shows trip progress using blue LEDs
void updateLEDProgress_Blue() {
  float progress = totalDistance / targetDistance;
  if (progress < 0) progress = 0;
  if (progress > 1.0) progress = 1.0; // Clamp at 100%

  int ledsToLight = round(progress * NUMPIXELS);
  pixels.clear();
  for (int i = 0; i < NUMPIXELS; i++) {
    if (i < ledsToLight) {
      pixels.setPixelColor(i, pixels.Color(0, 0, 150)); // Blue
    } else {
      pixels.setPixelColor(i, pixels.Color(0, 0, 0));   // Off
    }
  }
  pixels.show(); 
}

// Shows solid yellow LEDs when searching for BLE connection
void updateLED_Searching_Yellow() {
  pixels.fill(pixels.Color(100, 100, 0)); 
  pixels.show();
}