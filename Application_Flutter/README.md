# 📱 SmartHome MQTT Flutter App

**SmartHome MQTT Flutter App** est une application mobile développée avec **Flutter**, conçue pour être une **interface de supervision et de contrôle** pour un système domotique ou industriel basé sur le protocole **MQTT** et des microcontrôleurs **ESP32**.

L’application permet la **communication bidirectionnelle** avec les équipements IoT afin de :
- **Superviser** les données énergétiques et environnementales en temps réel
- **Recevoir des alertes**
- **Contrôler des relais** à distance

---

## 🔧 Fonctionnalités principales

### 🔗 1. Communication MQTT
- Connexion à un **broker MQTT** (adresse IP configurable, par défaut `192.168.61.108`)
- **Reconnexion automatique** en cas de perte de connexion
- Interface intégrée pour **changer l’adresse IP** du serveur MQTT

### ⚡ 2. Supervision des données énergétiques
- **Courant électrique (A)** : affichage sur jauge
- **Puissance électrique (W)** : affichage sur jauge

### 🌡️ 3. Surveillance environnementale
- **Température (°C)** : affichage coloré selon seuils
- **Humidité (%)** : jauge avec échelle dynamique
- **Luminosité** : via capteur LDR
- **Niveau de gaz** : via capteur MQ2

### 🚨 4. Système d’alarmes
- Détection et **affichage d’alertes** :
  - Température élevée
  - Faible luminosité
  - Présence de gaz
- **Icônes et couleurs d’état** clairs et explicites

### 🕹️ 5. Contrôle des relais
- Interface pour contrôler **4 relais** :
  - Ventilateur
  - Lumière
  - Alarme
  - Ventilation de secours
- **Noms personnalisables**
- **Synchronisation automatique** avec les états physiques via MQTT

---

## 🧩 Architecture technique
[ESP32 + Capteurs]
⇅ MQTT
[Broker MQTT]
⇅ MQTT
[SmartHome Flutter App]

---

## 📚 Technologies utilisées

| Technologie               | Rôle                                                  |
|---------------------------|--------------------------------------------------------|
| **Flutter**               | Développement mobile multiplateforme                   |
| **mqtt_client**           | Gestion de la communication MQTT                       |
| **syncfusion_flutter_gauges** | Affichage des jauges pour les mesures temps réel  |
| **ESP32 (côté firmware)** | Publication des données capteurs et réception commandes |
| **JSON**                  | Format des messages échangés via MQTT                 |

---

## 🔀 Topics MQTT utilisés

| Topic MQTT               | Rôle                                                  |
|--------------------------|--------------------------------------------------------|
| `energy/consumption`     | Données de courant et puissance électrique             |
| `sensors/status`         | Température, humidité, luminosité, gaz                 |
| `alarms/status`          | État des alarmes (format JSON)                         |
| `control/relay1` à `control/relay4` | Commande des relais depuis l’application    |

---

## 🧠 Format de données attendu (exemple)

```json
// sensors/status
{
  "temperature": 26.5,
  "humidity": 48,
  "luminosity": 700,
  "gas": 320
}

// energy/consumption
{
  "current": 1.25,
  "power": 275
}

// alarms/status
{
  "temp_alarm": true,
  "gas_alarm": false,
  "light_alarm": true
}
