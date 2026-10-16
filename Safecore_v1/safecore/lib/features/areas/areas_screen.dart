import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/area.dart';
import '../../models/enums.dart';
import '../../repositories/repositories.dart';
import '../../routes/app_routes.dart';
import '../../services/session_controller.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/safecore_app_bar.dart';
import '../../shared/widgets/search_field.dart';
import '../shell/main_shell.dart';
import 'area_visuals.dart';

class AreasScreen extends StatefulWidget {
  const AreasScreen({super.key, this.refresh});

  final Listenable? refresh;

  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> {
  String _query = '';
  AreaStatus? _status;

  List<Area> _filter(List<Area> areas) {
    final q = _query.trim().toLowerCase();
    return areas.where((a) {
      final matchesQuery = q.isEmpty ||
          a.name.toLowerCase().contains(q) ||
          a.code.toLowerCase().contains(q);
      return matchesQuery && (_status == null || a.status == _status);
    }).toList();
  }

  Future<void> _openForm() async {
    final saved = await Navigator.pushNamed(context, AppRoutes.areaNew);
    if (saved == true && mounted) ShellScope.maybeOf(context)?.refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      floatingActionButton: session.canCreateAreas
          ? FloatingActionButton.extended(
              heroTag: 'nova-area',
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Nova área'),
            )
          : null,
      appBar: const SafeCoreAppBar(title: 'Áreas de Monitoramento'),
      body: AsyncLoader<List<Area>>(
        load: Repos.areas.fetchAll,
        refresh: widget.refresh,
        builder: (context, areas, reload) {
          final filtered = _filter(areas);
          return RefreshIndicator(
            onRefresh: reload,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: SearchField(
                      hint: 'Buscar áreas...',
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _StatusFilter(
                  selected: _status,
                  areas: areas,
                  onSelected: (s) => setState(() => _status = s),
                )),
                if (filtered.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(message: 'Nenhuma área encontrada.', icon: Icons.search_off),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => AreaCard(
                        area: filtered[i],
                        onTap: () async {
                          await Navigator.pushNamed(context, AppRoutes.areaDetail,
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

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.selected, required this.areas, required this.onSelected});

  final AreaStatus? selected;
  final List<Area> areas;
  final ValueChanged<AreaStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('Todas (${areas.length})'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final s in AreaStatus.values)
            if (areas.any((a) => a.status == s))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${s.style.label} (${areas.where((a) => a.status == s).length})'),
                  selected: selected == s,
                  onSelected: (_) => onSelected(selected == s ? null : s),
                ),
              ),
        ],
      ),
    );
  }
}

/// Cartão de área (Figma): nome, status, ícone do setor e medições.
class AreaCard extends StatelessWidget {
  const AreaCard({super.key, required this.area, this.onTap});

  final Area area;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = area.status.style;
    String value(SensorType type) {
      final s = area.sensorOf(type);
      if (s == null || !s.isOnline) return '—';
      return Fmt.measure(s.lastValue, s.unit);
    }

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area.name,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusIndicator(style),
                        if (area.restricted) const RestrictedBadge(),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(areaTypeIcon(area.type), size: 34, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: ValueCaption(value: value(SensorType.temperatura), caption: 'Temperatura')),
              Expanded(child: ValueCaption(value: value(SensorType.pressao), caption: 'Pressão')),
              Expanded(child: ValueCaption(value: value(SensorType.umidade), caption: 'Umidade')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Selo de área restrita (visível somente a funcionários vinculados).
class RestrictedBadge extends StatelessWidget {
  const RestrictedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const Tooltip(
      message: 'Área restrita: visível somente para funcionários vinculados.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 14, color: AppColors.blocked),
          SizedBox(width: 2),
          Text('Restrita', style: TextStyle(fontSize: 12, color: AppColors.blocked, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
