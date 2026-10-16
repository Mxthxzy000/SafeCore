import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../repositories/repositories.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/safecore_app_bar.dart';
import '../auth/widgets/auth_layout.dart';

/// Alteração de senha: confirma a senha atual antes de definir a nova.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await Repos.auth.changePassword(current: _current.text, newPassword: _new.text);
      if (!mounted) return;
      showMessage(context, 'Senha alterada com sucesso.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SafeCoreAppBar(title: 'Alterar Senha'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            AccentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PasswordField(
                    controller: _current,
                    label: 'Senha atual',
                    hint: 'Senha atual',
                    validator: Validators.loginPassword,
                    textInputAction: TextInputAction.next,
                  ),
                  PasswordField(
                    controller: _new,
                    label: 'Nova senha',
                    hint: 'Mínimo 8 caracteres, letras e números',
                    validator: (v) {
                      final base = Validators.password(v);
                      if (base != null) return base;
                      return v == _current.text ? 'A nova senha deve ser diferente da atual.' : null;
                    },
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                  PasswordField(
                    controller: _confirm,
                    label: 'Confirmar nova senha',
                    hint: 'Repita a nova senha',
                    validator: (v) => v != _new.text ? 'As senhas não coincidem.' : null,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) => _save(),
                  ),
                  const Text(
                    'Por segurança, confirmamos sua senha atual antes da alteração.',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AuthButton(label: 'Alterar senha', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
