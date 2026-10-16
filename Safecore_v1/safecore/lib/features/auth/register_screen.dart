import 'package:flutter/material.dart';

import '../../core/utils/validators.dart';
import '../../repositories/repositories.dart';
import '../../shared/widgets/feedback.dart';
import 'widgets/auth_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final needsConfirmation = await Repos.auth.signUp(
        name: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      if (needsConfirmation) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirme seu e-mail'),
            content: Text(
              'Enviamos um link de confirmação para ${_email.text.trim()}. '
              'Após confirmar, volte e faça login.',
            ),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendi')),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
      } else {
        // Sessão criada: o AuthGate abre o painel automaticamente.
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Cadastro',
      showBack: true,
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledField(
                  label: 'Nome',
                  icon: Icons.person_outline,
                  controller: _name,
                  hint: 'Seu nome completo',
                  keyboardType: TextInputType.name,
                  autofillHints: const [AutofillHints.name],
                  validator: Validators.name,
                ),
                LabeledField(
                  label: 'Email',
                  icon: Icons.mail_outline,
                  controller: _email,
                  hint: 'seuemail@empresa.com',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                ),
                PasswordField(
                  controller: _password,
                  hint: 'Mínimo 8 caracteres, letras e números',
                  validator: Validators.password,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                PasswordField(
                  controller: _confirm,
                  label: 'Confirmar senha',
                  hint: 'Repita a senha',
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) => v != _password.text ? 'As senhas não coincidem.' : null,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 6),
                AuthButton(label: 'Cadastrar-se', loading: _loading, onPressed: _submit),
                const SizedBox(height: 18),
                InlineLink(
                  before: '',
                  link: 'Já possui uma conta?',
                  after: ' Entrar',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
