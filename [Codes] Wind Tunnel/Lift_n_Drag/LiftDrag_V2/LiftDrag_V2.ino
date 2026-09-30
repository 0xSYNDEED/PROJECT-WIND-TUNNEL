#include <HX711.h>
#include <EEPROM.h>
#include <math.h>

// ========== PIN DEFINITIONS ==========
const int LIFT_DOUT = 2;
const int LIFT_SCK  = 3;
const int DRAG_DOUT = 6;
const int DRAG_SCK  = 7;
const int PITOT_PIN = A3;   // MPXV7002DP on the Pitot-static tube (same pin as pressure_readings.ino)

HX711 scaleLift;
HX711 scaleDrag;

// ========== PITOT / FLOW CONSTANTS ==========
const float V_REF       = 4.93;                // measured 5 V rail
const float AIR_DENSITY = 1.164;               // kg/m^3 at 30 C
const float SENSITIVITY = 1.0 * (V_REF / 5.0); // V per kPa (MPXV7002DP is ratiometric)
const float G_ACC       = 9.788;               // m/s^2, local gravity (Dhaka), grams -> newtons
const float Q_MIN_VEL   = 0.5;                 // Pa: below this, velocity is reported as 0
const float Q_MIN_COEF  = 5.0;                 // Pa (~2.9 m/s): below this, CdA/ClA are reported as nan

// Lever amplification. Leave at 1.0 if the calibration masses were hung at the
// model/sting (the calibration slope then already contains the lever ratio).
// If the masses were hung directly on the load cells, set these to 4.0 / 4.5.
const float LIFT_LEVER = 1.0;
const float DRAG_LEVER = 1.0;

float offsetVoltage = 0.0;   // Pitot zero-pressure baseline (fan OFF)

// ========== CALIBRATION PARAMETERS ==========
float slopeLift = 0.0, interceptLift = 0.0;
float slopeDrag = 0.0, interceptDrag = 0.0;
bool calibrated = false;

// EEPROM storage – only slopes are saved
struct CalData {
  float slopeLift;
  float slopeDrag;
};
CalData calData;

// ========== CALIBRATION DATA COLLECTION ==========
const int MAX_POINTS = 20;
int pointCount = 0;

// ========== STREAMING ACCUMULATORS ==========
// The HX711s run at 10 samples/s, so each one is "ready" only every ~100 ms.
// Instead of blocking while we wait for them, the Pitot ADC is sampled every
// 1 ms in the meantime. One output line = HX_SAMPLES readings from each load
// cell plus every Pitot sample taken over the same time window (~500 samples).
const int HX_SAMPLES = 5;                    // ~2 lines per second at 10 SPS
const unsigned long ADC_INTERVAL_US = 1000;  // Pitot sampling period

long adcSum = 0;      unsigned long adcCount = 0;
long liftRawSum = 0;  int liftCount = 0;
long dragRawSum = 0;  int dragCount = 0;
unsigned long lastAdcMicros = 0;

void resetAccumulators() {
  adcSum = 0;     adcCount = 0;
  liftRawSum = 0; liftCount = 0;
  dragRawSum = 0; dragCount = 0;
}

// ========== HELPER: READ AVERAGE RAW VALUE ==========
float readAverage(HX711 &scale, int samples = 10, int delayMs = 10) {
  long sum = 0;
  for (int i = 0; i < samples; i++) {
    while (!scale.is_ready()) delay(5);
    sum += scale.get_units(1);   // raw value (scale factor = 1)
    delay(delayMs);
  }
  return (float)sum / samples;
}

// ========== HELPER: CLEAR SERIAL BUFFER ==========
void clearSerial() {
  delay(50);
  while (Serial.available()) Serial.read();
}

void waitForKey() {
  while (!Serial.available()) delay(10);
  clearSerial();
}

void printHeader() {
  Serial.println("Velocity_m/s,Drag_g,Lift_g,CdA_m2,ClA_m2");
}

