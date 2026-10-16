import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

class ChartPoint {
  const ChartPoint(this.time, this.value);

  final DateTime time;
  final double value;
}

class ReferenceLine {
  const ReferenceLine(this.value, this.label, this.color);

  final double value;
  final String label;
  final Color color;
}

/// Gráfico de linha simples (Figma: "Gráficos de Desempenho").
class TimeSeriesChart extends StatelessWidget {
  const TimeSeriesChart({
    super.key,
    required this.points,
    required this.color,
    required this.unit,
    this.references = const [],
    this.hourly = false,
    this.height = 170,
  });

  final List<ChartPoint> points;
  final Color color;
  final String unit;
  final List<ReferenceLine> references;
  final bool hourly;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('Dados insuficientes no período.',
              style: AppText.bodySecondary),
        ),
      );
    }

    final xs = points.map((p) => p.time.millisecondsSinceEpoch.toDouble()).toList();
    final data = points.map((p) => p.value).toList();
    final dataMin = data.reduce(math.min);
    final dataMax = data.reduce(math.max);
    final span = math.max(dataMax - dataMin, dataMax.abs() * 0.1);
    // Linhas de referência muito distantes dos dados achatariam o gráfico
    final refs = references
        .where((r) => r.value >= dataMin - span && r.value <= dataMax + span)
        .toList();
    final values = [...data, ...refs.map((r) => r.value)];
    var minY = values.reduce(math.min);
    var maxY = values.reduce(math.max);
    final pad = math.max((maxY - minY) * 0.12, 0.05);
    minY -= pad;
    maxY += pad;
    final minX = xs.first;
    final maxX = xs.last;
    final xInterval = math.max((maxX - minX) / 4, 1.0);
    final decimals = Fmt.decimalsFor(unit);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 0.8),
          ),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              bottom: BorderSide(color: AppColors.border),
              left: BorderSide(color: AppColors.border),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      Fmt.number(value, decimals: decimals == 0 ? 0 : math.min(decimals, 1)),
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: xInterval,
                getTitlesWidget: (value, meta) {
                  final isEdge = value == meta.min || value == meta.max;
                  final nearEdge = (value - meta.min) < xInterval * 0.6 ||
                      (meta.max - value) < xInterval * 0.6;
                  if (!isEdge && nearEdge) return const SizedBox.shrink();
                  final d = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      hourly ? Fmt.time(d) : Fmt.dayMonth(d),
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  );
                },
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              for (final r in refs)
                HorizontalLine(
                  y: r.value,
                  color: r.color.withValues(alpha: 0.7),
                  strokeWidth: 1,
                  dashArray: [5, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: TextStyle(fontSize: 9.5, color: r.color),
                    labelResolver: (_) => r.label,
                  ),
                ),
            ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.slate,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${Fmt.measure(s.y, unit)}\n'
                    '${Fmt.dateTime(DateTime.fromMillisecondsSinceEpoch(s.x.toInt()))}',
                    const TextStyle(color: AppColors.white, fontSize: 11),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < points.length; i++) FlSpot(xs[i], points[i].value)],
              color: color,
              barWidth: 1.8,
              isCurved: true,
              curveSmoothness: 0.15,
              preventCurveOverShooting: true,
              dotData: FlDotData(show: points.length <= 31),
              belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
            ),
          ],
        ),
      ),
    );
  }
}
