import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'brand.dart';

/// Degradê azul-marinho usado nos cabeçalhos.
const brandHeaderGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [AppColors.navy, AppColors.navyLight],
);

/// Barra superior em degradê com a logo e o título em caixa alta.
class SafeCoreAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SafeCoreAppBar({super.key, required this.title, this.actions, this.bottom});

  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(64 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: AppColors.navy,
      flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: brandHeaderGradient)),
      leadingWidth: canPop ? 96 : 64,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canPop)
            IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back, color: AppColors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: 14),
          const SafeCoreLogoBadge(size: 40),
        ],
      ),
      titleSpacing: 12,
      title: Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: actions,
      bottom: bottom,
    );
  }
}

/// Barra azul apenas com a logo centralizada (Login e Cadastro).
class BrandHeaderBar extends StatelessWidget {
  const BrandHeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: brandHeaderGradient),
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 10, bottom: 10),
      alignment: Alignment.center,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SafeCoreLogoBadge(size: 48),
          SizedBox(width: 12),
          Text(
            'SAFECORE',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
