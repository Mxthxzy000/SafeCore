import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Lê a configuração do Supabase do arquivo `.env` (ou de --dart-define).
///
/// Use somente a URL do projeto e a chave PÚBLICA (publishable/anon).
/// Nunca coloque a chave `service_role` no aplicativo.
abstract final class Env {
  static String get supabaseUrl => _read('SUPABASE_URL');

  static String get supabaseKey {
    final key = _read('SUPABASE_PUBLISHABLE_KEY');
    return key.isNotEmpty ? key : _read('SUPABASE_ANON_KEY');
  }

  /// Endereço para onde o link de recuperação de senha redireciona.
  static String get authRedirectUrl {
    final value = _read('AUTH_REDIRECT_URL');
    return value.isNotEmpty ? value : 'br.senai.safecore://login-callback';
  }

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') &&
      !supabaseUrl.contains('SEU-PROJETO') &&
      supabaseKey.length > 20 &&
      !supabaseKey.contains('SUA_CHAVE');

  static String _read(String name) {
    const defines = {
      'SUPABASE_URL': String.fromEnvironment('SUPABASE_URL'),
      'SUPABASE_PUBLISHABLE_KEY': String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
      'SUPABASE_ANON_KEY': String.fromEnvironment('SUPABASE_ANON_KEY'),
      'AUTH_REDIRECT_URL': String.fromEnvironment('AUTH_REDIRECT_URL'),
    };
    final fromDefine = defines[name] ?? '';
    if (fromDefine.isNotEmpty) return fromDefine;
    if (!dotenv.isInitialized) return '';
    return (dotenv.maybeGet(name) ?? '').trim();
  }
}
