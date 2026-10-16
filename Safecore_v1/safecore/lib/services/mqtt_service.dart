import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';

import '../models/area.dart';
import '../models/enums.dart';
import '../models/sensor.dart';
import 'mqtt_client_io.dart' if (dart.library.html) 'mqtt_client_web.dart';

/// Dados em tempo real recebidos via MQTT do ESP32 do setor Caldeira (Quimex).
class BoilerMqttTelemetry {
  const BoilerMqttTelemetry({
    required this.deviceId,
    required this.receivedAt,
    this.ambientTempC,
    this.boilerTempC,
    this.pressureHpa,
    this.pressureBar,
    this.humidityPercent,
    this.gasAdc,
    this.gasLelPercent,
    this.fanOn = false,
    this.emergency = false,
    this.riskLevel = 'NORMAL',
    this.reasons = '',
  });

  final String deviceId;
  final DateTime receivedAt;
  final double? ambientTempC;
  final double? boilerTempC;
  final double? pressureHpa;
  final double? pressureBar;
  final double? humidityPercent;
  final int? gasAdc;
  final double? gasLelPercent;
  final bool fanOn;
  final bool emergency;
  final String riskLevel;
  final String reasons;

  /// Temperatura principal da caldeira (DS18B20, com fallback para DHT22).
  double? get effectiveTempC => boilerTempC ?? ambientTempC;

  /// Pressão em bar (convertida de hPa caso pressao_bar não venha explícito).
  double? get effectivePressureBar =>
      pressureBar ?? (pressureHpa != null ? pressureHpa! / 1000.0 : null);

  /// Concentração de gás em %LEL (convertida do ADC 0..4095 caso gas_lel não venha explícito).
  double? get effectiveGasLel =>
      gasLelPercent ?? (gasAdc != null ? (gasAdc! / 4095.0) * 100.0 : null);

  factory BoilerMqttTelemetry.fromJson(Map<String, dynamic> json) {
    final amb = json['ambiente'] as Map<String, dynamic>? ?? const {};
    final cald = json['caldeira'] as Map<String, dynamic>? ?? const {};
    final sensores = json['sensores'] as Map<String, dynamic>? ?? const {};
    final atuadores = json['atuadores'] as Map<String, dynamic>? ?? const {};

    double? numVal(Object? v) => (v as num?)?.toDouble();

    final ambTemp = numVal(amb['temp_c']);
    final hum = numVal(sensores['CLD-UMD-01']) ?? numVal(amb['umidade_pct']);
    final gasAdc = (amb['gas_adc'] as num?)?.toInt();
    final gasLel = numVal(sensores['CLD-GAS-01']) ?? numVal(amb['gas_lel']);
    final bTemp = numVal(sensores['CLD-TMP-01']) ?? numVal(cald['temp_c']);
    final pHpa = numVal(cald['pressao_hpa']);
    final pBar = numVal(sensores['CLD-PRS-01']) ?? numVal(cald['pressao_bar']);

    return BoilerMqttTelemetry(
      deviceId: (json['device'] as String?) ?? 'quimex-caldeira-01',
      receivedAt: DateTime.now(),
      ambientTempC: ambTemp,
      boilerTempC: bTemp,
      pressureHpa: pHpa,
      pressureBar: pBar,
      humidityPercent: hum,
      gasAdc: gasAdc,
      gasLelPercent: gasLel,
      fanOn: atuadores['ventilacao'] == true,
      emergency: atuadores['emergencia'] == true,
      riskLevel: (json['risco'] as String?) ?? 'NORMAL',
      reasons: (json['motivos'] as String?) ?? '',
    );
  }
}

/// Serviço MQTT que conecta o SafeCore ao broker público `broker.mqtt.cool`
/// na sala da empresa `quimex`, setor `caldeira` (`safecore/quimex/caldeira/#`).
///
/// Todos os outros setores da planta permanecem desconectados até possuírem
/// suas próprias salas ativas no broker.
class MqttService extends ChangeNotifier {
  MqttService._();

  static final MqttService instance = MqttService._();

  static const String brokerHost = 'broker.mqtt.cool';
  static const int brokerPort = 1883;
  static const String company = 'quimex';
  static const String boilerSector = 'caldeira';

