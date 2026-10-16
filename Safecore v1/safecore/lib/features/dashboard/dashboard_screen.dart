import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/plant_summary.dart';
import '../../repositories/repositories.dart';
import '../../routes/app_routes.dart';
import '../../services/session_controller.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/safecore_app_bar.dart';
import '../shell/main_shell.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.refresh});

  final Listenable? refresh;

  Future<PlantSummary> _load() async {
    final (areas, alerts) = await (
      Repos.areas.fetchAll(),
      Repos.alerts.fetchAll(openOnly: true),
    ).wait;
    return PlantSummary.compute(areas: areas, openAlerts: alerts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SafeCoreAppBar(title: 'Painel de Monitoramento'),
      body: AsyncLoader<PlantSummary>(
        load: _load,
        refresh: refresh,
        builder: (context, summary, reload) => RefreshIndicator(
          onRefresh: reload,
          child: _DashboardBody(summary: summary, reload: reload),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.summary, required this.reload});

  final PlantSummary summary;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    final profile = SessionScope.of(context).profile;
    final name = Fmt.shortName(profile?.displayName ?? '');
    final shell = ShellScope.maybeOf(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Text(
          name.isEmpty ? 'Olá!' : 'Olá, $name',
          style: const TextStyle(fontSize: 22, color: AppColors.primary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        const Text.rich(
          TextSpan(children: [
            TextSpan(text: 'Bem vindo ao '),
            TextSpan(text: 'SafeCore', style: TextStyle(color: AppColors.safe, fontWeight: FontWeight.w600)),
          ]),
          style: AppText.bodySecondary,
        ),
        const SizedBox(height: 16),
        _PlantStatusCard(summary: summary, onTap: () => shell?.goTo(ShellTab.areas)),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Resumo Geral',
          child: _SummaryGrid(summary: summary),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Condições Gerais',
          child: _ConditionsList(summary: summary),
        ),
        const SizedBox(height: 14),
        const SectionCard(title: 'Acesso Rápido', child: _QuickAccess()),
        const SizedBox(height: 14),
        _SimulationCard(summary: summary, reload: reload),
      ],
    );
  }
}

class _PlantStatusCard extends StatelessWidget {
  const _PlantStatusCard({required this.summary, required this.onTap});

  final PlantSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = summary.overallStatus.style;
    final icon = switch (summary.overallStatus) {
      AreaStatus.segura => Icons.verified_user,
      AreaStatus.critica => Icons.gpp_bad,
      _ => Icons.gpp_maybe,
    };
    return SectionCard(
      title: 'Status Geral da Planta',
      child: Material(
        color: style.background,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: style.color.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 40, color: style.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.statusTitle,
                        style: TextStyle(
                          color: style.color,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(summary.statusMessage, style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final PlantSummary summary;

  @override
  Widget build(BuildContext context) {
    final shell = ShellScope.maybeOf(context);
    final tiles = [
      _Tile(
        icon: Icons.share_location_outlined,
        label: 'Áreas monitoradas',
        value: Fmt.twoDigits(summary.totalAreas),
        onTap: () => shell?.goTo(ShellTab.areas),
      ),
      _Tile(
        icon: Icons.sensors,
        label: 'Sensores ativos',
        value: Fmt.twoDigits(summary.onlineSensors),
        detail: 'de ${summary.totalSensors}',
        onTap: () => Navigator.pushNamed(context, AppRoutes.sensors),
      ),
      _Tile(
        icon: Icons.warning_amber_rounded,
        label: 'Alertas ativos',
        value: Fmt.twoDigits(summary.activeAlerts),
        valueColor: summary.activeAlerts > 0 ? AppColors.critical : AppColors.safe,
        onTap: () => shell?.goTo(ShellTab.alertas),
      ),
      _Tile(
        icon: Icons.wifi_tethering,
        label: 'Disponibilidade',
        value: Fmt.percent(summary.availability),
        valueColor: summary.availability >= 95 ? AppColors.safe : AppColors.warning,
        onTap: () => shell?.goTo(ShellTab.relatorios),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final t in tiles) SizedBox(width: width, child: t)],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.detail,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final Color? valueColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(color: AppColors.border),
            boxShadow: AppTheme.tileShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      style: AppText.caption,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? AppColors.primary,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(detail!, style: AppText.small),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConditionsList extends StatelessWidget {
  const _ConditionsList({required this.summary});

  final PlantSummary summary;

  @override
  Widget build(BuildContext context) {
    Color airColor() => switch (summary.airQuality) {
          AirQuality.boa => AppColors.safe,
          AirQuality.moderada => AppColors.warning,
          AirQuality.ruim => AppColors.critical,
          AirQuality.semDados => AppColors.offline,
        };
    Color ventColor() => switch (summary.ventilation) {
          VentilationState.ativa => AppColors.safe,
          VentilationState.insuficiente => AppColors.warning,
          VentilationState.semDados => AppColors.offline,
        };
    return Column(
      children: [
        _ConditionRow(
          icon: Icons.thermostat,
          label: 'Temperatura Média',
          value: Fmt.measure(summary.avgTemperature, '°C'),
        ),
        _ConditionRow(
          icon: Icons.cloud_outlined,
          label: 'Qualidade do Ar',
          value: summary.airQuality.label,
          valueColor: airColor(),
          dot: true,
        ),
        _ConditionRow(
          icon: Icons.air,
          label: 'Ventilação',
          value: summary.ventilation.label,
          valueColor: ventColor(),
          dot: true,
        ),
      ],
    );
  }
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.dot = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.slate),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          if (dot) ...[
            Icon(Icons.circle, size: 8, color: valueColor),
            const SizedBox(width: 5),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.map_outlined, 'Mapa da planta', AppRoutes.industrialMap),
      (Icons.sensors, 'Sensores', AppRoutes.sensors),
      (Icons.campaign_outlined, 'Mural de avisos', AppRoutes.occurrences),
    ];
    return Row(
      children: [
        for (final (i, (icon, label, route)) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              ),
              onPressed: () async {
                await Navigator.pushNamed(context, route);
                if (context.mounted) ShellScope.maybeOf(context)?.refreshAll();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 24),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SimulationCard extends StatefulWidget {
  const _SimulationCard({required this.summary, required this.reload});

  final PlantSummary summary;
  final Future<void> Function() reload;

  @override
  State<_SimulationCard> createState() => _SimulationCardState();
}

class _SimulationCardState extends State<_SimulationCard> {
  bool _running = false;

  Future<void> _simulate() async {
    setState(() => _running = true);
    try {
      final count = await Repos.sensors.simulateReadings();
      if (!mounted) return;
      showMessage(context, '$count leituras simuladas registradas.');
      ShellScope.maybeOf(context)?.refreshAll();
      await widget.reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = widget.summary.lastUpdate;
    return AccentCard(
      accent: AppColors.lightBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SimulatedBadge(),
              Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'As medições desta versão são simuladas para demonstração. '
            'A estrutura já está pronta para receber leituras de dispositivos ESP32.'
            '${last != null ? '\nÚltima leitura: ${Fmt.ago(last)}.' : ''}',
            style: AppText.caption,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _running ? null : _simulate,
              icon: _running
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('Gerar leitura simulada'),
            ),
          ),
        ],
      ),
    );
  }
}
