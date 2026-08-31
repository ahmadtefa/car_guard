// lib/core/errors/failures.dart

abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

class ValidationFailure extends Failure {
  final Map<String, String>? fieldErrors;
  const ValidationFailure(super.message, {this.fieldErrors});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

class ImportFailure extends Failure {
  final ImportFailureReason reason;
  const ImportFailure(super.message, {required this.reason});
}

class ExportFailure extends Failure {
  const ExportFailure(super.message);
}

class ConflictFailure extends Failure {
  const ConflictFailure(super.message);
}

enum ImportFailureReason {
  invalidFormat,
  unsupportedVersion,
  missingRequiredFields,
  invalidDataTypes,
  corruptedFile,
  schemaValidationFailed,
}
