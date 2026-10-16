import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/alert.dart';

/// Histórico de ações (alertas e áreas) em formato de linha do tempo.
class ActionTimeline extends StatelessWidget {
  const ActionTimeline({super.key, required this.actions});

  final List<ActionLog> actions;

  IconData _icon(String type) => switch (type) {
        'comentario' => Icons.chat_bubble_outline,
        'reconhecido' => Icons.assignment_ind_outlined,
        'resolvido' => Icons.check_circle_outline,
        'ventilacao' => Icons.air,
        'isolamento' => Icons.block,
        'liberacao' => Icons.lock_open,
        _ => Icons.memory,
      };

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Nenhuma ação registrada.', style: AppText.bodySecondary),
      );
    }
    return Column(
      children: [
        for (final a in actions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: a.isSimulation
                      ? AppColors.lightBlue.withValues(alpha: 0.3)
                      : AppColors.surfaceMuted,
                  child: Icon(_icon(a.actionType), size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${a.label} • ${a.userName}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(a.description, style: const TextStyle(fontSize: 12.5)),
                      const SizedBox(height: 2),
                      Text(
                        Fmt.dateTime(a.createdAt),
                        style: AppText.small,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
