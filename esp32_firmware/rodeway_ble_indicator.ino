/*
 * ============================================================
 *  Rodeway — ESP32 SuperMini BLE Turn Indicator Firmware
 *  (2-Channel Relay Module + 12V Bike Indicator Bulbs)
 * ============================================================
 *
 *  Commands received from the Rodeway Flutter app:
 *    RIGHT_ON  → Right indicator bulb blink ON
 *    LEFT_ON   → Left indicator bulb blink ON
 *    ALL_OFF   → All relays OFF (bulbs OFF)
 *
 *  BLE Config (must match ble_service.dart):
 *    Service UUID       : 4fafc201-1fb5-459e-8fcc-c5c9c331914b
 *    Characteristic UUID: beb5483e-36e1-4688-b7f5-ea07361b26a8
 *
 * ────────────────────────────────────────────────────────────
 *  WIRING DIAGRAM — 2-Channel Relay Module (with Optocoupler)
 * ────────────────────────────────────────────────────────────
 *
 *  ┌───────────────────┐
 *  │  ESP32C3 SuperMini│
 *  │                   │
 *  │  GPIO 2 ──────────┼──→ IN1 (Relay Module)  → LEFT Relay
 *  │  GPIO 3 ──────────┼──→ IN2 (Relay Module)  → RIGHT Relay
 *  │  GND ─────────────┼──→ GND (Relay Module)
 *  │  5V / VIN ────────┼──→ VCC (Relay Module, 5V power)
 *  └───────────────────┘
 *
 *  ┌─────────────────────────────────────────────────────┐
 *  │           2-Channel Relay Module                    │
 *  │                                                     │
 *  │  Relay 1 (LEFT):                                    │
 *  │    COM1 ──→ 12V Battery (+)                         │
 *  │    NO1  ──→ LEFT Indicator Bulb (+) wire            │
 *  │    NC1  ──→ (not connected)                         │
 *  │                                                     │
 *  │  Relay 2 (RIGHT):                                   │
 *  │    COM2 ──→ 12V Battery (+)                         │
 *  │    NO2  ──→ RIGHT Indicator Bulb (+) wire           │
 *  │    NC2  ──→ (not connected)                         │
 *  └─────────────────────────────────────────────────────┘
 *
 *  Indicator Bulbs:
 *    LEFT Bulb  (-) wire ──→ 12V Battery (-)  / Chassis GND
 *    RIGHT Bulb (-) wire ──→ 12V Battery (-)  / Chassis GND
 *
 *  Terminal Explanation:
 *    COM = Common (always connected to 12V+)
 *    NO  = Normally Open (connects to COM when relay is ON)
 *    NC  = Normally Closed (connects to COM when relay is OFF)
 *
 * ────────────────────────────────────────────────────────────
 *  IMPORTANT NOTES:
 *    • Most relay modules with optocoupler are ACTIVE LOW:
 *      - LOW  = Relay ON  (circuit closed, bulb lights up)
 *      - HIGH = Relay OFF (circuit open, bulb is off)
 *    • If your relay module is ACTIVE HIGH (rare), change
 *      RELAY_ACTIVE_LOW to false below.
 *    • Use NO (Normally Open) terminal so bulbs are OFF by
 *      default when ESP32 is powered off (safety).
 * ────────────────────────────────────────────────────────────
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

// ── Relay Module Configuration ──────────────────────────────
// 2-Channel Relay Module: only 1 signal pin per relay channel
#define PIN_LEFT_RELAY   2    // GPIO 2 → IN1 → Relay 1 (Left Indicator)
#define PIN_RIGHT_RELAY  3    // GPIO 3 → IN2 → Relay 2 (Right Indicator)

// Most optocoupler relay modules are ACTIVE LOW
// Set to false if your module is ACTIVE HIGH
#define RELAY_ACTIVE_LOW true

// Helper macros for relay control (handles active-low/high logic)
#if RELAY_ACTIVE_LOW
  #define RELAY_ON   LOW    // LOW  = relay energized = bulb ON
  #define RELAY_OFF  HIGH   // HIGH = relay released  = bulb OFF
#else
  #define RELAY_ON   HIGH   // HIGH = relay energized = bulb ON
  #define RELAY_OFF  LOW    // LOW  = relay released  = bulb OFF
#endif

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
const int     BLINK_INTERVAL = 400; // ms — blink speed (bike indicator style)

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
    allOff();  // Safety: turn off all relays on disconnect
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
      Serial.println("[CMD] → RIGHT indicator ON (Relay 2 blinking)");
    }
    else if (value == "LEFT_ON") {
      indicatorState = LEFT_BLINK;
      blinkOn = false;
      lastBlinkTime = 0;
      Serial.println("[CMD] → LEFT indicator ON (Relay 1 blinking)");
    }
    else if (value == "ALL_OFF") {
      indicatorState = IDLE;
      allOff();
      Serial.println("[CMD] → ALL OFF (both relays OFF)");
    }
    else {
      Serial.println("[CMD] Unknown command — ignored");
    }
  }
};

// ──────────────────────────────────────────────────────────
//  Helper: Turn off all relays immediately
// ──────────────────────────────────────────────────────────
void allOff() {
  digitalWrite(PIN_LEFT_RELAY,  RELAY_OFF);
  digitalWrite(PIN_RIGHT_RELAY, RELAY_OFF);
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
      // Right relay toggles, left relay stays OFF
      digitalWrite(PIN_RIGHT_RELAY, blinkOn ? RELAY_ON : RELAY_OFF);
      digitalWrite(PIN_LEFT_RELAY,  RELAY_OFF);
    }
    else if (indicatorState == LEFT_BLINK) {
      // Left relay toggles, right relay stays OFF
      digitalWrite(PIN_LEFT_RELAY,  blinkOn ? RELAY_ON : RELAY_OFF);
      digitalWrite(PIN_RIGHT_RELAY, RELAY_OFF);
    }
  }
}

// ──────────────────────────────────────────────────────────
//  Setup
// ──────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Serial.println("\n[Rodeway] ESP32 BLE Turn Indicator (Relay Module) starting...");

  // GPIO setup — only 2 pins needed for 2-channel relay
  pinMode(PIN_LEFT_RELAY,  OUTPUT);
  pinMode(PIN_RIGHT_RELAY, OUTPUT);
  allOff();  // Ensure both relays are OFF at boot

  Serial.println("[HW] Relay module configured:");
  Serial.println("  GPIO 2 → IN1 → Relay 1 (LEFT indicator)");
  Serial.println("  GPIO 3 → IN2 → Relay 2 (RIGHT indicator)");
  Serial.print("  Relay logic: ");
  Serial.println(RELAY_ACTIVE_LOW ? "ACTIVE LOW (LOW=ON)" : "ACTIVE HIGH (HIGH=ON)");

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
  Serial.println("[BLE] Device name: ESP32 Rodeway");
}

// ──────────────────────────────────────────────────────────
//  Loop
// ──────────────────────────────────────────────────────────
void loop() {
  // Handle relay blinking for indicators
  handleBlink();

  // Check for Serial commands (for testing without phone)
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    cmd.toUpperCase();

    if (cmd == "RIGHT_ON" || cmd == "RIGHT") {
      indicatorState = RIGHT_BLINK;
      blinkOn = false;
      lastBlinkTime = 0;
      Serial.println("[SERIAL] → RIGHT indicator ON (Relay 2 blinking)");
    }
    else if (cmd == "LEFT_ON" || cmd == "LEFT") {
      indicatorState = LEFT_BLINK;
      blinkOn = false;
      lastBlinkTime = 0;
      Serial.println("[SERIAL] → LEFT indicator ON (Relay 1 blinking)");
    }
    else if (cmd == "ALL_OFF" || cmd == "OFF") {
      indicatorState = IDLE;
      allOff();
      Serial.println("[SERIAL] → ALL OFF (both relays OFF)");
    }
    else if (cmd == "TEST") {
      // Quick test: toggle both relays once
      Serial.println("[TEST] Toggling LEFT relay...");
      digitalWrite(PIN_LEFT_RELAY, RELAY_ON);
      delay(500);
      digitalWrite(PIN_LEFT_RELAY, RELAY_OFF);
      delay(300);
      Serial.println("[TEST] Toggling RIGHT relay...");
      digitalWrite(PIN_RIGHT_RELAY, RELAY_ON);
      delay(500);
      digitalWrite(PIN_RIGHT_RELAY, RELAY_OFF);
      Serial.println("[TEST] Done ✓");
    }
    else if (cmd == "STATUS") {
      Serial.println("─── Relay Status ───");
      Serial.print("  Left Relay (GPIO 2):  ");
      Serial.println(digitalRead(PIN_LEFT_RELAY) == RELAY_ON ? "ON" : "OFF");
      Serial.print("  Right Relay (GPIO 3): ");
      Serial.println(digitalRead(PIN_RIGHT_RELAY) == RELAY_ON ? "ON" : "OFF");
      Serial.print("  Indicator State: ");
      Serial.println(indicatorState == IDLE ? "IDLE" :
                     indicatorState == LEFT_BLINK ? "LEFT BLINK" : "RIGHT BLINK");
      Serial.println("────────────────────");
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
