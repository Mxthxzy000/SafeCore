import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/alert.dart';
import '../../models/enums.dart';
import '../../models/occurrence.dart';
import '../../models/plant_summary.dart';
import '../../repositories/repositories.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/safecore_app_bar.dart';
import '../../shared/widgets/time_series_chart.dart';

enum ReportPeriod {
  diario('Resumo Diário', Duration(days: 1)),
  semanal('Resumo Semanal', Duration(days: 7)),
  mensal('Resumo Mensal', Duration(days: 30)),
  personalizado('Personalizado', Duration.zero);

  const ReportPeriod(this.label, this.duration);
  final String label;
  final Duration duration;
}

class _ReportData {
  const _ReportData({
    required this.summary,
    required this.series,
    required this.alerts,
    required this.occurrences,
  });

  final PlantSummary summary;
  final List<ReportPoint> series;
  final List<Alert> alerts;
  final List<Occurrence> occurrences;
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.refresh});

  final Listenable? refresh;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _loaderKey = GlobalKey<AsyncLoaderState<_ReportData>>();
  ReportPeriod _period = ReportPeriod.mensal;
  DateTimeRange? _custom;

  DateTimeRange get _range {
    if (_period == ReportPeriod.personalizado && _custom != null) {
      return DateTimeRange(start: _custom!.start, end: _custom!.end.add(const Duration(days: 1)));
    }
    final now = DateTime.now();
    return DateTimeRange(start: now.subtract(_period.duration), end: now);
  }

  bool get _hourly => _range.duration.inHours <= 48;

  Future<_ReportData> _load() async {
    final range = _range;
    final (areas, openAlerts, series, alerts, occurrences) = await (
      Repos.areas.fetchAll(),
      Repos.alerts.fetchAll(openOnly: true),
      Repos.reports.fetchSeries(from: range.start, to: range.end, hourly: _hourly),
      Repos.alerts.fetchInPeriod(range.start, range.end),
      Repos.occurrences.fetchInPeriod(range.start, range.end),
    ).wait;
    return _ReportData(
      summary: PlantSummary.compute(areas: areas, openAlerts: openAlerts),
      series: series,
      alerts: alerts,
      occurrences: occurrences,
    );
  }

  void _setPeriod(ReportPeriod p) {
    setState(() => _period = p);
    _loaderKey.currentState?.reload();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: _custom ??
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
      helpText: 'Selecione o período',
    );
    if (picked == null) return;
    _custom = picked;
    _setPeriod(ReportPeriod.personalizado);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SafeCoreAppBar(title: 'Relatórios'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ReportPeriod>(
                    initialValue: _period,
                    key: ValueKey(_period),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      fillColor: AppColors.white,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                    items: [
                      for (final p in ReportPeriod.values)
                        if (p != ReportPeriod.personalizado || _custom != null)
                          DropdownMenuItem(value: p, child: Text(p.label)),
                    ],
                    onChanged: (p) => p == null ? null : _setPeriod(p),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: IconButton(
                    tooltip: 'Escolher datas',
                    icon: const Icon(Icons.calendar_today_outlined, color: AppColors.slate),
                    onPressed: _pickRange,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncLoader<_ReportData>(
              key: _loaderKey,
              load: _load,
              refresh: widget.refresh,
              builder: (context, data, reload) => RefreshIndicator(
                onRefresh: reload,
                child: _ReportBody(data: data, range: _range, hourly: _hourly),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.data, required this.range, required this.hourly});

  final _ReportData data;
  final DateTimeRange range;
  final bool hourly;

  List<ChartPoint> _points(SensorType type) => [
        for (final p in data.series)
          if (p.type == type) ChartPoint(p.bucket, p.avg),
      ];

  @override
  Widget build(BuildContext context) {
    final s = data.summary;
    final end = range.end.subtract(const Duration(minutes: 1));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        SectionCard(
          title: 'Resumo do Período',
          trailing: const SimulatedBadge(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${Fmt.date(range.start)} a ${Fmt.date(end)}',
                style: AppText.caption,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Stat(value: Fmt.twoDigits(s.totalAreas), label: 'Áreas'),
                  _Stat(value: Fmt.twoDigits(s.totalSensors), label: 'Sensores'),
                  _Stat(
                    value: Fmt.twoDigits(data.alerts.length),
                    label: 'Alertas',
                    color: data.alerts.isEmpty ? AppColors.safe : AppColors.critical,
                  ),
                  _Stat(
                    value: Fmt.percent(s.availability),
                    label: 'Disponib.',
                    color: s.availability >= 95 ? AppColors.safe : AppColors.warning,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Gráficos de Desempenho',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Temperatura Média (°C)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TimeSeriesChart(
                points: _points(SensorType.temperatura),
                color: AppColors.primary,
                unit: '°C',
                hourly: hourly,
              ),
              const SizedBox(height: 18),
              const Text('Pressão Média (bar)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TimeSeriesChart(
                points: _points(SensorType.pressao),
                color: AppColors.critical,
                unit: 'bar',
                hourly: hourly,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Indicators(data: data),
        const SizedBox(height: 14),
        _History(data: data),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            FittedBox(
              child: Text(value,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: color ?? AppColors.primary)),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppText.small),
          ],
        ),
      ),
    );
  }
}

