import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/error_messages.dart';

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.critical : AppColors.slate,
      ),
    );
}

void showError(BuildContext context, Object error) =>
    showMessage(context, friendlyError(error), error: true);

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.critical)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Diálogo com campo de texto. Retorna o texto ou `null` se cancelado.
Future<String?> textInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  String confirmLabel = 'Salvar',
  String initialValue = '',
  bool required = true,
  int maxLines = 3,
  TextInputType? keyboardType,
  String? Function(String?)? validator,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _TextInputDialog(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      initialValue: initialValue,
      required: required,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.initialValue,
    required this.required,
    required this.maxLines,
    this.keyboardType,
    this.validator,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String initialValue;
  final bool required;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLines: widget.maxLines,
          minLines: 1,
          maxLength: 500,
          keyboardType: widget.keyboardType,
          decoration: InputDecoration(labelText: widget.label),
          validator: widget.validator ??
              (v) => widget.required && (v == null || v.trim().isEmpty)
                  ? 'Preencha este campo.'
                  : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
