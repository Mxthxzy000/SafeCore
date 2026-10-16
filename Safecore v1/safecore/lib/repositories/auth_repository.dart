import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/env.dart';
import '../services/supabase_service.dart';

/// Autenticação com Supabase Auth (e-mail e senha).
/// A sessão é persistida e renovada automaticamente pelo supabase_flutter.
class AuthRepository {
  GoTrueClient get _auth => SupabaseService.client.auth;

  User? get currentUser => _auth.currentUser;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Retorna `true` se o Supabase exigir confirmação por e-mail.
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await _auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': name.trim()},
      emailRedirectTo: Env.authRedirectUrl,
    );
    return res.session == null;
  }

  Future<void> signOut() => _auth.signOut();

  /// Envia o e-mail de recuperação (link e/ou código, conforme o template).
  Future<void> sendPasswordReset(String email) =>
      _auth.resetPasswordForEmail(email.trim(), redirectTo: Env.authRedirectUrl);

  /// Valida o código de recuperação recebido por e-mail e abre a sessão.
  Future<void> verifyRecoveryCode({required String email, required String code}) async {
    await _auth.verifyOTP(email: email.trim(), token: code.trim(), type: OtpType.recovery);
  }

  /// Define nova senha para a sessão atual (após recuperação).
  Future<void> updatePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Alteração de senha logado: confirma a senha atual antes de trocar.
  Future<void> changePassword({required String current, required String newPassword}) async {
    final email = currentUser?.email;
    if (email == null) throw const AuthException('Sessão expirada. Entre novamente.');
    try {
      await _auth.signInWithPassword(email: email, password: current);
    } on AuthException {
      throw const AuthException('Senha atual incorreta.');
    }
    await updatePassword(newPassword);
  }

  /// Solicita troca de e-mail; o Supabase envia confirmação ao novo endereço.
  Future<void> requestEmailChange(String newEmail) async {
    await _auth.updateUser(
      UserAttributes(email: newEmail.trim()),
      emailRedirectTo: Env.authRedirectUrl,
    );
  }
}
