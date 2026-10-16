import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Rótulo acima de um campo de formulário (padrão de todos os formulários).
class FormLabel extends StatelessWidget {
  const FormLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate),
        ),
      );
}

/// Seletor de data e hora em formato de campo.
class DateTimeField extends StatelessWidget {
  const DateTimeField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.formatted,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String formatted;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: value.isAfter(now) ? now : value,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(value));
    if (time == null) return;
    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    onChanged(picked.isAfter(now) ? now : picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(suffixIcon: Icon(Icons.event_outlined)),
        child: Text(formatted, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}
