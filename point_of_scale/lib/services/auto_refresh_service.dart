import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'api_service.dart';

class AutoRefreshService extends ChangeNotifier {
  static final AutoRefreshService _instance = AutoRefreshService._internal();
  factory AutoRefreshService() => _instance;
  AutoRefreshService._internal();

  // Timers
  Timer? _periodicRefreshTimer;
  Timer? _appResumeTimer;
  Timer? _smartRefreshTimer;

  // State
  bool _isInitialized = false;
  DateTime? _lastRefreshTime;
  bool _isRefreshing = false;
  bool _isAppActive = true;

  // Callbacks
  final List<Function()> _refreshCallbacks = [];
  final List<Function()> _appResumeCallbacks = [];

  // Configuration - Optimized for reduced backend load
  static const Duration _periodicRefreshInterval = Duration(
    minutes: 2,
  ); // Increased from 30s
  static const Duration _appResumeRefreshDelay = Duration(
    seconds: 3,
  ); // Increased from 2s
  static const Duration _minRefreshInterval = Duration(
    minutes: 3,
  ); // Increased from 1m
  static const Duration _smartRefreshInterval = Duration(
    minutes: 5,
  ); // New smart refresh

  // Request deduplication
  final Set<String> _activeRefreshRequests = {};
  static const Duration _requestTimeout = Duration(seconds: 45);

  /// Initialize the auto-refresh service
  void initialize() {
    if (_isInitialized) return;

    _isInitialized = true;
    _startPeriodicRefresh();
    _startSmartRefresh();
    print('🔄 AutoRefreshService initialized with optimized intervals');
  }

  /// Dispose the service
  void dispose() {
    _periodicRefreshTimer?.cancel();
    _appResumeTimer?.cancel();
    _smartRefreshTimer?.cancel();
    _refreshCallbacks.clear();
    _appResumeCallbacks.clear();
    _activeRefreshRequests.clear();
    _isInitialized = false;
    print('🔄 AutoRefreshService disposed');
  }

  /// Add a callback to be executed when data should be refreshed
  void addRefreshCallback(Function() callback) {
    if (!_refreshCallbacks.contains(callback)) {
      _refreshCallbacks.add(callback);
    }
  }

  /// Remove a refresh callback
  void removeRefreshCallback(Function() callback) {
    _refreshCallbacks.remove(callback);
  }

  /// Add a callback to be executed when app resumes
  void addAppResumeCallback(Function() callback) {
    if (!_appResumeCallbacks.contains(callback)) {
      _appResumeCallbacks.add(callback);
    }
  }

  /// Remove an app resume callback
  void removeAppResumeCallback(Function() callback) {
    _appResumeCallbacks.remove(callback);
  }

  /// Force refresh all registered callbacks with deduplication
  Future<void> forceRefresh() async {
    if (_isRefreshing) {
      print('⚠️ Refresh already in progress, skipping duplicate request');
      return;
    }

    final requestId = 'force_refresh_${DateTime.now().millisecondsSinceEpoch}';
    if (_activeRefreshRequests.contains(requestId)) {
      print('⚠️ Duplicate force refresh request detected, skipping');
      return;
    }

    _activeRefreshRequests.add(requestId);

    try {
      await _executeRefreshWithTimeout(requestId);
    } finally {
      _activeRefreshRequests.remove(requestId);
    }
  }

  /// Execute refresh with timeout and error handling
  Future<void> _executeRefreshWithTimeout(String requestId) async {
    _isRefreshing = true;
    _lastRefreshTime = DateTime.now();

    print('🔄 Force refreshing all data... (Request: $requestId)');

    try {
      // Check server health first with shorter timeout
      final isHealthy = await ApiService.checkServerHealth().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⚠️ Server health check timeout - skipping refresh');
          return false;
        },
      );

      if (!isHealthy) {
        print('⚠️ Server health check failed - skipping refresh');
        return;
      }

      // Execute all refresh callbacks with timeout
      await Future.wait(
        _refreshCallbacks.map((callback) => _executeCallbackSafely(callback)),
      ).timeout(
        _requestTimeout,
        onTimeout: () {
          print('⚠️ Refresh timeout - some callbacks may not have completed');
          return <void>[];
        },
      );

