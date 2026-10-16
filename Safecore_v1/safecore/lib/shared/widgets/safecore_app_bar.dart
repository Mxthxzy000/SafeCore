import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'brand.dart';

/// Barra superior azul com a logo à esquerda e o título centralizado (Figma).
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
      backgroundColor: AppColors.primary,
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
          const SafeCoreLogoMark(size: 40),
        ],
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: actions ?? const [SizedBox(width: 64)],
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
      color: AppColors.primary,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 10, bottom: 10),
      alignment: Alignment.center,
      child: const SafeCoreLogoMark(size: 52),
    );
  }
}
