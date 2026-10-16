import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';

/// Inicialização e acesso ao cliente do Supabase.
abstract final class SupabaseService {
  static bool _ready = false;

  static bool get isReady => _ready;

  static SupabaseClient get client => Supabase.instance.client;

  /// Carrega o `.env` e conecta ao Supabase. Retorna `false` se a
  /// configuração estiver ausente (o app mostra a tela de configuração).
  static Future<bool> init() async {
    await dotenv.load(fileName: '.env', isOptional: true);
    if (!Env.isConfigured) return false;

    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseKey,
      authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
    );
    _ready = true;
    return true;
  }
}
