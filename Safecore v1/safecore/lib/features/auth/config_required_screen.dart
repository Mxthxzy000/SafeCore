import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/error_messages.dart';
import '../../shared/widgets/safecore_app_bar.dart';

/// Exibida quando o `.env` não tem a URL/chave do Supabase.
class ConfigRequiredScreen extends StatelessWidget {
  const ConfigRequiredScreen({super.key, this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const BrandHeaderBar(),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.settings_suggest_outlined, size: 56, color: AppColors.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'Configuração do Supabase necessária',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Erro ao conectar: ${friendlyError(error!)}',
                        style: const TextStyle(color: AppColors.critical),
                      ),
                    ),
                  const Text(
                    '1. Copie o arquivo .env.example para .env na raiz do projeto.\n\n'
                    '2. Preencha SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY com os dados do '
                    'seu projeto (Supabase → Project Settings → API Keys).\n\n'
                    '3. Execute os scripts da pasta database/ no SQL Editor.\n\n'
                    '4. Pare o app e execute "flutter run" novamente.\n\n'
                    'Nunca utilize a chave service_role no aplicativo.',
                    style: TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
