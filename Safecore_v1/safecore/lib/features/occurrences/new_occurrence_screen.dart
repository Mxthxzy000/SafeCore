import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../models/area.dart';
import '../../models/enums.dart';
import '../../repositories/repositories.dart';
import '../../services/session_controller.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/form_fields.dart';
import '../../shared/widgets/safecore_app_bar.dart';

/// Cadastro de relato (ocorrência) ou aviso no mural.
class NewOccurrenceScreen extends StatefulWidget {
  const NewOccurrenceScreen({super.key, this.initialAreaId});

  final String? initialAreaId;

  @override
  State<NewOccurrenceScreen> createState() => _NewOccurrenceScreenState();
}

class _NewOccurrenceScreenState extends State<NewOccurrenceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  OccurrenceKind _kind = OccurrenceKind.ocorrencia;
  Priority _priority = Priority.media;
  late String? _areaId = widget.initialAreaId;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await Repos.occurrences.create(
        kind: _kind,
        title: _title.text,
        description: _description.text,
        priority: _priority,
        areaId: _areaId,
      );
      if (!mounted) return;
      showMessage(context, '${_kind.label} registrado(a) no mural.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final canPublishNotice =
        _areaId == null ? session.canOperateGeneral : session.canOperateArea(_areaId!);
    if (!canPublishNotice && _kind == OccurrenceKind.aviso) _kind = OccurrenceKind.ocorrencia;
    return Scaffold(
      appBar: const SafeCoreAppBar(title: 'Novo Relato'),
      body: AsyncLoader<List<Area>>(
        load: Repos.areas.fetchAll,
        builder: (context, areas, _) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              AccentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FormLabel('Tipo'),
                    SegmentedButton<OccurrenceKind>(
                      segments: [
                        const ButtonSegment(
                          value: OccurrenceKind.ocorrencia,
                          icon: Icon(Icons.assignment_late_outlined),
                          label: Text('Ocorrência'),
                        ),
                        ButtonSegment(
                          value: OccurrenceKind.aviso,
                          icon: const Icon(Icons.campaign_outlined),
                          label: const Text('Aviso'),
                          enabled: canPublishNotice,
                        ),
                      ],
                      selected: {_kind},
                      onSelectionChanged: (s) => setState(() => _kind = s.first),
                    ),
                    if (!canPublishNotice)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Para publicar avisos é preciso acesso de operação na área escolhida.',
                            style: AppText.caption),
                      ),
                    const SizedBox(height: 16),
                    const FormLabel('Área'),
                    DropdownButtonFormField<String?>(
                      initialValue: areas.any((a) => a.id == _areaId) ? _areaId : null,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Geral (toda a planta)')),
                        for (final a in areas) DropdownMenuItem<String?>(value: a.id, child: Text(a.name)),
                      ],
                      onChanged: (v) => setState(() => _areaId = v),
                    ),
                    const SizedBox(height: 16),
                    const FormLabel('Título'),
                    TextFormField(
                      controller: _title,
                      maxLength: 120,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: 'Ex.: Vazamento próximo à bomba 2'),
                      validator: (v) => Validators.minLength(v, 3, 'Título'),
                    ),
                    const SizedBox(height: 8),
                    const FormLabel('Descrição'),
                    TextFormField(
                      controller: _description,
                      maxLength: 1000,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(hintText: 'Descreva o que aconteceu, onde e quando.'),
                      validator: (v) => Validators.minLength(v, 10, 'Descrição'),
                    ),
                    const SizedBox(height: 8),
                    const FormLabel('Prioridade'),
                    SegmentedButton<Priority>(
                      showSelectedIcon: false,
                      segments: [
                        for (final p in Priority.values)
                          ButtonSegment(value: p, label: Text(p.label)),
                      ],
                      selected: {_priority},
                      onSelectionChanged: (s) => setState(() => _priority = s.first),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                      : const Icon(Icons.send),
                  label: const Text('Registrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
