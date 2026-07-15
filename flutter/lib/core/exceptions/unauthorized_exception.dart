import 'package:finance_ai/core/exceptions/app_exception.dart';

class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message, {super.code, super.cause});
}
