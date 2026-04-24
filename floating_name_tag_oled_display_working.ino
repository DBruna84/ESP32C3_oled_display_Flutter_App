#include <Wire.h>
#include <Adafruit_SSD1306.h>
#include <NimBLEDevice.h>

// ======================================================
// PIN CONFIG (ESP32-C3)
// ======================================================
#define SDA_PIN 6
#define SCL_PIN 7

// ======================================================
// OLED CONFIG
// ======================================================
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

// ======================================================
// BLE CONFIG
// ======================================================
#define SERVICE_UUID "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define RX_UUID      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

// ======================================================
// SHARED STATE
// ======================================================
volatile bool newData = false;
char rxBuffer[64] = "READY";
char oledBuffer[64] = "READY";

// ======================================================
// OLED RENDER
// ======================================================
void renderOLED(const char* text) {
  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 20);
  display.print(text);
  display.display();
}

// ======================================================
// BLE CALLBACK (FIXED FOR YOUR NIMBLE VERSION)
// ======================================================
class RXCallbacks : public NimBLECharacteristicCallbacks {

  // ✔ FIX: correct signature for NimBLE-Arduino builds you're using
  void onWrite(NimBLECharacteristic* c, NimBLEConnInfo& connInfo) override {
    std::string value = c->getValue();

    if (value.empty()) return;

    strncpy(rxBuffer, value.c_str(), sizeof(rxBuffer) - 1);
    rxBuffer[sizeof(rxBuffer) - 1] = '\0';

    newData = true;

    Serial.print("🔥 RX RECEIVED: ");
    Serial.println(rxBuffer);
  }
};

// ======================================================
// OLED INIT (ROBUST)
// ======================================================
bool initOLED() {
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(50000); // stability fix for ESP32-C3

  if (display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) return true;
  if (display.begin(SSD1306_SWITCHCAPVCC, 0x3D)) return true;

  return false;
}

// ======================================================
// SETUP
// ======================================================
void setup() {
  Serial.begin(115200);
  delay(300);

  Serial.println("\n===== ESP32-C3 NAMETAG BOOT =====");

  // ---------------- OLED ----------------
  if (!initOLED()) {
    Serial.println("OLED INIT FAILED");
    while (true);
  }

  renderOLED("BOOT");
  delay(800);
  renderOLED("READY");

  Serial.println("OLED INIT OK");

  // ---------------- BLE ----------------
  NimBLEDevice::init("FloatingNametag");

  NimBLEServer* server = NimBLEDevice::createServer();
  NimBLEService* service = server->createService(SERVICE_UUID);

  NimBLECharacteristic* rxChar = service->createCharacteristic(
    RX_UUID,
    NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR
  );

  rxChar->setCallbacks(new RXCallbacks());

  service->start();

  NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->start();

  Serial.println("BLE ADVERTISING ACTIVE");
}

// ======================================================
// LOOP
// ======================================================
void loop() {

  if (newData) {
    newData = false;

    strncpy(oledBuffer, rxBuffer, sizeof(oledBuffer));

    Serial.print("OLED UPDATE → ");
    Serial.println(oledBuffer);

    renderOLED(oledBuffer);
  }

  delay(20);
}
