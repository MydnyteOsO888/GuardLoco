/**
 * CarGuard ESP32-CAM Firmware
 * Board: AI-Thinker ESP32-CAM
 *
 * Required Arduino libraries (install via Library Manager):
 *   - ArduinoJson  (Benoit Blanchon)  >= 7.0
 *   - ESP32 board package: https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
 *
 * Board settings in Arduino IDE:
 *   Board: "AI Thinker ESP32-CAM"
 *   Partition Scheme: "Huge APP (3MB No OTA/1MB SPIFFS)"
 *   Upload Speed: 115200
 *   (Remove ESP32-CAM from programmer before upload, then reinsert)
 */

#include "config.h"
#include <WiFi.h>
#include <WebServer.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "esp_camera.h"   // re-enable once networking is confirmed working
// #include "esp_timer.h"

// ── Camera pin map (AI-Thinker ESP32-CAM) ────────────────────
#define CAM_PIN_PWDN    32
#define CAM_PIN_RESET   -1
#define CAM_PIN_XCLK     0
#define CAM_PIN_SDA     26
#define CAM_PIN_SCL     27
#define CAM_PIN_D7      35
#define CAM_PIN_D6      34
#define CAM_PIN_D5      39
#define CAM_PIN_D4      36
#define CAM_PIN_D3      21
#define CAM_PIN_D2      19
#define CAM_PIN_D1      18
#define CAM_PIN_D0       5
#define CAM_PIN_VSYNC   25
#define CAM_PIN_HREF    23
#define CAM_PIN_PCLK    22

// ── State ─────────────────────────────────────────────────────
WebServer   server(80);
WiFiServer  streamServer(81);  // MJPEG stream port

// MJPEG stream state — one client, non-blocking
WiFiClient        g_streamClient;
bool              g_streaming         = false;
unsigned long     g_lastStreamFrame   = 0;
#define STREAM_FRAME_INTERVAL_MS 100  // ~10 fps

bool   g_armed           = false;
bool   g_cameraReady     = false;
float  g_resolution      = 1080.0f;
int    g_fps             = 30;

unsigned long g_lastHeartbeat    = 0;
unsigned long g_lastSensorPoll   = 0;
unsigned long g_lastMotionAlert  = 0;
unsigned long g_lastVibAlert     = 0;
unsigned long g_lastProxAlert    = 0;
unsigned long g_startMs          = 0;

// ── Sensor state ──────────────────────────────────────────────
bool  g_motionDetected   = false;
bool  g_vibDetected      = false;
float g_ultrasonicMeters = 5.0f;
float g_mcuTempC         = 0.0f;

// ─────────────────────────────────────────────────────────────
// Camera init
// ─────────────────────────────────────────────────────────────
bool initCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;
  config.pin_d0       = CAM_PIN_D0;
  config.pin_d1       = CAM_PIN_D1;
  config.pin_d2       = CAM_PIN_D2;
  config.pin_d3       = CAM_PIN_D3;
  config.pin_d4       = CAM_PIN_D4;
  config.pin_d5       = CAM_PIN_D5;
  config.pin_d6       = CAM_PIN_D6;
  config.pin_d7       = CAM_PIN_D7;
  config.pin_xclk     = CAM_PIN_XCLK;
  config.pin_pclk     = CAM_PIN_PCLK;
  config.pin_vsync    = CAM_PIN_VSYNC;
  config.pin_href     = CAM_PIN_HREF;
  config.pin_sccb_sda = CAM_PIN_SDA;
  config.pin_sccb_scl = CAM_PIN_SCL;
  config.pin_pwdn     = CAM_PIN_PWDN;
  config.pin_reset    = CAM_PIN_RESET;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.grab_mode    = CAMERA_GRAB_WHEN_EMPTY;
  config.fb_location  = CAMERA_FB_IN_PSRAM;

  if (psramFound()) {
    config.frame_size   = FRAMESIZE_QVGA;  // 320×240 — fast over WiFi
    config.jpeg_quality = 15;
    config.fb_count     = 2;
  } else {
    config.frame_size   = FRAMESIZE_QQVGA; // 160×120 — fits in DRAM
    config.jpeg_quality = 20;
    config.fb_count     = 1;
  }

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("[CAM] Init failed: 0x%x\n", err);
    return false;
  }
  Serial.println("[CAM] Init OK");
  return true;
}

