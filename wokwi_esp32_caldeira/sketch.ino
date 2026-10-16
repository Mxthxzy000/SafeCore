// =====================================================
// SAFECORE - MONITORAMENTO INDUSTRIAL IoT
// ESP32 + MQTT + Wokwi — Setor: Caldeira (Quimex)
// =====================================================

#include <WiFi.h>
#include <Wire.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <Adafruit_BMP085.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// WIFI (Wokwi)
const char* WIFI_SSID = "Wokwi-GUEST";
const char* WIFI_PASSWORD = "";

// MQTT - Broker Público e Sala do Setor Caldeira da Quimex
const char* MQTT_HOST = "broker.mqtt.cool";
const uint16_t MQTT_PORT = 1883;
const char* COMPANY_ID = "quimex";
const char* SECTOR_ID = "caldeira";
const char* DEVICE_ID = "quimex-caldeira-01";
const char* MQTT_BASE = "safecore/quimex/caldeira";

// PINOS
#define DHT_PIN 15
#define DHT_TYPE DHT22
#define MQ2_PIN 34
#define FAN_PIN 25
#define EMERGENCY_LED 26
#define BUZZER_PIN 27
#define MANUAL_SWITCH 14
#define DS18B20_PIN 4

// SENSORES E CONEXOES
DHT dht(DHT_PIN, DHT_TYPE);
Adafruit_BMP085 bmp;
OneWire oneWire(DS18B20_PIN);
DallasTemperature boilerTempSensor(&oneWire);

WiFiClient wifiClient;
PubSubClient mqtt(wifiClient);

// LIMITES DE SEGURANCA DA CALDEIRA
const float TEMP_FAN_ON_C = 30.0;
const float TEMP_EMERGENCY_C = 45.0;
const float HUMIDITY_WARNING_PERCENT = 80.0;

const int GAS_WARNING_RAW = 1800;
const int GAS_EMERGENCY_RAW = 2500;

const float BOILER_TEMP_WARNING_C = 50.0;
const float BOILER_TEMP_EMERGENCY_C = 55.0;

const float PRESSURE_WARNING_HPA = 1030.0;
const float PRESSURE_EMERGENCY_HPA = 1050.0;

// INTERVALOS
const unsigned long SENSOR_INTERVAL_MS = 1000;
const unsigned long MQTT_INTERVAL_MS = 2000;
const unsigned long WIFI_RETRY_MS = 5000;
const unsigned long MQTT_RETRY_MS = 3000;

// ESTADO DOS SENSORES
float ambientTempC = NAN;
float humidityPercent = NAN;
float boilerTempC = NAN;
float pressureHpa = NAN;
float pressureBar = NAN;
float gasLelPercent = 0.0;
int gasRaw = 0;

bool bmpAvailable = false;
bool fanOn = false;
bool emergency = false;
bool manualVentilation = false;
bool remoteVentilation = false;

bool ambientSensorFault = true;
bool boilerSensorFault = true;
bool pressureSensorFault = true;

String riskLevel = "INICIALIZANDO";
String riskReasons = "";

unsigned long lastSensorRead = 0;
unsigned long lastPublish = 0;
unsigned long lastWifiAttempt = 0;
unsigned long lastMqttAttempt = 0;

// =====================================================
// CALLBACK MQTT (COMANDOS REMOTOS DO APP FLUTTER)
// =====================================================
void onMqttMessage(char* topic, byte* payload, unsigned int length) {
  String msg;
  for (unsigned int i = 0; i < length; i++) {
    msg += (char)payload[i];
  }
  msg.trim();

  Serial.print("[MQTT] Comando recebido em ");
  Serial.print(topic);
  Serial.print(": ");
  Serial.println(msg);

  if (msg.indexOf("ventilacao") >= 0 || msg == "FAN_ON") {
    remoteVentilation = true;
    digitalWrite(FAN_PIN, HIGH);
  } else if (msg == "FAN_OFF" || msg.indexOf("liberacao") >= 0) {
    remoteVentilation = false;
  }
}

// =====================================================
// CONEXAO WIFI (NAO BLOQUEANTE)
// =====================================================
void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;

  unsigned long now = millis();
  if (now - lastWifiAttempt < WIFI_RETRY_MS) return;

  lastWifiAttempt = now;
  Serial.println("[WiFi] Conectando ao Wi-Fi...");
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
}

