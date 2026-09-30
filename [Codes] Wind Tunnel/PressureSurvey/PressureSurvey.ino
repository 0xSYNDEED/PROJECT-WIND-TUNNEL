// ============================================================
//  Surface-pressure (Cp) survey with one MPXV7002DP on A3
//
//  Tubing convention:
//    "upper" tube = sensor's positive port (P1)
//    "lower" tube = sensor's reference port (P2) -> stays on Pitot STATIC
//
//  1. Fan OFF, both tubes on the Pitot tube   -> zero-pressure tare (once)
//  2. Fan ON, upper on Pitot TOTAL            -> q_inf and U_inf
//  3. Upper moved to tap 1..8, one key each   -> CSV row per tap
//  4. After tap 8 it automatically goes back to step 2.
//  Type X at any point (after the zero) to reset back to step 2.
// ============================================================

const int   sensorPin   = A3;
const float V_REF       = 4.93;                // measured 5 V rail
const float air_density = 1.164;               // kg/m^3 for 30 C air
const float SENSITIVITY = 1.0 * (V_REF / 5.0); // V per kPa (ratiometric)

const int           NUM_TAPS        = 8;
const int           N_SAMPLES       = 1000;  // samples averaged per reading
const int           SAMPLE_DELAY_MS = 2;     // -> ~2.1 s per reading
const unsigned long SETTLE_MS       = 1000;  // wait after tube swap before sampling
const float         Q_MIN           = 5.0;   // Pa (~2.9 m/s): below this, fan is treated as off

float offsetVoltage = 0.0;   // zero-pressure baseline
float q_inf = 0.0;           // freestream dynamic pressure [Pa]
float U_inf = 0.0;           // freestream velocity [m/s]

// ---------- helpers ----------

// Print x to 3 significant figures, right-aligned in a field of `width` chars
// (e.g. 17.4, 88.0, -108, 0.500, -0.0556)
void printSig3(float x, int width) {
  char buf[20];
  int decimals = 2;
  float a = fabs(x);
  if (a > 0) {
    int mag = (int)floor(log10(a));
    decimals = 2 - mag;
    if (decimals < 0) decimals = 0;
    // rounding can push it up a decade (9.996 -> 10.0): drop one decimal
    float p = pow(10, decimals);
    if (decimals > 0 && round(a * p) / p >= pow(10, mag + 1)) decimals--;
  }
  dtostrf(x, width, decimals, buf);   // AVR has no %f in sprintf
  Serial.print(buf);
}

// Drain the serial buffer. Returns true if an X was among the bytes.
// Anything else typed while a reading is in progress is discarded, so an
// accidental extra key press doesn't skip a tap.
bool resetPressed() {
  bool x = false;
  while (Serial.available() > 0) {
    char r = Serial.read();
    if (r == 'x' || r == 'X') x = true;
  }
  return x;
}

// Wait ms milliseconds; returns false if X was pressed meanwhile.
bool waitAbortable(unsigned long ms) {
  unsigned long t0 = millis();
  while (millis() - t0 < ms) {
    if (resetPressed()) return false;
  }
  return true;
}

// Average N_SAMPLES ADC reads -> sensor output voltage.
// If allowAbort, returns false as soon as X is pressed.
bool readVoltage(float &V, bool allowAbort) {
  long sum = 0;
  for (int i = 0; i < N_SAMPLES; i++) {
    sum += analogRead(sensorPin);
    delay(SAMPLE_DELAY_MS);
    if (allowAbort && resetPressed()) return false;
  }
  V = ((float)sum / N_SAMPLES) * V_REF / 1023.0;
  return true;
}

// Settle, then read signed pressure (upper - lower) in Pa, offset removed.
// Returns false if X was pressed.
bool readPressurePa(float &p) {
  if (!waitAbortable(SETTLE_MS)) return false;
  float V;
  if (!readVoltage(V, true)) return false;
  p = ((V - offsetVoltage) / SENSITIVITY) * 1000.0;
  return true;
}