// ─────────────────────────────────────────────────────────────
// WiFi
// ─────────────────────────────────────────────────────────────
void connectWiFi() {
#if WIFI_AP_MODE
  WiFi.mode(WIFI_AP_STA);  // AP+STA mode allows outbound HTTP from ESP32
  WiFi.softAP(AP_SSID, AP_PASSWORD);
  Serial.printf("[WiFi] AP started: SSID=%s  Password=%s\n", AP_SSID, AP_PASSWORD);
  Serial.printf("[WiFi] ESP32 IP: %s\n", WiFi.softAPIP().toString().c_str());
  Serial.println("[WiFi] Connect your PC to this hotspot, then run: ipconfig");
  Serial.printf("[WiFi] Backend expected at: %s\n", API_BASE_URL);
#else
  Serial.printf("[WiFi] Connecting to %s", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WiFi] Connected. IP: %s  RSSI: %d dBm\n",
                  WiFi.localIP().toString().c_str(), WiFi.RSSI());
  } else {
    Serial.println("\n[WiFi] Failed — rebooting in 5s");
    delay(5000);
    ESP.restart();
  }
#endif
}

// ─────────────────────────────────────────────────────────────
// Sensors
// ─────────────────────────────────────────────────────────────
float readUltrasonic() {
  digitalWrite(PIN_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_TRIG, LOW);

  long duration = pulseIn(PIN_ECHO, HIGH, 30000);  // 30ms timeout
  if (duration == 0) return 9.9f;                  // out of range
  return (duration * 0.034f) / 2.0f / 100.0f;      // cm → meters
}

float readMcuTemp() {
  // ESP32 internal temperature sensor (approximate)
  return temperatureRead();
}

void pollSensors() {
  g_motionDetected   = digitalRead(PIN_PIR) == HIGH;
  g_vibDetected      = digitalRead(PIN_VIBRATION) == HIGH;
  g_ultrasonicMeters = readUltrasonic();
  g_mcuTempC         = readMcuTemp();
}

// ─────────────────────────────────────────────────────────────
// HTTP helpers
// ─────────────────────────────────────────────────────────────
bool postJson(const char* path, const String& body) {
  if (WiFi.status() != WL_CONNECTED) return false;

  HTTPClient http;
  String url = String(API_BASE_URL) + path;
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Api-Key", ESP32_API_KEY);
  http.setTimeout(15000);

  int code = http.POST(body);
  bool ok  = (code == 200 || code == 201);
  if (!ok) Serial.printf("[HTTP] POST %s → %d\n", path, code);
  http.end();
  return ok;
}

// Returns response body or "" on failure
String postJsonGetResponse(const char* path, const String& body) {
  if (WiFi.status() != WL_CONNECTED) return "";

  HTTPClient http;
  String url = String(API_BASE_URL) + path;
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-Api-Key", ESP32_API_KEY);
  http.setTimeout(15000);

  int code = http.POST(body);
  String resp = "";
  if (code == 200 || code == 201) {
    resp = http.getString();
  } else {
    Serial.printf("[HTTP] POST %s → %d\n", path, code);
  }
  http.end();
  return resp;
}

// ─────────────────────────────────────────────────────────────
// Heartbeat
// ─────────────────────────────────────────────────────────────
void sendHeartbeat() {
  unsigned long uptimeSec = (millis() - g_startMs) / 1000;
  uint32_t totalBytes = 0, usedBytes = 0;

  // Storage info (SPIFFS not used here, report 0 or SD card if wired)
  // If you have SD card wired, replace with SD.totalBytes() / SD.usedBytes()

  JsonDocument doc;
  doc["is_armed"]           = g_armed;
  doc["ip_address"]         = WiFi.localIP().toString();
  doc["firmware_version"]   = FIRMWARE_VERSION;
  doc["uptime_seconds"]     = (int)uptimeSec;
  doc["mcu_temp_c"]         = g_mcuTempC;
  doc["wifi_rssi"]          = WiFi.RSSI();
  doc["motion_detected"]    = g_motionDetected;
  doc["vibration_g"]        = g_vibDetected ? 1.2f : 0.0f;
  doc["ultrasonic_meters"]  = g_ultrasonicMeters;
  doc["temperature_c"]      = g_mcuTempC;
  doc["storage_total_bytes"]  = totalBytes;
  doc["storage_used_bytes"]   = usedBytes;
  doc["storage_video_bytes"]  = 0;
  doc["storage_logs_bytes"]   = 0;

  String body;
  serializeJson(doc, body);
  postJson("/device/heartbeat", body);
}