// =====================================================
// CONEXAO MQTT (NAO BLOQUEANTE COM CLIENT ID UNICO)
// =====================================================
void connectMQTT() {
  if (WiFi.status() != WL_CONNECTED || mqtt.connected()) return;

  unsigned long now = millis();
  if (now - lastMqttAttempt < MQTT_RETRY_MS) return;

  lastMqttAttempt = now;

  // Garante um ClientID único a cada reconexão
  String clientId = String("SafeCore-") + DEVICE_ID + "-" + String(random(1000, 9999));
  String statusTopic = String(MQTT_BASE) + "/status";
  String cmdTopic = String(MQTT_BASE) + "/command";

  Serial.print("[MQTT] Tentando conexao com ");
  Serial.print(MQTT_HOST);
  Serial.print("...");

  // Last Will: informa 'offline' em caso de queda brusca
  bool connected = mqtt.connect(
    clientId.c_str(),
    statusTopic.c_str(),
    0,
    true,
    "offline"
  );

  if (connected) {
    Serial.println(" CONECTADO COM SUCESSO!");
    mqtt.publish(statusTopic.c_str(), "online", true);
    mqtt.subscribe(cmdTopic.c_str());
    Serial.print("[MQTT] Sala do Setor: ");
    Serial.println(MQTT_BASE);
  } else {
    Serial.print(" FALHA. Estado MQTT: ");
    Serial.println(mqtt.state());
  }
}

// =====================================================
// LEITURA DOS SENSORES
// =====================================================
void readSensors() {
  // 1. DHT22 (Temperatura Ambiente e Umidade da Caldeira)
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  ambientSensorFault = isnan(t) || isnan(h);
  if (!ambientSensorFault) {
    ambientTempC = t;
    humidityPercent = h;
  }

  // 2. MQ-2 (Gás Combustível - ADC 12 bits: 0..4095 -> 0..100 %LEL)
  gasRaw = analogRead(MQ2_PIN);
  gasLelPercent = (gasRaw / 4095.0f) * 100.0f;

  // 3. DS18B20 (Temperatura da Caldeira - Assíncrono)
  float bt = boilerTempSensor.getTempCByIndex(0);
  boilerSensorFault = (bt == DEVICE_DISCONNECTED_C || bt < -55.0 || bt > 125.0);
  if (!boilerSensorFault) {
    boilerTempC = bt;
  }
  boilerTempSensor.requestTemperatures();

  // 4. BMP180 (Pressão da Caldeira)
  if (bmpAvailable) {
    float p = bmp.readPressure() / 100.0f; // hPa
    pressureSensorFault = !isfinite(p) || p < 300.0f || p > 2000.0f;
    if (!pressureSensorFault) {
      pressureHpa = p;
      pressureBar = p / 1000.0f; // Conversão hPa -> bar para o app SafeCore
    }
  } else {
    pressureSensorFault = true;
  }

  Serial.println("\n------------------------------------");
  Serial.println("[SENSORES - CALDEIRA QUIMEX] Leitura realizada:");
  Serial.print(" - Temp. Ambiente: "); Serial.println(ambientSensorFault ? "FALHA" : String(ambientTempC, 1) + " C");
  Serial.print(" - Umidade (CLD-UMD-01): "); Serial.println(ambientSensorFault ? "FALHA" : String(humidityPercent, 1) + " %");
  Serial.print(" - Gas (CLD-GAS-01): "); Serial.println(String(gasLelPercent, 1) + " %LEL (ADC " + String(gasRaw) + ")");
  Serial.print(" - Temp. Caldeira (CLD-TMP-01): "); Serial.println(boilerSensorFault ? "FALHA" : String(boilerTempC, 1) + " C");
  Serial.print(" - Pressao (CLD-PRS-01): "); Serial.println((!bmpAvailable || pressureSensorFault) ? "N/A" : String(pressureBar, 2) + " bar (" + String(pressureHpa, 1) + " hPa)");
}