// Wait for the user to send anything; return its first non-space char (upper-case).
// Just pressing Enter counts too (returns '\n').
char waitForKey() {
  while (Serial.available() == 0) { }
  delay(50);                       // let the rest of the line arrive
  char c = '\n';
  while (Serial.available() > 0) {
    char r = Serial.read();
    if (c == '\n' && r != '\n' && r != '\r' && r != ' ') c = r;
  }
  return toupper(c);
}

// Measure q_inf and U_inf. Returns false if unusable or X was pressed.
bool measureVelocity() {
  Serial.println("-------------------------------------");
  Serial.println("Upper tube -> Pitot TOTAL, lower tube -> Pitot STATIC.");
  Serial.println("Fan ON, let it stabilise, then press any key to measure wind speed...");
  waitForKey();
  Serial.println("Measuring wind speed...");

  float p;
  if (!readPressurePa(p)) {
    Serial.println("RESET.");
    return false;
  }
  if (p < -Q_MIN) {
    Serial.print("Negative Pitot reading (");
    Serial.print(p, 1);
    Serial.println(" Pa). Tubes swapped? Fix and retry.");
    return false;
  }
  if (p < Q_MIN) {
    Serial.print("Pitot reading only ");
    Serial.print(p, 1);
    Serial.println(" Pa. Is the fan on? Retry.");
    return false;
  }

  q_inf = p;
  U_inf = sqrt((2.0 * q_inf) / air_density);

  Serial.print("Wind speed: ");
  printSig3(U_inf, 0);
  Serial.print(" m/s   (q_inf = ");
  printSig3(q_inf, 0);
  Serial.println(" Pa)");
  return true;
}

// ---------- setup: zero-pressure tare (once) ----------
void setup() {
  Serial.begin(9600);
  while (!Serial) { ; }

  Serial.println("=== PITOT + SURFACE PRESSURE SURVEY ===");
  Serial.println("Fan OFF. Connect BOTH sensor tubes to the Pitot tube.");
  Serial.println("Press any key to take the zero-pressure reading...");
  waitForKey();
  delay(SETTLE_MS);

  readVoltage(offsetVoltage, false);
  Serial.print("Baseline zero-voltage: ");
  Serial.print(offsetVoltage, 4);
  Serial.println(" V");
}

// ---------- loop: one full set = velocity + 8 taps ----------
void loop() {
  // 1. Wind speed (retries until valid)
  while (!measureVelocity()) { }

  // 2. Instructions once, then a clean CSV table
  Serial.println("-------------------------------------");
  Serial.print("Move the upper tube to each tap in turn (1 to ");
  Serial.print(NUM_TAPS);
  Serial.println(") and press any key to record it.");
  Serial.println("X at any time = reset and re-measure wind speed.");
  Serial.println();
  // column widths: Tap 3 | U 7 | P 8 | Cp 8
  Serial.println("Tap,   U_m/s,     P_Pa,       Cp");

  for (int tap = 1; tap <= NUM_TAPS; tap++) {
    if (waitForKey() == 'X') {
      Serial.println("RESET.");
      return;                       // loop() restarts -> velocity
    }

    float p_Pa;
    if (!readPressurePa(p_Pa)) {    // X pressed during the reading
      Serial.println("RESET.");
      return;
    }
    float Cp = p_Pa / q_inf;        // (p_tap - p_inf) / q_inf

    // Output: <tap>, <U_inf>, <Pa>, <Cp>   (aligned columns, 3 sig. figs)
    if (tap < 100) Serial.print(' ');
    if (tap < 10)  Serial.print(' ');
    Serial.print(tap);          Serial.print(", ");
    printSig3(U_inf, 7);        Serial.print(", ");
    printSig3(p_Pa, 8);         Serial.print(", ");
    printSig3(Cp, 8);           Serial.println();
  }

  // 3. Set finished -> automatically start over from velocity
  Serial.println();
  Serial.println("All taps done. Starting a new set.");
}