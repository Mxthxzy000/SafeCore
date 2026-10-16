import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient createPlatformMqttClient(String host, String clientId, int port) {
  // Para Web, brokers públicos como broker.mqtt.cool suportam WebSocket na porta 8083 (ws) ou 8084 (wss)
  final wsUrl = 'ws://$host:8083/mqtt';
  final client = MqttBrowserClient.withPort(wsUrl, clientId, 8083);
  return client;
}