// ========== TARE FUNCTIONS ==========
void doLoadCellTare() {
  float rawTareLift = 0, rawTareDrag = 0;
  for (int i = 0; i < 10; i++) {
    rawTareLift += readAverage(scaleLift, 5, 10);
    rawTareDrag += readAverage(scaleDrag, 5, 10);
  }
  rawTareLift /= 10.0;
  rawTareDrag /= 10.0;

  // Intercept = -slope * rawTare  => mass = 0 when raw = rawTare
  if (fabs(slopeLift) > 1e-6) interceptLift = -slopeLift * rawTareLift;
  else interceptLift = 0;
  if (fabs(slopeDrag) > 1e-6) interceptDrag = -slopeDrag * rawTareDrag;
  else interceptDrag = 0;

  Serial.println("Lift and Drag zeroed.");
}

void doPitotTare() {
  // Same mandatory zero-pressure tare as pressure_readings.ino (fan OFF)
  long sum = 0;
  for (int i = 0; i < 100; i++) {
    sum += analogRead(PITOT_PIN);
    delay(10);
  }
  offsetVoltage = (sum / 100.0) * V_REF / 1023.0;

  Serial.print("Pitot baseline zero-voltage: ");
  Serial.print(offsetVoltage, 4);
  Serial.println(" V");
}

// Load cells only (used inside the calibration routine)
void tareLoadCells() {
  Serial.println("\nRemove any load from both cells, then press any key...");
  waitForKey();
  doLoadCellTare();
  Serial.println("✅ Tare complete.");
}

// Load cells + Pitot (startup and the 't' command)
void tareAll() {
  Serial.println("\nFan OFF and no load on the model, then press any key to tare...");
  waitForKey();
  doLoadCellTare();
  doPitotTare();
  Serial.println("✅ Tare complete (load cells + Pitot).");
}

// ========== INDIVIDUAL CALIBRATION ROUTINE ==========
void runCalibration(char sensorType) {
  String sensorName = (sensorType == 'l') ? "LIFT" : "DRAG";
  HX711* activeScale = (sensorType == 'l') ? &scaleLift : &scaleDrag;

  float rawPoints[MAX_POINTS];
  float massPoints[MAX_POINTS];

  Serial.print("\n--- START CALIBRATION: ");
  Serial.print(sensorName);
  Serial.println(" ---");
  Serial.print("Apply known mass to ");
  Serial.print(sensorName);
  Serial.println(" (or type 'x' to finish).");
  pointCount = 0;

  while (pointCount < MAX_POINTS) {
    Serial.print("\nEnter mass in grams (or 'x' to finish): ");
    while (!Serial.available()) delay(10);
    String input = Serial.readStringUntil('\n');
    input.trim();
    clearSerial();

    if (input.equalsIgnoreCase("x")) break;

    float mass = input.toFloat();
    if (mass < 0) {
      Serial.println("Mass must be >= 0.");
      continue;
    }

    // Read only the active scale
    float rawVal = readAverage(*activeScale, 10, 10);

    rawPoints[pointCount] = rawVal;
    massPoints[pointCount] = mass;
    pointCount++;

    Serial.print("Recorded: "); Serial.print(mass); Serial.println(" g");
    Serial.print(sensorName); Serial.print(" raw = "); Serial.println(rawVal);
  }

  if (pointCount < 2) {
    Serial.println("Not enough points. Aborting calibration.");
    return;
  }

  // ---- Least-squares fit ----
  float sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
  for (int i = 0; i < pointCount; i++) {
    float x = rawPoints[i];
    float y = massPoints[i];
    sumX += x;
    sumY += y;
    sumXY += x * y;
    sumX2 += x * x;
  }

  float denom = pointCount * sumX2 - sumX * sumX;
  float calculatedSlope = 0.0;
  float calculatedIntercept = 0.0;

  if (fabs(denom) > 1e-6) {
    calculatedSlope = (pointCount * sumXY - sumX * sumY) / denom;
    calculatedIntercept = (sumY - calculatedSlope * sumX) / pointCount;

    if (sensorType == 'l') {
      slopeLift = calculatedSlope;
      interceptLift = calculatedIntercept;
    } else {
      slopeDrag = calculatedSlope;
      interceptDrag = calculatedIntercept;
    }
  } else {
    Serial.println("Calibration failed (denominator zero).");
    return;
  }

  // ---- Display results ----
  Serial.println("\n--- CALIBRATION RESULTS ---");
  Serial.print(sensorName); Serial.print(": slope = "); Serial.print(calculatedSlope, 6);
  Serial.print(", intercept = "); Serial.println(calculatedIntercept, 6);

  // ---- Verification (optional) ----
  Serial.print("\nApply a known weight to "); Serial.print(sensorName); Serial.println(" and type its mass to verify.");
  Serial.println("Type 's' to save and exit, 't' to tare first, or 'r' to redo.");

  while (true) {
    while (!Serial.available()) delay(10);
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    clearSerial();

    if (cmd.equalsIgnoreCase("s")) {
      calData.slopeLift = slopeLift;
      calData.slopeDrag = slopeDrag;
      EEPROM.put(0, calData);
      calibrated = true;
      Serial.println("✅ Calibration saved to EEPROM.");
      break;
    } else if (cmd.equalsIgnoreCase("t")) {
      tareLoadCells();
      Serial.println("Tared. Continue verification or type 's' to save.");
    } else if (cmd.equalsIgnoreCase("r")) {
      Serial.println("Aborting save. Restarting calibration loop...");
      return;
    } else {
      float testMass = cmd.toFloat();
      if (testMass > 0) {
        float rawTest = readAverage(*activeScale, 10, 10);
        // use the live intercept so a 't' tare during verification is respected
        float liveIntercept = (sensorType == 'l') ? interceptLift : interceptDrag;
        float computed = calculatedSlope * rawTest + liveIntercept;
        Serial.print(sensorName); Serial.print(" reads: "); Serial.print(computed, 3); Serial.print(" g  (error = ");
        Serial.print(computed - testMass, 3); Serial.println(" g)");
      } else {
        Serial.println("Enter a mass to test, 's' to save, 't' to tare, or 'r' to redo.");
      }
    }
  }
}

