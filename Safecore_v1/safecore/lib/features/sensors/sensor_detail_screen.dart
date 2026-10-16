import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/sensor.dart';
import '../../repositories/repositories.dart';
import '../../routes/app_routes.dart';
import '../../services/mqtt_service.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/safecore_app_bar.dart';
import '../../shared/widgets/time_series_chart.dart';

enum HistoryRange {
  day('24 horas', Duration(hours: 24)),
  week('7 dias', Duration(days: 7)),
  month('30 dias', Duration(days: 30));

  const HistoryRange(this.label, this.duration);
  final String label;
  final Duration duration;
}

class SensorDetailScreen extends StatefulWidget {
  const SensorDetailScreen({super.key, required this.sensorId});

  final String sensorId;

  @override
  State<SensorDetailScreen> createState() => _SensorDetailScreenState();
}

class _SensorDetailScreenState extends State<SensorDetailScreen> {
  HistoryRange _range = HistoryRange.day;
  final _loaderKey = GlobalKey<AsyncLoaderState<(Sensor, List<SensorReading>)>>();

  Future<(Sensor, List<SensorReading>)> _load() async {
    final since = DateTime.now().subtract(_range.duration);
    return (
      Repos.sensors.fetchById(widget.sensorId),
      Repos.sensors.fetchReadings(widget.sensorId, since),
    ).wait;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SafeCoreAppBar(title: 'Detalhes do Sensor'),
      body: AsyncLoader<(Sensor, List<SensorReading>)>(
        key: _loaderKey,
        load: _load,
        refresh: MqttService.instance,
        builder: (context, data, reload) {
          final (sensor, readings) = data;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _Header(sensor: sensor),
                const SizedBox(height: 14),
                _Limits(sensor: sensor),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Histórico de medições',
                  icon: Icons.show_chart,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<HistoryRange>(
                        showSelectedIcon: false,
                        segments: [
                          for (final r in HistoryRange.values)
                            ButtonSegment(value: r, label: Text(r.label, style: const TextStyle(fontSize: 12))),
                        ],
                        selected: {_range},
                        onSelectionChanged: (s) {
                          setState(() => _range = s.first);
                          _loaderKey.currentState?.reload();
                        },
                      ),
                      const SizedBox(height: 14),
                      TimeSeriesChart(
                        points: [for (final r in readings) ChartPoint(r.recordedAt.toLocal(), r.value)],
                        color: sensor.type.color,
                        unit: sensor.unit,
                        hourly: _range == HistoryRange.day,
                        references: [
                          if (sensor.refMax != null)
                            ReferenceLine(sensor.refMax!, 'Limite ${Fmt.number(sensor.refMax, decimals: Fmt.decimalsFor(sensor.unit))}', AppColors.warning),
                          if (sensor.criticalMax != null && _range == HistoryRange.day)
                            ReferenceLine(sensor.criticalMax!, 'Crítico', AppColors.critical),
                          if (sensor.refMin != null && sensor.refMin! > 0)
                            ReferenceLine(sensor.refMin!, 'Mínimo', AppColors.warning),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${readings.length} leituras no período',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Últimas leituras',
                  icon: Icons.list_alt,
                  child: readings.isEmpty
                      ? const Text('Nenhuma leitura no período.',
                          style: AppText.bodySecondary)
                      : Column(
                          children: [
                            for (final r in readings.reversed.take(10))
                              _ReadingRow(sensor: sensor, reading: r),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.sensor});

  final Sensor sensor;

  @override
  Widget build(BuildContext context) {
    final style = sensor.isOnline
        ? sensor.level.style
        : const StatusStyle('Sem comunicação', AppColors.offline, AppColors.offlineBg, Icons.wifi_off_rounded);
    return AccentCard(
      accent: style.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(sensor.type.icon, color: sensor.type.color, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sensor.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    Text('${sensor.type.label} • ${sensor.code}',
                        style: AppText.caption),
                  ],
                ),
              ),
              StatusTag(style),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              sensor.isOnline ? Fmt.measure(sensor.lastValue, sensor.unit) : '—',
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: style.color),
            ),
          ),
          Center(
            child: Text(
              sensor.lastReadingAt == null
                  ? 'Sem leituras'
                  : 'Última atualização: ${Fmt.dateTime(sensor.lastReadingAt!)}',
              style: AppText.caption,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => Navigator.pushNamed(context, AppRoutes.areaDetail, arguments: sensor.areaId),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(sensor.areaName ?? 'Área',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
                ),
                const Icon(Icons.chevron_right, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Limits extends StatelessWidget {
  const _Limits({required this.sensor});

  final Sensor sensor;

  String _range(double? min, double? max) {
    final d = Fmt.decimalsFor(sensor.unit);
    if (min == null && max != null) return 'até ${Fmt.number(max, decimals: d)} ${sensor.unit}';
    if (min != null && max == null) return 'a partir de ${Fmt.number(min, decimals: d)} ${sensor.unit}';
    if (min == null && max == null) return '—';
    return '${Fmt.number(min, decimals: d)} a ${Fmt.number(max, decimals: d)} ${sensor.unit}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Faixa segura', _range(sensor.refMin, sensor.refMax)),
      ('Limite crítico', [
        if (sensor.criticalMin != null) '≤ ${Fmt.measure(sensor.criticalMin, sensor.unit)}',
        if (sensor.criticalMax != null) '≥ ${Fmt.measure(sensor.criticalMax, sensor.unit)}',
      ].join(' ou ')),
      ('Comunicação', sensor.status.label),
      ('Dispositivo', sensor.deviceId ?? '—'),
      ('Origem dos dados', sensor.isSimulated ? 'Simulada (demonstração)' : 'Dispositivo IoT'),
    ];
    return SectionCard(
      title: 'Limites de referência',
      icon: Icons.rule,
      trailing: sensor.isSimulated ? const SimulatedBadge() : null,
      child: Column(
        children: [
          for (final (label, value) in rows)
            InfoRow(label: label, value: value),
        ],
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.sensor, required this.reading});

  final Sensor sensor;
  final SensorReading reading;

  @override
  Widget build(BuildContext context) {
    final level = sensor.levelFor(reading.value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(Icons.circle, size: 9, color: level.style.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(Fmt.relativeDay(reading.recordedAt), style: const TextStyle(fontSize: 13)),
          ),
          Text(Fmt.measure(reading.value, sensor.unit),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: level.style.color)),
        ],
      ),
    );
  }
}
