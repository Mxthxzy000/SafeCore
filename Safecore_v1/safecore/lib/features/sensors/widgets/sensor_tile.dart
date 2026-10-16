import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/enums.dart';
import '../../../models/sensor.dart';
import '../../../shared/widgets/cards.dart';

/// Linha de sensor: tipo, valor atual, estado e última atualização.
class SensorTile extends StatelessWidget {
  const SensorTile({super.key, required this.sensor, this.onTap, this.showArea = false});

  final Sensor sensor;
  final VoidCallback? onTap;
  final bool showArea;

  @override
  Widget build(BuildContext context) {
    final online = sensor.isOnline;
    final style = online
        ? sensor.level.style
        : const StatusStyle('Sem comunicação', AppColors.offline, AppColors.offlineBg, Icons.wifi_off_rounded);
    final subtitle = [
      if (showArea && sensor.areaName != null) sensor.areaName!,
      if (sensor.lastReadingAt != null) 'Atualizado ${Fmt.ago(sensor.lastReadingAt!)}',
    ].join(' • ');

    return AccentCard(
      accent: style.color,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: sensor.type.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(sensor.type.icon, color: sensor.type.color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sensor.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                online ? Fmt.measure(sensor.lastValue, sensor.unit) : '—',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: style.color),
              ),
              const SizedBox(height: 2),
              StatusTag(style, solid: false),
            ],
          ),
        ],
      ),
    );
  }
}
