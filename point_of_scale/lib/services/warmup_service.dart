import 'dart:async';
import 'package:point_of_scale/services/api_service.dart';

/// Service to keep the backend warm and prevent cold starts on Render.com
class WarmupService {
  static Timer? _warmupTimer;
  static bool _isWarming = false;
  static bool _isEnabled = true;
  
  /// Start the warmup service to prevent backend cold starts
  static void startWarmup() {
    if (_warmupTimer != null || !_isEnabled) return;
    
    print('🔥 Starting backend warmup service');
    
    // Initial warmup after a short delay
    Timer(Duration(seconds: 5), () {
      _performWarmup();
    });
    
    // Schedule periodic warmups every 8 minutes to prevent Render free tier cold starts
    _warmupTimer = Timer.periodic(Duration(minutes: 8), (timer) {
      _performWarmup();
    });
  }
  
  /// Stop the warmup service
  static void stopWarmup() {
    _warmupTimer?.cancel();
    _warmupTimer = null;
    print('🔥 Warmup service stopped');
  }
  
  /// Enable or disable the warmup service
  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      stopWarmup();
    } else if (_warmupTimer == null) {
      startWarmup();
    }
  }
  
  /// Perform a single warmup ping to the backend
  static Future<void> _performWarmup() async {
    if (_isWarming || !_isEnabled) return;
    _isWarming = true;
    
    try {
      print('🔥 Performing backend warmup ping...');
      
      // Simple health check to keep backend warm
      final isHealthy = await ApiService.checkServerHealth().timeout(
        Duration(seconds: 15),
        onTimeout: () {
          print('🔥 Warmup ping timeout');
          return false;
        },
      );
      
      if (isHealthy) {
        print('🔥 Warmup ping successful - backend is warm');
      } else {
        print('🔥 Warmup ping failed - backend may be cold starting');
      }
    } catch (e) {
      // Don't log every failure as errors to avoid spam
      if (e.toString().contains('Connection reset') || 
          e.toString().contains('SocketException')) {
        print('🔥 Warmup ping network issue (expected during cold start)');
      } else {
        print('🔥 Warmup ping failed: $e');
      }
    } finally {
      _isWarming = false;
    }
  }
  
  /// Force an immediate warmup ping
  static Future<bool> performImmediateWarmup() async {
    if (_isWarming) {
      print('🔥 Warmup already in progress');
      return false;
    }
    
    try {
      await _performWarmup();
      return true;
    } catch (e) {
      print('🔥 Immediate warmup failed: $e');
      return false;
    }
  }
  
  /// Get warmup service status
  static Map<String, dynamic> getStatus() {
    return {
      'isEnabled': _isEnabled,
      'isRunning': _warmupTimer?.isActive ?? false,
      'isWarming': _isWarming,
      'nextWarmupIn': _warmupTimer?.isActive == true 
          ? '${(Duration(minutes: 8).inSeconds)} seconds (estimated)'
          : 'Not scheduled',
    };
  }
}
