import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/alert.dart';
import '../../models/area.dart';
import '../../models/enums.dart';
import '../../repositories/repositories.dart';
import '../../routes/app_routes.dart';
import '../../services/mqtt_service.dart';
import '../../services/session_controller.dart';
import '../../shared/widgets/action_timeline.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/safecore_app_bar.dart';
import '../alerts/widgets/alert_card.dart';
import '../sensors/widgets/sensor_tile.dart';
import 'area_visuals.dart';
import 'areas_screen.dart';

class _AreaData {
  const _AreaData(this.area, this.alerts, this.actions);

  final Area area;
  final List<Alert> alerts;
  final List<ActionLog> actions;
}

class AreaDetailScreen extends StatefulWidget {
  const AreaDetailScreen({super.key, required this.areaId});

  final String areaId;

  @override
  State<AreaDetailScreen> createState() => _AreaDetailScreenState();
}

class _AreaDetailScreenState extends State<AreaDetailScreen> {
  final _loaderKey = GlobalKey<AsyncLoaderState<_AreaData>>();

  Future<_AreaData> _load() async {
    final (area, alerts, actions) = await (
      Repos.areas.fetchById(widget.areaId),
      Repos.alerts.fetchAll(areaId: widget.areaId, limit: 10),
      Repos.areas.fetchActions(widget.areaId),
    ).wait;
    return _AreaData(area, alerts, actions);
  }

  Future<void> _edit() async {
    final saved = await Navigator.pushNamed(context, AppRoutes.areaEdit, arguments: widget.areaId);
    if (saved == true) await _loaderKey.currentState?.reload();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Excluir área',
      message: 'Deseja excluir esta área?\n\n'
          'Se ela possuir sensores, leituras, alertas ou ocorrências, será ARQUIVADA: '
          'deixa de aparecer nas listas, mas todo o histórico é preservado.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      final archived = await Repos.areas.delete(widget.areaId);
      if (!mounted) return;
      showMessage(
        context,
        archived
            ? 'Área arquivada. O histórico de sensores e alertas foi preservado.'
            : 'Área excluída.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: SafeCoreAppBar(
        title: 'Detalhes da Área',
        actions: [
          if (session.canManageArea(widget.areaId))
            IconButton(tooltip: 'Editar área', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
          if (session.canDeleteAreas)
            IconButton(tooltip: 'Excluir área', icon: const Icon(Icons.delete_outline), onPressed: _delete),
          const SizedBox(width: 4),
        ],
      ),
      body: AsyncLoader<_AreaData>(
        key: _loaderKey,
        load: _load,
        refresh: MqttService.instance,
        builder: (context, data, reload) => RefreshIndicator(
          onRefresh: reload,
          child: _AreaBody(data: data, reload: reload),
        ),
      ),
    );
  }
}

class _AreaBody extends StatelessWidget {
  const _AreaBody({required this.data, required this.reload});

  final _AreaData data;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    final area = data.area;
    final style = area.status.style;
    final openAlerts = data.alerts.where((a) => !a.isResolved).toList();
    final isBoiler = MqttService.isBoilerArea(area);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        AccentCard(
          accent: style.color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          area.name,
                          style: const TextStyle(
                            fontSize: 19,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text('Código ${area.code}',
                            style: AppText.caption),
                      ],
                    ),
                  ),
                  Icon(areaTypeIcon(area.type), size: 40, color: AppColors.primary),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: StatusIndicator(style, fontSize: 14)),
                        if (area.restricted) const RestrictedBadge(),
                      ],
                    ),
                    if ((area.statusNote ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(area.statusNote!, style: const TextStyle(fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
              if ((area.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(area.description!, style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionHeader(
          'Sensores (${area.sensors.length})',
          trailing: SimulatedBadge(
            text: isBoiler ? 'MQTT: quimex/caldeira' : 'Broker desconectado',
          ),
        ),
        if (area.sensors.isEmpty)
          const EmptyView(message: 'Nenhum sensor cadastrado nesta área.', icon: Icons.sensors_off)
        else
          for (final s in area.sensors) ...[
            SensorTile(
              sensor: s,
              onTap: () => Navigator.pushNamed(context, AppRoutes.sensorDetail, arguments: s.id),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 10),
        SectionHeader(
          'Alertas abertos (${openAlerts.length})',
          trailing: SessionScope.of(context).canOperateArea(area.id)
              ? TextButton.icon(
                  onPressed: () async {
                    final saved =
                        await Navigator.pushNamed(context, AppRoutes.alertNew, arguments: area.id);
                    if (saved == true) await reload();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Novo alerta'),
                )
              : null,
        ),
        if (openAlerts.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Nenhum alerta aberto nesta área.',
                style: AppText.bodySecondary),
          )
        else
          for (final a in openAlerts) ...[
            AlertCard(
              alert: a,
              onTap: () async {
                await Navigator.pushNamed(context, AppRoutes.alertDetail, arguments: a.id);
                await reload();
              },
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 10),
        _AreaActions(area: area, reload: reload),
        const SizedBox(height: 18),
        const SectionHeader('Histórico de ações'),
        AccentCard(child: ActionTimeline(actions: data.actions)),
      ],
    );
  }
}

class _AreaActions extends StatefulWidget {
  const _AreaActions({required this.area, required this.reload});

  final Area area;
  final Future<void> Function() reload;

  @override
  State<_AreaActions> createState() => _AreaActionsState();
}

class _AreaActionsState extends State<_AreaActions> {
  bool _busy = false;

  Future<void> _run(AreaAction action) async {
    final messages = {
      AreaAction.ventilacao:
          'Será registrado o acionamento da ventilação de emergência em ${widget.area.name}.',
      AreaAction.isolamento:
          'A área ${widget.area.name} será marcada como interditada.',
      AreaAction.liberacao:
          'A área ${widget.area.name} voltará a ser monitorada normalmente.',
    };
    final ok = await confirmDialog(
      context,
      title: '${action.label} (simulação)',
      message: '${messages[action]}\n\nNesta versão nenhum equipamento físico é acionado: '
          'a ação é registrada no histórico como SIMULAÇÃO.',
      confirmLabel: 'Registrar simulação',
      destructive: action == AreaAction.isolamento,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await Repos.areas.simulateAction(widget.area.id, action);
      if (!mounted) return;
      showMessage(context, 'Simulação registrada: ${action.label.toLowerCase()}.');
      await widget.reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canOperate = SessionScope.of(context).canOperateArea(widget.area.id);
    final blocked = widget.area.status == AreaStatus.interditada;
    final enabled = canOperate && !_busy;

    return SectionCard(
      title: 'Ações na área',
      icon: Icons.touch_app_outlined,
      trailing: const SimulatedBadge(text: 'Simulação'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: enabled ? () => _run(AreaAction.ventilacao) : null,
                icon: const Icon(Icons.air, size: 18),
                label: const Text('Ativar ventilação'),
              ),
              if (blocked)
                OutlinedButton.icon(
                  onPressed: enabled ? () => _run(AreaAction.liberacao) : null,
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: const Text('Liberar área'),
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.critical),
                  onPressed: enabled ? () => _run(AreaAction.isolamento) : null,
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text('Isolar área'),
                ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.newOccurrence,
                    arguments: widget.area.id),
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('Registrar ocorrência'),
              ),
            ],
          ),
          if (!canOperate)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Você precisa de acesso de operação nesta área para executar ações.',
                style: AppText.caption,
              ),
            ),
        ],
      ),
    );
  }
}
