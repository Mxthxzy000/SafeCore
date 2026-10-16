import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/brand.dart';
import '../../../shared/widgets/safecore_app_bar.dart';

/// Estrutura das telas de Login/Cadastro do Figma: barra azul com a logo,
/// ilustração industrial ao fundo e cartão com cabeçalho azul.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.children,
    this.showBack = false,
    this.showWordmark = true,
  });

  final String title;
  final List<Widget> children;
  final bool showBack;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const BrandHeaderBar(),
          Expanded(
            child: Stack(
              children: [
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 280,
                  child: IndustrialIllustration(),
                ),
                SafeArea(
                  top: false,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: _AuthCard(
                          title: title,
                          showBack: showBack,
                          showWordmark: showWordmark,
                          children: children,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.title,
    required this.children,
    required this.showBack,
    required this.showWordmark,
  });

  final String title;
  final List<Widget> children;
  final bool showBack;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.primary,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (showBack)
                  Positioned(
                    left: 0,
                    child: IconButton(
                      tooltip: 'Voltar',
                      icon: const Icon(Icons.arrow_back, color: AppColors.white, size: 20),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showWordmark) ...[
                  const Center(child: SafeCoreWordmark()),
                  const SizedBox(height: 26),
                ],
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo com rótulo e ícone acima (ex.: "✉ Email").
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.obscure = false,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.onSubmitted,
    this.suffix,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscure;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(fontSize: 13, color: AppColors.slate)),
            ],
          ),
          const SizedBox(height: 5),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            obscureText: obscure,
            enabled: enabled,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            onFieldSubmitted: onSubmitted,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
          ),
        ],
      ),
    );
  }
}

/// Campo de senha com botão para mostrar/ocultar.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Senha',
    this.hint = 'Sua senha',
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: widget.label,
      icon: Icons.lock_outline,
      controller: widget.controller,
      hint: widget.hint,
      validator: widget.validator,
      obscure: _hidden,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      suffix: IconButton(
        tooltip: _hidden ? 'Mostrar senha' : 'Ocultar senha',
        icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
        onPressed: () => setState(() => _hidden = !_hidden),
      ),
    );
  }
}

/// Botão verde centralizado com indicador de carregamento.
class AuthButton extends StatelessWidget {
  const AuthButton({super.key, required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
              )
            : Text(label),
      ),
    );
  }
}

/// Texto com trecho clicável em verde (ex.: "clique aqui").
class InlineLink extends StatelessWidget {
  const InlineLink({
    super.key,
    required this.before,
    required this.link,
    this.after = '',
    required this.onTap,
  });

  final String before;
  final String link;
  final String after;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$before$link$after',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: before),
              TextSpan(
                text: link,
                style: const TextStyle(
                  color: AppColors.safe,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.safe,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(text: after),
            ]),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}
