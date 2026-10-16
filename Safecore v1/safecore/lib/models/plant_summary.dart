import 'alert.dart';
import 'area.dart';
import 'enums.dart';

enum AirQuality {
  boa('Boa'),
  moderada('Moderada'),
  ruim('Ruim'),
  semDados('Sem dados');

  const AirQuality(this.label);
  final String label;
}

enum VentilationState {
  ativa('Ativa'),
  insuficiente('Insuficiente'),
  semDados('Sem dados');

  const VentilationState(this.label);
  final String label;
}

/// Indicadores calculados a partir das áreas, sensores e alertas do banco.
/// O Painel e os Relatórios usam este mesmo cálculo.
class PlantSummary {
  const PlantSummary({
    required this.totalAreas,
    required this.totalSensors,
    required this.onlineSensors,
    required this.activeAlerts,
    required this.criticalAlerts,
    required this.avgTemperature,
    required this.avgPressure,
    required this.airQuality,
    required this.ventilation,
    required this.overallStatus,
    required this.areasNeedingAttention,
    required this.lastUpdate,
  });

  final int totalAreas;
  final int totalSensors;
  final int onlineSensors;
  final int activeAlerts;
  final int criticalAlerts;
  final double? avgTemperature;
  final double? avgPressure;
  final AirQuality airQuality;
  final VentilationState ventilation;
  final AreaStatus overallStatus;
  final List<Area> areasNeedingAttention;
  final DateTime? lastUpdate;

  /// Percentual de sensores comunicando (0 a 100).
  double get availability => totalSensors == 0 ? 0 : onlineSensors * 100 / totalSensors;

  String get statusTitle => switch (overallStatus) {
        AreaStatus.critica => 'Crítico',
        AreaStatus.atencao => 'Atenção',
        _ => 'Segura',
      };

  String get statusMessage {
    if (overallStatus == AreaStatus.segura) {
      return 'Todos os sistemas operando normalmente.';
    }
    final names = areasNeedingAttention.map((a) => a.name).join(', ');
    return overallStatus == AreaStatus.critica
        ? 'Ação imediata necessária: $names.'
        : 'Acompanhe as áreas: $names.';
  }

  factory PlantSummary.compute({required List<Area> areas, required List<Alert> openAlerts}) {
    final sensors = [for (final a in areas) ...a.sensors];
    final online = sensors.where((s) => s.isOnline).toList();

    double? avg(SensorType type) {
      final values = online
          .where((s) => s.type == type && s.lastValue != null)
          .map((s) => s.lastValue!)
          .toList();
      if (values.isEmpty) return null;
      return values.reduce((a, b) => a + b) / values.length;
    }

    final air = online.where((s) => s.type == SensorType.gas || s.type == SensorType.fumaca);
    final airQuality = air.isEmpty
        ? AirQuality.semDados
        : air.any((s) => s.level == SensorLevel.critico)
            ? AirQuality.ruim
            : air.any((s) => s.level == SensorLevel.atencao)
                ? AirQuality.moderada
                : AirQuality.boa;

    final vent = online.where((s) => s.type == SensorType.ventilacao);
    final ventilation = vent.isEmpty
        ? VentilationState.semDados
        : vent.any((s) => s.level != SensorLevel.normal)
            ? VentilationState.insuficiente
            : VentilationState.ativa;

    final attention = areas
        .where((a) =>
            a.status == AreaStatus.critica ||
            a.status == AreaStatus.atencao ||
            a.status == AreaStatus.desconectada)
        .toList()
      ..sort((a, b) => a.status.priority.compareTo(b.status.priority));

    final overall = attention.any((a) => a.status == AreaStatus.critica)
        ? AreaStatus.critica
        : attention.isNotEmpty
            ? AreaStatus.atencao
            : AreaStatus.segura;

    DateTime? last;
    for (final s in sensors) {
      final t = s.lastReadingAt;
      if (t != null && (last == null || t.isAfter(last))) last = t;
    }

    return PlantSummary(
      totalAreas: areas.length,
      totalSensors: sensors.length,
      onlineSensors: online.length,
      activeAlerts: openAlerts.where((a) => !a.isResolved).length,
      criticalAlerts:
          openAlerts.where((a) => !a.isResolved && a.severity == AlertSeverity.critico).length,
      avgTemperature: avg(SensorType.temperatura),
      avgPressure: avg(SensorType.pressao),
      airQuality: airQuality,
      ventilation: ventilation,
      overallStatus: overall,
      areasNeedingAttention: attention,
      lastUpdate: last,
    );
  }
}

/// Ponto agregado da série de relatórios (média por hora ou dia).
class ReportPoint {
  const ReportPoint({
    required this.bucket,
    required this.type,
    required this.avg,
    required this.min,
    required this.max,
  });

  final DateTime bucket;
  final SensorType type;
  final double avg;
  final double min;
  final double max;

  factory ReportPoint.fromMap(Map<String, dynamic> map) => ReportPoint(
        bucket: DateTime.parse(map['bucket'] as String).toLocal(),
        type: SensorType.parse(map['sensor_type'] as String?),
        avg: (map['avg_value'] as num).toDouble(),
        min: (map['min_value'] as num).toDouble(),
        max: (map['max_value'] as num).toDouble(),
      );
}