// =====================================================
// LOGICA DE SEGURANCA E ATUADORES
// =====================================================
void evaluateSafety() {
  bool gasWarning = gasRaw >= GAS_WARNING_RAW;
  bool gasCritical = gasRaw >= GAS_EMERGENCY_RAW;

  bool ambientHeatWarning = !ambientSensorFault && ambientTempC >= TEMP_FAN_ON_C;
  bool ambientHeatCritical = !ambientSensorFault && ambientTempC >= TEMP_EMERGENCY_C;

  bool boilerHeatWarning = !boilerSensorFault && boilerTempC >= BOILER_TEMP_WARNING_C;
  bool boilerHeatCritical = !boilerSensorFault && boilerTempC >= BOILER_TEMP_EMERGENCY_C;

  bool pressureWarning = !pressureSensorFault && pressureHpa >= PRESSURE_WARNING_HPA;
  bool pressureCritical = !pressureSensorFault && pressureHpa >= PRESSURE_EMERGENCY_HPA;

  bool sensorFault = ambientSensorFault && boilerSensorFault;

  fanOn = manualVentilation || remoteVentilation || gasWarning || ambientHeatWarning || boilerHeatWarning || sensorFault;
  emergency = gasCritical || ambientHeatCritical || boilerHeatCritical || pressureCritical || sensorFault;

  riskReasons = "";
  if (gasWarning) riskReasons += "GAS_DETECTADO;";
  if (gasCritical) riskReasons += "GAS_CRITICO;";
  if (ambientHeatWarning) riskReasons += "CALOR_AMBIENTE;";
  if (ambientHeatCritical) riskReasons += "CALOR_AMBIENTE_CRITICO;";
  if (!ambientSensorFault && humidityPercent >= HUMIDITY_WARNING_PERCENT) riskReasons += "UMIDADE_ALTA;";
  if (boilerHeatWarning) riskReasons += "CALDEIRA_TEMPERATURA_ALTA;";
  if (boilerHeatCritical) riskReasons += "CALDEIRA_TEMPERATURA_CRITICA;";
  if (pressureWarning) riskReasons += "PRESSAO_ALTA;";
  if (pressureCritical) riskReasons += "PRESSAO_CRITICA;";
  if (sensorFault) riskReasons += "FALHA_SENSOR;";
  if (manualVentilation || remoteVentilation) riskReasons += "VENTILACAO_ATIVA;";

  if (emergency) {
    riskLevel = "CRITICA";
  } else if (gasWarning || ambientHeatWarning || boilerHeatWarning || pressureWarning || (!ambientSensorFault && humidityPercent >= HUMIDITY_WARNING_PERCENT)) {
    riskLevel = "ATENCAO";
  } else {
    riskLevel = "SEGURA";
  }

  digitalWrite(FAN_PIN, fanOn ? HIGH : LOW);
  digitalWrite(EMERGENCY_LED, emergency ? HIGH : LOW);
  digitalWrite(BUZZER_PIN, emergency ? HIGH : LOW);

  Serial.print("[STATUS] Nivel de Risco: "); Serial.println(riskLevel);
  Serial.print("[ATUADORES] Exaustor: "); Serial.print(fanOn ? "LIGADO" : "DESLIGADO");
  Serial.print(" | Emergencia: "); Serial.println(emergency ? "ATIVA" : "INATIVA");
}

