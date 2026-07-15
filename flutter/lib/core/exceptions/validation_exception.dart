import 'package:finance_ai/core/exceptions/app_exception.dart';

class ValidationException extends AppException {
  const ValidationException(super.message, {super.code, super.cause});
}
