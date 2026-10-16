import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/enums.dart';

/// Cartão branco com sombra discreta e faixa colorida à esquerda (Figma).
class AccentCard extends StatelessWidget {
  const AccentCard({
    super.key,
    required this.child,
    this.accent = AppColors.primary,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.highlight = false,
  });

  final Widget child;
  final Color accent;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Cartões mais importantes recebem uma sombra mais marcada.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: highlight ? AppTheme.highlightShadow : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(border: Border(left: BorderSide(color: accent, width: 3))),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Cartão de seção com título (ex.: "Status Geral da Planta").
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.icon,
    this.highlight = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return AccentCard(
      highlight: highlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(title.toUpperCase(), style: AppText.section),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Etiqueta de status preenchida (ex.: "Crítico" no cartão de alerta).
class StatusTag extends StatelessWidget {
  const StatusTag(this.style, {super.key, this.solid = true});

  final StatusStyle style;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: solid ? style.color : style.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          color: solid ? AppColors.white : style.color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Indicador com ícone e texto colorido (ex.: "🛡 Segura").
class StatusIndicator extends StatelessWidget {
  const StatusIndicator(this.style, {super.key, this.fontSize = 12.5, this.label});

  final StatusStyle style;
  final double fontSize;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(style.icon, size: fontSize + 3, color: style.color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label ?? style.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: style.color, fontSize: fontSize, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Valor com legenda embaixo (ex.: "24,3 °C / Temperatura").
class ValueCaption extends StatelessWidget {
  const ValueCaption({super.key, required this.value, required this.caption, this.color});

  final String value;
  final String caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.slate,
            ),
          ),
        ),
        Text(caption, style: AppText.small),
      ],
    );
  }
}

/// Aviso discreto de que os dados exibidos são simulados.
class SimulatedBadge extends StatelessWidget {
  const SimulatedBadge({super.key, this.text = 'Dados simulados'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Medições geradas para demonstração. Não são leituras reais da fábrica.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.lightBlue.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.science_outlined, size: 13, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(fontSize: 11, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

/// Linha "rótulo .... valor" usada nos detalhes (alerta, sensor, ocorrência, relatórios).
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppText.label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: valueColor == null ? AppText.value : AppText.value.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Título de seção fora de cartões (ex.: "Sensores (4)").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(text.toUpperCase(), style: AppText.section)),
          ?trailing,
        ],
      ),
    );
  }
}
