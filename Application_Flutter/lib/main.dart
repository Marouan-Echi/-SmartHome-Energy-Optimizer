import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contrôleur MQTT',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Client MQTT
  MqttServerClient? client;
  bool isConnected = false;
  String connectionStatus = "Déconnecté";
  
  // Adresse du serveur MQTT (avec valeur par défaut)
  String mqttServerAddress = '192.168.61.108';
  
  // Données énergétiques
  double currentValue = 0.0;
  double powerValue = 0.0;
  
  // Données des capteurs
  double temperatureValue = 0.0;
  double humidityValue = 0.0;
  int lightValue = 0;
  int gasValue = 0;
  
  // État des alarmes
  bool tempAlarm = false;
  bool lightAlarm = false;
  bool gasAlarm = false;
  
  // État des relais
  List<bool> relayStates = List.generate(4, (index) => false);
  List<String> relayNames = ['Ventilateur', 'Lumière', 'Alarme', 'Ventilation secours'];
  
  @override
  void initState() {
    super.initState();
    _setupMqttClient();
    _connectClient();
    
    // Vérification périodique de la connexion MQTT
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!isConnected) {
        _connectClient();
      }
    });
  }
  
  @override
  void dispose() {
    _disconnectClient();
    super.dispose();
  }
  
  // Configuration du client MQTT
  void _setupMqttClient() {
    client = MqttServerClient(mqttServerAddress, 'flutter_client');
    client!.port = 1883;
    client!.keepAlivePeriod = 20;
    client!.onDisconnected = _onDisconnected;
    client!.onConnected = _onConnected;
    client!.onSubscribed = _onSubscribed;
    
    final connMess = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .withWillTopic('willtopic')
        .withWillMessage('Connexion perdue')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);
    
    client!.connectionMessage = connMess;
  }
  
  // Connexion au broker MQTT
  Future<void> _connectClient() async {
    try {
      setState(() {
        connectionStatus = "Connexion en cours...";
      });
      
      await client!.connect();
    } catch (e) {
      print('Exception: $e');
      _disconnectClient();
    }
    
    if (client!.connectionStatus!.state == MqttConnectionState.connected) {
      setState(() {
        isConnected = true;
        connectionStatus = "Connecté";
      });
      
      // S'abonner aux topics
      client!.subscribe('energy/consumption', MqttQos.atLeastOnce);
      client!.subscribe('sensors/status', MqttQos.atLeastOnce);
      
      // S'abonner aux topics de contrôle des relais
      for (int i = 1; i <= 4; i++) {
        client!.subscribe('control/relay$i', MqttQos.atLeastOnce);
      }
      
      // Écouter les messages entrants
      client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage message = c[0].payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(message.payload.message);
        
        _processMessage(c[0].topic, payload);
      });
    } else {
      setState(() {
        isConnected = false;
        connectionStatus = "Échec de connexion";
      });
      
      // Tentative de reconnexion après 5 secondes
      Future.delayed(const Duration(seconds: 5), () {
        _connectClient();
      });
    }
  }
  
  // Traitement des messages reçus
  void _processMessage(String topic, String payload) {
    if (topic == 'energy/consumption') {
      try {
        final data = jsonDecode(payload);
        setState(() {
          currentValue = data['current'].toDouble();
          powerValue = data['power'].toDouble();
        });
      } catch (e) {
        print('Erreur de décodage JSON: $e');
      }
    } else if (topic == 'sensors/status') {
      try {
        final data = jsonDecode(payload);
        setState(() {
          temperatureValue = data['temp'].toDouble();
          humidityValue = data['hum'].toDouble();
          lightValue = data['light'];
          gasValue = data['gas'];
          
          // Mise à jour des états d'alarme
          tempAlarm = data['alarms']['temp'] == 1;
          lightAlarm = data['alarms']['light'] == 1;
          gasAlarm = data['alarms']['gas'] == 1;
          
          // Mise à jour des états des relais en fonction des alarmes
          // Ces états sont contrôlés par l'ESP32, nous les synchronisons ici
          relayStates[0] = tempAlarm; // Ventilateur
          relayStates[1] = lightAlarm; // Lumière
          relayStates[2] = gasAlarm; // Alarme
          relayStates[3] = gasAlarm; // Ventilation secours
        });
      } catch (e) {
        print('Erreur de décodage JSON: $e');
      }
    }
  }
  
  // Déconnexion du client MQTT
  void _disconnectClient() {
    client?.disconnect();
    setState(() {
      isConnected = false;
      connectionStatus = "Déconnecté";
    });
  }
  
  // Callbacks MQTT
  void _onConnected() {
    setState(() {
      isConnected = true;
      connectionStatus = "Connecté";
    });
  }
  
  void _onDisconnected() {
    setState(() {
      isConnected = false;
      connectionStatus = "Déconnecté";
    });
    
    // Tentative de reconnexion après 5 secondes
    Future.delayed(const Duration(seconds: 5), () {
      _connectClient();
    });
  }
  
  void _onSubscribed(String topic) {
    print('Abonné au topic: $topic');
  }
  
  // Envoi d'une commande à un relais
  void _toggleRelay(int relayNumber, bool state) {
    if (client?.connectionStatus?.state == MqttConnectionState.connected) {
      final topic = 'control/relay$relayNumber';
      final payload = state ? 'ON' : 'OFF';
      
      final builder = MqttClientPayloadBuilder();
      builder.addString(payload);
      
      client!.publishMessage(
        topic,
        MqttQos.atLeastOnce,
        builder.payload!
      );
      
      setState(() {
        relayStates[relayNumber - 1] = state;
      });
      
      print('Commande envoyée: $topic -> $payload');
    } else {
      print('Impossible d\'envoyer la commande: non connecté au broker MQTT');
    }
  }
  
  // Ajouter un dialogue pour configurer l'adresse IP
  void _showServerConfigDialog() {
    TextEditingController controller = TextEditingController(text: mqttServerAddress);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Configuration Serveur MQTT'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Adresse IP du serveur',
            hintText: 'Exemple: 192.168.1.100',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
            
              setState(() {
                mqttServerAddress = controller.text;
              });
              
              // Reconnecter avec la nouvelle adresse
              _disconnectClient();
              _setupMqttClient();
              _connectClient();
              
              Navigator.pop(context);
            },
            child: Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contrôleur MQTT'),
        actions: [
          Chip(
            label: Text(connectionStatus),
            backgroundColor: isConnected ? Colors.green : Colors.red,
          ),
          IconButton(
            icon: Icon(isConnected ? Icons.link : Icons.link_off),
            onPressed: isConnected ? _disconnectClient : _connectClient,
          ),
          // Ajouter un bouton de configuration
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _showServerConfigDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0), // Réduire le padding de 16 à 8
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Affichage des jauges énergétiques
              Text(
                'Mesures Énergétiques',
                style: Theme.of(context).textTheme.titleLarge, // Changer headlineSmall à titleLarge
              ),
              const SizedBox(height: 8), // Réduire l'espace vertical
              Row(
                children: [
                  Expanded(
                    child: _buildCurrentGauge(),
                  ),
                  Expanded(
                    child: _buildPowerGauge(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Affichage des capteurs environnementaux
              Text(
                'Capteurs Environnementaux',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTemperatureGauge(),
                  ),
                  Expanded(
                    child: _buildHumidityGauge(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildLightGauge(),
                  ),
                  Expanded(
                    child: _buildGasGauge(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Affichage des alarmes
              Text(
                'État des Alarmes',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildAlarmIndicator('Température', tempAlarm),
                  ),
                  Expanded(
                    child: _buildAlarmIndicator('Luminosité', lightAlarm),
                  ),
                  Expanded(
                    child: _buildAlarmIndicator('Gaz', gasAlarm),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Contrôle des relais
              Text(
                'Contrôle des Relais',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.5, // Augmenter de 2.0 à 2.5 pour rendre les cartes plus larges que hautes
                  crossAxisSpacing: 8, // Réduire l'espacement horizontal de 10 à 8
                  mainAxisSpacing: 8, // Réduire l'espacement vertical de 10 à 8
                ),
                itemCount: 4,
                itemBuilder: (context, index) {
                  return _buildRelayControl(index + 1);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Widget pour la jauge de courant
  Widget _buildCurrentGauge() {
    return SfRadialGauge(
      title: const GaugeTitle(
        text: 'Courant (A)',
        textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold), // Réduire la taille de police
      ),
      enableLoadingAnimation: false, // Désactiver l'animation pour améliorer les performances
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 5,
          ranges: <GaugeRange>[
            GaugeRange(startValue: 0, endValue: 2, color: Colors.green),
            GaugeRange(startValue: 2, endValue: 4, color: Colors.orange),
            GaugeRange(startValue: 4, endValue: 5, color: Colors.red),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(value: currentValue),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                currentValue.toStringAsFixed(2) + ' A',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              angle: 90,
              positionFactor: 0.5,
            ),
          ],
        ),
      ],
    );
  }
  
  // Widget pour la jauge de puissance
  Widget _buildPowerGauge() {
    return SfRadialGauge(
      title: const GaugeTitle(
        text: 'Puissance (W)',
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 500,
          ranges: <GaugeRange>[
            GaugeRange(startValue: 0, endValue: 200, color: Colors.green),
            GaugeRange(startValue: 200, endValue: 400, color: Colors.orange),
            GaugeRange(startValue: 400, endValue: 500, color: Colors.red),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(value: powerValue),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                powerValue.toStringAsFixed(2) + ' W',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              angle: 90,
              positionFactor: 0.5,
            ),
          ],
        ),
      ],
    );
  }
  
  // Widget pour la jauge de température
  Widget _buildTemperatureGauge() {
    return SfRadialGauge(
      title: const GaugeTitle(
        text: 'Température (°C)',
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 50,
          ranges: <GaugeRange>[
            GaugeRange(startValue: 0, endValue: 20, color: Colors.blue),
            GaugeRange(startValue: 20, endValue: 30, color: Colors.green),
            GaugeRange(startValue: 30, endValue: 50, color: Colors.red),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(value: temperatureValue),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                temperatureValue.toStringAsFixed(1) + ' °C',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              angle: 90,
              positionFactor: 0.5,
            ),
          ],
        ),
      ],
    );
  }
  
  // Widget pour la jauge d'humidité
  Widget _buildHumidityGauge() {
    return SfRadialGauge(
      title: const GaugeTitle(
        text: 'Humidité (%)',
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 100,
          ranges: <GaugeRange>[
            GaugeRange(startValue: 0, endValue: 30, color: Colors.red),
            GaugeRange(startValue: 30, endValue: 70, color: Colors.green),
            GaugeRange(startValue: 70, endValue: 100, color: Colors.blue),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(value: humidityValue),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                humidityValue.toStringAsFixed(1) + ' %',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              angle: 90,
              positionFactor: 0.5,
            ),
          ],
        ),
      ],
    );
  }
  
  // Widget pour la jauge de luminosité
  Widget _buildLightGauge() {
    return SfRadialGauge(
      title: const GaugeTitle(
        text: 'Luminosité',
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 1023,
          ranges: <GaugeRange>[
            GaugeRange(startValue: 0, endValue: 500, color: Colors.red),
            GaugeRange(startValue: 500, endValue: 800, color: Colors.orange),
            GaugeRange(startValue: 800, endValue: 1023, color: Colors.green),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(value: lightValue.toDouble()),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                lightValue.toString(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              angle: 90,
              positionFactor: 0.5,
            ),
          ],
        ),
      ],
    );
  }
  
  // Widget pour la jauge de gaz
  Widget _buildGasGauge() {
    return SfRadialGauge(
      title: const GaugeTitle(
        text: 'Niveau de Gaz',
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 1023,
          ranges: <GaugeRange>[
            GaugeRange(startValue: 0, endValue: 400, color: Colors.green),
            GaugeRange(startValue: 400, endValue: 600, color: Colors.orange),
            GaugeRange(startValue: 600, endValue: 1023, color: Colors.red),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(value: gasValue.toDouble()),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                gasValue.toString(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              angle: 90,
              positionFactor: 0.5,
            ),
          ],
        ),
      ],
    );
  }
  
  // Widget pour l'indicateur d'alarme
  Widget _buildAlarmIndicator(String name, bool isActive) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.all(4), // Réduire les marges
      color: isActive ? Colors.red.shade100 : Colors.green.shade100,
      child: Padding(
        padding: const EdgeInsets.all(6.0), // Réduire le padding
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Icon(
              isActive ? Icons.warning_amber_rounded : Icons.check_circle,
              color: isActive ? Colors.red : Colors.green,
              size: 32,
            ),
            Text(
              isActive ? 'ALERTE' : 'Normal',
              style: TextStyle(
                color: isActive ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget pour le contrôle d'un relais
  Widget _buildRelayControl(int relayNumber) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(8.0), // Réduire le padding de 12 à 8
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(  // Ajouter Flexible ici
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Relais $relayNumber',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis, // Ajouter cette ligne
                  ),
                  Text(
                    relayNames[relayNumber - 1],
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis, // Ajouter cette ligne
                  ),
                ],
              ),
            ),
            FlutterSwitch(
              width: 55, // Réduire la largeur de 60 à 55
              height: 28, // Réduire la hauteur de 30 à 28
              valueFontSize: 10, // Réduire la taille de police de 12 à 10
              toggleSize: 22, // Réduire la taille du toggle de 25 à 22
              value: relayStates[relayNumber - 1],
              borderRadius: 30,
              padding: 2, // Réduire le padding de 4 à 2
              activeColor: Colors.green,
              showOnOff: true,
              onToggle: (val) {
                _toggleRelay(relayNumber, val);
              },
            ),
          ],
        ),
      ),
    );
  }
}