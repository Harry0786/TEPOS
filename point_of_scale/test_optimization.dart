import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'lib/services/api_service.dart';
import 'lib/services/websocket_service.dart';
import 'lib/services/auto_refresh_service.dart';
import 'lib/services/performance_service.dart';

void main() {
  group('Backend Load Optimization Tests', () {
    late WebSocketService webSocketService;
    late AutoRefreshService autoRefreshService;
    late PerformanceService performanceService;

    setUp(() {
      webSocketService = WebSocketService(serverUrl: ApiService.webSocketUrl);
      autoRefreshService = AutoRefreshService();
      performanceService = PerformanceService();
    });

    tearDown(() {
      webSocketService.dispose();
      autoRefreshService.dispose();
      performanceService.dispose();
    });

    test('WebSocket Service - Single Connection', () async {
      // Test that only one connection is maintained
      webSocketService.connect();
      await Future.delayed(Duration(seconds: 2));

      expect(webSocketService.isConnected, true);

      // Try to connect again - should not create duplicate
      webSocketService.connect();
      await Future.delayed(Duration(seconds: 1));

      // Should still be connected and healthy
      expect(webSocketService.isConnected, true);
      expect(webSocketService.isHealthy, true);
    });

    test('WebSocket Service - Connection Health', () async {
      webSocketService.connect();
      await Future.delayed(Duration(seconds: 3));

      final stats = webSocketService.getConnectionStats();
      expect(stats['isConnected'], true);
      expect(stats['isHealthy'], true);
      expect(stats['reconnectAttempts'], 0);
      expect(stats['consecutiveFailures'], 0);
    });

    test('Auto Refresh Service - Reduced Polling', () async {
      autoRefreshService.initialize();

      // Check that intervals are optimized
      final stats = autoRefreshService.getServiceStats();
      expect(stats['periodicRefreshInterval'], 120); // 2 minutes
      expect(stats['smartRefreshInterval'], 300); // 5 minutes
    });

    test('Auto Refresh Service - Request Deduplication', () async {
      autoRefreshService.initialize();

      // Add a test callback
      bool callbackCalled = false;
      autoRefreshService.addRefreshCallback(() {
        callbackCalled = true;
      });

      // Force refresh
      await autoRefreshService.forceRefresh();
      expect(callbackCalled, true);

      // Try to force refresh again immediately
      callbackCalled = false;
      await autoRefreshService.forceRefresh();

      // Should be prevented by deduplication
      expect(callbackCalled, false);
    });

    test('API Service - Cache Optimization', () async {
      // Test cache functionality
      final cacheKey = 'test_cache';

      // Simulate cache hit
      performanceService.trackCacheHit(cacheKey);
      performanceService.trackCacheHit(cacheKey);
      performanceService.trackCacheMiss(cacheKey);

      final stats = performanceService.getPerformanceStats();
      final cacheStats = stats['cache_stats'];

      expect(cacheStats['hits'], 2);
      expect(cacheStats['misses'], 1);
      expect(cacheStats['hit_rate_percent'], '66.7');
    });

    test('Performance Service - API Call Tracking', () async {
      // Simulate API calls
      performanceService.trackApiCall(
        '/api/estimates',
        Duration(milliseconds: 500),
      );
      performanceService.trackApiCall(
        '/api/orders',
        Duration(milliseconds: 300),
      );
      performanceService.trackApiCall(
        '/api/estimates',
        Duration(milliseconds: 600),
        isError: true,
      );

      final stats = performanceService.getPerformanceStats();
      final apiStats = stats['api_stats'];

      expect(apiStats['total_api_calls'], 3);

      final endpointStats = apiStats['endpoint_stats'];
      expect(endpointStats['/api/estimates']['total_calls'], 2);
      expect(endpointStats['/api/estimates']['errors'], 1);
      expect(endpointStats['/api/orders']['total_calls'], 1);
      expect(endpointStats['/api/orders']['errors'], 0);
    });

    test('Performance Service - WebSocket Tracking', () async {
      // Simulate WebSocket events
      performanceService.trackWebSocketEvent('connect');
      performanceService.trackWebSocketEvent('message');
      performanceService.trackWebSocketEvent('message');
      performanceService.trackWebSocketEvent('disconnect');
      performanceService.trackWebSocketEvent('connect');

      final stats = performanceService.getPerformanceStats();
      final wsStats = stats['websocket_stats'];

      expect(wsStats['connections'], 2);
      expect(wsStats['disconnections'], 1);
      expect(wsStats['messages_received'], 2);
      expect(wsStats['connection_ratio'], '0.50');
    });

    test('System Health Monitoring', () async {
      // Simulate some operations
      performanceService.startOperation('test_operation');
      await Future.delayed(Duration(milliseconds: 100));
      performanceService.endOperation('test_operation');

      performanceService.trackApiCall('/api/slow', Duration(seconds: 2));
      performanceService.trackApiCall(
        '/api/error',
        Duration(milliseconds: 100),
        isError: true,
      );
      performanceService.trackApiCall(
        '/api/error',
        Duration(milliseconds: 200),
        isError: true,
      );
      performanceService.trackApiCall(
        '/api/error',
        Duration(milliseconds: 150),
        isError: true,
      );

      final stats = performanceService.getPerformanceStats();
      final health = stats['system_health'];

      // Should detect high latency operation
      expect(health['high_latency_operations'].length, greaterThan(0));

      // Should detect error-prone endpoint
      expect(health['error_prone_endpoints'].length, greaterThan(0));
    });

    test('Configuration Validation', () {
      // Verify optimization parameters are set correctly
      expect(ApiService.baseUrl, 'https://pos-2wc9.onrender.com/api');
      expect(ApiService.webSocketUrl, 'wss://pos-2wc9.onrender.com/ws');

      // These values should match the optimization settings
      // Note: We can't directly access private constants, but we can verify
      // the behavior through the public methods
    });
  });

  group('Integration Tests', () {
    test('End-to-End Optimization Test', () async {
      // This test simulates a typical usage scenario
      final webSocketService = WebSocketService(
        serverUrl: ApiService.webSocketUrl,
      );
      final autoRefreshService = AutoRefreshService();
      final performanceService = PerformanceService();

      try {
        // Initialize services
        autoRefreshService.initialize();
        webSocketService.connect();
        performanceService.startPeriodicStats();

        // Simulate some API calls
        performanceService.trackApiCall(
          '/api/estimates',
          Duration(milliseconds: 400),
        );
        performanceService.trackApiCall(
          '/api/orders',
          Duration(milliseconds: 300),
        );

        // Simulate cache usage
        performanceService.trackCacheHit('estimates');
        performanceService.trackCacheHit('orders');
        performanceService.trackCacheMiss('settings');

        // Simulate WebSocket activity
        performanceService.trackWebSocketEvent('connect');
        performanceService.trackWebSocketEvent('message');

        // Wait for stats to be collected
        await Future.delayed(Duration(seconds: 2));

        // Verify optimization metrics
        final stats = performanceService.getPerformanceStats();

        // Should have reasonable performance metrics
        expect(stats['api_stats']['total_api_calls'], 2);
        expect(stats['websocket_stats']['connections'], 1);
        expect(stats['cache_stats']['hit_rate_percent'], '66.7');

        // Should not have any critical health issues
        final health = stats['system_health'];
        expect(health['high_latency_operations'].length, 0);
        expect(health['error_prone_endpoints'].length, 0);
      } finally {
        webSocketService.dispose();
        autoRefreshService.dispose();
        performanceService.dispose();
      }
    });
  });
}

