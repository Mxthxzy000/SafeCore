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

/// Cadastro (sem [areaId]) ou edição de uma área industrial.
/// Retorna `true` ao salvar, para a tela anterior recarregar.
class AreaFormScreen extends StatelessWidget {
  const AreaFormScreen({super.key, this.areaId});

  final String? areaId;

  @override
  Widget build(BuildContext context) {
    final editing = areaId != null;
    return Scaffold(
      appBar: SafeCoreAppBar(title: editing ? 'Editar Área' : 'Nova Área'),
      body: editing
          ? AsyncLoader<Area>(
              load: () => Repos.areas.fetchById(areaId!),
              builder: (context, area, _) => _AreaForm(area: area),
            )
          : const _AreaForm(),
    );
  }
}

class _AreaForm extends StatefulWidget {
  const _AreaForm({this.area});

  final Area? area;

  @override
  State<_AreaForm> createState() => _AreaFormState();
}

class _AreaFormState extends State<_AreaForm> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.area?.code ?? '');
  late final _name = TextEditingController(text: widget.area?.name ?? '');
  late final _description = TextEditingController(text: widget.area?.description ?? '');
  late final _note = TextEditingController(text: widget.area?.statusNote ?? '');
  late String _type = widget.area?.type ?? 'producao';
  late AreaStatus _status = widget.area?.status ?? AreaStatus.segura;
  late bool _restricted = widget.area?.restricted ?? false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_code, _name, _description, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      showMessage(context, 'Revise os campos destacados.', error: true);
      return;
    }
    final input = AreaInput(
      code: _code.text,
      name: _name.text,
      type: _type,
      status: _status.name,
      description: _description.text,
      statusNote: _note.text,
      restricted: _restricted,
    );
    setState(() => _saving = true);
    try {
      if (widget.area == null) {
        await Repos.areas.create(input);
      } else {
        await Repos.areas.update(widget.area!.id, input);
      }
      if (!mounted) return;
      showMessage(context, widget.area == null ? 'Área cadastrada.' : 'Área atualizada.');
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
    final canRestrict = session.role.managesAllAreas;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          SectionCard(
            title: 'Identificação',
            icon: Icons.badge_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormLabel('Código *'),
                TextFormField(
                  controller: _code,
                  maxLength: 20,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'Ex.: MNT'),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.length < 2) return 'Informe um código com 2 a 20 caracteres.';
                    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(t)) {
                      return 'Use apenas letras, números, "-" ou "_".';
                    }
                    return null;
                  },
                ),
                FormLabel('Nome *'),
                TextFormField(
                  controller: _name,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Ex.: Oficina de Manutenção'),
                  validator: (v) => Validators.minLength(v, 2, 'Nome'),
                ),
                FormLabel('Setor *'),
                DropdownButtonFormField<String>(
                  initialValue: areaTypes.containsKey(_type) ? _type : 'producao',
                  isExpanded: true,
                  items: [
                    for (final e in areaTypes.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: 14),
                FormLabel('Descrição'),
                TextFormField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 300,
                  decoration: const InputDecoration(hintText: 'Atividades e riscos da área'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Status e acesso',
            icon: Icons.verified_user_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormLabel('Status *'),
                DropdownButtonFormField<AreaStatus>(
                  initialValue: _status,
                  isExpanded: true,
                  items: [
                    for (final s in AreaStatus.values)
                      DropdownMenuItem(value: s, child: StatusIndicator(s.style, fontSize: 13.5)),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? _status),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Com sensores ativos, o status é recalculado a cada nova leitura '
                  '(exceto "Interditada", que só muda manualmente).',
                  style: AppText.caption,
                ),
                const SizedBox(height: 14),
                FormLabel('Observação do status'),
                TextFormField(
                  controller: _note,
                  maxLength: 200,
                  decoration: const InputDecoration(hintText: 'Ex.: Manutenção preventiva até sexta'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _restricted,
                  onChanged: canRestrict ? (v) => setState(() => _restricted = v) : null,
                  title: const Text('Área restrita', style: AppText.itemTitle),
                  subtitle: Text(
                    canRestrict
                        ? 'Somente funcionários vinculados à área poderão visualizá-la.'
                        : 'Somente administradores e supervisores alteram esta opção.',
                    style: AppText.caption,
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
              label: Text(widget.area == null ? 'Cadastrar área' : 'Salvar alterações'),
            ),
          ),
        ],
      ),
    );
  }

}
