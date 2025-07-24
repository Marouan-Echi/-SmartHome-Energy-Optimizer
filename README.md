# 🔋 SmartHome Energy Optimizer

**SmartHome Energy Optimizer**, une **solution IoT embarquée innovante** conçue pour **superviser et optimiser la consommation énergétique** dans les maisons connectées. Grâce à la **collecte** et à **l’analyse des données en temps réel**, ce système permet de **réduire le gaspillage d’énergie**, **diminuer les coûts** et **améliorer le confort des utilisateurs**.

---

## 🔍 Présentation du Projet

Ce système repose sur un **microcontrôleur ESP32** couplé à plusieurs capteurs (courant, température, luminosité, gaz). Il **mesure en continu** la consommation énergétique et les conditions ambiantes afin de :

- Détecter les **pics de consommation**
- **Automatiser** les équipements (éclairage, ventilation, alarmes)
- **Optimiser** la gestion énergétique de la maison

Les données collectées sont :

- Transmises via **MQTT/HTTP**
- **Stockées dans InfluxDB**
- **Analysées avec Node-RED**
- **Visualisées dynamiquement dans Grafana**
- Et **accessibles depuis une application mobile Flutter**

---

## 🧠 Technologies & Outils Utilisés

| Composant           | Description                                             |
|---------------------|---------------------------------------------------------|
| 🧠 **ESP32**        | Microcontrôleur central pour la gestion IoT            |
| 🔌 **ACS712**       | Capteur de courant pour mesurer la consommation        |
| 🌡️ **DHTxx**        | Capteur de température et humidité                     |
| ☀️ **LDR / BH1750** | Capteur de luminosité pour détecter l’éclairage naturel|
| 💨 **MQ-135**       | Capteur de gaz (CO₂, fumée) pour détection d’anomalies |
| 📡 **MQTT / HTTP**  | Protocoles de communication pour transfert des données |
| 📦 **InfluxDB**     | Base de données optimisée pour les séries temporelles  |
| ⚙️ **Node-RED**     | Plateforme pour le traitement et les flux de données   |
| 📊 **Grafana**      | Tableaux de bord pour visualisation en temps réel      |
| 📱 **Flutter**      | Application mobile multiplateforme pour l’utilisateur  |

---

## 💡 Fonctionnalités Clés

- 🔍 **Surveillance énergétique en temps réel**
- 🤖 **Contrôle automatique** des équipements selon les conditions ambiantes
- ⚠️ **Détection des pics de consommation** et **génération d’alertes**
- 📱 **Pilotage des appareils à distance** via une application mobile Flutter
- 🏗️ **Architecture évolutive** prête pour l’intégration d’autres capteurs et services (IA, domotique avancée…)

---

## 🌿 Impact et Résultats

Grâce à une gestion intelligente et automatique de l’énergie, le système a permis une **réduction mesurée de 8 à 12 % de la consommation électrique globale**, contribuant ainsi à une maison **plus intelligente, plus économique et plus respectueuse de l’environnement**.

---



## 🧩 Architecture du Système

[Capteurs]
↓
[ESP32]
↓ MQTT / HTTP
[InfluxDB] ←→ [Node-RED] ←→ [Grafana]
↓
[Application Flutter]
