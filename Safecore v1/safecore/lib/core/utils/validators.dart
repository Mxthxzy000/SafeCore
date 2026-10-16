/// Validações dos formulários (mensagens em português).
abstract final class Validators {
  static final _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Informe seu nome.';
    if (v.length < 3) return 'O nome deve ter ao menos 3 letras.';
    if (v.length > 120) return 'Nome muito longo.';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Informe seu e-mail.';
    if (!_email.hasMatch(v)) return 'E-mail inválido.';
    return null;
  }

  /// Regra para senhas novas (cadastro e alteração).
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Informe uma senha.';
    if (v.length < 8) return 'A senha deve ter ao menos 8 caracteres.';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Use letras e números na senha.';
    }
    return null;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Informe sua senha.';
    return null;
  }

  static String? phone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null; // opcional
    if (digits.length < 10 || digits.length > 13) return 'Telefone inválido.';
    return null;
  }

  static String? minLength(String? value, int min, String field) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$field é obrigatório.';
    if (v.length < min) return '$field deve ter ao menos $min caracteres.';
    return null;
  }

  static String? otp(String? value) {
    final v = value?.trim() ?? '';
    if (!RegExp(r'^\d{6,10}$').hasMatch(v)) return 'Informe o código recebido por e-mail.';
    return null;
  }
}
