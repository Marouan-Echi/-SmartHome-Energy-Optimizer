#include <WiFi.h>
#include <PubSubClient.h>
#include <DHT.h>
#include <ArduinoJson.h>
#include <EEPROM.h>

// Configuration WiFi
const char* ssid = "BEE HUAWEI-41AD";      // Nom du réseau WiFi
const char* password = "lajoconde2025";    // Mot de passe WiFi

// Configuration MQTT
String mqttServer = "192.168.100.113";  // Adresse IP du serveur MQTT (modifiable)
const int mqttPort = 1883;
const char* mqttClientId = "ESP32EnergyMonitor";

// Broches des capteurs
#define DHT_PIN 4
#define DHT_TYPE DHT11
#define LDR_PIN 32
#define MQ2_PIN 33
#define CURRENT_SENSOR_PIN 34

// Broches des relais
const int relayPins[] = {25, 26, 27, 14}; // Relais 1-4

// Seuils d'alarme
float TEMP_SEUIL = 30.0;   // °C
int LUM_SEUIL = 500;       // 0-1023
int GAZ_SEUIL = 600;       // 0-1023

// Calibration ACS712
float ACS712_OFFSET = 0.12;
const float ACS712_SENSITIVITY = 0.185; // V/A pour ACS712 5A
const float CURRENT_THRESHOLD = 0.1;    // Seuil minimal de courant (A)

// Adresse EEPROM pour stocker l'adresse IP du serveur MQTT
#define EEPROM_SIZE 100
#define MQTT_SERVER_ADDR 0

// Objets
DHT dht(DHT_PIN, DHT_TYPE);
WiFiClient espClient;
PubSubClient client(espClient);

// Variables pour filtrage
float currentFilter = 0;
const float FILTER_ALPHA = 0.1; // Facteur de lissage

// Variables pour le contrôle manuel/automatique
bool manualControl[4] = {false, false, false, false};

void setup() {
  Serial.begin(115200);
  Serial.println("\nDémarrage du système de surveillance énergétique");
  
  // Initialisation EEPROM
  EEPROM.begin(EEPROM_SIZE);
  
  // Charger l'adresse IP du serveur MQTT depuis l'EEPROM
  loadMqttServerFromEEPROM();
  
  // Initialisation des relais
  for (int i = 0; i < 4; i++) {
    pinMode(relayPins[i], OUTPUT);
    digitalWrite(relayPins[i], HIGH); // Désactivation initiale (relais inversés)
  }
  
  // Initialisation des capteurs
  dht.begin();
  pinMode(LDR_PIN, INPUT);
  pinMode(MQ2_PIN, INPUT);
  
  // Configuration WiFi et MQTT
  setupWiFi();
  client.setServer(mqttServer.c_str(), mqttPort);
  client.setCallback(callback);
  
  // Calibration initiale du capteur de courant
  calibrateACS712();
}

// Charger l'adresse IP du serveur MQTT depuis l'EEPROM
void loadMqttServerFromEEPROM() {
  String savedServer = "";
  for (int i = 0; i < 20; i++) {
    char c = EEPROM.read(MQTT_SERVER_ADDR + i);
    if (c == 0) break;
    savedServer += c;
  }
  
  if (savedServer.length() > 0 && savedServer.length() < 20) {
    mqttServer = savedServer;
    Serial.println("Adresse IP du serveur MQTT chargée: " + mqttServer);
  }
}

// Sauvegarder l'adresse IP du serveur MQTT dans l'EEPROM
void saveMqttServerToEEPROM(String server) {
  for (int i = 0; i < server.length(); i++) {
    EEPROM.write(MQTT_SERVER_ADDR + i, server[i]);
  }
  EEPROM.write(MQTT_SERVER_ADDR + server.length(), 0);
  EEPROM.commit();
  Serial.println("Adresse IP du serveur MQTT sauvegardée: " + server);
}

void setupWiFi() {
  delay(10);
  Serial.println("\nConnexion au réseau WiFi: " + String(ssid));
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nConnecté au WiFi! Adresse IP: " + WiFi.localIP().toString());
  } else {
    Serial.println("\nÉchec de connexion au WiFi après plusieurs tentatives.");
  }
}

void reconnect() {
  int attempts = 0;
  while (!client.connected() && attempts < 5) {
    Serial.print("Tentative de connexion MQTT à " + mqttServer + "...");
    if (client.connect(mqttClientId)) {
      Serial.println("connecté!");
      
      // S'abonner aux topics de contrôle
      client.subscribe("control/relay1");
      client.subscribe("control/relay2");
      client.subscribe("control/relay3");
      client.subscribe("control/relay4");
      client.subscribe("control/server");
      
      // Publier un message de connexion
      client.publish("esp32/status", "online");
    } else {
      Serial.print("échec, rc=");
      Serial.print(client.state());
      Serial.println(" nouvelle tentative dans 5s");
      delay(5000);
      attempts++;
    }
  }
}

