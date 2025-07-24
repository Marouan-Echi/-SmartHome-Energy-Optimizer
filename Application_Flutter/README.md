
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
