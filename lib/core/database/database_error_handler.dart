import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

// Database error types
enum DatabaseErrorType {
  connection,
  query,
  transaction,
  constraint,
  migration,
  backup,
  unknown,
}

// Database error severity
enum DatabaseErrorSeverity {
  low,
  medium,
  high,
  critical,
}

// Database error context
class DatabaseErrorContext {
  final String operation;
  final String? tableName;
  final Map<String, dynamic>? parameters;
  final String? sql;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  DatabaseErrorContext({
    required this.operation,
    this.tableName,
    this.parameters,
    this.sql,
    this.stackTrace,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// Database error info
class DatabaseErrorInfo {
  final DatabaseErrorType type;
  final DatabaseErrorSeverity severity;
  final String message;
  final String? details;
  final DatabaseErrorContext context;
  final dynamic originalError;

  DatabaseErrorInfo({
    required this.type,
    required this.severity,
    required this.message,
    this.details,
    required this.context,
    this.originalError,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'severity': severity.name,
      'message': message,
      'details': details,
      'context': {
        'operation': context.operation,
        'tableName': context.tableName,
        'parameters': context.parameters,
        'sql': context.sql,
        'timestamp': context.timestamp.toIso8601String(),
      },
      'originalError': originalError?.toString(),
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Database Error:');
    buffer.writeln('  Type: ${type.name}');
    buffer.writeln('  Severity: ${severity.name}');
    buffer.writeln('  Message: $message');
    if (details != null) buffer.writeln('  Details: $details');
    buffer.writeln('  Context:');
    buffer.writeln('    Operation: ${context.operation}');
    if (context.tableName != null) buffer.writeln('    Table: ${context.tableName}');
    if (context.sql != null) buffer.writeln('    SQL: ${context.sql}');
    if (originalError != null) buffer.writeln('  Original Error: $originalError');
    return buffer.toString();
  }
}

// Database error handler
class DatabaseErrorHandler {
  final Logger _logger;
  final List<DatabaseErrorInfo> _errorHistory = [];
  final int _maxHistorySize;
  final Map<DatabaseErrorType, int> _errorCounts = {};

  DatabaseErrorHandler({
    required Logger logger,
    int maxHistorySize = 1000,
  }) : _logger = logger,
       _maxHistorySize = maxHistorySize;

  // Error classification
  DatabaseErrorType classifyError(dynamic error) {
    if (error is SqliteException) {
      final message = error.message.toLowerCase();
      if (message.contains('no such table') || message.contains('database is locked')) {
        return DatabaseErrorType.connection;
      } else if (message.contains('constraint') || message.contains('unique')) {
        return DatabaseErrorType.constraint;
      } else if (message.contains('syntax') || message.contains('near')) {
        return DatabaseErrorType.query;
      }
    } else if (error is InvalidDataException) {
      return DatabaseErrorType.constraint;
    } else if (error is IOException) {
      return DatabaseErrorType.connection;
    }

    return DatabaseErrorType.unknown;
  }

  // Severity assessment
  DatabaseErrorSeverity assessSeverity(DatabaseErrorType type, dynamic error) {
    switch (type) {
      case DatabaseErrorType.connection:
        return DatabaseErrorSeverity.high;
      case DatabaseErrorType.migration:
        return DatabaseErrorSeverity.critical;
      case DatabaseErrorType.backup:
        return DatabaseErrorSeverity.medium;
      case DatabaseErrorType.constraint:
        return DatabaseErrorSeverity.medium;
      case DatabaseErrorType.query:
        return _isQueryErrorCritical(error)
            ? DatabaseErrorSeverity.high
            : DatabaseErrorSeverity.low;
      case DatabaseErrorType.transaction:
        return DatabaseErrorSeverity.high;
      case DatabaseErrorType.unknown:
        return DatabaseErrorSeverity.medium;
    }
  }

  bool _isQueryErrorCritical(dynamic error) {
    if (error is SqliteException) {
      final message = error.message.toLowerCase();
      return message.contains('corrupt') ||
             message.contains('disk I/O error') ||
             message.contains('database disk image is malformed');
    }
    return false;
  }

  // Handle and log database errors
  Future<T?> handleError<T>(
    String operation,
    dynamic error, {
    String? tableName,
    Map<String, dynamic>? parameters,
    String? sql,
    StackTrace? stackTrace,
    T? fallbackValue,
  }) async {
    final errorType = classifyError(error);
    final severity = assessSeverity(errorType, error);

    final context = DatabaseErrorContext(
      operation: operation,
      tableName: tableName,
      parameters: parameters,
      sql: sql,
      stackTrace: stackTrace,
    );

    final errorInfo = DatabaseErrorInfo(
      type: errorType,
      severity: severity,
      message: error.toString(),
      details: _extractErrorDetails(error),
      context: context,
      originalError: error,
    );

    // Record error
    await _recordError(errorInfo);

    // Log error based on severity
    _logError(errorInfo);

    // Attempt recovery for certain error types
    final recovered = await _attemptRecovery(errorInfo);
    if (recovered) {
      _logger.i('Error recovery successful for $operation');
      return fallbackValue;
    }

    // Handle based on severity
    return _handleBySeverity(errorInfo, fallbackValue);
  }

  String? _extractErrorDetails(dynamic error) {
    if (error is SqliteException) {
      return 'Extended Code: ${error.extendedCode}, Result Code: ${error.resultCode}';
    }
    return error.runtimeType.toString();
  }

  Future<void> _recordError(DatabaseErrorInfo errorInfo) async {
    // Add to history
    _errorHistory.add(errorInfo);

    // Maintain history size
    if (_errorHistory.length > _maxHistorySize) {
      _errorHistory.removeRange(0, _errorHistory.length - _maxHistorySize);
    }

    // Update error counts
    _errorCounts[errorInfo.type] = (_errorCounts[errorInfo.type] ?? 0) + 1;
  }

  void _logError(DatabaseErrorInfo errorInfo) {
    switch (errorInfo.severity) {
      case DatabaseErrorSeverity.critical:
        _logger.e('CRITICAL DATABASE ERROR', error: errorInfo.toString());
        break;
      case DatabaseErrorSeverity.high:
        _logger.e('HIGH SEVERITY DATABASE ERROR', error: errorInfo.toString());
        break;
      case DatabaseErrorSeverity.medium:
        _logger.w('MEDIUM SEVERITY DATABASE ERROR', error: errorInfo.toString());
        break;
      case DatabaseErrorSeverity.low:
        _logger.d('LOW SEVERITY DATABASE ERROR', error: errorInfo.toString());
        break;
    }
  }

  Future<bool> _attemptRecovery(DatabaseErrorInfo errorInfo) async {
    switch (errorInfo.type) {
      case DatabaseErrorType.connection:
        return await _recoverFromConnectionError(errorInfo);
      case DatabaseErrorType.transaction:
        return await _recoverFromTransactionError(errorInfo);
      case DatabaseErrorType.constraint:
        return await _recoverFromConstraintError(errorInfo);
      default:
        return false;
    }
  }

  Future<bool> _recoverFromConnectionError(DatabaseErrorInfo errorInfo) async {
    // For connection errors, we might want to retry the operation
    if (errorInfo.originalError is SqliteException) {
      final message = errorInfo.originalError!.message.toLowerCase();
      if (message.contains('database is locked')) {
        _logger.d('Database locked, waiting for unlock...');
        await Future.delayed(const Duration(milliseconds: 100));
        return true; // Indicate that retry might work
      }
    }
    return false;
  }

  Future<bool> _recoverFromTransactionError(DatabaseErrorInfo errorInfo) async {
    // For transaction errors, rollback is typically handled by Drift
    _logger.d('Transaction error occurred, rollback will be handled by ORM');
    return true;
  }

  Future<bool> _recoverFromConstraintError(DatabaseErrorInfo errorInfo) async {
    // For constraint errors, we might want to suggest data validation
    _logger.d('Constraint violation detected, check data integrity');
    return false;
  }

  T? _handleBySeverity<T>(DatabaseErrorInfo errorInfo, T? fallbackValue) {
    switch (errorInfo.severity) {
      case DatabaseErrorSeverity.critical:
        // For critical errors, we might want to throw
        throw DatabaseException(
          'Critical database error: ${errorInfo.message}',
          originalError: errorInfo.originalError,
        );
      case DatabaseErrorSeverity.high:
        // For high severity errors, log and return fallback
        return fallbackValue;
      case DatabaseErrorSeverity.medium:
        // For medium errors, log and return fallback
        return fallbackValue;
      case DatabaseErrorSeverity.low:
        // For low errors, just return fallback
        return fallbackValue;
    }
  }

  // Error statistics
  Map<DatabaseErrorType, int> getErrorCounts() => Map.unmodifiable(_errorCounts);

  List<DatabaseErrorInfo> getErrorHistory({DatabaseErrorType? type, DatabaseErrorSeverity? severity}) {
    var filtered = _errorHistory;

    if (type != null) {
      filtered = filtered.where((error) => error.type == type).toList();
    }

    if (severity != null) {
      filtered = filtered.where((error) => error.severity == severity).toList();
    }

    return List.unmodifiable(filtered);
  }

  List<DatabaseErrorInfo> getRecentErrors({Duration? timeRange}) {
    final cutoff = timeRange != null
        ? DateTime.now().subtract(timeRange)
        : DateTime.now().subtract(const Duration(hours: 1));

    return _errorHistory
        .where((error) => error.context.timestamp.isAfter(cutoff))
        .toList();
  }

  // Error rate monitoring
  double getErrorRate({Duration timeRange = const Duration(hours: 1)}) {
    final recentErrors = getRecentErrors(timeRange: timeRange);
    final timeInHours = timeRange.inHours.toDouble();
    return timeInHours > 0 ? recentErrors.length / timeInHours : 0.0;
  }

  bool hasErrorPattern(DatabaseErrorType type, {int threshold = 3, Duration? timeRange}) {
    final errors = getErrorHistory(type: type, severity: null);
    if (timeRange != null) {
      final cutoff = DateTime.now().subtract(timeRange);
      errors.removeWhere((error) => error.context.timestamp.isBefore(cutoff));
    }
    return errors.length >= threshold;
  }

  // Clear error history
  void clearErrorHistory() {
    _errorHistory.clear();
    _errorCounts.clear();
  }

  // Export error logs
  Map<String, dynamic> exportErrorLogs() {
    return {
      'exported_at': DateTime.now().toIso8601String(),
      'total_errors': _errorHistory.length,
      'error_counts': _errorCounts.map((key, value) => MapEntry(key.name, value)),
      'error_rate_per_hour': getErrorRate(),
      'errors': _errorHistory.map((error) => error.toJson()).toList(),
    };
  }

  // Database health monitoring
  DatabaseHealthReport getHealthReport() {
    final now = DateTime.now();
    final lastHour = now.subtract(const Duration(hours: 1));
    final last24Hours = now.subtract(const Duration(hours: 24));

    final errorsLastHour = _errorHistory.where((e) => e.context.timestamp.isAfter(lastHour));
    final errorsLast24Hours = _errorHistory.where((e) => e.context.timestamp.isAfter(last24Hours));

    final criticalErrors = errorsLast24Hours.where((e) => e.severity == DatabaseErrorSeverity.critical);
    final highSeverityErrors = errorsLast24Hours.where((e) => e.severity == DatabaseErrorSeverity.high);

    final healthScore = _calculateHealthScore(criticalErrors.length, highSeverityErrors.length, errorsLast24Hours.length);

    return DatabaseHealthReport(
      healthScore: healthScore,
      status: _getHealthStatus(healthScore),
      totalErrors: _errorHistory.length,
      errorsLastHour: errorsLastHour.length,
      errorsLast24Hours: errorsLast24Hours.length,
      criticalErrors: criticalErrors.length,
      highSeverityErrors: highSeverityErrors.length,
      errorRate: getErrorRate(),
      lastError: _errorHistory.isNotEmpty ? _errorHistory.last.context.timestamp : null,
      recommendations: _generateRecommendations(criticalErrors, highSeverityErrors, errorsLast24Hours),
    );
  }

  double _calculateHealthScore(int criticalErrors, int highSeverityErrors, int totalErrors) {
    if (criticalErrors > 0) return 0.0;
    if (highSeverityErrors > 5) return 25.0;
    if (highSeverityErrors > 2) return 50.0;
    if (totalErrors > 50) return 75.0;
    if (totalErrors > 20) return 85.0;
    return 100.0;
  }

  DatabaseHealthStatus _getHealthStatus(double score) {
    if (score >= 90) return DatabaseHealthStatus.excellent;
    if (score >= 75) return DatabaseHealthStatus.good;
    if (score >= 50) return DatabaseHealthStatus.warning;
    if (score >= 25) return DatabaseHealthStatus.poor;
    return DatabaseHealthStatus.critical;
  }

  List<String> _generateRecommendations(List<DatabaseErrorInfo> critical, List<DatabaseErrorInfo> high, List<DatabaseErrorInfo> all) {
    final recommendations = <String>[];

    if (critical.isNotEmpty) {
      recommendations.add('URGENT: Address critical database errors immediately');
    }

    if (high.isNotEmpty) {
      recommendations.add('Review and fix high severity errors');
    }

    if (_hasConnectionErrors(all)) {
      recommendations.add('Check database connection and file permissions');
    }

    if (_hasConstraintErrors(all)) {
      recommendations.add('Review data validation and integrity constraints');
    }

    if (_hasPerformanceIssues(all)) {
      recommendations.add('Consider database optimization and query tuning');
    }

    if (all.length > 100) {
      recommendations.add('High error volume detected - consider system review');
    }

    return recommendations;
  }

  bool _hasConnectionErrors(List<DatabaseErrorInfo> errors) {
    return errors.any((e) => e.type == DatabaseErrorType.connection);
  }

  bool _hasConstraintErrors(List<DatabaseErrorInfo> errors) {
    return errors.any((e) => e.type == DatabaseErrorType.constraint);
  }

  bool _hasPerformanceIssues(List<DatabaseErrorInfo> errors) {
    return errors.any((e) => e.context.operation.contains('slow') ||
                           e.context.operation.contains('timeout'));
  }
}

// Database health status
enum DatabaseHealthStatus {
  excellent,
  good,
  warning,
  poor,
  critical,
}

// Database health report
class DatabaseHealthReport {
  final double healthScore;
  final DatabaseHealthStatus status;
  final int totalErrors;
  final int errorsLastHour;
  final int errorsLast24Hours;
  final int criticalErrors;
  final int highSeverityErrors;
  final double errorRate;
  final DateTime? lastError;
  final List<String> recommendations;

  const DatabaseHealthReport({
    required this.healthScore,
    required this.status,
    required this.totalErrors,
    required this.errorsLastHour,
    required this.errorsLast24Hours,
    required this.criticalErrors,
    required this.highSeverityErrors,
    required this.errorRate,
    this.lastError,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() {
    return {
      'healthScore': healthScore,
      'status': status.name,
      'totalErrors': totalErrors,
      'errorsLastHour': errorsLastHour,
      'errorsLast24Hours': errorsLast24Hours,
      'criticalErrors': criticalErrors,
      'highSeverityErrors': highSeverityErrors,
      'errorRate': errorRate,
      'lastError': lastError?.toIso8601String(),
      'recommendations': recommendations,
    };
  }
}

// Database exception
class DatabaseException implements Exception {
  final String message;
  final dynamic originalError;
  final String? operation;

  DatabaseException(this.message, {this.originalError, this.operation});

  @override
  String toString() {
    final buffer = StringBuffer('DatabaseException: $message');
    if (operation != null) buffer.write(' (operation: $operation)');
    if (originalError != null) buffer.write(' (original error: $originalError)');
    return buffer.toString();
  }
}

// Safe database operation wrapper
class SafeDatabaseOperation {
  final DatabaseErrorHandler _errorHandler;

  SafeDatabaseOperation(this._errorHandler);

  Future<T> execute<T>(
    String operation,
    Future<T> Function() action, {
    String? tableName,
    Map<String, dynamic>? parameters,
    T? fallbackValue,
  }) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      final result = await _errorHandler.handleError<T>(
        operation,
        error,
        tableName: tableName,
        parameters: parameters,
        stackTrace: stackTrace,
        fallbackValue: fallbackValue,
      );

      if (result == null && fallbackValue == null) {
        rethrow; // Re-throw if no fallback provided and result is null
      }

      return result as T;
    }
  }

  Future<T> executeWithRetry<T>(
    String operation,
    Future<T> Function() action, {
    int maxRetries = 3,
    Duration delay = const Duration(milliseconds: 100),
    String? tableName,
    Map<String, dynamic>? parameters,
    T? fallbackValue,
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await action();
      } catch (error, stackTrace) {
        attempts++;

        if (attempts >= maxRetries) {
          // Final attempt with error handling
          return await execute(
            operation,
            action,
            tableName: tableName,
            parameters: parameters,
            fallbackValue: fallbackValue,
          );
        }

        // Check if error is retryable
        if (!_isRetryableError(error)) {
          return await execute(
            operation,
            action,
            tableName: tableName,
            parameters: parameters,
            fallbackValue: fallbackValue,
          );
        }

        // Wait before retry
        await Future.delayed(delay * attempts);
      }
    }

    throw DatabaseException('Operation failed after $maxRetries attempts', operation: operation);
  }

  bool _isRetryableError(dynamic error) {
    if (error is SqliteException) {
      final message = error.message.toLowerCase();
      return message.contains('database is locked') ||
             message.contains('busy') ||
             message.contains('timeout');
    }
    return false;
  }
}