void callback(char* topic, byte* payload, unsigned int length) {
  String message;
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  
  Serial.println("Message reçu [" + String(topic) + "]: " + message);
  
  // Contrôle des relais
  for (int i = 0; i < 4; i++) {
    if (String(topic) == "control/relay" + String(i+1)) {
      if (message == "ON") {
        digitalWrite(relayPins[i], LOW);  // Activer (relais inversé)
        manualControl[i] = true;
      } else if (message == "OFF") {
        digitalWrite(relayPins[i], HIGH); // Désactiver (relais inversé)
        manualControl[i] = true;
      } else if (message == "AUTO") {
        manualControl[i] = false;
      }
      break;
    }
  }
  
  // Changement d'adresse du serveur MQTT
  if (String(topic) == "control/server") {
    if (message.length() > 0 && message.length() < 20) {
      mqttServer = message;
      saveMqttServerToEEPROM(mqttServer);
      
      // Reconnecter avec la nouvelle adresse
      client.disconnect();
      client.setServer(mqttServer.c_str(), mqttPort);
      reconnect();
    }
  }
}

void calibrateACS712() {
  Serial.println("Calibration du capteur de courant...");
  float sum = 0;
  for(int i=0; i<200; i++) {
    sum += (analogRead(CURRENT_SENSOR_PIN) / 4095.0 * 5.0) - 1.65;
    delay(2);
  }
  ACS712_OFFSET = sum / 200;
  Serial.printf("Offset ACS712 calibré: %.4fV\n", ACS712_OFFSET);
}

float readCurrent() {
  // Lecture RMS sur 1 période secteur (20ms pour 50Hz)
  unsigned long start = millis();
  float sum_sq = 0;
  int samples = 0;
  
  while(millis() - start < 20) {
    float voltage = (analogRead(CURRENT_SENSOR_PIN) / 4095.0 * 5.0) - 1.65 - ACS712_OFFSET;
    sum_sq += voltage * voltage;
    samples++;
  }
  
  float current_rms = sqrt(sum_sq / samples) / ACS712_SENSITIVITY;
  
  // Filtrage exponentiel
  currentFilter = (FILTER_ALPHA * current_rms) + ((1 - FILTER_ALPHA) * currentFilter);
  
  // Seuil minimal
  return currentFilter < CURRENT_THRESHOLD ? 0 : currentFilter;
}

void readAndControlSensors() {
  // Lecture des capteurs
  float temp = dht.readTemperature();
  float hum = dht.readHumidity();
  int lumiere = analogRead(LDR_PIN);
  int gaz = analogRead(MQ2_PIN);
  
  // Vérification des valeurs NaN
  if (isnan(temp) || isnan(hum)) {
    Serial.println("Erreur de lecture du capteur DHT!");
    temp = 0;
    hum = 0;
  }
  
  // Détection des conditions d'alarme
  bool temp_high = temp > TEMP_SEUIL;
  bool dark = lumiere < LUM_SEUIL;
  bool gas_detected = gaz > GAZ_SEUIL;
  
  // Contrôle automatique des relais (si pas en mode manuel)
  if (!manualControl[0]) digitalWrite(relayPins[0], temp_high ? LOW : HIGH);  // Ventilateur
  if (!manualControl[1]) digitalWrite(relayPins[1], dark ? LOW : HIGH);       // Lumière
  if (!manualControl[2]) digitalWrite(relayPins[2], gas_detected ? LOW : HIGH); // Alarme
  if (!manualControl[3]) digitalWrite(relayPins[3], gas_detected ? LOW : HIGH); // Ventilation secours
  
  // Création du JSON pour les données des capteurs
  StaticJsonDocument<200> doc;
  doc["temp"] = temp;
  doc["hum"] = hum;
  doc["light"] = lumiere;
  doc["gas"] = gaz;
  
  JsonObject alarms = doc.createNestedObject("alarms");
  alarms["temp"] = temp_high ? 1 : 0;
  alarms["light"] = dark ? 1 : 0;
  alarms["gas"] = gas_detected ? 1 : 0;
  
  // Conversion en chaîne JSON
  char sensorData[200];
  serializeJson(doc, sensorData);
  
  // Publication des données
  client.publish("sensors/status", sensorData);
  
  // Affichage des données pour débogage
  Serial.println("Données capteurs: " + String(sensorData));
}

void publishEnergyData() {
  float current = readCurrent();
  float power = current * 230.0; // 230V AC
  
  // Création du JSON pour les données énergétiques
  StaticJsonDocument<100> doc;
  doc["current"] = current;
  doc["power"] = power;
  doc["offset"] = ACS712_OFFSET;
  
  // Conversion en chaîne JSON
  char energyData[100];
  serializeJson(doc, energyData);
  
  // Publication des données
  client.publish("energy/consumption", energyData);
  
  // Affichage des données pour débogage
  Serial.println("Données énergie: " + String(energyData));
}

void loop() {
  // Vérifier la connexion WiFi
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Connexion WiFi perdue. Tentative de reconnexion...");
    setupWiFi();
  }
  
  // Vérifier la connexion MQTT
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  // Mise à jour périodique des données
  static unsigned long lastUpdate = 0;
  if (millis() - lastUpdate >= 2000) { // Toutes les 2 secondes
    readAndControlSensors();
    publishEnergyData();
    lastUpdate = millis();
    
    // Recalibration périodique du capteur de courant
    static unsigned long lastCalib = 0;
    if (millis() - lastCalib > 3600000) { // Toutes les heures
      calibrateACS712();
      lastCalib = millis();
    }
  }
}