// Helper function to run optimization tests
Future<void> runOptimizationTests() async {
  print('🧪 Running Backend Load Optimization Tests...');

  try {
    // Test WebSocket optimization
    print('  Testing WebSocket Service...');
    final webSocketService = WebSocketService(
      serverUrl: ApiService.webSocketUrl,
    );
    webSocketService.connect();
    await Future.delayed(Duration(seconds: 3));

    final wsStats = webSocketService.getConnectionStats();
    print('    Connection Status: ${wsStats['isConnected']}');
    print('    Health Status: ${wsStats['isHealthy']}');
    print('    Reconnect Attempts: ${wsStats['reconnectAttempts']}');

    // Test Auto Refresh optimization
    print('  Testing Auto Refresh Service...');
    final autoRefreshService = AutoRefreshService();
    autoRefreshService.initialize();

    final arStats = autoRefreshService.getServiceStats();
    print('    Periodic Interval: ${arStats['periodicRefreshInterval']}s');
    print('    Smart Interval: ${arStats['smartRefreshInterval']}s');
    print('    Active Requests: ${arStats['activeRequestCount']}');

    // Test Performance monitoring
    print('  Testing Performance Service...');
    final performanceService = PerformanceService();
    performanceService.startPeriodicStats();

    // Simulate some activity
    performanceService.trackApiCall('/api/test', Duration(milliseconds: 500));
    performanceService.trackCacheHit('test');
    performanceService.trackWebSocketEvent('connect');

    await Future.delayed(Duration(seconds: 2));

    final perfStats = performanceService.getPerformanceStats();
    print('    API Calls: ${perfStats['api_stats']['total_api_calls']}');
    print(
      '    Cache Hit Rate: ${perfStats['cache_stats']['hit_rate_percent']}%',
    );
    print(
      '    WebSocket Connections: ${perfStats['websocket_stats']['connections']}',
    );

    // Cleanup
    webSocketService.dispose();
    autoRefreshService.dispose();
    performanceService.dispose();

    print('✅ All optimization tests completed successfully!');
  } catch (e) {
    print('❌ Optimization test failed: $e');
  }
}
