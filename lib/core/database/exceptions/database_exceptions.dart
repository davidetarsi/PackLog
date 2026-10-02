import '../../errors/app_exception.dart';

sealed class AppDatabaseException extends AppException {
  final String operation;
  final Object? cause;
  const AppDatabaseException(this.operation, {this.cause});
}

final class EntitySaveException extends AppDatabaseException {
  const EntitySaveException(super.operation, {super.cause});

  @override
  String toString() =>
      'EntitySaveException[$operation]${cause != null ? ': $cause' : ''}';
}

final class EntityNotFoundException extends AppDatabaseException {
  const EntityNotFoundException(super.operation, {super.cause});

  @override
  String toString() =>
      'EntityNotFoundException[$operation]${cause != null ? ': $cause' : ''}';
}
