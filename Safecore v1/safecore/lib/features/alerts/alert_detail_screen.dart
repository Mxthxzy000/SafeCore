import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/alert.dart';
import '../../models/enums.dart';
import '../../repositories/repositories.dart';
import '../../routes/app_routes.dart';
import '../../services/session_controller.dart';
import '../../shared/widgets/action_timeline.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/safecore_app_bar.dart';

class AlertDetailScreen extends StatefulWidget {
  const AlertDetailScreen({super.key, required this.alertId});

  final String alertId;

  @override
  State<AlertDetailScreen> createState() => _AlertDetailScreenState();
}

class _AlertDetailScreenState extends State<AlertDetailScreen> {
  final _loaderKey = GlobalKey<AsyncLoaderState<(Alert, List<ActionLog>)>>();
  Alert? _alert;

  Future<(Alert, List<ActionLog>)> _load() async {
    final data =
        await (Repos.alerts.fetchById(widget.alertId), Repos.alerts.fetchActions(widget.alertId)).wait;
    if (mounted) setState(() => _alert = data.$1);
    return data;
  }

  Future<void> _edit() async {
    final saved = await Navigator.pushNamed(context, AppRoutes.alertEdit, arguments: widget.alertId);
    if (saved == true) await _loaderKey.currentState?.reload();
  }