class _Indicators extends StatelessWidget {
  const _Indicators({required this.data});

  final _ReportData data;

  @override
  Widget build(BuildContext context) {
    final alerts = data.alerts;
    final critical = alerts.where((a) => a.severity == AlertSeverity.critico).length;
    final resolved = alerts.where((a) => a.isResolved && a.resolvedAt != null).toList();
    final avgMinutes = resolved.isEmpty
        ? null
        : resolved
                .map((a) => a.resolvedAt!.difference(a.detectedAt).inMinutes)
                .reduce((a, b) => a + b) /
            resolved.length;

    final byArea = <String, int>{};
    for (final a in alerts) {
      byArea[a.areaName] = (byArea[a.areaName] ?? 0) + 1;
    }
    final topArea = byArea.entries.isEmpty
        ? null
        : byArea.entries.reduce((a, b) => a.value >= b.value ? a : b);

    double? extreme(SensorType type) {
      final values = data.series.where((p) => p.type == type).map((p) => p.max);
      return values.isEmpty ? null : values.reduce(math.max);
    }

    String duration(double minutes) {
      if (minutes < 60) return '${minutes.round()} min';
      final h = minutes ~/ 60;
      final m = (minutes % 60).round();
      return m == 0 ? '$h h' : '$h h $m min';
    }

    final rows = [
      ('Alertas críticos / atenção', '$critical / ${alerts.length - critical}'),
      ('Alertas resolvidos', alerts.isEmpty ? '—' : '${resolved.length} de ${alerts.length}'),
      ('Tempo médio de resolução', avgMinutes == null ? '—' : duration(avgMinutes)),
      ('Área com mais alertas', topArea == null ? '—' : '${topArea.key} (${topArea.value})'),
      ('Temperatura máxima', Fmt.measure(extreme(SensorType.temperatura), '°C')),
      ('Pressão máxima', Fmt.measure(extreme(SensorType.pressao), 'bar')),
      ('Ocorrências registradas', '${data.occurrences.length}'),
    ];

    return SectionCard(
      title: 'Indicadores',
      icon: Icons.analytics_outlined,
      child: Column(
        children: [
          for (final (label, value) in rows)
            InfoRow(label: label, value: value),
        ],
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.data});

  final _ReportData data;

  @override
  Widget build(BuildContext context) {
    final items = <(DateTime, Widget)>[
      for (final a in data.alerts)
        (
          a.detectedAt,
          _HistoryTile(
            icon: a.tagStyle.icon,
            color: a.tagStyle.color,
            title: a.title,
            subtitle: '${a.areaName} • ${a.tagStyle.label}',
            date: a.detectedAt,
            onTap: () => Navigator.pushNamed(context, AppRoutes.alertDetail, arguments: a.id),
          ),
        ),
      for (final o in data.occurrences)
        (
          o.createdAt,
          _HistoryTile(
            icon: o.kind.icon,
            color: o.status.style.color,
            title: o.title,
            subtitle: '${o.kind.label} • ${o.areaName ?? 'Geral'} • ${o.status.style.label}',
            date: o.createdAt,
            onTap: () => Navigator.pushNamed(context, AppRoutes.occurrenceDetail, arguments: o.id),
          ),
        ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    return SectionCard(
      title: 'Histórico de Ocorrências',
      icon: Icons.history,
      child: items.isEmpty
          ? const Text('Nenhum alerta ou ocorrência no período.',
              style: AppText.bodySecondary)
          : Column(children: [for (final (_, w) in items) w]),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.value),
                  Text(subtitle, style: AppText.caption),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(Fmt.relativeDay(date),
                style: AppText.small),
          ],
        ),
      ),
    );
  }
}
