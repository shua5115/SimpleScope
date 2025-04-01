#define BAUD 115200
#define PERIOD_US 500 // microseconds per sample

void setup() {
  Serial.begin(BAUD);
}

void loop() {
  unsigned long end_time = micros() + PERIOD_US;
  uint16_t a = analogRead(0);
  uint16_t b = analogRead(1);
  // little-endian byte order
  char msg[4] = {
    (uint8_t) a,
    (uint8_t) (a >> 8) | 0b10000000, // label channel A with a 1 bit in the MSB
    (uint8_t) b,
    (uint8_t) (b >> 8) & 0b01111111, // label channel B with a 0 bit in the MSB
  };
  Serial.write(msg, 4);
  while(micros() < end_time) {
  }
}
