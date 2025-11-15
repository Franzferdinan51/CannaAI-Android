import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'enhanced_ai_service.dart';

/// AI cache service for caching analysis results and chat responses
class AICacheService {
  final Logger _logger = Logger();
  late final Directory _cacheDir;
  late final File _analysisCacheFile;
  late final File _chatCacheFile;
  late final File _metadataFile;

  final Map<String, CachedAnalysis> _analysisCache = {};
  final Map<String, List<CachedChatMessage>> _chatCache = {};
  final Map<String, dynamic> _metadata = {};

  Timer? _cleanupTimer;
  bool _initialized = false;

  /// Initialize cache service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _logger.i('Initializing AI cache service...');

      // Get application documents directory
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/ai_cache');

      // Create cache directory if it doesn't exist
      if (!await _cacheDir.exists()) {
        await _cacheDir.create(recursive: true);
      }

      // Initialize cache files
      _analysisCacheFile = File('${_cacheDir.path}/analysis_cache.json');
      _chatCacheFile = File('${_cacheDir.path}/chat_cache.json');
      _metadataFile = File('${_cacheDir.path}/metadata.json');

      // Load existing cache data
      await _loadAnalysisCache();
      await _loadChatCache();
      await _loadMetadata();

      // Start cleanup timer
      _startCleanupTimer();

