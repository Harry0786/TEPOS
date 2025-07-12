import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  // Performance metrics
  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, List<Duration>> _operationDurations = {};
  final List<String> _performanceLog = [];

  // Memory monitoring
  Timer? _memoryMonitorTimer;
  int _lastMemoryUsage = 0;

  /// Start monitoring an operation
  void startOperation(String operationName) {
    _operationStartTimes[operationName] = DateTime.now();
    if (kDebugMode) {
      print('⏱️ Started: $operationName');
    }
  }

  /// End monitoring an operation
  void endOperation(String operationName) {
    final startTime = _operationStartTimes[operationName];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _operationStartTimes.remove(operationName);

      // Store duration for averaging
      _operationDurations.putIfAbsent(operationName, () => []);
      _operationDurations[operationName]!.add(duration);

      // Keep only last 10 measurements
      if (_operationDurations[operationName]!.length > 10) {
        _operationDurations[operationName]!.removeAt(0);
      }

      if (kDebugMode) {
        print('✅ Completed: $operationName in ${duration.inMilliseconds}ms');
      }

      // Log slow operations
      if (duration.inMilliseconds > 100) {
        _performanceLog.add(
          '⚠️ Slow operation: $operationName took ${duration.inMilliseconds}ms',
        );
      }
    }
  }

  /// Get average duration for an operation
  Duration getAverageDuration(String operationName) {
    final durations = _operationDurations[operationName];
    if (durations == null || durations.isEmpty) {
      return Duration.zero;
    }

    final totalMilliseconds = durations.fold<int>(
      0,
      (sum, duration) => sum + duration.inMilliseconds,
    );

    return Duration(milliseconds: totalMilliseconds ~/ durations.length);
  }

  /// Get performance summary
  Map<String, dynamic> getPerformanceSummary() {
    final summary = <String, dynamic>{};

    for (final entry in _operationDurations.entries) {
      final operationName = entry.key;
      final durations = entry.value;

      if (durations.isNotEmpty) {
        final avgDuration = getAverageDuration(operationName);
        final maxDuration = durations.reduce((a, b) => a > b ? a : b);
        final minDuration = durations.reduce((a, b) => a < b ? a : b);

        summary[operationName] = {
          'average': avgDuration.inMilliseconds,
          'max': maxDuration.inMilliseconds,
          'min': minDuration.inMilliseconds,
          'count': durations.length,
        };
      }
    }

    return summary;
  }

  /// Get recent performance logs
  List<String> getRecentLogs() {
    return List.from(_performanceLog.reversed.take(20));
  }

  /// Clear performance logs
  void clearLogs() {
    _performanceLog.clear();
    _operationDurations.clear();
    _operationStartTimes.clear();
  }

  /// Start memory monitoring
  void startMemoryMonitoring() {
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkMemoryUsage();
    });
  }

  /// Stop memory monitoring
  void stopMemoryMonitoring() {
    _memoryMonitorTimer?.cancel();
    _memoryMonitorTimer = null;
  }

  /// Check memory usage
  void _checkMemoryUsage() {
    // This is a simplified memory check
    // In a real app, you might use platform channels to get actual memory usage
    final currentTime = DateTime.now();
    if (kDebugMode) {
      print('🧠 Memory check at ${currentTime.toIso8601String()}');
    }
  }

  /// Dispose resources
  void dispose() {
    stopMemoryMonitoring();
    clearLogs();
  }
}

/// Performance monitoring mixin for widgets
mixin PerformanceMixin<T extends StatefulWidget> on State<T> {
  final PerformanceService _performanceService = PerformanceService();

  @override
  void initState() {
    super.initState();
    _performanceService.startOperation('${widget.runtimeType}_init');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _performanceService.endOperation('${widget.runtimeType}_init');
  }

  @override
  void dispose() {
    _performanceService.endOperation('${widget.runtimeType}_dispose');
    super.dispose();
  }

  /// Monitor a specific operation
  void monitorOperation(
    String operationName,
    Future<void> Function() operation,
  ) async {
    _performanceService.startOperation(operationName);
    try {
      await operation();
    } finally {
      _performanceService.endOperation(operationName);
    }
  }

  /// Monitor a synchronous operation
  T monitorSyncOperation<T>(String operationName, T Function() operation) {
    _performanceService.startOperation(operationName);
    try {
      return operation();
    } finally {
      _performanceService.endOperation(operationName);
    }
  }
}