      print('✅ Force refresh completed successfully');
    } catch (e) {
      print('❌ Error during force refresh: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  /// Execute a single callback safely
  Future<void> _executeCallbackSafely(Function() callback) async {
    try {
      callback();
    } catch (e) {
      print('❌ Error in refresh callback: $e');
    }
    return;
  }

  /// Handle app lifecycle changes
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.inactive:
        _onAppInactive();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.hidden:
        _onAppHidden();
        break;
    }
  }

  /// Start periodic refresh timer with optimized interval
  void _startPeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = Timer.periodic(_periodicRefreshInterval, (timer) {
      if (!_isRefreshing && _isAppActive) {
        _executeRefreshCallbacks();
      }
    });
  }

  /// Start smart refresh timer for background optimization
  void _startSmartRefresh() {
    _smartRefreshTimer?.cancel();
    _smartRefreshTimer = Timer.periodic(_smartRefreshInterval, (timer) {
      if (!_isRefreshing && _isAppActive) {
        _executeSmartRefresh();
      }
    });
  }

  /// Execute refresh callbacks with smart logic
  void _executeRefreshCallbacks() {
    if (_isRefreshing) return;

    // Check if enough time has passed since last refresh
    if (_lastRefreshTime != null &&
        DateTime.now().difference(_lastRefreshTime!) < _minRefreshInterval) {
      print('⏰ Skipping refresh - too soon since last refresh');
      return;
    }

    _isRefreshing = true;
    _lastRefreshTime = DateTime.now();

    print('🔄 Auto-refreshing data...');

    for (final callback in _refreshCallbacks) {
      try {
        callback();
      } catch (e) {
        print('❌ Error in auto-refresh callback: $e');
      }
    }

    _isRefreshing = false;
  }

  /// Execute smart refresh with conditional logic
  void _executeSmartRefresh() {
    if (_isRefreshing) return;

    // Only refresh if app has been active for a while
    if (_lastRefreshTime != null &&
        DateTime.now().difference(_lastRefreshTime!) < _minRefreshInterval) {
      return;
    }

    print('🧠 Smart refresh triggered...');
    _executeRefreshCallbacks();
  }

  /// Handle app resumed event with optimized logic
  void _onAppResumed() {
    print('📱 App resumed - scheduling optimized refresh...');
    _isAppActive = true;

    // Cancel any existing resume timer
    _appResumeTimer?.cancel();

    // Schedule refresh after a longer delay to reduce immediate load
    _appResumeTimer = Timer(_appResumeRefreshDelay, () {
      // Execute app resume callbacks
      for (final callback in _appResumeCallbacks) {
        try {
          callback();
        } catch (e) {
          print('❌ Error in app resume callback: $e');
        }
      }

      // Check if we need to refresh data with longer interval
      if (_lastRefreshTime == null ||
          DateTime.now().difference(_lastRefreshTime!) >= _minRefreshInterval) {
        _executeRefreshCallbacks();
      } else {
        print('⏰ Skipping refresh on app resume - too soon since last refresh');
      }
    });
  }

  /// Handle app paused event
  void _onAppPaused() {
    print('📱 App paused - reducing refresh activity');
    _isAppActive = false;
    // Keep timers running but reduce activity
  }

  /// Handle app inactive event
  void _onAppInactive() {
    print('📱 App inactive');
    _isAppActive = false;
  }

  /// Handle app detached event
  void _onAppDetached() {
    print('📱 App detached - stopping refresh timers');
    _isAppActive = false;
    _periodicRefreshTimer?.cancel();
    _smartRefreshTimer?.cancel();
  }

  /// Handle app hidden event
  void _onAppHidden() {
    print('📱 App hidden - reducing refresh activity');
    _isAppActive = false;
  }

  /// Get current refresh status
  bool get isRefreshing => _isRefreshing;
  bool get isAppActive => _isAppActive;

  /// Get last refresh time
  DateTime? get lastRefreshTime => _lastRefreshTime;

  /// Get number of registered callbacks
  int get refreshCallbackCount => _refreshCallbacks.length;
  int get appResumeCallbackCount => _appResumeCallbacks.length;

  /// Get active request count
  int get activeRequestCount => _activeRefreshRequests.length;

  /// Get service statistics
  Map<String, dynamic> getServiceStats() {
    return {
      'isInitialized': _isInitialized,
      'isRefreshing': _isRefreshing,
      'isAppActive': _isAppActive,
      'lastRefreshTime': _lastRefreshTime?.toIso8601String(),
      'refreshCallbackCount': refreshCallbackCount,
      'appResumeCallbackCount': appResumeCallbackCount,
      'activeRequestCount': activeRequestCount,
      'periodicRefreshInterval': _periodicRefreshInterval.inSeconds,
      'smartRefreshInterval': _smartRefreshInterval.inSeconds,
    };
  }
}

/// Mixin to easily add auto-refresh functionality to any widget
mixin AutoRefreshMixin<T extends StatefulWidget> on State<T> {
  late AutoRefreshService _autoRefreshService;

  @override
  void initState() {
    super.initState();
    _autoRefreshService = AutoRefreshService();
    _autoRefreshService.initialize();
    _autoRefreshService.addRefreshCallback(_onRefresh);
    _autoRefreshService.addAppResumeCallback(_onAppResume);
  }

  @override
  void dispose() {
    _autoRefreshService.removeRefreshCallback(_onRefresh);
    _autoRefreshService.removeAppResumeCallback(_onAppResume);
    super.dispose();
  }

  /// Override this method to define what happens when data should be refreshed
  void _onRefresh() {
    // Default implementation - override in subclasses
    print('🔄 Auto-refresh triggered for ${widget.runtimeType}');
  }

  /// Override this method to define what happens when app resumes
  void _onAppResume() {
    // Default implementation - override in subclasses
    print('📱 App resume triggered for ${widget.runtimeType}');
  }

  /// Force refresh data
  Future<void> forceRefresh() async {
    await _autoRefreshService.forceRefresh();
  }

  /// Get refresh status
  bool get isRefreshing => _autoRefreshService.isRefreshing;
  DateTime? get lastRefreshTime => _autoRefreshService.lastRefreshTime;
  bool get isAppActive => _autoRefreshService.isAppActive;
}
