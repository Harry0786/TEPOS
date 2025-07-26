import 'dart:developer' as developer;

/// Performance monitoring service for tracking operations
class PerformanceService {
  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, Duration> _operationDurations = {};
  
  /// Start timing an operation
  void startOperation(String operationName) {
    _operationStartTimes[operationName] = DateTime.now();
    developer.log('⏱️ Started: $operationName', name: 'Performance');
  }
  
  /// End timing an operation and log the duration
  void endOperation(String operationName) {
    final startTime = _operationStartTimes[operationName];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _operationDurations[operationName] = duration;
      developer.log(
        '✅ Completed: $operationName in ${duration.inMilliseconds}ms',
        name: 'Performance',
      );
      _operationStartTimes.remove(operationName);
    } else {
      developer.log('⚠️ Operation $operationName was not started', name: 'Performance');
    }
  }
  
  /// Get the duration of a completed operation
  Duration? getOperationDuration(String operationName) {
    return _operationDurations[operationName];
  }
  
  /// Get all operation durations
  Map<String, Duration> getAllDurations() {
    return Map.from(_operationDurations);
  }
  
  /// Clear all recorded durations
  void clearHistory() {
    _operationDurations.clear();
    _operationStartTimes.clear();
  }
  
  /// Log a performance warning if operation takes too long
  void checkPerformance(String operationName, Duration threshold) {
    final duration = _operationDurations[operationName];
    if (duration != null && duration > threshold) {
      developer.log(
        '🐌 Slow operation: $operationName took ${duration.inMilliseconds}ms (threshold: ${threshold.inMilliseconds}ms)',
        name: 'Performance',
      );
    }
  }
  
  /// Dispose the service and clean up
  void dispose() {
    clearHistory();
    developer.log('🧹 PerformanceService disposed', name: 'Performance');
  }
}
