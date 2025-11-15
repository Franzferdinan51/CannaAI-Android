import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';
import '../constants/app_constants.dart';
import '../utils/storage_helper.dart';
import 'exceptions/api_exception.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'interceptors/cache_interceptor.dart';
import 'interceptors/offline_interceptor.dart';

/// Comprehensive HTTP client with interceptors, retry logic, and offline capabilities
class HttpClient {
  static final HttpClient _instance = HttpClient._internal();
  factory HttpClient() => _instance;
  HttpClient._internal();

  late Dio _dio;
  late Dio _offlineDio;
  final Logger _logger = Logger();
  final StorageHelper _storage = StorageHelper();
  final Connectivity _connectivity = Connectivity();

  bool _initialized = false;
  String _baseUrl = '';
  String? _authToken;
  Map<String, dynamic> _defaultHeaders = {};

  // Network connectivity state
  bool _isOnline = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  /// Initialize HTTP client with configuration
  Future<void> initialize({
    required String baseUrl,
    String? authToken,
    Duration connectTimeout = const Duration(seconds: 30),
    Duration receiveTimeout = const Duration(seconds: 30),
    Duration sendTimeout = const Duration(seconds: 30),
    Map<String, dynamic>? defaultHeaders,
    bool enableLogging = kDebugMode,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    if (_initialized) return;

    try {
      _baseUrl = baseUrl;
      _authToken = authToken;
      _defaultHeaders = defaultHeaders ?? {};

      // Initialize connectivity monitoring
      await _initializeConnectivity();

      // Create primary Dio instance for online requests
      _dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
        headers: _buildHeaders(authToken),
        validateStatus: (status) => status != null && status < 500,
        responseType: ResponseType.json,
        contentType: 'application/json',
      ));

      // Create secondary Dio instance for offline queue
      _offlineDio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(milliseconds: 100),
        receiveTimeout: const Duration(milliseconds: 100),
        sendTimeout: const Duration(milliseconds: 100),
        headers: _buildHeaders(authToken),
        validateStatus: (status) => true,
      ));

      // Add interceptors in order
      await _setupInterceptors(enableLogging, maxRetries, retryDelay);

      _initialized = true;
      _logger.i('HTTP client initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize HTTP client: $e');
      rethrow;
    }
  }

  /// Build default headers with optional auth token
  Map<String, dynamic> _buildHeaders([String? authToken]) {
    final headers = Map<String, dynamic>.from(_defaultHeaders);

    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    headers['User-Agent'] = 'CannaAI-Flutter/${AppConstants.appVersion}';
    headers['Accept'] = 'application/json';
    headers['X-Client-Version'] = AppConstants.appVersion;
    headers['X-Platform'] = Platform.operatingSystem;

    return headers;
  }

  /// Initialize connectivity monitoring
  Future<void> _initializeConnectivity() async {
    try {
      final initialResult = await _connectivity.checkConnectivity();
      _isOnline = _isConnectionResultOnline(initialResult);

      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
        final wasOnline = _isOnline;
        _isOnline = _isConnectionResultOnline(result);

        if (!wasOnline && _isOnline) {
          _logger.i('Network connection restored');
          _processOfflineQueue();
        } else if (wasOnline && !_isOnline) {
          _logger.w('Network connection lost - switching to offline mode');
        }
      });
    } catch (e) {
      _logger.e('Failed to initialize connectivity monitoring: $e');
      _isOnline = false;
    }
  }

  /// Check if connectivity result indicates online status
  bool _isConnectionResultOnline(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
      case ConnectivityResult.ethernet:
      case ConnectivityResult.mobile:
        return true;
      case ConnectivityResult.bluetooth:
      case ConnectivityResult.vpn:
      case ConnectivityResult.other:
      case ConnectivityResult.none:
      default:
        return false;
    }
  }

  /// Setup all interceptors
  Future<void> _setupInterceptors(bool enableLogging, int maxRetries, Duration retryDelay) async {
    // 1. Logging interceptor (development only)
    if (enableLogging) {
      _dio.interceptors.add(LoggingInterceptor());
      _offlineDio.interceptors.add(LoggingInterceptor());
    }

    // 2. Auth interceptor for token management
    final authInterceptor = AuthInterceptor(
      storage: _storage,
      onTokenRefresh: _refreshToken,
    );
    _dio.interceptors.add(authInterceptor);
    _offlineDio.interceptors.add(authInterceptor);

    // 3. Cache interceptor for response caching
    final cacheInterceptor = CacheInterceptor(
      storage: _storage,
      defaultCacheDuration: const Duration(minutes: 5),
      maxCacheSize: 50 * 1024 * 1024, // 50MB
    );
    _dio.interceptors.add(cacheInterceptor);

    // 4. Retry interceptor with exponential backoff
    final retryInterceptor = RetryInterceptor(
      dio: _dio,
      maxRetries: maxRetries,
      retryDelay: retryDelay,
      logger: _logger,
    );
    _dio.interceptors.add(retryInterceptor);

    // 5. Offline interceptor for queueing failed requests
    final offlineInterceptor = OfflineInterceptor(
      storage: _storage,
      isOnline: () => _isOnline,
      processOfflineQueue: _processOfflineQueue,
    );
    _dio.interceptors.add(offlineInterceptor);
  }

  /// Process offline queue when connection is restored
  Future<void> _processOfflineQueue() async {
    try {
      final queue = await _storage.getOfflineQueue();
      if (queue.isEmpty) return;

      _logger.i('Processing offline queue with ${queue.length} requests');

      for (int i = 0; i < queue.length; i++) {
        final request = queue[i];
        try {
          await _executeQueuedRequest(request);
          await _storage.removeQueuedRequest(i);
        } catch (e) {
          _logger.e('Failed to process queued request: $e');
        }
      }
    } catch (e) {
      _logger.e('Failed to process offline queue: $e');
    }
  }

  /// Execute a queued request
  Future<void> _executeQueuedRequest(Map<String, dynamic> request) async {
    final method = request['method'] as String;
    final path = request['path'] as String;
    final data = request['data'];
    final queryParameters = request['queryParameters'] as Map<String, dynamic>?;

    switch (method.toUpperCase()) {
      case 'GET':
        await get(path, queryParameters: queryParameters);
        break;
      case 'POST':
        await post(path, data: data, queryParameters: queryParameters);
        break;
      case 'PUT':
        await put(path, data: data, queryParameters: queryParameters);
        break;
      case 'DELETE':
        await delete(path, queryParameters: queryParameters);
        break;
      case 'PATCH':
        await patch(path, data: data, queryParameters: queryParameters);
        break;
    }
  }

  /// Refresh authentication token
  Future<String?> _refreshToken() async {
    try {
      _logger.d('Attempting to refresh authentication token');

      // Implementation depends on your auth system
      // This is a placeholder - implement according to your auth flow
      final response = await _dio.post('/auth/refresh', data: {
        'refresh_token': await _storage.getRefreshToken(),
      });

      if (response.statusCode == 200) {
        final newToken = response.data['access_token'];
        await _storage.saveAuthToken(newToken);
        _authToken = newToken;
        return newToken;
      }
    } catch (e) {
      _logger.e('Token refresh failed: $e');
    }
    return null;
  }

  /// HTTP GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool forceRefresh = false,
  }) async {
    _ensureInitialized();

    final requestOptions = options ?? Options();
    if (forceRefresh) {
      requestOptions.extra = {'cache_force_refresh': true};
    }

    return await (_isOnline ? _dio : _offlineDio).get<T>(
      path,
      queryParameters: queryParameters,
      options: requestOptions,
      cancelToken: cancelToken,
    );
  }

  /// HTTP POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    _ensureInitialized();

    return await (_isOnline ? _dio : _offlineDio).post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// HTTP PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    _ensureInitialized();

    return await (_isOnline ? _dio : _offlineDio).put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// HTTP DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    _ensureInitialized();

    return await (_isOnline ? _dio : _offlineDio).delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// HTTP PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    _ensureInitialized();

    return await (_isOnline ? _dio : _offlineDio).patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// File upload with progress tracking
  Future<Response<T>> uploadFile<T>(
    String path,
    String filePath, {
    Map<String, dynamic>? data,
    ProgressCallback? onSendProgress,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    _ensureInitialized();

    final file = File(filePath);
    if (!file.existsSync()) {
      throw ApiException('File not found: $filePath', type: ApiExceptionType.notFound);
    }

    final fileName = file.path.split('/').last;
    final fileBytes = await file.readAsBytes();

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      ...?data,
    });

    return await (_isOnline ? _dio : _offlineDio).post<T>(
      path,
      data: formData,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
  }

  /// File download with progress tracking
  Future<Response> downloadFile(
    String urlPath,
    String savePath, {
    ProgressCallback? onReceiveProgress,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    _ensureInitialized();

    if (!_isOnline) {
      throw ApiException('Cannot download files in offline mode', type: ApiExceptionType.noConnection);
    }

    return await _dio.download(
      urlPath,
      savePath,
      onReceiveProgress: onReceiveProgress,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Multiple concurrent requests
  Future<List<Response>> concurrentRequests(List<Future<Response>> requests) async {
    _ensureInitialized();

    if (!_isOnline) {
      throw ApiException('Cannot make concurrent requests in offline mode', type: ApiExceptionType.noConnection);
    }

    return await Future.wait(requests);
  }

  /// Check if client is online
  bool get isOnline => _isOnline;

  /// Get current base URL
  String get baseUrl => _baseUrl;

  /// Update base URL
  void updateBaseUrl(String newBaseUrl) {
    _baseUrl = newBaseUrl;
    _dio.options.baseUrl = newBaseUrl;
    _offlineDio.options.baseUrl = newBaseUrl;
  }

  /// Update authentication token
  void updateAuthToken(String? token) {
    _authToken = token;
    _dio.options.headers['Authorization'] = token != null ? 'Bearer $token' : null;
    _offlineDio.options.headers['Authorization'] = token != null ? 'Bearer $token' : null;
  }

  /// Update default headers
  void updateHeaders(Map<String, dynamic> headers) {
    _defaultHeaders.addAll(headers);
    _dio.options.headers.addAll(_buildHeaders(_authToken));
    _offlineDio.options.headers.addAll(_buildHeaders(_authToken));
  }

  /// Clear all headers
  void clearHeaders() {
    _defaultHeaders.clear();
    _dio.options.headers.clear();
    _offlineDio.options.headers.clear();
    updateHeaders(_buildHeaders(_authToken));
  }

  /// Cancel all ongoing requests
  void cancelAllRequests() {
    _dio.close(force: true);
    _offlineDio.close(force: true);
  }

  /// Clear cache
  Future<void> clearCache() async {
    await _storage.clearCache();
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    return await _storage.getCacheStats();
  }

  /// Get offline queue statistics
  Future<Map<String, dynamic>> getOfflineQueueStats() async {
    return await _storage.getOfflineQueueStats();
  }

  /// Ensure client is initialized
  void _ensureInitialized() {
    if (!_initialized) {
      throw ApiException('HTTP client not initialized. Call initialize() first.', type: ApiExceptionType.notInitialized);
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _dio.close();
    _offlineDio.close();
    _initialized = false;
    _logger.i('HTTP client disposed');
  }
}