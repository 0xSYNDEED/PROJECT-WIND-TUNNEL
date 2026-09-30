const int sensorPin = A3;
const float V_REF = 4.93;          // Your exact measured voltage rail
const float air_density = 1.164;   // kg/m^3 for 30°C air

float offsetVoltage = 0.0;
float actualSensitivity = 1.0 * (V_REF / 5.0);

// Reference Pitot voltage after measuring U_inf
float pitotVoltage = 0.0;

void setup() {
  Serial.begin(9600);
  while (!Serial) { ; }

  Serial.println("STEP 1: Fan OFF. Calibrating zero-pressure baseline...");
  delay(2000);

  // MANDATORY TARE
  long sum = 0;
  for (int i = 0; i < 100; i++) {
    sum += analogRead(sensorPin);
    delay(10);
  }

  float avgADC = sum / 100.0;
  offsetVoltage = (avgADC * V_REF) / 1023.0;

  Serial.print("Baseline Zero-Voltage: ");
  Serial.print(offsetVoltage, 4);
  Serial.println(" V");

  Serial.println("-------------------------------------");

  Serial.println("STEP 2: Turn the fan ON and let the wind stabilize.");
  Serial.println("Type ANY character and press Enter to start measuring...");

  while (Serial.available() == 0) { }

  delay(50);
  while (Serial.available() > 0) {
    Serial.read();
  }

  Serial.println("-------------------------------------");

  // -------------------------------------------------
  // REFERENCE PITOT MEASUREMENT
  // -------------------------------------------------

  Serial.println("Measuring reference Pitot pressure...");

  sum = 0;
  for (int i = 0; i < 50; i++) {
    sum += analogRead(sensorPin);
    delay(5);
  }

  avgADC = sum / 50.0;
  pitotVoltage = (avgADC * V_REF) / 1023.0;

  float pitotDeltaV = pitotVoltage - offsetVoltage;

  // Convert Pitot voltage difference to pressure
  float pitotDeltaP_kPa = pitotDeltaV / actualSensitivity;
  float pitotPressure_Pa = fabs(pitotDeltaP_kPa * 1000.0);

  // Dynamic pressure q_inf
  float q_inf = pitotPressure_Pa;

  // Reference velocity
  float U_inf = 0.0;

  if (q_inf > 0.5) {
    U_inf = sqrt((2.0 * q_inf) / air_density);
  }

  Serial.print("Pitot Voltage: ");
  Serial.print(pitotVoltage, 4);
  Serial.println(" V");

  Serial.print("Reference Dynamic Pressure: ");
  Serial.print(q_inf, 1);
  Serial.println(" Pa");

  Serial.print("Reference Velocity U_inf: ");
  Serial.print(U_inf, 2);
  Serial.println(" m/s");

  Serial.println("-------------------------------------");
  Serial.println("Measuring live pressure and Cp...");
}

void loop() {

  // 1. Read sensor
  long sum = 0;

  for (int i = 0; i < 20; i++) {
    sum += analogRead(sensorPin);
    delay(5);
  }

  float avgADC = sum / 20.0;

  // 2. Convert ADC to voltage
  float V_out = (avgADC * V_REF) / 1023.0;

  // Voltage difference from zero-pressure baseline
  float deltaV = V_out - offsetVoltage;

  // 3. Convert voltage to pressure
  float deltaP_kPa = deltaV / actualSensitivity;

  float pressure_Pa = delta_kPa*1000;
  float abs_pressure_Pa = fabs(deltaP_kPa * 1000.0);

  // 4. Calculate velocity from absolute pressure
  float velocity = 0.0;

  if (abs_pressure_Pa > 0.5) {
    velocity = sqrt((2.0 * abs_pressure_Pa) / air_density);
  }

  // -------------------------------------------------
  // 5. DIRECT VOLTAGE-RATIO Cp
  // -------------------------------------------------

  float Cp = 0.0;

  float pitotDeltaV = pitotVoltage - offsetVoltage;

  if (fabs(pitotDeltaV) > 0.001) {
    Cp = deltaV / pitotDeltaV;
  }

  // -------------------------------------------------
  // 6. Local velocity ratio from Cp
  // -------------------------------------------------

  float velocityRatio = sqrt(1.0 - Cp);

  // -------------------------------------------------
  // 7. Output
  // -------------------------------------------------

  Serial.print("Voltage: ");
  Serial.print(V_out, 4);
  Serial.print(" V  |  ");

  Serial.print("Dynamic Pressure: ");
  Serial.print(pressure_Pa, 1);
  Serial.print(" Pa  |  ");

  Serial.print("Velocity: ");
  Serial.print(velocity, 2);
  Serial.print(" m/s  |  ");

  Serial.print("Cp (V-ratio): ");
  Serial.print(Cp, 4);
  Serial.print("  |  ");

  Serial.print("U/U_inf: ");
  Serial.print(velocityRatio, 3);

  Serial.println();

  delay(250);
}