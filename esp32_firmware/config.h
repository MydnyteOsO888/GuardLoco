#pragma once

// ── WiFi mode ─────────────────────────────────────────────────
// AP mode: ESP32 creates its own hotspot — connect your PC to it
// STA mode: ESP32 joins an existing WiFi network
#define WIFI_AP_MODE  0   // 1 = AP mode, 0 = station mode

// ── AP mode settings (ESP32 hotspot) ─────────────────────────
#define AP_SSID       "CarGuard-CAM"
#define AP_PASSWORD   "carguard123"
// In AP mode: ESP32 = 192.168.4.1, your PC will be 192.168.4.2
#define API_BASE_URL  "http://192.168.137.1:8000/api/v1"

// ── Station mode settings (join existing WiFi) ────────────────
#define WIFI_SSID     "DESKTOP-7MUVH1P 7528"
#define WIFI_PASSWORD "647qN804"
// #define API_BASE_URL  "http://172.20.10.2:8000/api/v1"

#define ESP32_API_KEY    "dev-esp32-key"   // must match ESP32_API_KEY in .env

// ── Firmware version (shown in app status screen) ─────────────
#define FIRMWARE_VERSION "1.0.0"

// ── Pin definitions (AI-Thinker ESP32-CAM) ────────────────────
// Free GPIOs after camera uses: 0,2,4,5,18,19,21,22,25,26,27,32,33,34,35,36,39
#define PIN_PIR          13   // HC-SR501 data pin
#define PIN_VIBRATION    12   // SW-420 digital vibration sensor (or MPU-6050 INT)
#define PIN_TRIG         14   // HC-SR04 ultrasonic trigger
#define PIN_ECHO         15   // HC-SR04 ultrasonic echo
// NOTE: If using MPU-6050 instead of SW-420, wire SDA→GPIO14, SCL→GPIO16
//       and enable USE_MPU6050 below (requires additional I2C library)

// ── Alert thresholds ──────────────────────────────────────────
#define PROX_ALERT_METERS     1.5f   // alert if object closer than this
#define HEARTBEAT_INTERVAL_MS 5000   // report to API every 5 seconds
#define SENSOR_POLL_MS        300    // poll sensors every 300ms
#define ALERT_COOLDOWN_MS     3000   // don't re-send same alert within 3s

// ── Clip settings ─────────────────────────────────────────────
#define CLIP_DURATION_MS      10000  // record 10s clip on alert
#define CLIP_FRAME_COUNT      50     // ~5fps × 10s
