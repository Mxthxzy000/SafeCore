import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/formatters.dart';
import '../../models/alert.dart';
import '../../models/occurrence.dart';
import '../../models/plant_summary.dart';

const _primary = PdfColor.fromInt(0xFF1B3F6B);
const _navy = PdfColor.fromInt(0xFF0F2541);
const _slate = PdfColor.fromInt(0xFF2F4858);
const _muted = PdfColor.fromInt(0xFF6B7C88);
const _border = PdfColor.fromInt(0xFFDCE3E8);
const _surface = PdfColor.fromInt(0xFFF3F6F8);
const _safe = PdfColor.fromInt(0xFF2E9E4F);
const _critical = PdfColor.fromInt(0xFFD32F2F);

/// As fontes padrão do PDF só cobrem Latin-1; troca o resto por equivalentes.
String _t(String s) => String.fromCharCodes(
  s.replaceAll('—', '-').replaceAll('–', '-').replaceAll('•', '-').runes.map((r) => r > 255 ? 0x3F : r),
);

/// Monta o PDF do relatório do período com a logo e os dados da tela.
Future<Uint8List> buildReportPdf({
  required Uint8List logoPng,
  required String periodLabel,
  required DateTime start,
  required DateTime end,
  required PlantSummary summary,
  required List<Alert> alerts,
  required List<Occurrence> occurrences,
  required List<(String, String)> indicators,
  required List<(String, String)> temperature,
  String? generatedBy,
}) async {
  final logo = pw.MemoryImage(logoPng);
  final now = DateTime.now();
  final doc = pw.Document(title: 'Relatório SafeCore', author: 'SafeCore');

  final history = <(DateTime, List<String>)>[
    for (final a in alerts)
      (a.detectedAt, [Fmt.dateTime(a.detectedAt), 'Alerta', a.title, a.areaName, a.tagStyle.label]),
    for (final o in occurrences)
      (
        o.createdAt,
        [Fmt.dateTime(o.createdAt), o.kind.label, o.title, o.areaName ?? 'Geral', o.status.style.label],
      ),
  ]..sort((a, b) => b.$1.compareTo(a.$1));

  pw.Widget section(String title, pw.Widget child) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 14),
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        left: const pw.BorderSide(color: _primary, width: 3),
        top: const pw.BorderSide(color: _border),
        right: const pw.BorderSide(color: _border),
        bottom: const pw.BorderSide(color: _border),
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          _t(title),
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _primary),
        ),
        pw.SizedBox(height: 8),
        child,
      ],
    ),
  );

  pw.Widget stat(String value, String label, {PdfColor color = _primary}) => pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: 3),
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(color: _surface, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Column(
        children: [
          pw.Text(
            _t(value),
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color),
          ),
          pw.SizedBox(height: 2),
          pw.Text(_t(label), style: const pw.TextStyle(fontSize: 9, color: _muted)),
        ],
      ),
    ),
  );

  pw.Widget rows(List<(String, String)> items) => pw.Column(
    children: [
      for (final (label, value) in items)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.5)),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(_t(label), style: const pw.TextStyle(fontSize: 10, color: _slate)),
              ),
              pw.Text(
                _t(value),
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _slate),
              ),
            ],
          ),
        ),
    ],
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
      header: (context) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 16),
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const pw.BoxDecoration(
          gradient: pw.LinearGradient(
            begin: pw.Alignment.topCenter,
            end: pw.Alignment.bottomCenter,
            colors: [_navy, _primary],
          ),
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: 44,
              height: 44,
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Image(logo),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SafeCore',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  ),
                  pw.Text(
                    _t('Monitoramento e Segurança Industrial'),
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  _t('Relatório - $periodLabel'),
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
                pw.Text(
                  '${Fmt.date(start)} a ${Fmt.date(end)}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.white),
                ),
              ],
            ),
          ],
        ),
      ),
      footer: (context) => pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              _t(
                'Gerado em ${Fmt.dateTime(now)}${generatedBy == null || generatedBy.isEmpty ? '' : ' por $generatedBy'}'
                ' - medições simuladas para demonstração',
              ),
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ),
          pw.Text(
            _t('Página ${context.pageNumber} de ${context.pagesCount}'),
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
      build: (context) => [
        section(
          'Resumo do Período',
          pw.Row(
            children: [
              stat(Fmt.twoDigits(summary.totalAreas), 'Áreas'),
              stat(Fmt.twoDigits(summary.totalSensors), 'Sensores'),
              stat(Fmt.twoDigits(alerts.length), 'Alertas', color: alerts.isEmpty ? _safe : _critical),
              stat(
                Fmt.percent(summary.availability),
                'Disponibilidade',
                color: summary.availability >= 95 ? _safe : _critical,
              ),
            ],
          ),
        ),
        section(
          'Status Geral da Planta',
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _t(summary.statusTitle),
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _slate),
              ),
              pw.SizedBox(height: 2),
              pw.Text(_t(summary.statusMessage), style: const pw.TextStyle(fontSize: 10, color: _slate)),
            ],
          ),
        ),
        section('Indicadores', rows(indicators)),
        section('Temperatura no Período', rows(temperature)),
        section(
          'Histórico de Ocorrências',
          history.isEmpty
              ? pw.Text(
                  _t('Nenhum alerta ou ocorrência no período.'),
                  style: const pw.TextStyle(fontSize: 10, color: _muted),
                )
              : pw.TableHelper.fromTextArray(
                  headers: const ['Data', 'Tipo', 'Título', 'Área', 'Situação'],
                  data: [for (final (_, cells) in history) cells.map(_t).toList()],
                  headerStyle: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(color: _primary),
                  cellStyle: const pw.TextStyle(fontSize: 8.5, color: _slate),
                  oddRowDecoration: const pw.BoxDecoration(color: _surface),
                  border: null,
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.2),
                    1: const pw.FlexColumnWidth(1.3),
                    2: const pw.FlexColumnWidth(3),
                    3: const pw.FlexColumnWidth(1.8),
                    4: const pw.FlexColumnWidth(1.4),
                  },
                ),
        ),
      ],
    ),
  );

  return doc.save();
}