// ========== CONTINUOUS MEASUREMENT (non-blocking) ==========
void streamMeasurements() {
  // 1. Pitot: sample the ADC every ADC_INTERVAL_US while waiting on the HX711s
  unsigned long now = micros();
  if (now - lastAdcMicros >= ADC_INTERVAL_US) {
    lastAdcMicros = now;
    adcSum += analogRead(PITOT_PIN);
    adcCount++;
  }

  // 2. Load cells: grab a reading only when a new conversion is ready
  if (liftCount < HX_SAMPLES && scaleLift.is_ready()) {
    liftRawSum += scaleLift.read();
    liftCount++;
  }
  if (dragCount < HX_SAMPLES && scaleDrag.is_ready()) {
    dragRawSum += scaleDrag.read();
    dragCount++;
  }

  // 3. Window complete -> compute and print one line
  if (liftCount < HX_SAMPLES || dragCount < HX_SAMPLES || adcCount == 0) return;

  // Forces (grams, then newtons)
  float rawL = (float)liftRawSum / liftCount;
  float rawD = (float)dragRawSum / dragCount;
  float lift_g = (slopeLift * rawL + interceptLift) / LIFT_LEVER;
  float drag_g = (slopeDrag * rawD + interceptDrag) / DRAG_LEVER;
  float lift_N = lift_g * 1e-3 * G_ACC;
  float drag_N = drag_g * 1e-3 * G_ACC;

  // Pitot -> dynamic pressure -> velocity (same method as pressure_readings.ino)
  float V_out    = ((float)adcSum / adcCount) * V_REF / 1023.0;
  float deltaV   = V_out - offsetVoltage;
  float q_Pa     = fabs(deltaV / SENSITIVITY * 1000.0);
  float velocity = 0.0;
  if (q_Pa > Q_MIN_VEL) velocity = sqrt((2.0 * q_Pa) / AIR_DENSITY);

  // Force coefficients times reference area [m^2]:  CxA = F / (0.5 * rho * U^2)
  // (0.5*rho*U^2 is just q_Pa again, so the assumed density cancels out here;
  //  it only affects the printed velocity.)
  float q_inf = 0.5 * AIR_DENSITY * velocity * velocity;
  float CdA = NAN, ClA = NAN;
  if (q_Pa > Q_MIN_COEF) {
    CdA = drag_N / q_inf;
    ClA = lift_N / q_inf;
  }

  // Output: velocity, drag, lift, Cd*A, Cl*A
  Serial.print(velocity, 2); Serial.print(',');
  Serial.print(drag_g, 2);   Serial.print(',');
  Serial.print(lift_g, 2);   Serial.print(',');
  Serial.print(CdA, 7);      Serial.print(',');
  Serial.println(ClA, 7);

  resetAccumulators();
}

