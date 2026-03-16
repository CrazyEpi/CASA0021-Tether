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
#define NUMPIXELS  24   
#define BOOT_PIN   0

Adafruit_NeoPixel pixels(NUMPIXELS, LED_PIN, NEO_GRB + NEO_KHZ800);
XPowersPMU power;
TouchDrvCST92xx touch;

Arduino_DataBus *bus = new Arduino_ESP32QSPI(LCD_CS, LCD_SCLK, LCD_SDIO0, LCD_SDIO1, LCD_SDIO2, LCD_SDIO3);
Arduino_CO5300 *gfx = new Arduino_CO5300(bus, LCD_RESET, 0, LCD_WIDTH, LCD_HEIGHT, 6, 0, 0, 0);

static lv_disp_draw_buf_t draw_buf;
static lv_color_t buf[LCD_WIDTH * LCD_HEIGHT / 10];

// Bluetooth UUID
const char* BLE_SERVICE_UUID       = "19B10000-E8F2-537E-4F6C-D104768A1214";
// 注意：locationChar 的作用已变更为从手机接收数据
const char* BLE_LOCATION_CHAR_UUID = "19B10001-E8F2-537E-4F6C-D104768A1214"; 
const char* BLE_GOAL_CHAR_UUID     = "19B10002-E8F2-537E-4F6C-D104768A1214"; 
const char* BLE_TIME_CHAR_UUID     = "19B10003-E8F2-537E-4F6C-D104768A1214"; 
const char* BLE_FRIEND_CHAR_UUID   = "19B10004-E8F2-537E-4F6C-D104768A1214"; 
const char* BLE_SOS_CHAR_UUID      = "19B10005-E8F2-537E-4F6C-D104768A1214";

BLEService bikeService(BLE_SERVICE_UUID);
// 权限更改为 BLEWrite，允许 App 写入当前速度和距离
BLEStringCharacteristic locationChar(BLE_LOCATION_CHAR_UUID, BLERead | BLEWrite, 50);
BLEFloatCharacteristic goalChar(BLE_GOAL_CHAR_UUID, BLERead | BLEWrite); 
BLEStringCharacteristic timeChar(BLE_TIME_CHAR_UUID, BLERead | BLEWrite, 10);
BLEIntCharacteristic friendChar(BLE_FRIEND_CHAR_UUID, BLERead | BLEWrite);
BLEByteCharacteristic sosChar(BLE_SOS_CHAR_UUID, BLERead | BLENotify);

// default data
double totalDistance = 0.0, targetDistance = 5000.0;
float currentSpeed = 0.0;
int onlineFriends = 0;
char currentTime[16] = "--:--"; 
bool isPhoneConnected = false;
unsigned long connectionTimestamp = 0;

bool isScreenOn = true;
bool isEmergency = false;
int16_t touch_x[5], touch_y[5];

//LVGL UI Stuff
lv_obj_t *label_speed;    
lv_obj_t *label_gps;      
lv_obj_t *label_friends;  
lv_obj_t *label_battery;  
lv_obj_t *sos_container;

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

// touchscreen read
void my_touchpad_read(lv_indev_drv_t *indev_driver, lv_indev_data_t *data) {
  uint8_t touched = touch.getPoint(touch_x, touch_y, touch.getSupportTouchPoint());
  if (touched > 0) {
    data->state = LV_INDEV_STATE_PR;
    data->point.x = touch_x[0];
    data->point.y = touch_y[0];
  } else {
    data->state = LV_INDEV_STATE_REL;
  }
}

void example_increase_lvgl_tick(void *arg) { lv_tick_inc(2); }

// SOS long press cancle
void sos_clear_event_cb(lv_event_t * e) {
  if (isEmergency) {
    isEmergency = false;
    lv_obj_add_flag(sos_container, LV_OBJ_FLAG_HIDDEN); 
    sosChar.writeValue((uint8_t)0);
    Serial.println("Emergency Canceled!");
  }
}

