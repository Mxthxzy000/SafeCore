import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/alert.dart';
import '../../models/enums.dart';
import '../../repositories/repositories.dart';
import '../../routes/app_routes.dart';
import '../../services/session_controller.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/safecore_app_bar.dart';
import '../../shared/widgets/search_field.dart';
import '../shell/main_shell.dart';
import 'widgets/alert_card.dart';

enum AlertFilter {
  abertos('Abertos'),
  critico('Crítico'),
  atencao('Atenção'),
  resolvido('Resolvido'),
  todos('Todos');

  const AlertFilter(this.label);
  final String label;

  bool matches(Alert a) => switch (this) {
        abertos => !a.isResolved,
        critico => !a.isResolved && a.severity == AlertSeverity.critico,
        atencao => !a.isResolved && a.severity == AlertSeverity.atencao,
        resolvido => a.isResolved,
        todos => true,
      };
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, this.refresh});

  final Listenable? refresh;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  AlertFilter _filter = AlertFilter.abertos;
  String _query = '';
  String? _area;

  List<Alert> _apply(List<Alert> alerts) {
    final q = _query.trim().toLowerCase();
    return alerts.where((a) {
      if (!_filter.matches(a)) return false;
      if (_area != null && a.areaName != _area) return false;
      if (q.isEmpty) return true;
      return a.title.toLowerCase().contains(q) ||
          a.areaName.toLowerCase().contains(q) ||
          (a.description ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _pickArea(List<Alert> alerts) async {
    final areas = alerts.map((a) => a.areaName).toSet().toList()..sort();
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Filtrar por área', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.select_all),
              title: const Text('Todas as áreas'),
              selected: _area == null,
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final a in areas)
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(a),
                selected: _area == a,
                onTap: () => Navigator.pop(ctx, a),
              ),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _area = selected.isEmpty ? null : selected);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      floatingActionButton: session.canCreateAlerts
          ? FloatingActionButton.extended(
              heroTag: 'novo-alerta',
              onPressed: () async {
                final saved = await Navigator.pushNamed(context, AppRoutes.alertNew);
                if (saved == true && context.mounted) ShellScope.maybeOf(context)?.refreshAll();
              },
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Novo alerta'),
            )
          : null,
      appBar: const SafeCoreAppBar(title: 'Alertas'),
      body: AsyncLoader<List<Alert>>(
        load: () => Repos.alerts.fetchAll(),
        refresh: widget.refresh,
        builder: (context, alerts, reload) {
          final filtered = _apply(alerts);
          return RefreshIndicator(
            onRefresh: reload,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: SearchField(
                      hint: 'Buscar alertas...',
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: const Icon(Icons.location_on_outlined, size: 16),
                            label: Text(_area ?? 'Todas as áreas'),
                            backgroundColor: _area == null ? null : AppColors.lightBlue.withValues(alpha: 0.3),
                            onPressed: () => _pickArea(alerts),
                          ),
                        ),
                        for (final f in AlertFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('${f.label} (${alerts.where(f.matches).length})'),
                              selected: _filter == f,
                              onSelected: (_) => setState(() => _filter = f),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      message: _filter == AlertFilter.abertos
                          ? 'Nenhum alerta aberto. Tudo sob controle!'
                          : 'Nenhum alerta encontrado.',
                      icon: Icons.notifications_off_outlined,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => AlertCard(
                        alert: filtered[i],
                        onTap: () async {
                          await Navigator.pushNamed(context, AppRoutes.alertDetail,
                              arguments: filtered[i].id);
                          if (context.mounted) ShellScope.maybeOf(context)?.refreshAll();
                        },
                      ),
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
