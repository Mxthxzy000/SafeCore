import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/alert.dart';
import '../../../models/enums.dart';
import '../../../shared/widgets/cards.dart';

/// Cartão de alerta (Figma): título, etiqueta, área, descrição, valor e horário.
class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.alert, required this.onTap});

  final Alert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = alert.tagStyle;
    return AccentCard(
      accent: style.color,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  alert.title,
                  style: TextStyle(color: style.color, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              StatusTag(style),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 15, color: AppColors.warning),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  alert.areaName,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.warning, fontWeight: FontWeight.w500),
                ),
              ),
              if (alert.isManual) ...[
                const SizedBox(width: 8),
                const Icon(Icons.edit_note, size: 15, color: AppColors.textSecondary),
                const Text('Manual', style: AppText.caption),
              ],
              if (alert.status == AlertStatus.emAndamento) ...[
                const SizedBox(width: 8),
                const Text('• Em andamento', style: TextStyle(fontSize: 11.5, color: AppColors.primary)),
              ],
            ],
          ),
          if ((alert.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              alert.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySecondary,
            ),
          ],
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 6),
          if (alert.detectedValue != null)
            Text.rich(
              TextSpan(children: [
                TextSpan(text: alert.isResolved ? 'Valor registrado: ' : 'Valor atual: '),
                TextSpan(
                  text: Fmt.measure(alert.detectedValue, alert.unit ?? ''),
                  style: TextStyle(color: style.color, fontWeight: FontWeight.w600),
                ),
              ]),
              style: const TextStyle(fontSize: 12.5),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  Fmt.relativeDay(alert.detectedAt),
                  style: AppText.caption,
                ),
              ),
              OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Ver detalhes'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