  Future<void> _delete(Alert alert) async {
    final ok = await confirmDialog(
      context,
      title: 'Excluir alerta',
      message: 'Excluir o alerta "${alert.title}" e o seu histórico de ações?\n\n'
          '${alert.isManual ? 'As medições dos sensores não são afetadas.' : 'Este alerta foi gerado por sensor. As leituras do sensor continuam preservadas.'}',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await Repos.alerts.delete(alert.id);
      if (!mounted) return;
      showMessage(context, 'Alerta excluído.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final alert = _alert;
    return Scaffold(
      appBar: SafeCoreAppBar(
        title: 'Detalhes do Alerta',
        actions: [
          if (alert != null && session.canEditAlert(alert))
            IconButton(tooltip: 'Editar alerta', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
          if (alert != null && session.canDeleteAlert(alert))
            IconButton(
              tooltip: 'Excluir alerta',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(alert),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: AsyncLoader<(Alert, List<ActionLog>)>(
        key: _loaderKey,
        load: _load,
        builder: (context, data, reload) {
          final (alert, actions) = data;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _AlertInfo(alert: alert),
                const SizedBox(height: 14),
                _AlertActions(alert: alert, reload: reload),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Histórico de ações',
                  icon: Icons.history,
                  child: ActionTimeline(actions: actions),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AlertInfo extends StatelessWidget {
  const _AlertInfo({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final style = alert.tagStyle;
    final rows = <(String, String)>[
      ('Área', alert.areaName),
      ('Categoria', alert.category.label),
      ('Origem', alert.origin.label),
      if (alert.sensorName != null) ('Sensor', alert.sensorName!),
      ('Severidade', alert.severity.style.label),
      ('Situação', alert.status.label),
      if (alert.detectedValue != null)
        ('Valor detectado', Fmt.measure(alert.detectedValue, alert.unit ?? '')),
      ('Detectado em', Fmt.dateTime(alert.detectedAt)),
      if (alert.resolvedAt != null) ('Resolvido em', Fmt.dateTime(alert.resolvedAt!)),
    ];

    return AccentCard(
      accent: style.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(style.icon, color: style.color, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert.title,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: style.color),
                ),
              ),
              StatusTag(style),
            ],
          ),
          if ((alert.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(alert.description!, style: const TextStyle(fontSize: 13.5)),
          ],
          const SizedBox(height: 12),
          for (final (label, value) in rows)
            InfoRow(label: label, value: value),
          if ((alert.resolutionNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.safeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Solução: ${alert.resolutionNote}', style: const TextStyle(fontSize: 13)),
            ),
          ],
          if (alert.isSimulated && !alert.isManual) ...[
            const SizedBox(height: 10),
            const SimulatedBadge(text: 'Alerta gerado a partir de dados simulados'),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.areaDetail, arguments: alert.areaId),
                icon: const Icon(Icons.location_on_outlined, size: 18),
                label: const Text('Ver área'),
              ),
              if (alert.sensorId != null)
                TextButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.sensorDetail, arguments: alert.sensorId),
                  icon: const Icon(Icons.show_chart, size: 18),
                  label: const Text('Ver sensor'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertActions extends StatefulWidget {
  const _AlertActions({required this.alert, required this.reload});

  final Alert alert;
  final Future<void> Function() reload;

  @override
  State<_AlertActions> createState() => _AlertActionsState();
}

class _AlertActionsState extends State<_AlertActions> {
  bool _busy = false;

  Future<void> _guard(Future<void> Function() task, String success) async {
    setState(() => _busy = true);
    try {
      await task();
      if (!mounted) return;
      showMessage(context, success);
      await widget.reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _comment() async {
    final text = await textInputDialog(context, title: 'Registrar ação', label: 'Descreva a ação realizada');
    if (text == null || text.isEmpty) return;
    await _guard(() => Repos.alerts.addComment(widget.alert.id, text), 'Ação registrada.');
  }

  Future<void> _acknowledge() =>
      _guard(() => Repos.alerts.acknowledge(widget.alert.id), 'Alerta assumido.');

  Future<void> _simulate(AreaAction action) async {
    final ok = await confirmDialog(
      context,
      title: '${action.label} (simulação)',
      message: 'Nenhum equipamento físico será acionado nesta versão. '
          'A ação será registrada no histórico como SIMULAÇÃO.',
      confirmLabel: 'Registrar simulação',
      destructive: action == AreaAction.isolamento,
    );
    if (!ok) return;
    await _guard(
      () => Repos.areas.simulateAction(widget.alert.areaId, action, alertId: widget.alert.id),
      'Simulação registrada.',
    );
  }

  Future<void> _resolve() async {
    final note = await textInputDialog(
      context,
      title: 'Resolver alerta',
      label: 'O que foi feito para resolver?',
      confirmLabel: 'Resolver',
    );
    if (note == null || note.isEmpty) return;
    await _guard(() => Repos.alerts.resolve(widget.alert.id, note), 'Alerta resolvido.');
  }

  @override
  Widget build(BuildContext context) {
    final canOperate = SessionScope.of(context).canOperateArea(widget.alert.areaId);
    final alert = widget.alert;
    final enabled = !_busy;

    if (alert.isResolved) {
      return SectionCard(
        title: 'Ações',
        icon: Icons.touch_app_outlined,
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: enabled ? _comment : null,
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Adicionar observação'),
          ),
        ),
      );
    }

    return SectionCard(
      title: 'Ações',
      icon: Icons.touch_app_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: enabled ? _comment : null,
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Registrar ação'),
              ),
              if (alert.status == AlertStatus.ativo)
                OutlinedButton.icon(
                  onPressed: enabled && canOperate ? _acknowledge : null,
                  icon: const Icon(Icons.assignment_ind_outlined, size: 18),
                  label: const Text('Assumir'),
                ),
              OutlinedButton.icon(
                onPressed: enabled && canOperate ? () => _simulate(AreaAction.ventilacao) : null,
                icon: const Icon(Icons.air, size: 18),
                label: const Text('Ativar ventilação'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.critical),
                onPressed: enabled && canOperate ? () => _simulate(AreaAction.isolamento) : null,
                icon: const Icon(Icons.block, size: 18),
                label: const Text('Isolar área'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Ventilação e isolamento são SIMULAÇÕES: apenas registram a ação no histórico.',
            style: AppText.caption,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: enabled && canOperate ? _resolve : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Marcar como resolvido'),
          ),
          if (!canOperate)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Você pode registrar ações. Assumir, simular e resolver alertas exige '
                'acesso de operação nesta área.',
                style: AppText.caption,
              ),
            ),
        ],
      ),
    );
  }
}