//Initialize UI components
void init_bike_dashboard() {
  lv_obj_set_style_bg_color(lv_scr_act(), lv_color_hex(0x000000), LV_PART_MAIN);

  label_speed = lv_label_create(lv_scr_act());
  lv_obj_set_style_text_color(label_speed, lv_color_hex(0xFFFFFF), LV_PART_MAIN);
  lv_obj_set_style_text_font(label_speed, &lv_font_montserrat_48, LV_PART_MAIN); 
  lv_label_set_text(label_speed, "0.0\nkm/h");
  lv_obj_set_style_text_align(label_speed, LV_TEXT_ALIGN_CENTER, LV_PART_MAIN);
  lv_obj_align(label_speed, LV_ALIGN_CENTER, 0, -10);

  label_gps = lv_label_create(lv_scr_act());
  lv_obj_set_style_text_color(label_gps, lv_color_hex(0xAAAAAA), LV_PART_MAIN);
  lv_obj_set_style_text_font(label_gps, &lv_font_montserrat_24, LV_PART_MAIN);
  lv_label_set_text(label_gps, "--:-- | Waiting App...");
  lv_obj_align(label_gps, LV_ALIGN_TOP_MID, 0, 40); 

  label_friends = lv_label_create(lv_scr_act());
  lv_obj_set_style_text_color(label_friends, lv_color_hex(0x00FFFF), LV_PART_MAIN);
  lv_obj_set_style_text_font(label_friends, &lv_font_montserrat_24, LV_PART_MAIN);
  lv_label_set_text(label_friends, ""); 
  lv_obj_align(label_friends, LV_ALIGN_BOTTOM_MID, 0, -80);
  
  label_battery = lv_label_create(lv_scr_act());
  lv_obj_set_style_text_color(label_battery, lv_color_hex(0x00FF00), LV_PART_MAIN);
  lv_obj_set_style_text_font(label_battery, &lv_font_montserrat_24, LV_PART_MAIN);
  lv_label_set_text(label_battery, "BAT: --%");
  lv_obj_align(label_battery, LV_ALIGN_BOTTOM_MID, 0, -40);

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

  Serial.println("\n--- Bike Tracker Started (Phone GPS Mode) ---");

  pinMode(BOOT_PIN, INPUT_PULLUP);

  Wire.begin(IIC_SDA, IIC_SCL);
  if(power.begin(Wire, AXP2101_SLAVE_ADDRESS, IIC_SDA, IIC_SCL)) {
    power.clearIrqStatus(); 
    power.enableBattVoltageMeasure();
    power.enableIRQ(XPOWERS_AXP2101_PKEY_SHORT_IRQ);
  }

  touch.setPins(TP_RESET, TP_INT);
  if(!touch.begin(Wire, 0x5A, IIC_SDA, IIC_SCL)) {
     Serial.println("Warning: Touch not found!");
  } else {
     touch.setMaxCoordinates(LCD_WIDTH, LCD_HEIGHT);
     touch.setMirrorXY(true, true);
  }

  gfx->begin();
  gfx->setBrightness(90);
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

  const esp_timer_create_args_t lvgl_tick_timer_args = { .callback = &example_increase_lvgl_tick, .name = "lvgl_tick" };
  esp_timer_handle_t lvgl_tick_timer = NULL;
  esp_timer_create(&lvgl_tick_timer_args, &lvgl_tick_timer);
  esp_timer_start_periodic(lvgl_tick_timer, 2000); 

  init_bike_dashboard();
  
  pixels.begin();
  pixels.setBrightness(50); 
  pixels.clear(); 
  pixels.show();
  
  delay(300); 

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
  
  // 1. 电源键息屏
  power.getIrqStatus();
  if (power.isPekeyShortPressIrq()) {
    isScreenOn = !isScreenOn;
    gfx->setBrightness(isScreenOn ? 90 : 0);
    power.clearIrqStatus();
  }

  // 2. BOOT 长按 SOS
  static unsigned long bootPressTime = 0;
  static bool bootPressed = false;
  
  if (digitalRead(BOOT_PIN) == LOW) {
    if (!bootPressed) {
      bootPressed = true;
      bootPressTime = millis();
    } else if (millis() - bootPressTime > 3000 && !isEmergency) {
      isEmergency = true;
      lv_obj_clear_flag(sos_container, LV_OBJ_FLAG_HIDDEN); 
      sosChar.writeValue((uint8_t)1); 
      if (!isScreenOn) {
        isScreenOn = true;
        gfx->setBrightness(90);
      }
      Serial.println("SOS Alert Sent to App!");
    }
  } else {
    bootPressed = false;
  }

  // 3. 蓝牙数据解析 (现在位置数据由手机 App 提供)
  if (central && central.connected()) {
    
    // 如果是刚连接上，记录时间用于绿灯提示
    if (!isPhoneConnected) {
      isPhoneConnected = true;
      connectionTimestamp = millis();
    }

    if (goalChar.written()) targetDistance = goalChar.value();
    
    if (timeChar.written()) {
      String tStr = timeChar.value();
      strncpy(currentTime, tStr.c_str(), sizeof(currentTime) - 1);
      currentTime[sizeof(currentTime) - 1] = '\0'; 
    }
    
    if (friendChar.written()) {
      onlineFriends = friendChar.value();
      if (onlineFriends > 0) {
        lv_label_set_text_fmt(label_friends, " %d Online", onlineFriends);
      } else {
        lv_label_set_text(label_friends, ""); 
      }
    }

    // --- 核心改动：解析手机发来的 GPS 数据 ---
    // 假设手机发来的字符串格式为: "速度,距离" (例如: "15.2,1250.5")
    if (locationChar.written()) {
      String locStr = locationChar.value();
      int commaIndex = locStr.indexOf(',');
      if (commaIndex > 0) {
        currentSpeed = locStr.substring(0, commaIndex).toFloat();
        totalDistance = locStr.substring(commaIndex + 1).toFloat();
      }
    }
  } else {
    // 如果手机断开连接，状态重置
    isPhoneConnected = false;
    currentSpeed = 0.0;
  }

  // 4. UI 与灯光刷新逻辑
  static unsigned long lastUIUpdate = 0;
  if (millis() - lastUIUpdate > 100) {
    lastUIUpdate = millis();

    if (power.isBatteryConnect()) {
      lv_label_set_text_fmt(label_battery, "BAT: %d%%", power.getBatteryPercent());
    }

    // --- 状态显示更新 ---
    if (isPhoneConnected) {
      lv_label_set_text_fmt(label_gps, "%s | App Connected", currentTime);
      //lv_label_set_text_fmt(label_speed, "%.1f\nkm/h", currentSpeed);

      static char speed_buf[16];
      snprintf(speed_buf, sizeof(speed_buf), "%.1f\nkm/h", currentSpeed);
      lv_label_set_text(label_speed, speed_buf);

      if (!isEmergency) {
        // 连接成功的前 3 秒亮绿灯，之后亮蓝色进度条
        if (millis() - connectionTimestamp < 3000) {
          pixels.fill(pixels.Color(0, 150, 0)); 
          pixels.show();
        } else {
          updateLEDProgress_Blue(); 
        }
      }
    } else {
      // 手机断开连接时的显示
      lv_label_set_text_fmt(label_gps, "%s | Waiting App...", currentTime);
      lv_label_set_text(label_speed, "0.0\nkm/h");
      if (!isEmergency) updateLED_Searching_Yellow();
    }
    
    // 紧急状态红灯闪烁覆盖
    if (isEmergency) {
       if ((millis() / 300) % 2 == 0) {
          pixels.fill(pixels.Color(200, 0, 0));
       } else {
          pixels.clear();
       }
       pixels.show();
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
      pixels.setPixelColor(i, pixels.Color(0, 0, 150)); 
    } else {
      pixels.setPixelColor(i, pixels.Color(0, 0, 0));
    }
  }
  pixels.show(); 
}

void updateLED_Searching_Yellow() {
  pixels.fill(pixels.Color(100, 100, 0)); 
  pixels.show();
}