import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Operação bloqueada pelas permissões do banco (RLS).
class PermissionDeniedException implements Exception {
  const PermissionDeniedException(this.action);

  final String action;

  @override
  String toString() => 'Você não tem permissão para $action.';
}

/// Converte exceções técnicas em mensagens claras para o usuário.
String friendlyError(Object error) {
  if (error is PermissionDeniedException) return error.toString();
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login credentials')) return 'E-mail ou senha incorretos.';
    if (msg.contains('email not confirmed')) {
      return 'Confirme seu e-mail antes de entrar (verifique sua caixa de entrada).';
    }
    if (msg.contains('already registered') || msg.contains('already been registered')) {
      return 'Este e-mail já está cadastrado.';
    }
    if (msg.contains('same password') || msg.contains('different from the old')) {
      return 'A nova senha deve ser diferente da atual.';
    }
    if (msg.contains('password should be') || msg.contains('weak')) {
      return 'Senha fraca. Use ao menos 8 caracteres com letras e números.';
    }
    if (msg.contains('rate limit') || error.statusCode == '429') {
      return 'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
    }
    if (msg.contains('token') && (msg.contains('expired') || msg.contains('invalid'))) {
      return 'Código inválido ou expirado. Solicite um novo.';
    }
    if (error is AuthRetryableFetchException) {
      return 'Sem conexão com o servidor. Verifique sua internet.';
    }
    return error.message;
  }
  if (error is PostgrestException) {
    if (error.code == 'P0001') return error.message; // mensagens das funções SQL
    if (error.code == '23505') {
      return 'Já existe um registro com esse código. Use outro código.';
    }
    if (error.code == '42501' || error.message.contains('permission denied') ||
        error.message.contains('row-level security')) {
      return 'Você não tem permissão para esta ação.';
    }
    if (error.code == 'PGRST202' || error.code == 'PGRST205' ||
        error.code == '42P01' || error.code == '42883') {
      return 'Banco de dados não configurado. Execute os scripts da pasta database/.';
    }
    return 'Erro ao acessar o banco de dados: ${error.message}';
  }
  if (error is TimeoutException) {
    return 'O servidor demorou para responder. Tente novamente.';
  }
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('ClientException')) {
    return 'Sem conexão com o servidor. Verifique sua internet.';
  }
  return 'Ocorreu um erro inesperado. Tente novamente.';
}
