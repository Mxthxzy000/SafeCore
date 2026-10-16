import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../repositories/repositories.dart';
import '../../shared/widgets/feedback.dart';
import 'widgets/auth_layout.dart';

/// Definição da nova senha após abrir o link ou validar o código de recuperação.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Repos.auth.updatePassword(_password.text);
      if (!mounted) return;
      showMessage(context, 'Senha alterada com sucesso.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Nova senha',
      showBack: true,
      showWordmark: false,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Crie uma nova senha com ao menos 8 caracteres, usando letras e números.',
                style: AppText.label,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                label: 'Nova senha',
                hint: 'Nova senha',
                validator: Validators.password,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
              ),
              PasswordField(
                controller: _confirm,
                label: 'Confirmar nova senha',
                hint: 'Repita a nova senha',
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) => v != _password.text ? 'As senhas não coincidem.' : null,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 6),
              AuthButton(label: 'Salvar senha', loading: _loading, onPressed: _submit),
            ],
          ),
        ),
      ],
    );
  }
}
