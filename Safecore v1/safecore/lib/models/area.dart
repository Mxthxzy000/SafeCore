import 'enums.dart';
import 'sensor.dart';

class Area {
  const Area({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.status,
    this.description,
    this.statusNote,
    this.mapX = 0,
    this.mapY = 0,
    this.mapW = 0.2,
    this.mapH = 0.2,
    this.sensors = const [],
    this.restricted = false,
    this.archivedAt,
  });

  final String id;
  final String code;
  final String name;
  final String type;
  final AreaStatus status;
  final String? description;
  final String? statusNote;
  final double mapX;
  final double mapY;
  final double mapW;
  final double mapH;
  final List<Sensor> sensors;

  /// Área restrita: visível somente para funcionários com vínculo.
  final bool restricted;

  /// Data de arquivamento (área "excluída" que possui histórico).
  final DateTime? archivedAt;

  factory Area.fromMap(Map<String, dynamic> map) {
    final rawSensors = map['sensors'];
    return Area(
      id: map['id'] as String,
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: map['area_type'] as String? ?? 'producao',
      status: AreaStatus.parse(map['status'] as String?),
      description: map['description'] as String?,
      statusNote: map['status_note'] as String?,
      mapX: (map['map_x'] as num?)?.toDouble() ?? 0,
      mapY: (map['map_y'] as num?)?.toDouble() ?? 0,
      mapW: (map['map_w'] as num?)?.toDouble() ?? 0.2,
      mapH: (map['map_h'] as num?)?.toDouble() ?? 0.2,
      sensors: rawSensors is List
          ? rawSensors.map((s) => Sensor.fromMap(Map<String, dynamic>.from(s as Map))).toList()
          : const [],
      restricted: map['restricted'] as bool? ?? false,
      archivedAt: map['archived_at'] == null ? null : DateTime.parse(map['archived_at'] as String),
    );
  }

  /// Primeiro sensor do tipo informado (ex.: temperatura da área).
  Sensor? sensorOf(SensorType type) {
    for (final s in sensors) {
      if (s.type == type) return s;
    }
    return null;
  }
}

/// Tipos de setor disponíveis (coluna areas.area_type).
const areaTypes = <String, String>{
  'producao': 'Produção',
  'armazem': 'Armazém',
  'caldeira': 'Caldeira',
  'laboratorio': 'Laboratório',
  'escritorio': 'Escritório',
  'tanques': 'Tanques',
  'expedicao': 'Expedição',
  'tratamento': 'Tratamento',
};
