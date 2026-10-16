import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/alert.dart';
import '../../models/area.dart';
import '../../models/enums.dart';
import '../../repositories/repositories.dart';
import '../../services/session_controller.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/safecore_app_bar.dart';

/// Cadastro (alerta manual) ou edição de alerta.
/// Alertas gerados por sensores só permitem editar título, descrição e status:
/// as medições e o histórico do sensor nunca são alterados por este formulário.
class AlertFormScreen extends StatelessWidget {
  const AlertFormScreen({super.key, this.alertId, this.initialAreaId});

  final String? alertId;
  final String? initialAreaId;

  Future<(Alert?, List<Area>)> _load() async {
    final areas = Repos.areas.fetchAll();
    if (alertId == null) return (null, await areas);
    final (alert, list) = await (Repos.alerts.fetchById(alertId!), areas).wait;
    return (alert, list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SafeCoreAppBar(title: alertId == null ? 'Novo Alerta' : 'Editar Alerta'),
      body: AsyncLoader<(Alert?, List<Area>)>(
        load: _load,
        builder: (context, data, _) {
          final session = SessionScope.of(context);
          final (alert, areas) = data;
          final allowed = areas.where((a) => session.canOperateArea(a.id)).toList();
          if (alert == null && allowed.isEmpty) {
            return const EmptyView(
              message: 'Você não tem permissão de operação em nenhuma área para cadastrar alertas.',
              icon: Icons.lock_outline,
            );
          }
          return _AlertForm(alert: alert, areas: allowed, initialAreaId: initialAreaId);
        },
      ),
    );
  }
}

class _AlertForm extends StatefulWidget {
  const _AlertForm({required this.areas, this.alert, this.initialAreaId});

  final Alert? alert;
  final List<Area> areas;
  final String? initialAreaId;

  @override
  State<_AlertForm> createState() => _AlertFormState();
}

class _AlertFormState extends State<_AlertForm> {
  final _formKey = GlobalKey<FormState>();
  late final Alert? _alert = widget.alert;
  late final bool _sensorAlert = _alert != null && !_alert.isManual;
  late final _title = TextEditingController(text: _alert?.title ?? '');
  late final _description = TextEditingController(text: _alert?.description ?? '');
  late final _value = TextEditingController(
      text: _alert?.detectedValue == null ? '' : Fmt.number(_alert!.detectedValue, decimals: 2));
  late final _unit = TextEditingController(text: _alert?.unit ?? '');
  late String? _areaId = _initialArea();
  late AlertSeverity _severity = _alert?.severity ?? AlertSeverity.atencao;
  late AlertStatus _status = _alert?.status ?? AlertStatus.ativo;
  late AlertCategory _category = _alert?.category ?? AlertCategory.outro;
  late DateTime _detectedAt = _alert?.detectedAt.toLocal() ?? DateTime.now();
  bool _saving = false;

