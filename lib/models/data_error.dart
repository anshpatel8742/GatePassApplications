enum DataErrorType {
  notFound,      // When document/record doesn't exist
  validation,    // When data fails validation checks
  invalidData,   // When data exists but is malformed
  unauthorized,  // When user lacks permissions
  network,       // For connectivity issues
  database,      // For Firestore/database errors
  unknown,       // Catch-all for unexpected errors
  // Add any other types you need
}

class DataError {
  final DataErrorType type;
  final String message;
  final DateTime timestamp;
  final StackTrace? stackTrace;

  DataError(this.type, this.message, [this.stackTrace]) 
    : timestamp = DateTime.now();

  // Factory constructors for common error types
  factory DataError.notFound(String message, [StackTrace? stackTrace]) =>
    DataError(DataErrorType.notFound, message, stackTrace);

  factory DataError.validation(String message, [StackTrace? stackTrace]) =>
    DataError(DataErrorType.validation, message, stackTrace);

  factory DataError.invalidData(String message, [StackTrace? stackTrace]) =>
    DataError(DataErrorType.invalidData, message, stackTrace);

  factory DataError.network(String message, [StackTrace? stackTrace]) =>
    DataError(DataErrorType.network, message, stackTrace);

  factory DataError.fromException(dynamic error, StackTrace stackTrace) {
    if (error is DataError) return error;
    return DataError(
      DataErrorType.unknown,
      error.toString(),
      stackTrace,
    );
  }

  @override
  String toString() => message;
}