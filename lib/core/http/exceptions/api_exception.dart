/// Types of API exceptions
enum ApiExceptionType {
  network,
  timeout,
  server,
  validation,
  authentication,
  authorization,
  notFound,
  conflict,
  rateLimit,
  noConnection,
  notInitialized,
  parsing,
  storage,
  unknown,
}

/// Custom API exception with detailed error information
class ApiException implements Exception {
  final String message;
  final ApiExceptionType type;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? details;
  final dynamic originalError;
  final DateTime timestamp;

  ApiException(
    this.message, {
    this.type = ApiExceptionType.unknown,
    this.statusCode,
    this.code,
    this.details,
    this.originalError,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create network-related exception
  factory ApiException.network(
    String message, {
    int? statusCode,
    String? code,
    dynamic originalError,
  }) {
    return ApiException(
      message,
      type: ApiExceptionType.network,
      statusCode: statusCode,
      code: code,
      originalError: originalError,
    );
  }

  /// Create timeout exception
  factory ApiException.timeout({
    String? message,
    dynamic originalError,
  }) {
    return ApiException(
      message ?? 'Request timed out',
      type: ApiExceptionType.timeout,
      originalError: originalError,
    );
  }

  /// Create server error exception
  factory ApiException.server(
    String message, {
    required int statusCode,
    String? code,
    Map<String, dynamic>? details,
  }) {
    return ApiException(
      message,
      type: ApiExceptionType.server,
      statusCode: statusCode,
      code: code,
      details: details,
    );
  }

  /// Create validation error exception
  factory ApiException.validation(
    String message, {
    Map<String, dynamic>? errors,
    String? code,
  }) {
    return ApiException(
      message,
      type: ApiExceptionType.validation,
      code: code,
      details: errors != null ? {'validation_errors': errors} : null,
    );
  }

  /// Create authentication exception
  factory ApiException.authentication(
    String message, {
    String? code,
  }) {
    return ApiException(
      message,
      type: ApiExceptionType.authentication,
      code: code,
    );
  }

  /// Create authorization exception
  factory ApiException.authorization(
    String message, {
    String? code,
  }) {
    return ApiException(
      message,
      type: ApiExceptionType.authorization,
      code: code,
    );
  }

  /// Create not found exception
  factory ApiException.notFound(
    String message, {
    String? resource,
    String? code,
  }) {
    return ApiException(
      message,
      type: ApiExceptionType.notFound,
      code: code,
      details: resource != null ? {'resource': resource} : null,
    );
  }

  /// Create conflict exception
  factory ApiException.conflict(
    String message, {
    String? code,
    Map<String, dynamic>? details,
  }) {
    return ApiException(
      message,
      type: ApiExceptionType.conflict,
      code: code,
      details: details,
    );
  }

  /// Create rate limit exception
  factory ApiException.rateLimit({
    String? message,
    int? retryAfter,
    String? code,
  }) {
    return ApiException(
      message ?? 'Rate limit exceeded',
      type: ApiExceptionType.rateLimit,
      code: code,
      details: retryAfter != null ? {'retry_after': retryAfter} : null,
    );
  }

  /// Create no connection exception
  factory ApiException.noConnection({
    String? message,
  }) {
    return ApiException(
      message ?? 'No internet connection available',
      type: ApiExceptionType.noConnection,
    );
  }

  /// Create not initialized exception
  factory ApiException.notInitialized({
    String? message,
  }) {
    return ApiException(
      message ?? 'Service not initialized',
      type: ApiExceptionType.notInitialized,
    );
  }

  /// Create parsing exception
  factory ApiException.parsing(
    String message, {
    dynamic originalError,
    String? code,
  }) {
    return ApiException(
      message,
      type: ApiExceptionType.parsing,
      originalError: originalError,
      code: code,
    );
  }

  /// Create storage exception
  factory ApiException.storage(
    String message, {
    dynamic originalError,
    String? operation,
  }) {
    return ApiException(
      message,
      type: ApiExceptionType.storage,
      originalError: originalError,
      details: operation != null ? {'operation': operation} : null,
    );
  }

  /// Create exception from Dio error
  factory ApiException.fromDioError(DioException dioError) {
    String message = 'An unknown error occurred';
    ApiExceptionType type = ApiExceptionType.unknown;
    int? statusCode;
    String? code;
    Map<String, dynamic>? details;

    switch (dioError.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Request timed out';
        type = ApiExceptionType.timeout;
        break;

      case DioExceptionType.badResponse:
        statusCode = dioError.response?.statusCode;
        final responseData = dioError.response?.data;

        if (responseData is Map<String, dynamic>) {
          message = responseData['message'] ?? responseData['error'] ?? 'Server error';
          code = responseData['code'];
          details = responseData['errors'] ?? responseData['details'];
        } else {
          message = 'Server error: ${statusCode ?? 'Unknown'}';
        }

        if (statusCode != null) {
          if (statusCode >= 400 && statusCode < 500) {
            if (statusCode == 401) {
              type = ApiExceptionType.authentication;
              message = message.isEmpty ? 'Authentication failed' : message;
            } else if (statusCode == 403) {
              type = ApiExceptionType.authorization;
              message = message.isEmpty ? 'Access denied' : message;
            } else if (statusCode == 404) {
              type = ApiExceptionType.notFound;
              message = message.isEmpty ? 'Resource not found' : message;
            } else if (statusCode == 409) {
              type = ApiExceptionType.conflict;
              message = message.isEmpty ? 'Resource conflict' : message;
            } else if (statusCode == 422) {
              type = ApiExceptionType.validation;
              message = message.isEmpty ? 'Validation failed' : message;
            } else if (statusCode == 429) {
              type = ApiExceptionType.rateLimit;
              message = message.isEmpty ? 'Rate limit exceeded' : message;
            } else {
              type = ApiExceptionType.validation;
              message = message.isEmpty ? 'Bad request' : message;
            }
          } else if (statusCode >= 500) {
            type = ApiExceptionType.server;
            message = message.isEmpty ? 'Internal server error' : message;
          }
        }
        break;

      case DioExceptionType.cancel:
        message = 'Request was cancelled';
        type = ApiExceptionType.network;
        break;

      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        if (dioError.error is SocketException) {
          message = 'No internet connection';
          type = ApiExceptionType.noConnection;
        } else {
          message = 'Network error: ${dioError.message}';
          type = ApiExceptionType.network;
        }
        break;

      default:
        message = dioError.message ?? 'An unknown error occurred';
        type = ApiExceptionType.network;
        break;
    }

    return ApiException(
      message,
      type: type,
      statusCode: statusCode,
      code: code,
      details: details,
      originalError: dioError,
    );
  }

  /// Get user-friendly error message
  String get userMessage {
    switch (type) {
      case ApiExceptionType.network:
      case ApiExceptionType.noConnection:
        return 'Please check your internet connection and try again.';
      case ApiExceptionType.timeout:
        return 'The request took too long to complete. Please try again.';
      case ApiExceptionType.server:
        return 'Server is experiencing issues. Please try again later.';
      case ApiExceptionType.authentication:
        return 'Please log in to continue.';
      case ApiExceptionType.authorization:
        return 'You don\'t have permission to perform this action.';
      case ApiExceptionType.notFound:
        return 'The requested resource was not found.';
      case ApiExceptionType.validation:
        return 'Please check your input and try again.';
      case ApiExceptionType.rateLimit:
        return 'Too many requests. Please wait a moment and try again.';
      case ApiExceptionType.notInitialized:
        return 'Service is not ready. Please restart the app.';
      case ApiExceptionType.storage:
        return 'Storage error occurred. Please check your device storage.';
      case ApiExceptionType.parsing:
        return 'Data format error. Please try again.';
      case ApiExceptionType.conflict:
        return 'Data conflict detected. Please refresh and try again.';
      case ApiExceptionType.unknown:
      default:
        return message;
    }
  }

  /// Check if error is retryable
  bool get isRetryable {
    switch (type) {
      case ApiExceptionType.network:
      case ApiExceptionType.timeout:
      case ApiExceptionType.server:
        return true;
      case ApiExceptionType.rateLimit:
        return details?['retry_after'] != null;
      case ApiExceptionType.noConnection:
      case ApiExceptionType.authentication:
      case ApiExceptionType.authorization:
      case ApiExceptionType.notFound:
      case ApiExceptionType.validation:
      case ApiExceptionType.conflict:
      case ApiExceptionType.notInitialized:
      case ApiExceptionType.storage:
      case ApiExceptionType.parsing:
      case ApiExceptionType.unknown:
        return false;
    }
  }

  /// Get suggested retry delay
  Duration get suggestedRetryDelay {
    switch (type) {
      case ApiExceptionType.timeout:
        return const Duration(seconds: 2);
      case ApiExceptionType.rateLimit:
        final retryAfter = details?['retry_after'] as int?;
        return Duration(seconds: retryAfter ?? 60);
      case ApiExceptionType.server:
        return const Duration(seconds: 5);
      case ApiExceptionType.network:
        return const Duration(seconds: 1);
      default:
        return Duration.zero;
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'type': type.toString(),
      'statusCode': statusCode,
      'code': code,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
      'userMessage': userMessage,
      'isRetryable': isRetryable,
      'suggestedRetryDelay': suggestedRetryDelay.inSeconds,
    };
  }

  @override
  String toString() {
    return 'ApiException: $message (Type: $type, Status: $statusCode)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApiException &&
        other.message == message &&
        other.type == type &&
        other.statusCode == statusCode &&
        other.code == code;
  }

  @override
  int get hashCode {
    return message.hashCode ^ type.hashCode ^ statusCode.hashCode ^ code.hashCode;
  }
}

/// Exception thrown when offline queue operations fail
class OfflineQueueException extends ApiException {
  OfflineQueueException(String message, {dynamic originalError})
      : super(
          message,
          type: ApiExceptionType.storage,
          originalError: originalError,
        );
}

/// Exception thrown when cache operations fail
class CacheException extends ApiException {
  CacheException(String message, {dynamic originalError})
      : super(
          message,
          type: ApiExceptionType.storage,
          originalError: originalError,
        );
}