// ─────────────────────────────────────────────────────────────
// Alert + clip
// ─────────────────────────────────────────────────────────────
String sendAlert(const char* eventType, float sensorValue) {
  JsonDocument doc;
  doc["event_type"]   = eventType;
  doc["sensor_value"] = sensorValue;

  String body;
  serializeJson(doc, body);

  String resp = postJsonGetResponse("/events/alert", body);
  if (resp.isEmpty()) return "";

  // Parse event_id from response so we can associate the clip
  JsonDocument respDoc;
  if (deserializeJson(respDoc, resp) == DeserializationError::Ok) {
    return respDoc["event_id"].as<String>();
  }
  return "";
}

void captureAndUploadClip(const String& eventId, const char* eventType) {
  if (!g_cameraReady) return;
  if (eventId.isEmpty()) return;

  Serial.printf("[CAM] Capturing clip for event %s (%s)\n", eventId.c_str(), eventType);

  unsigned long clipStart = millis();
  int framesCaptured = 0;

  while (millis() - clipStart < CLIP_DURATION_MS && framesCaptured < CLIP_FRAME_COUNT) {
    camera_fb_t* fb = esp_camera_fb_get();
    if (!fb) {
      Serial.println("[CAM] Frame capture failed");
      delay(100);
      continue;
    }

    // Upload each JPEG frame to the backend
    if (WiFi.status() == WL_CONNECTED) {
      HTTPClient http;
      String url = String(API_BASE_URL) + "/clips/upload-frame";
      http.begin(url);
      http.addHeader("Content-Type", "image/jpeg");
      http.addHeader("X-Api-Key", ESP32_API_KEY);
      http.addHeader("X-Event-Id", eventId);
      http.addHeader("X-Frame-Index", String(framesCaptured));
      http.setTimeout(10000);
      http.POST(fb->buf, fb->len);
      http.end();
    }

    esp_camera_fb_return(fb);
    framesCaptured++;
    delay(200);  // ~5 fps
  }

  Serial.printf("[CAM] Clip done — %d frames\n", framesCaptured);
}

void checkAndAlert() {
  if (!g_armed) return;

  unsigned long now = millis();

  // Motion alert
  if (g_motionDetected && (now - g_lastMotionAlert > ALERT_COOLDOWN_MS)) {
    g_lastMotionAlert = now;
    Serial.println("[ALERT] Motion detected");
    String eventId = sendAlert("motion", 1.0f);
    captureAndUploadClip(eventId, "motion");
  }

  // Vibration / impact alert
  if (g_vibDetected && (now - g_lastVibAlert > ALERT_COOLDOWN_MS)) {
    g_lastVibAlert = now;
    Serial.println("[ALERT] Vibration/impact detected");
    String eventId = sendAlert("impact", 1.2f);
    captureAndUploadClip(eventId, "impact");
  }

  // Proximity alert
  if (g_ultrasonicMeters < PROX_ALERT_METERS && g_ultrasonicMeters > 0.05f
      && (now - g_lastProxAlert > ALERT_COOLDOWN_MS)) {
    g_lastProxAlert = now;
    Serial.printf("[ALERT] Proximity: %.2f m\n", g_ultrasonicMeters);
    String eventId = sendAlert("proximity", g_ultrasonicMeters);
    captureAndUploadClip(eventId, "proximity");
  }
}

// ─────────────────────────────────────────────────────────────
// Local HTTP server — receives commands from FastAPI backend
// ─────────────────────────────────────────────────────────────
void handlePing() {
  server.send(200, "application/json", "{\"status\":\"ok\"}");
}

void handleArm() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"error\":\"no body\"}");
    return;
  }
  JsonDocument doc;
  if (deserializeJson(doc, server.arg("plain")) != DeserializationError::Ok) {
    server.send(400, "application/json", "{\"error\":\"invalid json\"}");
    return;
  }
  g_armed = doc["armed"] | false;
  Serial.printf("[CMD] Armed: %s\n", g_armed ? "true" : "false");
  server.send(200, "application/json", g_armed ? "{\"armed\":true}" : "{\"armed\":false}");
}

void handleReboot() {
  server.send(200, "application/json", "{\"status\":\"rebooting\"}");
  delay(300);
  ESP.restart();
}

void handleSettings() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"error\":\"no body\"}");
    return;
  }
  JsonDocument doc;
  if (deserializeJson(doc, server.arg("plain")) != DeserializationError::Ok) {
    server.send(400, "application/json", "{\"error\":\"invalid json\"}");
    return;
  }

  // Camera settings disabled until esp_camera.h is re-enabled

  server.send(200, "application/json", "{\"status\":\"ok\"}");
}

