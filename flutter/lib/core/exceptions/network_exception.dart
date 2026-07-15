import 'package:finance_ai/core/exceptions/app_exception.dart';

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.cause});
}
