import 'package:finance_ai/core/exceptions/app_exception.dart';

class CacheException extends AppException {
  const CacheException(super.message, {super.code, super.cause});
}
