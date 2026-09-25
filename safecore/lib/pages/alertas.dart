import 'package:flutter/material.dart';

class AlertasPage extends StatefulWidget {
  const AlertasPage({super.key});

  @override
  State<AlertasPage> createState() => _AlertasPageState();
}

class _AlertasPageState extends State<AlertasPage> {
  int _selectedFilterIndex = 0;

  @override
  Widget build(BuildContext context) {
    final alerts = [
      _AlertItem(
        title: 'Sensor de fumaça',
        location: 'Estacionamento - nível 2',
        time: 'Há 4 min',
        severity: 'Crítico',
        severityColor: const Color(0xFFD94A4A),
        detail: 'Disparo confirmado em área de circulação.',
      ),
      _AlertItem(
        title: 'Temperatura elevada',
        location: 'Cozinha industrial',
        time: 'Há 12 min',
        severity: 'Alerta',
        severityColor: const Color(0xFFE4A93A),
        detail: 'Ar condicionado fora do limiar recomendado.',
      ),
      _AlertItem(
        title: 'Acesso indevido',
        location: 'Portaria norte',
        time: 'Há 28 min',
        severity: 'Médio',
        severityColor: const Color(0xFF0F5EC8),
        detail: 'Tentativa bloqueada e registrada em log.',
      ),
      _AlertItem(
        title: 'Manutenção programada',
        location: 'Sistema de energia',
        time: 'Hoje, 14:00',
        severity: 'Informativo',
        severityColor: const Color(0xFF2EAE7A),
        detail: 'Ação planejada sem interrupção de operação.',
      ),
    ];

    final filters = ['Todos', 'Críticos', 'Ativos', 'Resolvidos'];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 28 : 20,
                isDesktop ? 24 : 18,
                isDesktop ? 28 : 20,
                isDesktop ? 32 : 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alertas',
                    style: TextStyle(
                      color: Color(0xFF1F2A37),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Eventos e incidentes em tempo real.',
                    style: TextStyle(
                      color: Color(0xFF5E6C82),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: filters.length,
                      separatorBuilder: (context, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final filter = filters[index];
                        final selected = index == _selectedFilterIndex;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedFilterIndex = index;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Filtro "$filter" aplicado aos alertas.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFF0F5EC8) : Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              filter,
                              style: TextStyle(
                                color: selected ? Colors.white : const Color(0xFF4A5A6D),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, innerConstraints) {
                        final columns = isDesktop ? 2 : 1;
                        final spacing = 14.0;
                        final width = columns == 1
                            ? innerConstraints.maxWidth
                            : (innerConstraints.maxWidth - spacing) / 2;

                        return SingleChildScrollView(
                          child: Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: alerts
                                .map(
                                  (alert) => SizedBox(
                                    width: width,
                                    child: alert,
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      },
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
}

class _AlertItem extends StatelessWidget {
  final String title;
  final String location;
  final String time;
  final String severity;
  final Color severityColor;
  final String detail;

  const _AlertItem({
    required this.title,
    required this.location,
    required this.time,
    required this.severity,
    required this.severityColor,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: severityColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF1F2A37),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: severityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        severity,
                        style: TextStyle(
                          color: severityColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  location,
                  style: const TextStyle(
                    color: Color(0xFF5E6C82),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detail,
                  style: const TextStyle(
                    color: Color(0xFF4A5A6D),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 15,
                      color: Color(0xFF73839C),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: const TextStyle(
                        color: Color(0xFF73839C),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
