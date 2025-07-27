import 'dart:async';
import 'dart:collection';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  // Performance tracking
  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, Duration> _operationDurations = {};
  final Queue<Map<String, dynamic>> _recentOperations = Queue();
  final Map<String, int> _operationCounts = {};
  final Map<String, List<Duration>> _operationLatencies = {};

  // API call tracking
  final Map<String, int> _apiCallCounts = {};
  final Map<String, List<Duration>> _apiCallLatencies = {};
  final Map<String, int> _apiCallErrors = {};
  DateTime? _lastApiCallTime;

  // WebSocket tracking
  int _websocketConnections = 0;
  int _websocketDisconnections = 0;
  int _websocketMessages = 0;
  DateTime? _lastWebSocketMessageTime;

  // Cache performance
  int _cacheHits = 0;
  int _cacheMisses = 0;
  final Map<String, int> _cacheHitCounts = {};

  // Timer for periodic stats
  Timer? _statsTimer;
  static const Duration _statsInterval = Duration(minutes: 5);

  /// Start tracking an operation
  void startOperation(String operationName) {
    _operationStartTimes[operationName] = DateTime.now();
    _operationCounts[operationName] =
        (_operationCounts[operationName] ?? 0) + 1;
  }

  /// End tracking an operation
  void endOperation(String operationName) {
    final startTime = _operationStartTimes[operationName];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _operationDurations[operationName] = duration;
      _operationStartTimes.remove(operationName);

      // Track latency
      _operationLatencies[operationName] ??= [];
      _operationLatencies[operationName]!.add(duration);

      // Keep only last 100 latencies
      if (_operationLatencies[operationName]!.length > 100) {
        _operationLatencies[operationName]!.removeAt(0);
      }

      // Add to recent operations
      _recentOperations.add({
        'operation': operationName,
        'duration': duration.inMilliseconds,
        'timestamp': DateTime.now(),
      });

      // Keep only last 50 operations
      if (_recentOperations.length > 50) {
        _recentOperations.removeFirst();
      }
    }
  }

  /// Track API call
  void trackApiCall(
    String endpoint,
    Duration duration, {
    bool isError = false,
  }) {
    _apiCallCounts[endpoint] = (_apiCallCounts[endpoint] ?? 0) + 1;
    _lastApiCallTime = DateTime.now();

    if (isError) {
      _apiCallErrors[endpoint] = (_apiCallErrors[endpoint] ?? 0) + 1;
    }

    // Track latency
    _apiCallLatencies[endpoint] ??= [];
    _apiCallLatencies[endpoint]!.add(duration);

    // Keep only last 50 latencies per endpoint
    if (_apiCallLatencies[endpoint]!.length > 50) {
      _apiCallLatencies[endpoint]!.removeAt(0);
    }
  }

  /// Track WebSocket event
  void trackWebSocketEvent(String eventType) {
    switch (eventType) {
      case 'connect':
        _websocketConnections++;
        break;
      case 'disconnect':
        _websocketDisconnections++;
        break;
      case 'message':
        _websocketMessages++;
        _lastWebSocketMessageTime = DateTime.now();
        break;
    }
  }

  /// Track cache hit/miss
  void trackCacheHit(String cacheKey) {
    _cacheHits++;
    _cacheHitCounts[cacheKey] = (_cacheHitCounts[cacheKey] ?? 0) + 1;
  }

  void trackCacheMiss(String cacheKey) {
    _cacheMisses++;
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final now = DateTime.now();

    // Calculate average latencies
    final Map<String, double> avgLatencies = {};
    _operationLatencies.forEach((operation, latencies) {
      if (latencies.isNotEmpty) {
        final totalMs = latencies.fold<int>(
          0,
          (sum, duration) => sum + duration.inMilliseconds,
        );
        avgLatencies[operation] = totalMs / latencies.length;
      }
    });

    // Calculate API call statistics
    final Map<String, dynamic> apiStats = {};
    _apiCallCounts.forEach((endpoint, count) {
      final errors = _apiCallErrors[endpoint] ?? 0;
      final latencies = _apiCallLatencies[endpoint] ?? [];
      double avgLatency = 0;

      if (latencies.isNotEmpty) {
        final totalMs = latencies.fold<int>(
          0,
          (sum, duration) => sum + duration.inMilliseconds,
        );
        avgLatency = totalMs / latencies.length;
      }

      apiStats[endpoint] = {
        'total_calls': count,
        'errors': errors,
        'success_rate':
            count > 0
                ? ((count - errors) / count * 100).toStringAsFixed(1)
                : '0.0',
        'avg_latency_ms': avgLatency.toStringAsFixed(1),
      };
    });

    // Calculate cache hit rate
    final totalCacheAccess = _cacheHits + _cacheMisses;
    final cacheHitRate =
        totalCacheAccess > 0 ? (_cacheHits / totalCacheAccess * 100) : 0.0;

    return {
      'timestamp': now.toIso8601String(),
      'operation_stats': {
        'total_operations': _operationCounts.values.fold<int>(
          0,
          (sum, count) => sum + count,
        ),
        'operation_counts': _operationCounts,
        'avg_latencies_ms': avgLatencies,
        'recent_operations': _recentOperations.take(10).toList(),
      },
      'api_stats': {
        'total_api_calls': _apiCallCounts.values.fold<int>(
          0,
          (sum, count) => sum + count,
        ),
        'endpoint_stats': apiStats,
        'last_api_call': _lastApiCallTime?.toIso8601String(),
      },
      'websocket_stats': {
        'connections': _websocketConnections,
        'disconnections': _websocketDisconnections,
        'messages_received': _websocketMessages,
        'last_message': _lastWebSocketMessageTime?.toIso8601String(),
        'connection_ratio':
            _websocketConnections > 0
                ? (_websocketDisconnections / _websocketConnections)
                    .toStringAsFixed(2)
                : '0.0',
      },
      'cache_stats': {
        'hits': _cacheHits,
        'misses': _cacheMisses,
        'hit_rate_percent': cacheHitRate.toStringAsFixed(1),
        'cache_key_hits': _cacheHitCounts,
      },
      'system_health': {
        'high_latency_operations':
            avgLatencies.entries
                .where((entry) => entry.value > 1000) // > 1 second
                .map(
                  (entry) =>
                      '${entry.key}: ${entry.value.toStringAsFixed(0)}ms',
                )
                .toList(),
        'frequent_api_calls':
            _apiCallCounts.entries
                .where((entry) => entry.value > 10) // > 10 calls
                .map((entry) => '${entry.key}: ${entry.value} calls')
                .toList(),
        'error_prone_endpoints':
            _apiCallErrors.entries
                .where((entry) => entry.value > 2) // > 2 errors
                .map((entry) => '${entry.key}: ${entry.value} errors')
                .toList(),
      },
    };
  }

  /// Get real-time performance summary
  String getPerformanceSummary() {
    final stats = getPerformanceStats();
    final apiStats = stats['api_stats'] as Map<String, dynamic>;
    final wsStats = stats['websocket_stats'] as Map<String, dynamic>;
    final cacheStats = stats['cache_stats'] as Map<String, dynamic>;

    final totalApiCalls = apiStats['total_api_calls'] as int;
    final totalWsMessages = wsStats['messages_received'] as int;
    final cacheHitRate = cacheStats['hit_rate_percent'] as String;

    return '''
Performance Summary:
- API Calls: $totalApiCalls
- WebSocket Messages: $totalWsMessages
- Cache Hit Rate: ${cacheHitRate}%
- WebSocket Connections: ${wsStats['connections']}
- Recent Operations: ${stats['operation_stats']['recent_operations'].length}
''';
  }

  /// Start periodic stats collection
  void startPeriodicStats() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(_statsInterval, (timer) {
      final stats = getPerformanceStats();
      print('📊 Performance Stats: ${stats['timestamp']}');
      print('   API Calls: ${stats['api_stats']['total_api_calls']}');
      print(
        '   WebSocket Messages: ${stats['websocket_stats']['messages_received']}',
      );
      print('   Cache Hit Rate: ${stats['cache_stats']['hit_rate_percent']}%');

      // Log health issues
      final health = stats['system_health'] as Map<String, dynamic>;
      if (health['high_latency_operations'].isNotEmpty) {
        print('   ⚠️ High Latency: ${health['high_latency_operations']}');
      }
      if (health['error_prone_endpoints'].isNotEmpty) {
        print('   ❌ Error Prone: ${health['error_prone_endpoints']}');
      }
    });
  }

  /// Stop periodic stats collection
  void stopPeriodicStats() {
    _statsTimer?.cancel();
  }

  /// Reset all statistics
  void resetStats() {
    _operationStartTimes.clear();
    _operationDurations.clear();
    _recentOperations.clear();
    _operationCounts.clear();
    _operationLatencies.clear();
    _apiCallCounts.clear();
    _apiCallLatencies.clear();
    _apiCallErrors.clear();
    _websocketConnections = 0;
    _websocketDisconnections = 0;
    _websocketMessages = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
    _cacheHitCounts.clear();
    _lastApiCallTime = null;
    _lastWebSocketMessageTime = null;
  }

  /// Dispose the service
  void dispose() {
    stopPeriodicStats();
    resetStats();
  }
}