      _initialized = true;
      _logger.i('AI cache service initialized');
    } catch (e) {
      _logger.e('Failed to initialize AI cache service: $e');
      rethrow;
    }
  }

  /// Get cached analysis result
  Future<PlantAnalysisResult?> getCachedAnalysis(String cacheKey) async {
    if (!_initialized) await initialize();

    try {
      final cached = _analysisCache[cacheKey];
      if (cached == null) {
        return null;
      }

      // Check if cache entry is still valid
      if (_isCacheExpired(cached.timestamp, Duration(hours: 24))) {
        _analysisCache.remove(cacheKey);
        await _saveAnalysisCache();
        return null;
      }

      _logger.d('Cache hit for analysis: $cacheKey');
      return cached.result;
    } catch (e) {
      _logger.e('Failed to get cached analysis: $e');
      return null;
    }
  }

  /// Cache analysis result
  Future<void> cacheAnalysis(String cacheKey, PlantAnalysisResult result) async {
    if (!_initialized) await initialize();

    try {
      final cachedAnalysis = CachedAnalysis(
        cacheKey: cacheKey,
        result: result,
        timestamp: DateTime.now(),
        hits: 0,
      );

      _analysisCache[cacheKey] = cachedAnalysis;
      await _saveAnalysisCache();

      _logger.d('Cached analysis: $cacheKey');
    } catch (e) {
      _logger.e('Failed to cache analysis: $e');
    }
  }

  /// Get cached chat messages for session
  Future<List<CachedChatMessage>> getCachedChatMessages(String sessionId) async {
    if (!_initialized) await initialize();

    try {
      final messages = _chatCache[sessionId] ?? [];

      // Filter out expired messages
      final validMessages = messages.where((msg) =>
        !_isCacheExpired(msg.timestamp, Duration(days: 7))
      ).toList();

      if (validMessages.length != messages.length) {
        _chatCache[sessionId] = validMessages;
        await _saveChatCache();
      }

      return validMessages;
    } catch (e) {
      _logger.e('Failed to get cached chat messages: $e');
      return [];
    }
  }

  /// Cache chat message
  Future<void> cacheChatMessage(
    String sessionId,
    String userMessage,
    ChatResponse aiResponse,
  ) async {
    if (!_initialized) await initialize();

    try {
      final timestamp = DateTime.now();
      final messages = _chatCache[sessionId] ?? [];

      // Add new messages
      messages.add(CachedChatMessage(
        sessionId: sessionId,
        userMessage: userMessage,
        aiResponse: aiResponse.message,
        timestamp: timestamp,
      ));

      // Keep only last 50 messages per session
      if (messages.length > 50) {
        messages.removeRange(0, messages.length - 50);
      }

      _chatCache[sessionId] = messages;
      await _saveChatCache();

      _logger.d('Cached chat message for session: $sessionId');
    } catch (e) {
      _logger.e('Failed to cache chat message: $e');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStatistics() {
    return {
      'analysis_cache_size': _analysisCache.length,
      'chat_sessions_count': _chatCache.length,
      'total_chat_messages': _chatCache.values.fold(0, (sum, messages) => sum + messages.length),
      'cache_directory': _cacheDir.path,
      'last_cleanup': _metadata['last_cleanup'],
      'total_cache_hits': _metadata['total_hits'] ?? 0,
      'total_cache_misses': _metadata['total_misses'] ?? 0,
    };
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    if (!_initialized) await initialize();

    try {
      _analysisCache.clear();
      _chatCache.clear();

      await _saveAnalysisCache();
      await _saveChatCache();

      _logger.i('All AI caches cleared');
    } catch (e) {
      _logger.e('Failed to clear caches: $e');
    }
  }

  /// Clear expired cache entries
  Future<void> clearExpiredEntries() async {
    if (!_initialized) await initialize();

    try {
      int removedAnalyses = 0;
      int removedMessages = 0;

      // Clear expired analysis cache
      final expiredAnalyses = <String>[];
      _analysisCache.forEach((key, cached) {
        if (_isCacheExpired(cached.timestamp, Duration(hours: 24))) {
          expiredAnalyses.add(key);
        }
      });

      for (final key in expiredAnalyses) {
        _analysisCache.remove(key);
        removedAnalyses++;
      }

      // Clear expired chat messages
      final expiredSessions = <String>[];
      _chatCache.forEach((sessionId, messages) {
        final validMessages = messages.where((msg) =>
          !_isCacheExpired(msg.timestamp, Duration(days: 7))
        ).toList();

        if (validMessages.isEmpty) {
          expiredSessions.add(sessionId);
        } else if (validMessages.length != messages.length) {
          removedMessages += (messages.length - validMessages.length);
          _chatCache[sessionId] = validMessages;
        }
      });

      for (final sessionId in expiredSessions) {
        _chatCache.remove(sessionId);
      }

      // Save changes
      if (removedAnalyses > 0 || removedMessages > 0) {
        await _saveAnalysisCache();
        await _saveChatCache();

        _metadata['last_cleanup'] = DateTime.now().toIso8601String();
        await _saveMetadata();

        _logger.i('Cache cleanup completed: removed $removedAnalyses analyses, $removedMessages messages');
      }
    } catch (e) {
      _logger.e('Cache cleanup failed: $e');
    }
  }

  /// Optimize cache for storage
  Future<void> optimizeCache() async {
    if (!_initialized) await initialize();

    try {
      // Remove least recently used analyses if cache is too large
      if (_analysisCache.length > 100) {
        final sortedAnalyses = _analysisCache.entries.toList()
          ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

        final toRemove = sortedAnalyses.take(_analysisCache.length - 100);
        for (final entry in toRemove) {
          _analysisCache.remove(entry.key);
        }

        await _saveAnalysisCache();
        _logger.i('Optimized analysis cache: removed ${toRemove.length} old entries');
      }

      // Optimize chat cache
      int totalMessages = _chatCache.values.fold(0, (sum, messages) => sum + messages.length);
      if (totalMessages > 1000) {
        int removed = 0;
        _chatCache.forEach((sessionId, messages) {
          if (messages.length > 20) {
            final excess = messages.length - 20;
            messages.removeRange(0, excess);
            removed += excess;
          }
        });

        if (removed > 0) {
          await _saveChatCache();
          _logger.i('Optimized chat cache: removed $removed old messages');
        }
      }
    } catch (e) {
      _logger.e('Cache optimization failed: $e');
    }
  }

  /// Load analysis cache from file
  Future<void> _loadAnalysisCache() async {
    try {
      if (await _analysisCacheFile.exists()) {
        final content = await _analysisCacheFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        for (final entry in data.entries) {
          final cachedData = entry.value as Map<String, dynamic>;
          _analysisCache[entry.key] = CachedAnalysis(
            cacheKey: entry.key,
            result: _deserializeAnalysisResult(cachedData['result']),
            timestamp: DateTime.parse(cachedData['timestamp']),
            hits: cachedData['hits'] ?? 0,
          );
        }

        _logger.d('Loaded ${_analysisCache.length} cached analyses');
      }
    } catch (e) {
      _logger.w('Failed to load analysis cache: $e');
    }
  }

  /// Load chat cache from file
  Future<void> _loadChatCache() async {
    try {
      if (await _chatCacheFile.exists()) {
        final content = await _chatCacheFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        for (final entry in data.entries) {
          final messagesData = entry.value as List;
          final messages = messagesData.map((msgData) {
            final data = msgData as Map<String, dynamic>;
            return CachedChatMessage(
              sessionId: data['sessionId'],
              userMessage: data['userMessage'],
              aiResponse: data['aiResponse'],
              timestamp: DateTime.parse(data['timestamp']),
            );
          }).toList();

          _chatCache[entry.key] = messages;
        }

        final totalMessages = _chatCache.values.fold(0, (sum, messages) => sum + messages.length);
        _logger.d('Loaded chat cache: ${_chatCache.length} sessions, $totalMessages messages');
      }
    } catch (e) {
      _logger.w('Failed to load chat cache: $e');
    }
  }

  /// Load metadata from file
  Future<void> _loadMetadata() async {
    try {
      if (await _metadataFile.exists()) {
        final content = await _metadataFile.readAsString();
        _metadata = jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      _logger.w('Failed to load metadata: $e');
    }
  }

  /// Save analysis cache to file
  Future<void> _saveAnalysisCache() async {
    try {
      final data = <String, dynamic>{};

      _analysisCache.forEach((key, cached) {
        data[key] = {
          'result': _serializeAnalysisResult(cached.result),
          'timestamp': cached.timestamp.toIso8601String(),
          'hits': cached.hits,
        };
      });

      await _analysisCacheFile.writeAsString(jsonEncode(data));
    } catch (e) {
      _logger.e('Failed to save analysis cache: $e');
    }
  }

  /// Save chat cache to file
  Future<void> _saveChatCache() async {
    try {
      final data = <String, dynamic>{};

      _chatCache.forEach((sessionId, messages) {
        data[sessionId] = messages.map((msg) => {
          'sessionId': msg.sessionId,
          'userMessage': msg.userMessage,
          'aiResponse': msg.aiResponse,
          'timestamp': msg.timestamp.toIso8601String(),
        }).toList();
      });

      await _chatCacheFile.writeAsString(jsonEncode(data));
    } catch (e) {
      _logger.e('Failed to save chat cache: $e');
    }
  }

  /// Save metadata to file
  Future<void> _saveMetadata() async {
    try {
      await _metadataFile.writeAsString(jsonEncode(_metadata));
    } catch (e) {
      _logger.e('Failed to save metadata: $e');
    }
  }

  /// Check if cache entry is expired
  bool _isCacheExpired(DateTime timestamp, Duration maxAge) {
    return DateTime.now().difference(timestamp) > maxAge;
  }

  /// Start automatic cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(Duration(hours: 6), (_) {
      clearExpiredEntries();
      optimizeCache();
    });
  }

  /// Serialize analysis result for caching
  Map<String, dynamic> _serializeAnalysisResult(PlantAnalysisResult result) {
    return {
      'strainDetected': result.strainDetected,
      'symptoms': result.symptoms,
      'severity': result.severity.toString(),
      'confidenceScore': result.confidenceScore,
      'detectedIssues': result.detectedIssues,
      'deficiencies': result.deficiencies,
      'diseases': result.diseases,
      'pests': result.pests,
      'environmentalIssues': result.environmentalIssues,
      'recommendations': result.recommendations,
      'actionableSteps': result.actionableSteps,
      'estimatedRecoveryTime': result.estimatedRecoveryTime,
      'preventionTips': result.preventionTips,
      'growthStage': result.growthStage,
      'isPurpleStrain': result.isPurpleStrain,
      'metrics': {
        'leafColorScore': result.metrics.leafColorScore,
        'leafHealthScore': result.metrics.leafHealthScore,
        'growthRateScore': result.metrics.growthRateScore,
        'pestDamageScore': result.metrics.pestDamageScore,
        'nutrientDeficiencyScore': result.metrics.nutrientDeficiencyScore,
        'diseaseScore': result.metrics.diseaseScore,
        'overallVigorScore': result.metrics.overallVigorScore,
        'customMetrics': result.metrics.customMetrics,
      },
      'analysisTimestamp': result.analysisTimestamp.toIso8601String(),
      'analysisType': result.analysisType,
      'processingTime': result.processingTime.inMilliseconds,
      'provider': result.provider,
    };
  }

  /// Deserialize analysis result from cache
  PlantAnalysisResult _deserializeAnalysisResult(Map<String, dynamic> data) {
    final metricsData = data['metrics'] as Map<String, dynamic>;

    return PlantAnalysisResult(
      strainDetected: data['strainDetected'],
      symptoms: List<String>.from(data['symptoms']),
      severity: _parseSeverity(data['severity']),
      confidenceScore: data['confidenceScore'],
      detectedIssues: List<String>.from(data['detectedIssues']),
      deficiencies: List<String>.from(data['deficiencies']),
      diseases: List<String>.from(data['diseases']),
      pests: List<String>.from(data['pests']),
      environmentalIssues: List<String>.from(data['environmentalIssues']),
      recommendations: List<String>.from(data['recommendations']),
      actionableSteps: List<String>.from(data['actionableSteps']),
      estimatedRecoveryTime: data['estimatedRecoveryTime'],
      preventionTips: List<String>.from(data['preventionTips']),
      growthStage: data['growthStage'],
      isPurpleStrain: data['isPurpleStrain'],
      metrics: PlantMetrics(
        leafColorScore: metricsData['leafColorScore'],
        leafHealthScore: metricsData['leafHealthScore'],
        growthRateScore: metricsData['growthRateScore'],
        pestDamageScore: metricsData['pestDamageScore'],
        nutrientDeficiencyScore: metricsData['nutrientDeficiencyScore'],
        diseaseScore: metricsData['diseaseScore'],
        overallVigorScore: metricsData['overallVigorScore'],
        customMetrics: metricsData['customMetrics'] != null
            ? Map<String, double>.from(metricsData['customMetrics'])
            : null,
      ),
      analysisTimestamp: DateTime.parse(data['analysisTimestamp']),
      analysisType: data['analysisType'],
      processingTime: Duration(milliseconds: data['processingTime']),
      provider: data['provider'],
    );
  }

  AnalysisSeverity _parseSeverity(String severity) {
    switch (severity) {
      case 'healthy':
        return AnalysisSeverity.healthy;
      case 'mild':
        return AnalysisSeverity.mild;
      case 'moderate':
        return AnalysisSeverity.moderate;
      case 'severe':
        return AnalysisSeverity.severe;
      default:
        return AnalysisSeverity.unknown;
    }
  }

  /// Get cache directory size
  Future<int> getCacheSize() async {
    try {
      if (!await _cacheDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in _cacheDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      _logger.e('Failed to get cache size: $e');
      return 0;
    }
  }

  /// Dispose of cache service
  Future<void> dispose() async {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;

    // Save any pending changes
    if (_initialized) {
      await _saveAnalysisCache();
      await _saveChatCache();
      await _saveMetadata();
    }

    _initialized = false;
    _logger.i('AI cache service disposed');
  }
}

// Supporting classes

class CachedAnalysis {
  final String cacheKey;
  final PlantAnalysisResult result;
  final DateTime timestamp;
  int hits;

  CachedAnalysis({
    required this.cacheKey,
    required this.result,
    required this.timestamp,
    this.hits = 0,
  });
}

class CachedChatMessage {
  final String sessionId;
  final String userMessage;
  final String aiResponse;
  final DateTime timestamp;

  CachedChatMessage({
    required this.sessionId,
    required this.userMessage,
    required this.aiResponse,
    required this.timestamp,
  });
}