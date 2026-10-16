import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:safecore/features/reports/report_pdf.dart';
import 'package:safecore/models/alert.dart';
import 'package:safecore/models/enums.dart';
import 'package:safecore/models/occurrence.dart';
import 'package:safecore/models/plant_summary.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  test('gera o PDF do relatório com logo, acentos e histórico', () async {
    final now = DateTime(2026, 10, 16, 10);
    final bytes = await buildReportPdf(
      logoPng: File('assets/images/logo.png').readAsBytesSync(),
      periodLabel: 'Resumo Mensal',
      start: now.subtract(const Duration(days: 30)),
      end: now,
      summary: PlantSummary.compute(areas: const [], openAlerts: const []),
      alerts: [
        Alert(
          id: '1',
          areaId: 'a',
          areaName: 'Caldeiraria — Setor 2',
          title: 'Temperatura acima do limite',
          severity: AlertSeverity.critico,
          status: AlertStatus.resolvido,
          detectedAt: now.subtract(const Duration(hours: 5)),
          resolvedAt: now.subtract(const Duration(hours: 4)),
        ),
      ],
      occurrences: [
        Occurrence(
          id: '2',
          kind: OccurrenceKind.ocorrencia,
          title: 'Vazamento de óleo • prensa',
          description: '',
          priority: Priority.alta,
          status: OccurrenceStatus.emAnalise,
          reportedByName: 'João',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ],
      indicators: const [('Alertas resolvidos', '1 de 1'), ('Tempo médio de resolução', '1 h')],
      temperature: const [('Temperatura média', '24,3 °C')],
      generatedBy: 'Usuário Teste',
    );

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final out = Platform.environment['SAFECORE_PDF_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });
}

