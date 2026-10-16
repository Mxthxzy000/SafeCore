import 'enums.dart';

class Sensor {
  const Sensor({
    required this.id,
    required this.areaId,
    required this.code,
    required this.name,
    required this.type,
    required this.unit,
    required this.status,
    required this.level,
    this.refMin,
    this.refMax,
    this.criticalMin,
    this.criticalMax,
    this.lastValue,
    this.lastReadingAt,
    this.deviceId,
    this.isSimulated = true,
    this.areaName,
  });

  final String id;
  final String areaId;
  final String code;
  final String name;
  final SensorType type;
  final String unit;
  final SensorStatus status;
  final SensorLevel level;
  final double? refMin;
  final double? refMax;
  final double? criticalMin;
  final double? criticalMax;
  final double? lastValue;
  final DateTime? lastReadingAt;
  final String? deviceId;
  final bool isSimulated;
  final String? areaName;

  bool get isOnline => status == SensorStatus.online;

  factory Sensor.fromMap(Map<String, dynamic> map) {
    final area = map['areas'];
    return Sensor(
      id: map['id'] as String,
      areaId: map['area_id'] as String? ?? '',
      code: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: SensorType.parse(map['sensor_type'] as String?),
      unit: map['unit'] as String? ?? '',
      status: SensorStatus.parse(map['status'] as String?),
      level: SensorLevel.parse(map['level'] as String?),
      refMin: _d(map['ref_min']),
      refMax: _d(map['ref_max']),
      criticalMin: _d(map['critical_min']),
      criticalMax: _d(map['critical_max']),
      lastValue: _d(map['last_value']),
      lastReadingAt: map['last_reading_at'] == null
          ? null
          : DateTime.parse(map['last_reading_at'] as String),
      deviceId: map['device_id'] as String?,
      isSimulated: map['is_simulated'] as bool? ?? true,
      areaName: area is Map ? area['name'] as String? : null,
    );
  }

  /// Mesma regra da função SQL `sensor_level`, para avaliar valores do histórico.
  SensorLevel levelFor(double value) {
    if ((criticalMax != null && value >= criticalMax!) ||
        (criticalMin != null && value <= criticalMin!)) {
      return SensorLevel.critico;
    }
    if ((refMax != null && value > refMax!) || (refMin != null && value < refMin!)) {
      return SensorLevel.atencao;
    }
    return SensorLevel.normal;
  }

  static double? _d(Object? v) => (v as num?)?.toDouble();
}

class SensorReading {
  const SensorReading({required this.value, required this.recordedAt, required this.source});

  final double value;
  final DateTime recordedAt;
  final String source;

  factory SensorReading.fromMap(Map<String, dynamic> map) => SensorReading(
        value: (map['value'] as num).toDouble(),
        recordedAt: DateTime.parse(map['recorded_at'] as String),
        source: map['source'] as String? ?? 'simulado',
      );
}
