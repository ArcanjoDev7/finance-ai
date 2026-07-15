sealed class Result<T> {
  const Result();

  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) => switch (this) {
    Success<T>(:final value) => success(value),
    FailureResult<T>(failure: final resultFailure) => failure(resultFailure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);
  final Failure failure;
}

class Failure {
  const Failure({required this.code, required this.message, this.cause});
  final String code;
  final String message;
  final Object? cause;
}
