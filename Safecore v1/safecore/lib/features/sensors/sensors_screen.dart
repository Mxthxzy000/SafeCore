import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/sensor.dart';
import '../../repositories/repositories.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/safecore_app_bar.dart';
import '../../shared/widgets/search_field.dart';
import 'widgets/sensor_tile.dart';

class SensorsScreen extends StatefulWidget {
  const SensorsScreen({super.key, this.initialAreaId});

  final String? initialAreaId;

  @override
  State<SensorsScreen> createState() => _SensorsScreenState();
}

class _SensorsScreenState extends State<SensorsScreen> {
  SensorType? _type;
  String _query = '';
  bool _onlyIssues = false;

  List<Sensor> _filter(List<Sensor> sensors) {
    final q = _query.trim().toLowerCase();
    return sensors.where((s) {
      if (widget.initialAreaId != null && s.areaId != widget.initialAreaId) return false;
      if (_type != null && s.type != _type) return false;
      if (_onlyIssues && s.isOnline && s.level == SensorLevel.normal) return false;
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) ||
          s.code.toLowerCase().contains(q) ||
          (s.areaName ?? '').toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        int rank(Sensor s) => !s.isOnline
            ? 2
            : switch (s.level) {
                SensorLevel.critico => 0,
                SensorLevel.atencao => 1,
                SensorLevel.normal => 3,
              };
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.name.compareTo(b.name);
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SafeCoreAppBar(title: 'Sensores'),
      body: AsyncLoader<List<Sensor>>(
        load: Repos.sensors.fetchAll,
        builder: (context, sensors, reload) {
          final filtered = _filter(sensors);
          return RefreshIndicator(
            onRefresh: reload,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: SearchField(
                      hint: 'Buscar sensor ou área...',
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
                          child: FilterChip(
                            label: const Text('Fora do normal'),
                            selected: _onlyIssues,
                            onSelected: (v) => setState(() => _onlyIssues = v),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('Todos'),
                            selected: _type == null,
                            onSelected: (_) => setState(() => _type = null),
                          ),
                        ),
                        for (final t in SensorType.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              avatar: Icon(t.icon, size: 16),
                              label: Text(t.label),
                              selected: _type == t,
                              onSelected: (_) => setState(() => _type = _type == t ? null : t),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${filtered.length} sensor(es)',
                              style: const TextStyle(fontSize: 12.5)),
                        ),
                        const SimulatedBadge(),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(message: 'Nenhum sensor encontrado.', icon: Icons.sensors_off),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => SensorTile(
                        sensor: filtered[i],
                        showArea: true,
                        onTap: () async {
                          await Navigator.pushNamed(context, AppRoutes.sensorDetail,
                              arguments: filtered[i].id);
                          await reload();
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