// ========== SETUP ==========
void setup() {
  Serial.begin(9600);
  while (!Serial) ;
  Serial.setTimeout(50);

  scaleLift.begin(LIFT_DOUT, LIFT_SCK);
  scaleDrag.begin(DRAG_DOUT, DRAG_SCK);

  Serial.println("\n=== DUAL LOAD CELL + PITOT SYSTEM ===");

  // ---- Load saved slopes (blank EEPROM reads back as NaN, so reject that) ----
  EEPROM.get(0, calData);
  bool validCal = !isnan(calData.slopeLift) && !isnan(calData.slopeDrag) &&
                  (calData.slopeLift != 0.0 || calData.slopeDrag != 0.0);
  if (validCal) {
    slopeLift = calData.slopeLift;
    slopeDrag = calData.slopeDrag;
    calibrated = true;
    Serial.println("Previous calibration found in memory.");
  } else {
    Serial.println("No saved calibration. Use 'cl' or 'cd' to calibrate.");
  }

  // ---- Always perform a tare at startup (fan OFF) ----
  Serial.println("Performing initial tare...");
  tareAll();

  // ---- Menu ----
  Serial.println("\nCommands:");
  Serial.println("  t   - tare load cells + Pitot (fan OFF, no load)");
  Serial.println("  cl  - run calibration for LIFT");
  Serial.println("  cd  - run calibration for DRAG");
  Serial.println("  s   - save current slopes to EEPROM");
  Serial.println("  p   - print current calibration parameters");
  Serial.println("\nReady. Turn the fan on whenever you like.");
  printHeader();

  resetAccumulators();
  lastAdcMicros = micros();
}

// ========== MAIN LOOP ==========
void loop() {
  // Check for serial commands
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    clearSerial();

    if (cmd.equalsIgnoreCase("t")) {
      tareAll();
    }
    else if (cmd.equalsIgnoreCase("cl")) {
      runCalibration('l');
    }
    else if (cmd.equalsIgnoreCase("cd")) {
      runCalibration('d');
    }
    else if (cmd.equalsIgnoreCase("s")) {
      calData.slopeLift = slopeLift;
      calData.slopeDrag = slopeDrag;
      EEPROM.put(0, calData);
      Serial.println("✅ Both slopes saved to EEPROM.");
    }
    else if (cmd.equalsIgnoreCase("p")) {
      Serial.println("\n--- Current Parameters ---");
      Serial.print("Lift: slope = "); Serial.print(slopeLift, 6); Serial.print(", intercept = "); Serial.println(interceptLift, 6);
      Serial.print("Drag: slope = "); Serial.print(slopeDrag, 6); Serial.print(", intercept = "); Serial.println(interceptDrag, 6);
      Serial.print("Pitot zero-voltage = "); Serial.print(offsetVoltage, 4); Serial.println(" V");
    }
    else if (cmd.length() > 0) {
      Serial.println("Unknown command. Use t, cl, cd, s, p.");
    }

    // Discard any half-filled window (commands can block for a while)
    resetAccumulators();
    printHeader();
  }

  // ---- Continuous measurement output ----
  if (calibrated && slopeLift != 0 && slopeDrag != 0) {
    streamMeasurements();
  } else {
    static unsigned long lastMsg = 0;
    if (millis() - lastMsg > 3000) {
      Serial.println("Missing calibration on one or both sensors. Type 'cl' or 'cd'.");
      lastMsg = millis();
    }
  }
}