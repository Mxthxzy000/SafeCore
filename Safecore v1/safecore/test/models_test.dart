import 'package:flutter_test/flutter_test.dart';
import 'package:safecore/models/alert.dart';
import 'package:safecore/models/area.dart';
import 'package:safecore/models/enums.dart';
import 'package:safecore/models/plant_summary.dart';
import 'package:safecore/models/sensor.dart';

Map<String, dynamic> sensorMap(
  String id,
  String type,
  double value, {
  String level = 'normal',
  String status = 'online',
  String unit = '°C',
}) =>
    {
      'id': id,
      'area_id': 'a',
      'code': id,
      'name': 'Sensor $id',
      'sensor_type': type,
      'unit': unit,
      'status': status,
      'level': level,
      'last_value': value,
      'last_reading_at': '2026-10-09T10:00:00Z',
      'ref_min': 15,
      'ref_max': 40,
      'critical_min': 5,
      'critical_max': 55,
    };

Area areaWith(String id, String status, List<Map<String, dynamic>> sensors) => Area.fromMap({
      'id': id,
      'code': id.toUpperCase(),
      'name': 'Área $id',
      'area_type': 'producao',
      'status': status,
      'sensors': sensors,
    });

void main() {
  group('Sensor.levelFor (mesma regra do SQL)', () {
    final sensor = Sensor.fromMap(sensorMap('t', 'temperatura', 20));

    test('dentro da faixa segura é normal', () {
      expect(sensor.levelFor(25), SensorLevel.normal);
      expect(sensor.levelFor(40), SensorLevel.normal);
    });

    test('fora da faixa segura é atenção', () {
      expect(sensor.levelFor(45), SensorLevel.atencao);
      expect(sensor.levelFor(10), SensorLevel.atencao);
    });

    test('no limite crítico é crítico', () {
      expect(sensor.levelFor(55), SensorLevel.critico);
      expect(sensor.levelFor(58.7), SensorLevel.critico);
      expect(sensor.levelFor(4), SensorLevel.critico);
    });
  });

  group('PlantSummary', () {
    test('planta segura quando todas as áreas estão seguras', () {
      final summary = PlantSummary.compute(
        areas: [
          areaWith('a', 'segura', [
            sensorMap('t1', 'temperatura', 20),
            sensorMap('p1', 'pressao', 1.0, unit: 'bar'),
            sensorMap('g1', 'gas', 2, unit: '%LEL'),
            sensorMap('v1', 'ventilacao', 1.5, unit: 'm/s'),
          ]),
        ],
        openAlerts: const [],
      );
      expect(summary.overallStatus, AreaStatus.segura);
      expect(summary.statusMessage, 'Todos os sistemas operando normalmente.');
      expect(summary.availability, 100);
      expect(summary.airQuality, AirQuality.boa);
      expect(summary.ventilation, VentilationState.ativa);
    });

    test('médias, disponibilidade e status crítico vêm dos mesmos registros', () {
      final summary = PlantSummary.compute(
        areas: [
          areaWith('cld', 'critica', [
            sensorMap('t1', 'temperatura', 58.7, level: 'critico'),
            sensorMap('g1', 'gas', 12, level: 'atencao', unit: '%LEL'),
          ]),
          areaWith('esc', 'segura', [sensorMap('t2', 'temperatura', 21.3)]),
          areaWith('exp', 'desconectada', [
            sensorMap('t3', 'temperatura', 99, status: 'offline'),
          ]),
        ],
        openAlerts: [
          Alert.fromMap({
            'id': '1',
            'area_id': 'cld',
            'title': 'Temperatura Elevada',
            'severity': 'critico',
            'status': 'ativo',
            'detected_at': '2026-10-09T10:00:00Z',
          }),
        ],
      );

      expect(summary.totalAreas, 3);
      expect(summary.totalSensors, 4);
      expect(summary.onlineSensors, 3);
      expect(summary.availability, closeTo(75, 0.01));
      // Sensor offline não entra na média
      expect(summary.avgTemperature, closeTo((58.7 + 21.3) / 2, 0.001));
      expect(summary.activeAlerts, 1);
      expect(summary.criticalAlerts, 1);
      expect(summary.overallStatus, AreaStatus.critica);
      expect(summary.airQuality, AirQuality.moderada);
      expect(summary.ventilation, VentilationState.semDados);
      expect(summary.areasNeedingAttention.first.id, 'cld');
    });
  });

  group('Alert', () {
    test('alerta resolvido usa a etiqueta "Resolvido"', () {
      final alert = Alert.fromMap({
        'id': '1',
        'area_id': 'a',
        'areas': {'name': 'Armazém'},
        'title': 'Umidade abaixo do ideal',
        'severity': 'atencao',
        'status': 'resolvido',
        'detected_at': '2026-10-07T10:00:00Z',
        'resolved_at': '2026-10-07T13:00:00Z',
      });
      expect(alert.isResolved, isTrue);
      expect(alert.tagStyle.label, 'Resolvido');
      expect(alert.areaName, 'Armazém');
    });

    test('status em_andamento é interpretado', () {
      expect(AlertStatus.parse('em_andamento'), AlertStatus.emAndamento);
      expect(AlertStatus.emAndamento.dbValue, 'em_andamento');
    });
  });

  test('papéis com permissão de operação', () {
    expect(UserRole.operador.canOperate, isFalse);
    expect(UserRole.tecnico.canOperate, isTrue);
    expect(UserRole.parse('desconhecido'), UserRole.operador);
  });
}
