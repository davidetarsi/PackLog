abstract class AuthDomainException implements Exception {
  final String message;
  final Object? originalError;
  final StackTrace? stackTrace;

  const AuthDomainException(
    this.message, {
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => '$runtimeType: $message'
      '${originalError != null ? ' (${originalError.toString()})' : ''}';
}

class SignInFailedException extends AuthDomainException {
  const SignInFailedException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

class SignUpFailedException extends AuthDomainException {
  const SignUpFailedException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

class SignOutFailedException extends AuthDomainException {
  const SignOutFailedException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}

class SessionExpiredException extends AuthDomainException {
  const SessionExpiredException(
    super.message, {
    super.originalError,
    super.stackTrace,
  });
}
