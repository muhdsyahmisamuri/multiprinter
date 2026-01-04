import 'package:dartz/dartz.dart';
import '../errors/failures.dart';

/// Type alias for Either with Failure and success value
typedef Result<T> = Either<Failure, T>;

/// Type alias for async results
typedef FutureResult<T> = Future<Result<T>>;

/// Extension methods for Result handling
extension ResultExtension<T> on Result<T> {
  /// Get the value or throw if failure
  T getOrThrow() {
    return fold(
      (failure) => throw Exception(failure.message),
      (value) => value,
    );
  }

  /// Get the value or return default
  T getOrElse(T defaultValue) {
    return fold((_) => defaultValue, (value) => value);
  }

  /// Check if result is success
  bool get isSuccess => isRight();

  /// Check if result is failure
  bool get isFailure => isLeft();

  /// Get failure message if failed
  String? get failureMessage {
    return fold((failure) => failure.message, (_) => null);
  }
}

