import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../repositories/repositories.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets/feedback.dart';
import 'widgets/auth_layout.dart';

/// Recuperação de senha: envia o e-mail e permite validar o código recebido.
/// O link do e-mail também funciona (abre o app pelo deep link configurado).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _sent = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Repos.auth.sendPasswordReset(_email.text);
      if (!mounted) return;
      setState(() => _sent = true);
      showMessage(context, 'Se o e-mail estiver cadastrado, você receberá as instruções.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Repos.auth.verifyRecoveryCode(email: _email.text, code: _code.text);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.resetPassword);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Recuperar senha',
      showBack: true,
      showWordmark: false,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _sent
                    ? 'Abra o link enviado para o seu e-mail neste celular ou digite '
                        'abaixo o código recebido.'
                    : 'Informe o e-mail da sua conta. Enviaremos as instruções para '
                        'criar uma nova senha.',
                style: AppText.label,
              ),
              const SizedBox(height: 16),
              LabeledField(
                label: 'Email',
                icon: Icons.mail_outline,
                controller: _email,
                hint: 'seuemail@empresa.com',
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
                enabled: !_sent,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _sent ? null : _send(),
              ),
              if (_sent)
                LabeledField(
                  label: 'Código de verificação',
                  icon: Icons.pin_outlined,
                  controller: _code,
                  hint: '000000',
                  keyboardType: TextInputType.number,
                  validator: Validators.otp,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _verify(),
                ),
              const SizedBox(height: 6),
              AuthButton(
                label: _sent ? 'Validar código' : 'Enviar instruções',
                loading: _loading,
                onPressed: _sent ? _verify : _send,
              ),
              if (_sent)
                TextButton(
                  onPressed: _loading ? null : () => setState(() => _sent = false),
                  child: const Text('Reenviar ou trocar e-mail'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