  /// Tópico base ("sala") do setor da Caldeira na Quimex.
  static const String boilerBaseTopic = 'safecore/$company/$boilerSector';
  static const String telemetryTopic = '$boilerBaseTopic/telemetry';
  static const String statusTopic = '$boilerBaseTopic/status';
  static const String commandTopic = '$boilerBaseTopic/command';

  MqttClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _updatesSub;
  Timer? _reconnectTimer;
  Timer? _watchdogTimer;

  bool _brokerConnected = false;
  bool _deviceOnline = false;
  BoilerMqttTelemetry? _lastTelemetry;

  /// Histórico em memória das leituras recebidas via MQTT na sessão atual (por código de sensor).
  final Map<String, List<SensorReading>> _liveReadings = {};

  bool get isBrokerConnected => _brokerConnected;

  /// Indica se a sala da Caldeira está ativa e recebendo dados do ESP32.
  bool get isBoilerOnline {
    if (_lastTelemetry != null) {
      final age = DateTime.now().difference(_lastTelemetry!.receivedAt);
      if (age <= const Duration(seconds: 30)) return true;
    }
    return _deviceOnline && _lastTelemetry != null;
  }

  BoilerMqttTelemetry? get lastTelemetry => _lastTelemetry;

  /// Inicializa a conexão com o broker público.
  Future<void> init() async {
    _startWatchdog();
    await connect();
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_lastTelemetry != null) {
        final age = DateTime.now().difference(_lastTelemetry!.receivedAt);
        if (age > const Duration(seconds: 30) && _deviceOnline) {
          _deviceOnline = false;
          notifyListeners();
        }
      }
      if (!_brokerConnected) {
        connect();
      }
    });
  }

  Future<void> connect() async {
    if (_client != null &&
        (_client!.connectionStatus?.state == MqttConnectionState.connected ||
            _client!.connectionStatus?.state == MqttConnectionState.connecting)) {
      return;
    }

    final randomId = Random().nextInt(90000) + 10000;
    final clientId = 'SafeCore-Flutter-$company-$randomId';

    try {
      final client = createPlatformMqttClient(brokerHost, clientId, brokerPort);
      client.keepAlivePeriod = 30;
      client.autoReconnect = true;
      client.logging(on: false);

      client.onConnected = _onConnected;
      client.onDisconnected = _onDisconnected;
      client.onAutoReconnected = _onConnected;

      final connMess = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);
      client.connectionMessage = connMess;

      _client = client;
      await client.connect();
    } catch (e) {
      debugPrint('[MQTT] Falha ao conectar em $brokerHost: $e');
      _brokerConnected = false;
      _client?.disconnect();
      _scheduleReconnect();
    }
  }

  void _onConnected() {
    _brokerConnected = true;
    debugPrint('[MQTT] Conectado ao broker $brokerHost ($boilerBaseTopic)');

    final client = _client;
    if (client == null) return;

    // Assina a sala da Caldeira da Quimex (e também o tópico legado demo01 por compatibilidade)
    client.subscribe('$boilerBaseTopic/#', MqttQos.atMostOnce);
    client.subscribe('safecore/$company/demo01/#', MqttQos.atMostOnce);

    _updatesSub?.cancel();
    _updatesSub = client.updates?.listen(_onMessage);
    notifyListeners();
  }

  void _onDisconnected() {
    _brokerConnected = false;
    debugPrint('[MQTT] Desconectado do broker.');
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_brokerConnected) connect();
    });
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    var changed = false;
    for (final msg in messages) {
      final topic = msg.topic;
      final pubMsg = msg.payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(pubMsg.payload.message);

      if (topic.endsWith('/status')) {
        final online = payload.trim().toLowerCase() == 'online';
        if (_deviceOnline != online) {
          _deviceOnline = online;
          changed = true;
        }
      } else if (topic.endsWith('/telemetry')) {
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            final telemetry = BoilerMqttTelemetry.fromJson(decoded);
            _lastTelemetry = telemetry;
            _deviceOnline = true;
            _recordLiveReadings(telemetry);
            changed = true;
          }
        } catch (e) {
          debugPrint('[MQTT] Erro ao decodificar JSON de telemetria: $e');
        }
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void _recordLiveReadings(BoilerMqttTelemetry t) {
    void addReading(String code, double? value) {
      if (value == null) return;
      final list = _liveReadings.putIfAbsent(code, () => <SensorReading>[]);
      list.add(SensorReading(
        value: double.parse(value.toStringAsFixed(2)),
        recordedAt: t.receivedAt,
        source: 'esp32',
      ));
      if (list.length > 500) {
        list.removeAt(0);
      }
    }

    addReading('CLD-TMP-01', t.effectiveTempC);
    addReading('CLD-PRS-01', t.effectivePressureBar);
    addReading('CLD-UMD-01', t.humidityPercent);
    addReading('CLD-GAS-01', t.effectiveGasLel);
  }

  /// Envia um comando MQTT para a sala da Caldeira (ex.: acionar ventilação no ESP32).
  void publishCommand(String command) {
    final client = _client;
    if (client == null || !_brokerConnected) return;
    final builder = MqttClientPayloadBuilder()..addString(command);
    client.publishMessage(commandTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  /// Verifica se a área corresponde ao setor da Caldeira.
  static bool isBoilerArea(Area area) =>
      area.code.toUpperCase() == 'CLD' || area.type.toLowerCase() == 'caldeira';

  /// Verifica se o sensor pertence ao setor da Caldeira.
  static bool isBoilerSensor(Sensor sensor) =>
      sensor.code.toUpperCase().startsWith('CLD-') ||
      (sensor.areaName?.toLowerCase().contains('caldeira') ?? false);

  /// Aplica o estado real do broker MQTT sobre um sensor:
  /// - Sensores de outros setores: sempre `offline` (Desconectado) e sem simulação.
  /// - Sensores da Caldeira (`CLD-*`): `online` com os valores em tempo real do JSON do ESP32
  ///   quando o broker está enviando dados, ou `offline` se o ESP32 estiver desligado.
  Sensor applyToSensor(Sensor sensor) {
    if (!isBoilerSensor(sensor)) {
      return Sensor(
        id: sensor.id,
        areaId: sensor.areaId,
        code: sensor.code,
        name: sensor.name,
        type: sensor.type,
        unit: sensor.unit,
        status: SensorStatus.offline,
        level: SensorLevel.normal,
        refMin: sensor.refMin,
        refMax: sensor.refMax,
        criticalMin: sensor.criticalMin,
        criticalMax: sensor.criticalMax,
        lastValue: null,
        lastReadingAt: null,
        deviceId: sensor.deviceId,
        isSimulated: false,
        areaName: sensor.areaName,
      );
    }

    final t = _lastTelemetry;
    if (!isBoilerOnline || t == null) {
      return Sensor(
        id: sensor.id,
        areaId: sensor.areaId,
        code: sensor.code,
        name: sensor.name,
        type: sensor.type,
        unit: sensor.unit,
        status: SensorStatus.offline,
        level: SensorLevel.normal,
        refMin: sensor.refMin,
        refMax: sensor.refMax,
        criticalMin: sensor.criticalMin,
        criticalMax: sensor.criticalMax,
        lastValue: null,
        lastReadingAt: t?.receivedAt,
        deviceId: t?.deviceId ?? 'quimex-caldeira-01',
        isSimulated: false,
        areaName: sensor.areaName,
      );
    }

    final double? liveValue = switch (sensor.type) {
      SensorType.temperatura => t.effectiveTempC,
      SensorType.pressao => t.effectivePressureBar,
      SensorType.umidade => t.humidityPercent,
      SensorType.gas => t.effectiveGasLel,
      _ => sensor.lastValue,
    };

    if (liveValue == null) {
      return Sensor(
        id: sensor.id,
        areaId: sensor.areaId,
        code: sensor.code,
        name: sensor.name,
        type: sensor.type,
        unit: sensor.unit,
        status: SensorStatus.offline,
        level: SensorLevel.normal,
        refMin: sensor.refMin,
        refMax: sensor.refMax,
        criticalMin: sensor.criticalMin,
        criticalMax: sensor.criticalMax,
        lastValue: null,
        lastReadingAt: t.receivedAt,
        deviceId: t.deviceId,
        isSimulated: false,
        areaName: sensor.areaName,
      );
    }

    final computedLevel = sensor.levelFor(liveValue);

    return Sensor(
      id: sensor.id,
      areaId: sensor.areaId,
      code: sensor.code,
      name: sensor.name,
      type: sensor.type,
      unit: sensor.unit,
      status: SensorStatus.online,
      level: computedLevel,
      refMin: sensor.refMin,
      refMax: sensor.refMax,
      criticalMin: sensor.criticalMin,
      criticalMax: sensor.criticalMax,
      lastValue: liveValue,
      lastReadingAt: t.receivedAt,
      deviceId: t.deviceId,
      isSimulated: false,
      areaName: sensor.areaName,
    );
  }

  /// Aplica o estado real do broker MQTT sobre uma Área:
  /// - Todos os setores exceto a Caldeira ficam como `AreaStatus.desconectada`
  ///   e com todos os seus sensores `offline`.
  /// - O setor da Caldeira fica conectado ao tópico `safecore/quimex/caldeira`
  ///   e reflete o status real calculado pelos sensores do ESP32.
  Area applyToArea(Area area) {
    final updatedSensors = area.sensors.map(applyToSensor).toList();

    if (!isBoilerArea(area)) {
      return Area(
        id: area.id,
        code: area.code,
        name: area.name,
        type: area.type,
        status: AreaStatus.desconectada,
        description: area.description,
        statusNote: 'Setor desconectado do broker MQTT (safecore/$company/${area.code.toLowerCase()}).',
        mapX: area.mapX,
        mapY: area.mapY,
        mapW: area.mapW,
        mapH: area.mapH,
        sensors: updatedSensors,
        restricted: area.restricted,
        archivedAt: area.archivedAt,
      );
    }

    if (area.status == AreaStatus.interditada) {
      return Area(
        id: area.id,
        code: area.code,
        name: area.name,
        type: area.type,
        status: AreaStatus.interditada,
        description: area.description,
        statusNote: area.statusNote,
        mapX: area.mapX,
        mapY: area.mapY,
        mapW: area.mapW,
        mapH: area.mapH,
        sensors: updatedSensors,
        restricted: area.restricted,
        archivedAt: area.archivedAt,
      );
    }

    final t = _lastTelemetry;
    if (!isBoilerOnline || t == null) {
      return Area(
        id: area.id,
        code: area.code,
        name: area.name,
        type: area.type,
        status: AreaStatus.desconectada,
        description: area.description,
        statusNote: _brokerConnected
            ? 'Aguardando telemetria do ESP32 no tópico $telemetryTopic...'
            : 'Conectando ao broker $brokerHost ($boilerBaseTopic)...',
        mapX: area.mapX,
        mapY: area.mapY,
        mapW: area.mapW,
        mapH: area.mapH,
        sensors: updatedSensors,
        restricted: area.restricted,
        archivedAt: area.archivedAt,
      );
    }

    final onlineSensors = updatedSensors.where((s) => s.isOnline).toList();
    final riskUpper = t.riskLevel.toUpperCase();

    AreaStatus liveStatus;
    if (t.emergency ||
        riskUpper == 'EMERGENCIA' ||
        riskUpper == 'CRITICA' ||
        onlineSensors.any((s) => s.level == SensorLevel.critico)) {
      liveStatus = AreaStatus.critica;
    } else if (riskUpper == 'ALERTA' ||
        riskUpper == 'ATENCAO' ||
        onlineSensors.any((s) => s.level == SensorLevel.atencao)) {
      liveStatus = AreaStatus.atencao;
    } else if (onlineSensors.isEmpty) {
      liveStatus = AreaStatus.desconectada;
    } else {
      liveStatus = AreaStatus.segura;
    }

    final reasonsText = t.reasons.isNotEmpty
        ? ' • Motivos: ${t.reasons.replaceAll(';', ', ').replaceAll(RegExp(r', $'), '')}'
        : '';
    final ventText = t.fanOn ? 'Exaustor: LIGADO' : 'Exaustor: DESLIGADO';

    return Area(
      id: area.id,
      code: area.code,
      name: area.name,
      type: area.type,
      status: liveStatus,
      description: area.description,
      statusNote: 'Conectado ao broker ($boilerBaseTopic) • $ventText$reasonsText',
      mapX: area.mapX,
      mapY: area.mapY,
      mapW: area.mapW,
      mapH: area.mapH,
      sensors: updatedSensors,
      restricted: area.restricted,
      archivedAt: area.archivedAt,
    );
  }

  /// Retorna as leituras em tempo real recebidas via MQTT para um sensor da Caldeira.
  List<SensorReading> liveReadingsFor(String sensorCode, DateTime since) {
    final list = _liveReadings[sensorCode.toUpperCase()] ?? const [];
    return list.where((r) => !r.recordedAt.isBefore(since)).toList();
  }
}
