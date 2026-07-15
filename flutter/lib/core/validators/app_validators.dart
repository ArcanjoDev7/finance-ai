abstract final class AppValidators {
  static String? requiredText(String? value, {String label = 'Campo'}) {
    if (value == null || value.trim().isEmpty) return '$label é obrigatório.';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'E-mail é obrigatório.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) return 'E-mail inválido.';
    return null;
  }
}
