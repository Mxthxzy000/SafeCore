import 'enums.dart';

class Alert {
  const Alert({
    required this.id,
    required this.areaId,
    required this.areaName,
    required this.title,
    required this.severity,
    required this.status,
    required this.detectedAt,
    this.sensorId,
    this.sensorName,
    this.description,
    this.detectedValue,
    this.unit,
    this.resolvedAt,
    this.resolutionNote,
    this.isSimulated = true,
    this.origin = AlertOrigin.sensor,
    this.category = AlertCategory.outro,
  });

  final String id;
  final String areaId;
  final String areaName;
  final String? sensorId;
  final String? sensorName;
  final String title;
  final String? description;
  final AlertSeverity severity;
  final AlertStatus status;
  final double? detectedValue;
  final String? unit;
  final DateTime detectedAt;
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final bool isSimulated;
  final AlertOrigin origin;
  final AlertCategory category;

  bool get isManual => origin == AlertOrigin.manual;

  bool get isResolved => status == AlertStatus.resolvido;

  /// Estilo exibido na etiqueta do cartão (Crítico, Atenção ou Resolvido).
  StatusStyle get tagStyle => isResolved ? resolvedStyle : severity.style;

  factory Alert.fromMap(Map<String, dynamic> map) {
    final area = map['areas'];
    final sensor = map['sensors'];
    return Alert(
      id: map['id'] as String,
      areaId: map['area_id'] as String,
      areaName: area is Map ? (area['name'] as String? ?? '') : '',
      sensorId: map['sensor_id'] as String?,
      sensorName: sensor is Map ? sensor['name'] as String? : null,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      severity: AlertSeverity.parse(map['severity'] as String?),
      status: AlertStatus.parse(map['status'] as String?),
      detectedValue: (map['detected_value'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
      detectedAt: DateTime.parse(map['detected_at'] as String),
      resolvedAt: map['resolved_at'] == null ? null : DateTime.parse(map['resolved_at'] as String),
      resolutionNote: map['resolution_note'] as String?,
      isSimulated: map['is_simulated'] as bool? ?? true,
      origin: AlertOrigin.parse(map['origin'] as String?),
      category: AlertCategory.parse(map['category'] as String?),
    );
  }
}

class ActionLog {
  const ActionLog({
    required this.id,
    required this.userName,
    required this.actionType,
    required this.description,
    required this.isSimulation,
    required this.createdAt,
    this.areaName,
  });

  final String id;
  final String userName;
  final String actionType;
  final String description;
  final bool isSimulation;
  final DateTime createdAt;
  final String? areaName;

  String get label => switch (actionType) {
        'comentario' => 'Comentário',
        'reconhecido' => 'Alerta assumido',
        'resolvido' => 'Resolvido',
        'reaberto' => 'Reaberto',
        'ventilacao' => 'Ventilação (simulação)',
        'isolamento' => 'Isolamento (simulação)',
        'liberacao' => 'Liberação (simulação)',
        _ => 'Sistema',
      };

  factory ActionLog.fromMap(Map<String, dynamic> map) {
    final area = map['areas'];
    return ActionLog(
      id: map['id'] as String,
      userName: map['user_name'] as String? ?? 'Sistema',
      actionType: map['action_type'] as String? ?? 'sistema',
      description: map['description'] as String? ?? '',
      isSimulation: map['is_simulation'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      areaName: area is Map ? area['name'] as String? : null,
    );
  }
}
