#include <ArduinoBLE.h>
#include <lvgl.h>
#include "Arduino_GFX_Library.h"
#include "pin_config.h" 
#include <Wire.h>
#include "XPowersLib.h"
#include "TouchDrvCSTXXX.hpp" 

// --- Configuration ---
#define BOOT_PIN   0

// --- Hardware Objects ---
XPowersPMU power;
TouchDrvCST92xx touch;

// --- Display Setup ---
// Using QSPI Bus for the T-Display-S3
Arduino_DataBus *bus = new Arduino_ESP32QSPI(LCD_CS, LCD_SCLK, LCD_SDIO0, LCD_SDIO1, LCD_SDIO2, LCD_SDIO3);
Arduino_CO5300 *gfx = new Arduino_CO5300(bus, LCD_RESET, 0, LCD_WIDTH, LCD_HEIGHT, 6, 0, 0, 0);

static lv_disp_draw_buf_t draw_buf;
static lv_color_t *buf; // We will allocate this in PSRAM during setup

// --- BLE Characteristics ---
const char* BLE_SERVICE_UUID       = "19B10000-E8F2-537E-4F6C-D104768A1214";
BLEService bikeService(BLE_SERVICE_UUID);
BLEStringCharacteristic locationChar("19B10001-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite, 50);
BLEFloatCharacteristic goalChar("19B10002-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite); 
BLEStringCharacteristic timeChar("19B10003-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite, 10);
BLEIntCharacteristic friendChar("19B10004-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite);
BLEByteCharacteristic socialSyncChar("19B10006-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite);
BLEByteCharacteristic sosChar("19B10005-E8F2-537E-4F6C-D104768A1214", BLERead | BLENotify);

// --- Variables ---
double totalDistance = 0.0, targetDistance = 5000.0;
float currentSpeed = 0.0;
int onlineFriends = 0;
char currentTime[16] = "--:--"; 
bool isPhoneConnected = false;
bool isEmergency = false;
int16_t touch_x[5], touch_y[5];

lv_obj_t *label_speed, *label_gps, *label_friends, *label_battery, *sos_container;

// --- Callbacks ---
void my_disp_flush(lv_disp_drv_t *disp, const lv_area_t *area, lv_color_t *color_p) {
  uint32_t w = (area->x2 - area->x1 + 1); 
  uint32_t h = (area->y2 - area->y1 + 1);
  // Direct bitmap drawing is the fastest way to avoid flicker
  gfx->draw16bitRGBBitmap(area->x1, area->y1, (uint16_t *)&color_p->full, w, h);
  lv_disp_flush_ready(disp);
}

void my_touchpad_read(lv_indev_drv_t *indev_driver, lv_indev_data_t *data) {
  uint8_t touched = touch.getPoint(touch_x, touch_y, touch.getSupportTouchPoint());
  if (touched > 0) {
    data->state = LV_INDEV_STATE_PR; 
    data->point.x = touch_x[0]; data->point.y = touch_y[0];
  } else {
    data->state = LV_INDEV_STATE_REL; 
  }
}

// Tick incrementer
void lvgl_tick_cb(void *arg) { lv_tick_inc(5); }

void setup() {
  Serial.begin(115200);
  pinMode(BOOT_PIN, INPUT_PULLUP);
  Wire.begin(IIC_SDA, IIC_SCL);
  
  // Initialize Power & Touch
  power.begin(Wire, AXP2101_SLAVE_ADDRESS, IIC_SDA, IIC_SCL);
  touch.setPins(TP_RESET, TP_INT);
  touch.begin(Wire, 0x5A, IIC_SDA, IIC_SCL);
  touch.setMaxCoordinates(LCD_WIDTH, LCD_HEIGHT);
  touch.setMirrorXY(true, true);

  // [FIX] Lower speed to 40MHz for maximum signal stability
  gfx->begin(40000000); 
  gfx->setBrightness(90);

  lv_init();

  // [FIX] Use PSRAM for the buffer to prevent memory-related flickering
  buf = (lv_color_t *)ps_malloc(LCD_WIDTH * 40 * sizeof(lv_color_t));
  if (buf == NULL) buf = (lv_color_t *)malloc(LCD_WIDTH * 40 * sizeof(lv_color_t));
  
  lv_disp_draw_buf_init(&draw_buf, buf, NULL, LCD_WIDTH * 40);
  
  static lv_disp_drv_t disp_drv;
  lv_disp_drv_init(&disp_drv);
  disp_drv.hor_res = LCD_WIDTH; disp_drv.ver_res = LCD_HEIGHT;
  disp_drv.flush_cb = my_disp_flush; 
  disp_drv.draw_buf = &draw_buf;
  lv_disp_drv_register(&disp_drv);

  static lv_indev_drv_t indev_drv;
  lv_indev_drv_init(&indev_drv);
  indev_drv.type = LV_INDEV_TYPE_POINTER;
  indev_drv.read_cb = my_touchpad_read;
  lv_indev_drv_register(&indev_drv);

  // Periodic timer for LVGL
  const esp_timer_create_args_t tick_args = { .callback = &lvgl_tick_cb, .name = "lvgl_tick" };
  esp_timer_handle_t tick_timer = NULL;
  esp_timer_create(&tick_args, &tick_timer);
  esp_timer_start_periodic(tick_timer, 5000); 

  init_bike_dashboard();

  // BLE Setup
  if (BLE.begin()) {
    BLE.setLocalName("BikeTracker_E"); 
    BLE.setAdvertisedService(bikeService);
    bikeService.addCharacteristic(locationChar);
    bikeService.addCharacteristic(goalChar);
    bikeService.addCharacteristic(timeChar);
    bikeService.addCharacteristic(friendChar);
    bikeService.addCharacteristic(socialSyncChar);
    bikeService.addCharacteristic(sosChar); 
    BLE.addService(bikeService);
    BLE.advertise();
  }
}

void loop() {
  // 1. Run LVGL handler as fast as possible
  lv_timer_handler(); 

  // 2. Check for Phone Connection
  BLEDevice central = BLE.central();
  if (central && central.connected()) {
    isPhoneConnected = true;
    if (locationChar.written()) {
       String loc = locationChar.value();
       int comma = loc.indexOf(',');
       if (comma > 0) currentSpeed = loc.substring(0, comma).toFloat();
    }
    if (timeChar.written()) strncpy(currentTime, timeChar.value().c_str(), 15);
  } else {
    isPhoneConnected = false;
  }

  // 3. [FIX] Update Labels only every 250ms
  static unsigned long lastLabelUpdate = 0;
  if (millis() - lastLabelUpdate > 250) {
    lastLabelUpdate = millis();
    update_ui_labels();
  }

  delay(2); // Small rest for ESP32 background tasks
}

void update_ui_labels() {
    static char b[64];
    snprintf(b, sizeof(b), "%s %d%%", power.isVbusIn() ? LV_SYMBOL_USB : LV_SYMBOL_BATTERY_FULL, power.getBatteryPercent());
    lv_label_set_text(label_battery, b);

    snprintf(b, sizeof(b), "%s | %s", currentTime, isPhoneConnected ? "Connected" : "Waiting...");
    lv_label_set_text(label_gps, b);

    snprintf(b, sizeof(b), "%.1f\nkm/h", currentSpeed);
    lv_label_set_text(label_speed, b);
}

void init_bike_dashboard() {
  lv_obj_set_style_bg_color(lv_scr_act(), lv_color_hex(0x000000), 0);
  label_speed = lv_label_create(lv_scr_act());
  lv_obj_set_style_text_font(label_speed, &lv_font_montserrat_48, 0);
  lv_obj_set_style_text_color(label_speed, lv_color_hex(0xFFFFFF), 0);
  lv_obj_align(label_speed, LV_ALIGN_CENTER, 0, -20);
  lv_label_set_text(label_speed, "0.0\nkm/h");

  label_gps = lv_label_create(lv_scr_act());
  lv_obj_align(label_gps, LV_ALIGN_TOP_MID, 0, 30);
  lv_label_set_text(label_gps, "--:--");

  label_battery = lv_label_create(lv_scr_act());
  lv_obj_align(label_battery, LV_ALIGN_BOTTOM_MID, 0, -30);
  lv_label_set_text(label_battery, "---%");
}