  String? _initialArea() {
    final ids = widget.areas.map((a) => a.id).toSet();
    final candidate = widget.alert?.areaId ?? widget.initialAreaId;
    if (candidate != null && (ids.contains(candidate) || widget.alert != null)) return candidate;
    return widget.areas.length == 1 ? widget.areas.first.id : null;
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _value, _unit]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parseValue() {
    var t = _value.text.trim();
    // Aceita "1,40" (padrão brasileiro, com "." de milhar) e "1.40"
    if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
    return t.isEmpty ? null : double.tryParse(t);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      showMessage(context, 'Revise os campos destacados.', error: true);
      return;
    }
    final input = AlertInput(
      areaId: _areaId!,
      title: _title.text,
      description: _description.text,
      severity: _severity,
      status: _status,
      category: _category,
      detectedAt: _detectedAt,
      detectedValue: _parseValue(),
      unit: _unit.text,
    );
    setState(() => _saving = true);
    try {
      if (_alert == null) {
        await Repos.alerts.create(input);
      } else {
        await Repos.alerts.update(_alert.id, input, sensorAlert: _sensorAlert);
      }
      if (!mounted) return;
      showMessage(context, _alert == null ? 'Alerta cadastrado.' : 'Alerta atualizado.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _sensorAlert;
    // Na edição, a área atual aparece mesmo se o usuário não puder escolhê-la de novo
    final areaItems = [
      ...widget.areas,
      if (_alert != null && !widget.areas.any((a) => a.id == _alert.areaId))
        Area(id: _alert.areaId, code: '', name: _alert.areaName, type: '', status: AreaStatus.segura),
    ];

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (_alert != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _OriginNotice(alert: _alert),
            ),
          SectionCard(
            title: 'Informações do alerta',
            icon: Icons.warning_amber_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FormLabel('Título *'),
                TextFormField(
                  controller: _title,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Ex.: Vazamento de óleo na bomba 2'),
                  validator: (v) => Validators.minLength(v, 3, 'Título'),
                ),
                const FormLabel('Descrição'),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 500,
                  decoration: const InputDecoration(hintText: 'O que foi observado e onde.'),
                ),
                const FormLabel('Área *'),
                DropdownButtonFormField<String>(
                  initialValue: _areaId,
                  isExpanded: true,
                  hint: const Text('Selecione a área'),
                  items: [
                    for (final a in areaItems) DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: locked ? null : (v) => setState(() => _areaId = v),
                  validator: (v) => v == null ? 'Selecione a área.' : null,
                ),
                const SizedBox(height: 14),
                const FormLabel('Categoria (tipo de risco) *'),
                DropdownButtonFormField<AlertCategory>(
                  initialValue: _category,
                  isExpanded: true,
                  items: [
                    for (final c in AlertCategory.values)
                      DropdownMenuItem(value: c, child: Text(c.label)),
                  ],
                  onChanged: locked ? null : (v) => setState(() => _category = v ?? _category),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Severidade e situação',
            icon: Icons.flag_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FormLabel('Severidade *'),
                SegmentedButton<AlertSeverity>(
                  segments: [
                    for (final s in AlertSeverity.values)
                      ButtonSegment(value: s, icon: Icon(s.style.icon), label: Text(s.style.label)),
                  ],
                  selected: {_severity},
                  onSelectionChanged: locked ? null : (s) => setState(() => _severity = s.first),
                ),
                const SizedBox(height: 14),
                const FormLabel('Status *'),
                SegmentedButton<AlertStatus>(
                  showSelectedIcon: false,
                  segments: [
                    for (final s in AlertStatus.values)
                      ButtonSegment(value: s, label: Text(s.label, style: const TextStyle(fontSize: 12.5))),
                  ],
                  selected: {_status},
                  onSelectionChanged: (s) => setState(() => _status = s.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Medição e horário',
            icon: Icons.schedule,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _value,
                        enabled: !locked,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(labelText: 'Valor detectado'),
                        validator: (v) => (v ?? '').trim().isNotEmpty && _parseValue() == null
                            ? 'Número inválido.'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _unit,
                        enabled: !locked,
                        maxLength: 10,
                        decoration: const InputDecoration(labelText: 'Unidade', counterText: ''),
                        validator: (v) => _value.text.trim().isNotEmpty && (v ?? '').trim().isEmpty
                            ? 'Informe a unidade.'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const FormLabel('Data e hora da detecção *'),
                IgnorePointer(
                  ignoring: locked,
                  child: Opacity(
                    opacity: locked ? 0.6 : 1,
                    child: DateTimeField(
                      value: _detectedAt,
                      formatted: Fmt.dateTime(_detectedAt),
                      onChanged: (d) => setState(() => _detectedAt = d),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_alert == null ? 'Cadastrar alerta' : 'Salvar alterações'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OriginNotice extends StatelessWidget {
  const _OriginNotice({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final sensor = !alert.isManual;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sensor ? AppColors.lightBlue.withValues(alpha: 0.2) : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(alert.origin.icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sensor
                  ? 'Alerta gerado automaticamente por leitura de sensor. Para preservar o '
                      'histórico de medições, só é possível editar título, descrição e status.'
                  : 'Alerta cadastrado manualmente. Alterações não afetam as medições dos sensores.',
              style: AppText.bodySecondary,
            ),
          ),
        ],
      ),
    );
  }
}
