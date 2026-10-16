import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Hierarquia tipográfica única do aplicativo.
abstract final class AppText {
  /// Título principal de uma tela ou de um cartão de destaque.
  static const title = TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.primary);

  /// Título de seção/cartão (ex.: "Resumo Geral").
  static const section = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.slate);

  /// Nome de item em listas (ex.: nome da área, do sensor).
  static const itemTitle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate);

  static const body = TextStyle(fontSize: 13.5, color: AppColors.slate, height: 1.35);
  static const bodySecondary = TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.3);

  /// Rótulos de linhas de informação (lado esquerdo).
  static const label = TextStyle(fontSize: 13, color: AppColors.textSecondary);

  /// Valores de linhas de informação (lado direito).
  static const value = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate);

  /// Textos auxiliares (datas, legendas, dicas).
  static const caption = TextStyle(fontSize: 12, color: AppColors.textSecondary);
  static const small = TextStyle(fontSize: 11, color: AppColors.textSecondary);
}