// =====================================================
// PUBLICACAO MQTT (JSON PARA O APP SAFECORE)
// =====================================================
void publishTelemetry() {
  if (!mqtt.connected()) {
    Serial.println("[MQTT] Telemetria retida: Sem conexao com o Broker.");
    return;
  }

  String topic = String(MQTT_BASE) + "/telemetry";

  char payload[640];
  char jsonAmbTemp[12], jsonHumidity[12], jsonBoilerTemp[12], jsonPressureHpa[12], jsonPressureBar[12], jsonGasLel[12];

  if (ambientSensorFault) {
    strcpy(jsonAmbTemp, "null");
    strcpy(jsonHumidity, "null");
  } else {
    snprintf(jsonAmbTemp, sizeof(jsonAmbTemp), "%.2f", ambientTempC);
    snprintf(jsonHumidity, sizeof(jsonHumidity), "%.2f", humidityPercent);
  }

  // Se o DS18B20 falhar, usa a temperatura do DHT22 como fallback para CLD-TMP-01
  if (!boilerSensorFault) {
    snprintf(jsonBoilerTemp, sizeof(jsonBoilerTemp), "%.2f", boilerTempC);
  } else if (!ambientSensorFault) {
    snprintf(jsonBoilerTemp, sizeof(jsonBoilerTemp), "%.2f", ambientTempC);
  } else {
    strcpy(jsonBoilerTemp, "null");
  }

  if (pressureSensorFault || !bmpAvailable) {
    // Caso o BMP180 não esteja conectado no esquemático Wokwi, envia 1013.25 hPa (1.01 bar) padrão ou null
    snprintf(jsonPressureHpa, sizeof(jsonPressureHpa), "%.2f", 1013.25);
    snprintf(jsonPressureBar, sizeof(jsonPressureBar), "%.2f", 1.01);
  } else {
    snprintf(jsonPressureHpa, sizeof(jsonPressureHpa), "%.2f", pressureHpa);
    snprintf(jsonPressureBar, sizeof(jsonPressureBar), "%.2f", pressureBar);
  }

  snprintf(jsonGasLel, sizeof(jsonGasLel), "%.2f", gasLelPercent);

  snprintf(payload, sizeof(payload),
    "{"
      "\"empresa\":\"%s\","
      "\"setor\":\"%s\","
      "\"codigo_setor\":\"CLD\","
      "\"device\":\"%s\","
      "\"uptime_ms\":%lu,"
      "\"ambiente\":{\"temp_c\":%s,\"umidade_pct\":%s,\"gas_adc\":%d,\"gas_lel\":%s},"
      "\"caldeira\":{\"temp_c\":%s,\"pressao_hpa\":%s,\"pressao_bar\":%s},"
      "\"sensores\":{"
        "\"CLD-TMP-01\":%s,"
        "\"CLD-PRS-01\":%s,"
        "\"CLD-UMD-01\":%s,"
        "\"CLD-GAS-01\":%s"
      "},"
      "\"atuadores\":{\"ventilacao\":%s,\"emergencia\":%s},"
      "\"risco\":\"%s\","
      "\"motivos\":\"%s\""
    "}",
    COMPANY_ID, SECTOR_ID, DEVICE_ID, millis(),
    jsonAmbTemp, jsonHumidity, gasRaw, jsonGasLel,
    jsonBoilerTemp, jsonPressureHpa, jsonPressureBar,
    jsonBoilerTemp, jsonPressureBar, jsonHumidity, jsonGasLel,
    fanOn ? "true" : "false", emergency ? "true" : "false",
    riskLevel.c_str(), riskReasons.c_str()
  );

  // Publica com retain = true para que o app Flutter receba o estado imediatamente ao abrir
  bool published = mqtt.publish(topic.c_str(), payload, true);

  if (published) {
    Serial.println("[MQTT] Telemetria enviada com sucesso!");
    Serial.print("[MQTT] Topico: ");
    Serial.println(topic);
    Serial.print("[MQTT] JSON: ");
    Serial.println(payload);

    String riskTopic = String(MQTT_BASE) + "/risk";
    mqtt.publish(riskTopic.c_str(), riskLevel.c_str(), true);

    String emergencyTopic = String(MQTT_BASE) + "/emergency";
    mqtt.publish(emergencyTopic.c_str(), emergency ? "true" : "false", true);
  } else {
    Serial.println("[MQTT] ERRO ao publicar mensagem no broker.");
  }
}

// =====================================================
// SETUP
// =====================================================
void setup() {
  Serial.begin(115200);
  randomSeed(micros());

  pinMode(FAN_PIN, OUTPUT);
  pinMode(EMERGENCY_LED, OUTPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(MANUAL_SWITCH, INPUT_PULLUP);

  digitalWrite(FAN_PIN, LOW);
  digitalWrite(EMERGENCY_LED, LOW);
  digitalWrite(BUZZER_PIN, LOW);

  analogReadResolution(12);

  dht.begin();

  // Configuração não bloqueante para o DS18B20
  boilerTempSensor.begin();
  boilerTempSensor.setWaitForConversion(false);
  boilerTempSensor.requestTemperatures();

  Wire.begin(21, 22);
  bmpAvailable = bmp.begin();

  if (bmpAvailable) {
    Serial.println("[BMP180] Sensor de pressao detectado com sucesso.");
  } else {
    Serial.println("[BMP180] Aviso: Sensor nao detectado. Usando pressao nominal de referencia.");
  }

  // Configuração do MQTT
  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setCallback(onMqttMessage);
  mqtt.setBufferSize(1024);
  mqtt.setKeepAlive(30);

  Serial.println("\n=== SAFECORE IoT - QUIMEX (SETOR: CALDEIRA) INICIALIZADO ===");
  connectWiFi();
}

// =====================================================
// LOOP PRINCIPAL
// =====================================================
void loop() {
  connectWiFi();

  if (WiFi.status() == WL_CONNECTED) {
    connectMQTT();
    if (mqtt.connected()) {
      mqtt.loop();
    }
  }

  unsigned long now = millis();

  // Leitura de Sensores e Regras de Segurança
  if (now - lastSensorRead >= SENSOR_INTERVAL_MS) {
    lastSensorRead = now;
    manualVentilation = (digitalRead(MANUAL_SWITCH) == LOW);
    readSensors();
    evaluateSafety();
  }

  // Disparo de Telemetria
  if (now - lastPublish >= MQTT_INTERVAL_MS) {
    lastPublish = now;
    publishTelemetry();
  }
}