void handleSnapshot() {
  if (!g_cameraReady) {
    server.send(503, "application/json", "{\"error\":\"camera not ready\"}");
    return;
  }
  camera_fb_t* fb = esp_camera_fb_get();
  if (!fb) {
    server.send(500, "application/json", "{\"error\":\"capture failed\"}");
    return;
  }
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send_P(200, "image/jpeg", (const char*)fb->buf, fb->len);
  esp_camera_fb_return(fb);
}

// ─────────────────────────────────────────────────────────────
// MJPEG stream — port 81, non-blocking (one frame per loop tick)
// ─────────────────────────────────────────────────────────────
void acceptStreamClient() {
  if (g_streaming) return;  // already serving one client
  WiFiClient client = streamServer.available();
  if (!client) return;

  // Drain HTTP request headers
  while (client.connected() && client.available()) {
    String line = client.readStringUntil('\n');
    if (line == "\r") break;
  }

  client.print(
    "HTTP/1.1 200 OK\r\n"
    "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n"
    "Access-Control-Allow-Origin: *\r\n"
    "Cache-Control: no-cache, no-store\r\n"
    "\r\n"
  );

  g_streamClient = client;
  g_streaming    = true;
  Serial.println("[STREAM] Client connected");
}

void tickStreamFrame() {
  if (!g_streaming) return;

  if (!g_streamClient.connected()) {
    g_streaming = false;
    Serial.println("[STREAM] Client disconnected");
    return;
  }

  unsigned long now = millis();
  if (now - g_lastStreamFrame < STREAM_FRAME_INTERVAL_MS) return;
  g_lastStreamFrame = now;

  if (!g_cameraReady) return;
  camera_fb_t* fb = esp_camera_fb_get();
  if (!fb) return;

  g_streamClient.printf(
    "--frame\r\n"
    "Content-Type: image/jpeg\r\n"
    "Content-Length: %d\r\n"
    "\r\n",
    fb->len
  );
  g_streamClient.write(fb->buf, fb->len);
  g_streamClient.print("\r\n");
  esp_camera_fb_return(fb);
}

void setupRoutes() {
  server.on("/ping",     HTTP_GET,  handlePing);
  server.on("/snapshot", HTTP_GET,  handleSnapshot);
  server.on("/arm",      HTTP_POST, handleArm);
  server.on("/reboot",   HTTP_POST, handleReboot);
  server.on("/settings", HTTP_POST, handleSettings);
  server.onNotFound([]() {
    server.send(404, "application/json", "{\"error\":\"not found\"}");
  });
}

// ─────────────────────────────────────────────────────────────
// Setup & loop
// ─────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(2000);  // wait for Serial Monitor to connect before printing
  Serial.println("\n[CarGuard] Booting...");
  Serial.printf("  Free heap: %d bytes\n", ESP.getFreeHeap());
  Serial.printf("  PSRAM found: %s\n", psramFound() ? "yes" : "no");

  // Sensor pins (use PULLDOWN to avoid floating pin issues)
  pinMode(PIN_PIR,       INPUT_PULLDOWN);
  pinMode(PIN_VIBRATION, INPUT_PULLDOWN);
  pinMode(PIN_TRIG,      OUTPUT);
  pinMode(PIN_ECHO,      INPUT);

  // Camera — delay lets power rail stabilise before OV2640 init
  delay(500);
  Serial.println("[CAM] Initializing...");
  g_cameraReady = initCamera();
  Serial.printf("[CAM] Init %s\n", g_cameraReady ? "OK" : "FAILED — continuing without camera");

  // WiFi
  connectWiFi();

  // HTTP server
  setupRoutes();
  server.begin();
  streamServer.begin();
  Serial.println("[HTTP] Control server on port 80, MJPEG stream on port 81");

  g_startMs = millis();

  // Send initial heartbeat immediately so app shows device as online
  sendHeartbeat();
  g_lastHeartbeat = millis();

  Serial.printf("[CarGuard] Ready. API: %s\n", API_BASE_URL);
}

void loop() {
  server.handleClient();

  acceptStreamClient();   // pick up a new stream client if none active
  tickStreamFrame();      // send one frame if interval elapsed

  unsigned long now = millis();

  // Reconnect WiFi if dropped (station mode only)
#if !WIFI_AP_MODE
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WiFi] Reconnecting...");
    connectWiFi();
  }
#endif

  // Poll sensors
  if (now - g_lastSensorPoll >= SENSOR_POLL_MS) {
    g_lastSensorPoll = now;
    pollSensors();
    checkAndAlert();
  }

  // Periodic heartbeat
  if (now - g_lastHeartbeat >= HEARTBEAT_INTERVAL_MS) {
    g_lastHeartbeat = now;
    sendHeartbeat();
  }
}
