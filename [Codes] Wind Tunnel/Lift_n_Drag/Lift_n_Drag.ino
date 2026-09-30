#include <HX711.h>
#include <EEPROM.h>

// ========== PIN DEFINITIONS ==========
const int LIFT_DOUT = 2;
const int LIFT_SCK  = 3;
const int DRAG_DOUT = 6;
const int DRAG_SCK  = 7;

HX711 scaleLift;
HX711 scaleDrag;

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

// ========== TARE FUNCTION ==========
void tareLoadCells() {
  Serial.println("\nRemove any load from both cells, then press any key...");
  while (!Serial.available()) delay(10);
  clearSerial();

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

  Serial.println("✅ Tare complete. Lift and Drag are now zeroed.");
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

  // ---- Least‑squares fit ----
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
        float computed = calculatedSlope * rawTest + calculatedIntercept;
        Serial.print(sensorName); Serial.print(" reads: "); Serial.print(computed, 3); Serial.print(" g  (error = ");
        Serial.print(computed - testMass, 3); Serial.println(" g)");
      } else {
        Serial.println("Enter a mass to test, 's' to save, 't' to tare, or 'r' to redo.");
      }
    }
  }
}

// ========== SETUP ==========
void setup() {
  Serial.begin(9600);
  while (!Serial) ;   
  Serial.setTimeout(50); 

  scaleLift.begin(LIFT_DOUT, LIFT_SCK);
  scaleDrag.begin(DRAG_DOUT, DRAG_SCK);

  Serial.println("\n=== DUAL LOAD CELL SYSTEM ===");

  // ---- Load saved slopes ----
  EEPROM.get(0, calData);
  if (calData.slopeLift != 0.0 || calData.slopeDrag != 0.0) {
    slopeLift = calData.slopeLift;
    slopeDrag = calData.slopeDrag;
    calibrated = true;
    Serial.println("Previous calibration found in memory.");
  } else {
    Serial.println("No saved calibration. Use 'cl' or 'cd' to calibrate.");
  }

  // ---- Always perform a tare at startup ----
  Serial.println("Performing initial tare...");
  tareLoadCells();

  // ---- Menu ----
  Serial.println("\nCommands:");
  Serial.println("  t   - tare (re‑zero both sensors)");
  Serial.println("  cl  - run calibration for LIFT");
  Serial.println("  cd  - run calibration for DRAG");
  Serial.println("  s   - save current slopes to EEPROM");
  Serial.println("  p   - print current calibration parameters");
  Serial.println("\nReady.");
}

// ========== MAIN LOOP ==========
void loop() {
  // Check for serial commands
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    clearSerial();
    
    if (cmd.equalsIgnoreCase("t")) {
      tareLoadCells();
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
    }
    else if (cmd.length() > 0) {
      Serial.println("Unknown command. Use t, cl, cd, s, p.");
    }
  }

  // ---- Continuous measurement output ----
  if (calibrated && slopeLift != 0 && slopeDrag != 0) {
    static unsigned long lastPrint = 0;
    if (millis() - lastPrint > 500) {
      float rawL = readAverage(scaleLift, 5, 5);  
      float rawD = readAverage(scaleDrag, 5, 5);
      float lift_g = slopeLift * rawL + interceptLift;
      float drag_g = slopeDrag * rawD + interceptDrag;
      Serial.print("Lift: "); Serial.print(lift_g, 2); Serial.print(" g  |  Drag: ");
      Serial.print(drag_g, 2); Serial.println(" g");
      lastPrint = millis();
    }
  } else {
    static unsigned long lastMsg = 0;
    if (millis() - lastMsg > 3000) {
      Serial.println("Missing calibration on one or both sensors. Type 'cl' or 'cd'.");
      lastMsg = millis();
    }
  }
  delay(10);   
}