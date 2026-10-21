// ==========================================================
// ESP32-C3 Super Mini - Relay Module Control Code
// ==========================================================
// Pin Connections:
// ----------------
// Relay VCC  -> ESP32 5V (or 3.3V)
// Relay GND  -> ESP32 GND
// Relay IN   -> ESP32 GPIO 2 (D2)
// ==========================================================

#define RELAY_PIN 2     // Relay control pin (GPIO 2)
#define ONBOARD_LED 8   // ESP32-C3 Super Mini onboard blue LED

// Standard Relay Modules are Active LOW:
// LOW  (0V) = Relay Turns ON (Clicks & LED glows on relay)
// HIGH (3.3V) = Relay Turns OFF
#define RELAY_ON  LOW
#define RELAY_OFF HIGH

void setup() {
  Serial.begin(115200);
  delay(1000);

  pinMode(RELAY_PIN, OUTPUT);
  pinMode(ONBOARD_LED, OUTPUT);

  // Default state: Relay OFF, LED OFF
  digitalWrite(RELAY_PIN, RELAY_OFF);
  digitalWrite(ONBOARD_LED, HIGH); // Onboard LED is Active LOW

  Serial.println("==========================================");
  Serial.println(" ESP32-C3 Super Mini - Relay Module Ready ");
  Serial.println(" Relay Pin: GPIO 2 | Status LED: GPIO 8   ");
  Serial.println(" Send '1' for Relay ON | '0' for Relay OFF");
  Serial.println("==========================================");
}

void loop() {
  // Check for Serial Monitor input (Instant execution)
  if (Serial.available() > 0) {
    char cmd = Serial.read();
    if (cmd == '1') {
      Serial.println("[Command] Relay turned ON");
      digitalWrite(RELAY_PIN, RELAY_ON);
      digitalWrite(ONBOARD_LED, LOW); // Turn Onboard LED ON
    } else if (cmd == '0') {
      Serial.println("[Command] Relay turned OFF");
      digitalWrite(RELAY_PIN, RELAY_OFF);
      digitalWrite(ONBOARD_LED, HIGH); // Turn Onboard LED OFF
    }
  }
}
