import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/occurrence.dart';
import '../../repositories/repositories.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/safecore_app_bar.dart';

enum _MuralFilter {
  todos('Todos'),
  avisos('Avisos'),
  ocorrencias('Ocorrências'),
  pendentes('Pendentes'),
  resolvidas('Resolvidas');

  const _MuralFilter(this.label);
  final String label;

  bool matches(Occurrence o) => switch (this) {
        todos => true,
        avisos => o.kind == OccurrenceKind.aviso,
        ocorrencias => o.kind == OccurrenceKind.ocorrencia,
        pendentes => o.status != OccurrenceStatus.resolvida,
        resolvidas => o.status == OccurrenceStatus.resolvida,
      };
}

/// Mural de avisos e ocorrências relacionados às áreas.
class OccurrencesScreen extends StatefulWidget {
  const OccurrencesScreen({super.key});

  @override
  State<OccurrencesScreen> createState() => _OccurrencesScreenState();
}

class _OccurrencesScreenState extends State<OccurrencesScreen> {
  final _loaderKey = GlobalKey<AsyncLoaderState<List<Occurrence>>>();
  _MuralFilter _filter = _MuralFilter.todos;

  Future<void> _open(String route, [Object? args]) async {
    final changed = await Navigator.pushNamed(context, route, arguments: args);
    if (changed == true || route == AppRoutes.occurrenceDetail) {
      await _loaderKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SafeCoreAppBar(title: 'Mural de Avisos'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        onPressed: () => _open(AppRoutes.newOccurrence),
        icon: const Icon(Icons.add),
        label: const Text('Novo relato'),
      ),
      body: AsyncLoader<List<Occurrence>>(
        key: _loaderKey,
        load: Repos.occurrences.fetchAll,
        builder: (context, items, reload) {
          final filtered = items.where(_filter.matches).toList();
          // Avisos abertos ficam no topo do mural
          filtered.sort((a, b) {
            int pin(Occurrence o) =>
                o.kind == OccurrenceKind.aviso && o.status != OccurrenceStatus.resolvida ? 0 : 1;
            final p = pin(a).compareTo(pin(b));
            return p != 0 ? p : b.createdAt.compareTo(a.createdAt);
          });
          return RefreshIndicator(
            onRefresh: reload,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      children: [
                        for (final f in _MuralFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('${f.label} (${items.where(f.matches).length})'),
                              selected: _filter == f,
                              onSelected: (_) => setState(() => _filter = f),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(message: 'Nenhum registro no mural.', icon: Icons.campaign_outlined),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => OccurrenceCard(
                        occurrence: filtered[i],
                        onTap: () => _open(AppRoutes.occurrenceDetail, filtered[i].id),
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

class OccurrenceCard extends StatelessWidget {
  const OccurrenceCard({super.key, required this.occurrence, required this.onTap});

  final Occurrence occurrence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = occurrence;
    final isNotice = o.kind == OccurrenceKind.aviso;
    return AccentCard(
      accent: isNotice ? AppColors.primary : o.priority.color,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(o.kind.icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(o.kind.label.toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.6)),
              const Spacer(),
              StatusTag(o.status.style, solid: false),
            ],
          ),
          const SizedBox(height: 6),
          Text(o.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            o.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodySecondary,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _Meta(icon: Icons.location_on_outlined, text: o.areaName ?? 'Geral'),
              _Meta(icon: Icons.flag_outlined, text: 'Prioridade ${o.priority.label.toLowerCase()}', color: o.priority.color),
              _Meta(icon: Icons.person_outline, text: o.reportedByName),
              _Meta(icon: Icons.schedule, text: Fmt.relativeDay(o.createdAt)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11.5, color: color ?? AppColors.textSecondary)),
      ],
    );
  }
}
