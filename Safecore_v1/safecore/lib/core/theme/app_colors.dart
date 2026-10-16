import 'package:flutter/material.dart';

export 'app_text.dart';

/// Paleta oficial do SafeCore (guia visual do Figma).
abstract final class AppColors {
  static const primary = Color(0xFF1B3F6B); // Azul-marinho principal
  static const navy = Color(0xFF0F2541); // Topo do degradê do cabeçalho
  static const navyLight = Color(0xFF26517F); // Base do degradê do cabeçalho
  static const heading = Color(0xFF16263B); // Títulos de cartões
  static const accentBlue = Color(0xFF2F78C4); // Azul de destaque (ex.: local do alerta)
  static const lightBlue = Color(0xFF86BBD8); // Azul claro
  static const slate = Color(0xFF2F4858); // Azul acinzentado
  static const green = Color(0xFF79CC4B); // Verde
  static const white = Color(0xFFFFFFFF);

  // Apoio (usados com moderação)
  static const background = Color(0xFFEEF1F5);
  static const surfaceMuted = Color(0xFFEAEEF2);
  static const border = Color(0xFFD5DCE4);
  static const textSecondary = Color(0xFF5E7280);

  // Estados
  static const safe = Color(0xFF5BAE2E); // verde escurecido p/ texto legível
  static const safeBg = Color(0xFFE8F6DF);
  static const warning = Color(0xFFE59A12);
  static const warningBg = Color(0xFFFFF3DC);
  static const critical = Color(0xFFD32F2F);
  static const criticalBg = Color(0xFFFDE7E7);
  static const blocked = Color(0xFF6A3FA0);
  static const blockedBg = Color(0xFFF0E9F8);
  static const offline = Color(0xFF7D8B95);
  static const offlineBg = Color(0xFFECEFF1);
}
