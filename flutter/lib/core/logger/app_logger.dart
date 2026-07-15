import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppLogger {
  void debug(String message) => _log('DEBUG', message);
  void info(String message) => _log('INFO', message);
  void warning(String message) => _log('WARNING', message);

  void error(String message, Object error, StackTrace? stackTrace) {
    _log('ERROR', '$message: $error');
    if (stackTrace != null) _log('ERROR', stackTrace.toString());
  }

  void _log(String level, String message) {
    if (kDebugMode) debugPrint('[$level] $message');
  }
}

class RiverpodLoggerObserver extends ProviderObserver {
  RiverpodLoggerObserver(this._logger);
  final AppLogger _logger;

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    _logger.debug('Provider updated: ${context.provider.name ?? context.provider.runtimeType}');
  }
}
