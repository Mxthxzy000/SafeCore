import 'package:flutter/material.dart';

import '../../core/utils/validators.dart';
import '../../repositories/repositories.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets/feedback.dart';
import 'widgets/auth_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await Repos.auth.signIn(email: _email.text, password: _password.text);
      // O AuthGate troca para o painel ao receber o evento de login.
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Login',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  validator: Validators.loginPassword,
                  onSubmitted: (_) => _submit(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
                    child: const Text('Esqueci minha senha', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(height: 6),
                AuthButton(label: 'Avançar', loading: _loading, onPressed: _submit),
                const SizedBox(height: 18),
                InlineLink(
                  before: 'Caso ainda não tenha uma conta,\nclique ',
                  link: 'aqui',
                  after: ' para criar uma.',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.register),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
