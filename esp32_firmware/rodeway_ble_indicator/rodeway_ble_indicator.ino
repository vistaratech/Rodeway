/*
 * ============================================================
 *  Rodeway — ESP32 SuperMini BLE Turn Indicator Firmware
 * ============================================================
 *  Commands received from the Rodeway Flutter app:
 *    RIGHT_ON  → Right indicator LED ON
 *    LEFT_ON   → Left indicator LED ON
 *    ALL_OFF   → All LEDs OFF
 *
 *  BLE Config (must match ble_service.dart):
 *    Service UUID       : 4fafc201-1fb5-459e-8fcc-c5c9c331914b
 *    Characteristic UUID: beb5483e-36e1-4688-b7f5-ea07361b26a8
 *
 *  Wiring:
 *    GPIO 2 → Right indicator LED (+ resistor → GND)
 *    GPIO 3 → Left  indicator LED (+ resistor → GND)
 *
 *  Library required:
 *    ESP32 BLE Arduino (built-in with ESP32 board package)
 *
 *  Board: ESP32C3 SuperMini (or any ESP32 variant)
 * ============================================================
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ── Pin Configuration for Motor Driver Module ───────────────
// Channel A (OUT1 & OUT2 - Left Turn) : IN1 = GPIO 2, IN2 = GPIO 4 (or GND)
// Channel B (OUT3 & OUT4 - Right Turn): IN3 = GPIO 3, IN4 = GPIO 5 (or GND)
#define PIN_LEFT        2    // GPIO 2 -> IN1 -> OUT1/OUT2 (Left Turn)
#define PIN_LEFT_GND    4    // GPIO 4 -> IN2 -> Ground reference for Left Turn
#define PIN_RIGHT       3    // GPIO 3 -> IN3 -> OUT3/OUT4 (Right Turn)
#define PIN_RIGHT_GND   5    // GPIO 5 -> IN4 -> Ground reference for Right Turn

// ── BLE UUIDs (must match ble_service.dart) ───────────────
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// ── Forward Declarations ──────────────────────────────────
void allOff();
void handleBlink();

// ── BLE Globals ────────────────────────────────────────────
BLEServer*         pServer         = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
bool               deviceConnected = false;
bool               oldConnected    = false;

// ── Blink state (for indicator flashing) ──────────────────
enum IndicatorState { IDLE, RIGHT_BLINK, LEFT_BLINK };
IndicatorState indicatorState = IDLE;

unsigned long lastBlinkTime  = 0;
bool          blinkOn        = false;
const int     BLINK_INTERVAL = 400; // ms — blink speed

// ──────────────────────────────────────────────────────────
//  BLE Server Callbacks — connection events
// ──────────────────────────────────────────────────────────
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    deviceConnected = true;
    Serial.println("[BLE] Phone connected ✓");
  }

  void onDisconnect(BLEServer* pServer) override {
    deviceConnected = false;
    Serial.println("[BLE] Phone disconnected");
    allOff();  // Safety: turn off all LEDs on disconnect
  }
};

// ──────────────────────────────────────────────────────────
//  BLE Characteristic Callbacks — command received
// ──────────────────────────────────────────────────────────
class CharacteristicCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) override {
    String value = pCharacteristic->getValue().c_str();
    value.trim();

    Serial.print("[CMD] Received: ");
    Serial.println(value);

    if (value == "RIGHT_ON") {
      indicatorState = RIGHT_BLINK;
      blinkOn = false;
      lastBlinkTime = 0;
      Serial.println("[CMD] → RIGHT indicator ON");
    }
    else if (value == "LEFT_ON") {
      indicatorState = LEFT_BLINK;
      blinkOn = false;
      lastBlinkTime = 0;
      Serial.println("[CMD] → LEFT indicator ON");
    }
    else if (value == "ALL_OFF") {
      indicatorState = IDLE;
      allOff();
      Serial.println("[CMD] → ALL OFF");
    }
    else {
      Serial.println("[CMD] Unknown command — ignored");
    }
  }
};

// ──────────────────────────────────────────────────────────
//  Helper: Turn off all LEDs immediately
// ──────────────────────────────────────────────────────────
void allOff() {
  digitalWrite(PIN_RIGHT,     LOW);
  digitalWrite(PIN_RIGHT_GND, LOW);
  digitalWrite(PIN_LEFT,      LOW);
  digitalWrite(PIN_LEFT_GND,  LOW);
  blinkOn = false;
}

// ──────────────────────────────────────────────────────────
//  Helper: Handle indicator blinking in loop()
// ──────────────────────────────────────────────────────────
void handleBlink() {
  if (indicatorState == IDLE) return;

  unsigned long now = millis();
  if (now - lastBlinkTime >= BLINK_INTERVAL) {
    lastBlinkTime = now;
    blinkOn = !blinkOn;

    if (indicatorState == RIGHT_BLINK) {
      // Channel A (OUT1 & OUT2) -> RIGHT
      digitalWrite(PIN_RIGHT,     blinkOn ? HIGH : LOW);
      digitalWrite(PIN_RIGHT_GND, LOW);
      digitalWrite(PIN_LEFT,      LOW);
      digitalWrite(PIN_LEFT_GND,  LOW);
    }
    else if (indicatorState == LEFT_BLINK) {
      // Channel B (OUT3 & OUT4) -> LEFT
      digitalWrite(PIN_LEFT,      blinkOn ? HIGH : LOW);
      digitalWrite(PIN_LEFT_GND,  LOW);
      digitalWrite(PIN_RIGHT,     LOW);
      digitalWrite(PIN_RIGHT_GND, LOW);
    }
  }
}

// ──────────────────────────────────────────────────────────
//  Setup
// ──────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Serial.println("\n[Rodeway] ESP32 BLE Turn Indicator starting...");

  // GPIO setup
  pinMode(PIN_RIGHT,     OUTPUT);
  pinMode(PIN_RIGHT_GND, OUTPUT);
  pinMode(PIN_LEFT,      OUTPUT);
  pinMode(PIN_LEFT_GND,  OUTPUT);
  allOff();

  // ── BLE Init ──
  BLEDevice::init("ESP32 Rodeway");   // Device name visible during BLE scan

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  // Create BLE Service
  BLEService* pService = pServer->createService(SERVICE_UUID);

  // Create BLE Characteristic (WRITE + NOTIFY)
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_WRITE |
    BLECharacteristic::PROPERTY_WRITE_NR |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pCharacteristic->addDescriptor(new BLE2902());
  pCharacteristic->setCallbacks(new CharacteristicCallbacks());

  // Start service & advertising
  pService->start();

  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);  // Advertise UUID for app to find
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);
  BLEDevice::startAdvertising();

  Serial.println("[BLE] Advertising started — waiting for Rodeway app...");
  Serial.print("[BLE] Device name: ESP32 Rodeway");
  Serial.println();
}

// ──────────────────────────────────────────────────────────
//  Loop
// ──────────────────────────────────────────────────────────
void loop() {
  // Handle LED blinking
  handleBlink();

  // Check for Serial commands for easy multimeter testing over USB
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    cmd.toUpperCase();

    if (cmd == "RIGHT_ON" || cmd == "RIGHT") {
      indicatorState = RIGHT_BLINK;
      blinkOn = false;
      lastBlinkTime = 0;
      Serial.println("[SERIAL] → RIGHT indicator ON (GPIO 3 -> OUT3 & OUT4)");
    }
    else if (cmd == "LEFT_ON" || cmd == "LEFT") {
      indicatorState = LEFT_BLINK;
      blinkOn = false;
      lastBlinkTime = 0;
      Serial.println("[SERIAL] → LEFT indicator ON (GPIO 2 -> OUT1 & OUT2)");
    }
    else if (cmd == "ALL_OFF" || cmd == "OFF") {
      indicatorState = IDLE;
      allOff();
      Serial.println("[SERIAL] → ALL OFF");
    }
  }

  // Restart advertising after disconnect (so app can reconnect)
  if (!deviceConnected && oldConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("[BLE] Restarted advertising — ready to reconnect");
    oldConnected = false;
  }

  if (deviceConnected && !oldConnected) {
    oldConnected = true;
  }
}
