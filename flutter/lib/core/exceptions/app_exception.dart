class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});
  final String message;
  final String? code;
  final Object? cause;
}
