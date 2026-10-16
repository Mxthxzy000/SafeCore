import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/occurrence.dart';
import '../../repositories/repositories.dart';
import '../../routes/app_routes.dart';
import '../../services/session_controller.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/safecore_app_bar.dart';

class OccurrenceDetailScreen extends StatefulWidget {
  const OccurrenceDetailScreen({super.key, required this.occurrenceId});

  final String occurrenceId;

  @override
  State<OccurrenceDetailScreen> createState() => _OccurrenceDetailScreenState();
}

class _OccurrenceDetailScreenState extends State<OccurrenceDetailScreen> {
  bool _busy = false;

  Future<void> _setStatus(OccurrenceStatus status, Future<void> Function() reload) async {
    setState(() => _busy = true);
    try {
      await Repos.occurrences.updateStatus(widget.occurrenceId, status);
      if (!mounted) return;
      showMessage(context, 'Status atualizado para "${status.style.label}".');
      await reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: const SafeCoreAppBar(title: 'Detalhes do Registro'),
      body: AsyncLoader<Occurrence>(
        load: () => Repos.occurrences.fetchById(widget.occurrenceId),
        builder: (context, o, reload) {
          final canEdit = o.reportedBy == session.profile?.id ||
              (o.areaId == null ? session.canOperateGeneral : session.canOperateArea(o.areaId!));
          final rows = [
            ('Tipo', o.kind.label),
            ('Área', o.areaName ?? 'Geral (toda a planta)'),
            ('Prioridade', o.priority.label),
            ('Registrado por', o.reportedByName),
            ('Responsável', o.responsibleName ?? 'Não atribuído'),
            ('Data', Fmt.dateTime(o.createdAt)),
          ];
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                AccentCard(
                  accent: o.status.style.color,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(o.kind.icon, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(o.title,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ),
                          StatusTag(o.status.style),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(o.description, style: const TextStyle(fontSize: 14, height: 1.35)),
                      const SizedBox(height: 14),
                      for (final (label, value) in rows)
                        InfoRow(label: label, value: value),
                      if (o.areaId != null)
                        TextButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.areaDetail, arguments: o.areaId),
                          icon: const Icon(Icons.location_on_outlined, size: 18),
                          label: const Text('Ver área'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Atualizar status',
                  icon: Icons.published_with_changes,
                  child: canEdit
                      ? Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (o.status != OccurrenceStatus.emAnalise && o.status != OccurrenceStatus.resolvida)
                              OutlinedButton.icon(
                                onPressed: _busy ? null : () => _setStatus(OccurrenceStatus.emAnalise, reload),
                                icon: const Icon(Icons.assignment_ind_outlined, size: 18),
                                label: const Text('Assumir análise'),
                              ),
                            if (o.status != OccurrenceStatus.resolvida)
                              ElevatedButton.icon(
                                onPressed: _busy ? null : () => _setStatus(OccurrenceStatus.resolvida, reload),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Concluir'),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: _busy ? null : () => _setStatus(OccurrenceStatus.aberta, reload),
                                icon: const Icon(Icons.replay, size: 18),
                                label: const Text('Reabrir'),
                              ),
                          ],
                        )
                      : const Text(
                          'Somente o autor do registro ou quem tem acesso de operação na área pode alterar o status.',
                          style: AppText.bodySecondary,
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
