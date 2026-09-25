import 'package:flutter/material.dart';

class PainelPage extends StatelessWidget {
  const PainelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricCard(
        title: 'Áreas ativas',
        value: '18',
        subtitle: '8 críticas',
        color: const Color(0xFF0F5EC8),
        icon: Icons.location_on_outlined,
      ),
      _MetricCard(
        title: 'Alertas',
        value: '12',
        subtitle: '3 exigem atenção',
        color: const Color(0xFFDB5A42),
        icon: Icons.warning_amber_rounded,
      ),
      _MetricCard(
        title: 'Resposta',
        value: '4m 20s',
        subtitle: 'tempo médio',
        color: const Color(0xFF00A676),
        icon: Icons.timelapse_rounded,
      ),
      _MetricCard(
        title: 'Disponibilidade',
        value: '98.7%',
        subtitle: 'sistema estável',
        color: const Color(0xFF6F5EF5),
        icon: Icons.shield_outlined,
      ),
    ];

    final areas = [
      _AreaStatus(
        name: 'Portaria',
        status: 'Normal',
        statusColor: const Color(0xFF2EAE7A),
        usage: '86%',
        detail: 'Acesso controlado',
      ),
      _AreaStatus(
        name: 'Cozinha',
        status: 'Alerta',
        statusColor: const Color(0xFFE4A93A),
        usage: '72%',
        detail: 'Temperatura acima do ideal',
      ),
      _AreaStatus(
        name: 'Estacionamento',
        status: 'Crítico',
        statusColor: const Color(0xFFD94A4A),
        usage: '94%',
        detail: 'Sensor de fumaça ativo',
      ),
    ];

    final activities = [
      'Portaria liberou acesso prioritário no turno da manhã.',
      'Sensor de temperatura da cozinha disparou por 12 minutos.',
      'Relatório de manutenção do circuito foi atualizado.',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            final contentPadding = isDesktop
                ? const EdgeInsets.fromLTRB(28, 24, 28, 32)
                : const EdgeInsets.fromLTRB(20, 18, 20, 28);

            return SingleChildScrollView(
              padding: contentPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF014D90),
                          Color(0xFF0F5EC8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F5EC8).withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Bem-vindo',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Operação Central',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.circle,
                                color: Color(0xFF7ED321),
                                size: 10,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Online',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, cardConstraints) {
                      final columns = isDesktop ? 4 : 2;
                      final spacing = 12.0;
                      final cardWidth = (cardConstraints.maxWidth - (columns - 1) * spacing) / columns;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: metrics
                            .map(
                              (metric) => SizedBox(
                                width: cardWidth,
                                child: metric,
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'Monitoramento por área',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2A37),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, areaConstraints) {
                      final columns = isDesktop ? 2 : 1;
                      final spacing = 12.0;
                      final cardWidth = columns == 1
                          ? areaConstraints.maxWidth
                          : (areaConstraints.maxWidth - spacing) / 2;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: areas
                            .map(
                              (area) => SizedBox(
                                width: cardWidth,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 0),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  area.name,
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1F2A37),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: area.statusColor.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                  child: Text(
                                                    area.status,
                                                    style: TextStyle(
                                                      color: area.statusColor,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              area.detail,
                                              style: const TextStyle(
                                                color: Color(0xFF5E6C82),
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: LinearProgressIndicator(
                                                value: _progressValue(area.usage),
                                                minHeight: 8,
                                                backgroundColor: const Color(0xFFE8EEF8),
                                                valueColor: AlwaysStoppedAnimation<Color>(
                                                  area.statusColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            'Uso',
                                            style: TextStyle(
                                              color: Color(0xFF73839C),
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            area.usage,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1F2A37),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Atividades recentes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2A37),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: activities
                          .map(
                            (activity) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(top: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F5EC8),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      activity,
                                      style: const TextStyle(
                                        color: Color(0xFF2A3342),
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  double _progressValue(String usage) {
    final value = int.tryParse(usage.replaceAll('%', '')) ?? 0;
    return (value / 100).clamp(0.0, 1.0).toDouble();
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF5E6C82),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2A37),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7A8F),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaStatus {
  final String name;
  final String status;
  final Color statusColor;
  final String usage;
  final String detail;

  const _AreaStatus({
    required this.name,
    required this.status,
    required this.statusColor,
    required this.usage,
    required this.detail,
  });
}
