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

  // State
  bool _isInitialized = false;
  DateTime? _lastRefreshTime;
  bool _isRefreshing = false;

  // Callbacks
  final List<Function()> _refreshCallbacks = [];
  final List<Function()> _appResumeCallbacks = [];

  // Configuration
  static const Duration _periodicRefreshInterval = Duration(seconds: 30);
  static const Duration _appResumeRefreshDelay = Duration(seconds: 2);
  static const Duration _minRefreshInterval = Duration(minutes: 1);

  /// Initialize the auto-refresh service
  void initialize() {
    if (_isInitialized) return;

    _isInitialized = true;
    _startPeriodicRefresh();
    print('🔄 AutoRefreshService initialized');
  }

  /// Dispose the service
  void dispose() {
    _periodicRefreshTimer?.cancel();
    _appResumeTimer?.cancel();
    _refreshCallbacks.clear();
    _appResumeCallbacks.clear();
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

  /// Force refresh all registered callbacks
  Future<void> forceRefresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _lastRefreshTime = DateTime.now();

    print('🔄 Force refreshing all data...');

    try {
      // Check server health first
      final isHealthy = await ApiService.checkServerHealth();
      if (!isHealthy) {
        print('⚠️ Server health check failed - skipping refresh');
        return;
      }

      // Execute all refresh callbacks
      for (final callback in _refreshCallbacks) {
        try {
          callback();
        } catch (e) {
          print('❌ Error in refresh callback: $e');
        }
      }

      print('✅ Force refresh completed');
    } catch (e) {
      print('❌ Error during force refresh: $e');
    } finally {
      _isRefreshing = false;
    }
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

  /// Start periodic refresh timer
  void _startPeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = Timer.periodic(_periodicRefreshInterval, (timer) {
      if (!_isRefreshing) {
        _executeRefreshCallbacks();
      }
    });
  }

  /// Execute refresh callbacks
  void _executeRefreshCallbacks() {
    if (_isRefreshing) return;

    // Check if enough time has passed since last refresh
    if (_lastRefreshTime != null &&
        DateTime.now().difference(_lastRefreshTime!) < _minRefreshInterval) {
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

  /// Handle app resumed event
  void _onAppResumed() {
    print('📱 App resumed - scheduling refresh...');

    // Cancel any existing resume timer
    _appResumeTimer?.cancel();

    // Schedule refresh after a short delay
    _appResumeTimer = Timer(_appResumeRefreshDelay, () {
      // Execute app resume callbacks
      for (final callback in _appResumeCallbacks) {
        try {
          callback();
        } catch (e) {
          print('❌ Error in app resume callback: $e');
        }
      }

      // Check if we need to refresh data
      if (_lastRefreshTime == null ||
          DateTime.now().difference(_lastRefreshTime!) >= _minRefreshInterval) {
        _executeRefreshCallbacks();
      }
    });
  }

  /// Handle app paused event
  void _onAppPaused() {
    print('📱 App paused');
    // Optionally pause periodic refresh to save resources
    // _periodicRefreshTimer?.cancel();
  }

  /// Handle app inactive event
  void _onAppInactive() {
    print('📱 App inactive');
  }

  /// Handle app detached event
  void _onAppDetached() {
    print('📱 App detached');
    _periodicRefreshTimer?.cancel();
  }

  /// Handle app hidden event
  void _onAppHidden() {
    print('📱 App hidden');
  }

  /// Get current refresh status
  bool get isRefreshing => _isRefreshing;

  /// Get last refresh time
  DateTime? get lastRefreshTime => _lastRefreshTime;

  /// Get number of registered callbacks
  int get refreshCallbackCount => _refreshCallbacks.length;
  int get appResumeCallbackCount => _appResumeCallbacks.length;
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
}
