import 'package:flutter/material.dart';

class ReportSummary {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const ReportSummary({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });
}

class ReportEntry {
  final String title;
  final String description;
  final String date;
  final String category;
  final IconData icon;

  const ReportEntry({
    required this.title,
    required this.description,
    required this.date,
    required this.category,
    required this.icon,
  });
}

class SafeCoreSnapshot {
  final List<ReportSummary> summary;
  final List<ReportEntry> reports;

  const SafeCoreSnapshot({
    required this.summary,
    required this.reports,
  });

  factory SafeCoreSnapshot.initial() {
    return const SafeCoreSnapshot(
      summary: [
        ReportSummary(
          title: 'Incidentes',
          value: '24',
          subtitle: 'mitigados este mês',
          color: Color(0xFF0F5EC8),
        ),
        ReportSummary(
          title: 'Conformidade',
          value: '96%',
          subtitle: 'prazo legal atendido',
          color: Color(0xFF2EAE7A),
        ),
        ReportSummary(
          title: 'Tempo de resposta',
          value: '4m',
          subtitle: 'média operacional',
          color: Color(0xFFE4A93A),
        ),
      ],
      reports: [
        ReportEntry(
          title: 'Relatório de prevenção',
          description: 'Resíduos, incêndio e energia',
          date: '15 ago',
          category: 'Operacional',
          icon: Icons.shield_outlined,
        ),
        ReportEntry(
          title: 'Checklist de segurança',
          description: 'Validações diárias por área',
          date: '12 ago',
          category: 'Compliance',
          icon: Icons.fact_check_outlined,
        ),
        ReportEntry(
          title: 'Histórico de acessos',
          description: 'Registro de entradas e saídas',
          date: '09 ago',
          category: 'Acesso',
          icon: Icons.lock_clock_outlined,
        ),
        ReportEntry(
          title: 'Monitoramento de risco',
          description: 'Análise de comportamento por setor',
          date: '05 ago',
          category: 'Análise',
          icon: Icons.analytics_outlined,
        ),
      ],
    );
  }
}

class SafeCoreRepository {
  static SafeCoreSnapshot getInitialSnapshot() => SafeCoreSnapshot.initial();
}
