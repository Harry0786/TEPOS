import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

// Structured WebSocket message types
class WebSocketMessage {
  final String type;
  final String action;
  final String id;
  final Map<String, dynamic>? data;
  final String? orderId;
  final String? orderNumber;

  WebSocketMessage({
    required this.type,
    required this.action,
    required this.id,
    this.data,
    this.orderId,
    this.orderNumber,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] ?? '',
      action: json['action'] ?? '',
      id: json['id'] ?? '',
      data: json['data'],
      orderId: json['order_id'],
      orderNumber: json['order_number'],
    );
  }

  factory WebSocketMessage.fromString(String message) {
    try {
      final json = jsonDecode(message);
      return WebSocketMessage.fromJson(json);
    } catch (e) {
      // Fallback for legacy string messages
      return WebSocketMessage(type: 'legacy', action: message, id: '');
    }
  }

  bool get isLegacy => type == 'legacy';
  bool get isEstimate => type == 'estimate';
  bool get isOrder => type == 'order';
  bool get isCreate => action == 'create';
  bool get isUpdate => action == 'update';
  bool get isDelete => action == 'delete';
  bool get isConvertToOrder => action == 'convert_to_order';
}

class WebSocketService {
  static WebSocketService? _instance;
  static WebSocketService get instance {
    _instance ??= WebSocketService._internal();
    return _instance!;
  }
  
  WebSocketService._internal();
  
  // Factory constructor for backward compatibility
  factory WebSocketService({required String serverUrl}) {
    _serverUrl = serverUrl;
    return instance;
  }
  
  static String _serverUrl = '';
  WebSocketChannel? _channel;
  StreamController<WebSocketMessage>? _messageController;
  StreamController<String>? _legacyMessageController;
  StreamController<bool>? _connectionStatusController;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _debounceTimer;

  // Connection management
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5; // Reduced for better stability
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  // Performance optimization
  static const Duration _debounceDelay = Duration(milliseconds: 300);
  String? _lastMessage;
  DateTime? _lastMessageTime;
  DateTime? _lastConnectionTime;

  // Connection health monitoring
  bool _isHealthy = false;
  int _consecutiveFailures = 0;
  static const int _maxConsecutiveFailures = 5; // Increased from 3

  bool get isConnected => _isConnected && _isHealthy;
  bool get isHealthy => _isHealthy;
  DateTime? get lastConnectionTime => _lastConnectionTime;
  
  // Last time connection status was checked and logged
  DateTime? _lastStatusCheckTime;
  static const Duration _statusCheckThrottle = Duration(seconds: 10);

  // Method to manually check and update connection status (with reduced logging)
  void checkConnectionStatus() {
    final previousStatus = isConnected;
    final now = DateTime.now();
    final shouldLog = _lastStatusCheckTime == null || 
        now.difference(_lastStatusCheckTime!) > _statusCheckThrottle;
    
    // Check if channel is actually open
    if (_channel == null) {
      _isConnected = false;
      _isHealthy = false;
      if (shouldLog) {
        print('🔌 Connection check: No channel exists');
      }
    } else {
      try {
        // Try sending a ping to check connection
        _channel!.sink.add('ping');
        // If we get here without error, connection is likely ok
        _isConnected = true;
        _isHealthy = true;
        if (shouldLog) {
          // Only log at reduced frequency or if status changed
          print('🔌 Connection check: Channel is active');
        }
      } catch (e) {
        if (shouldLog) {
          print('❌ Connection check failed: $e');
        }
        _isConnected = false;
        _isHealthy = false;
      }
    }
    
    if (previousStatus != isConnected) {
      // Always log status changes
      print('🔌 Connection status changed to: ${isConnected ? 'Connected' : 'Disconnected'}');
      _lastStatusCheckTime = now; // Update timestamp on status change
      
      // If status changed from connected to disconnected, try to reconnect
      if (!isConnected) {
        // Attempt to reconnect
        _reconnectAttempts = 0; // Reset attempts
        connect();
      }
    } else if (shouldLog) {
      // Update timestamp if we logged
      _lastStatusCheckTime = now;
    }
  }

  // Stream for structured messages
  Stream<WebSocketMessage> get messageStream {
    _messageController ??= StreamController<WebSocketMessage>.broadcast();
    return _messageController!.stream;
  }

  // Stream for legacy string messages (backward compatibility)
  Stream<String> get legacyMessageStream {
    _legacyMessageController ??= StreamController<String>.broadcast();
    return _legacyMessageController!.stream;
  }

  // Stream for connection status updates
  Stream<bool> get connectionStream {
    _connectionStatusController ??= StreamController<bool>.broadcast();
    return _connectionStatusController!.stream;
  }

  // Helper method to update connection status and notify listeners
  void _updateConnectionStatus(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      _connectionStatusController?.add(connected);
      print('🔌 Connection status changed: ${connected ? "Connected" : "Disconnected"}');
    }
  }

  void connect() {
    // Throttle connection attempts by checking last attempt time
    final now = DateTime.now();
    final shouldLog = _lastConnectionTime == null || 
        now.difference(_lastConnectionTime!) > _statusCheckThrottle;
        
    if (_isConnected && _isHealthy) {
      if (shouldLog) {
        print('🔌 WebSocket already connected and healthy');
      }
      return;
    }

    try {
      if (shouldLog) {
        print('🔌 Connecting to WebSocket: $_serverUrl');
      }

      // Close existing connection if any
      _channel?.sink.close();
      _channel = null;

      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
      _isConnected = true;
      _lastConnectionTime = now;

      // Listen to the stream with error handling
      _channel!.stream.listen(
        (message) {
          // Reset failure counters on successful message
          _consecutiveFailures = 0;
          _reconnectAttempts = 0;
          _isHealthy = true;

          // Check if service is still active before handling message
          if (_isConnected && _messageController?.isClosed == false) {
            _handleMessage(message.toString());
          }
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          _handleConnectionFailure();
        },
        onDone: () {
          print('🔌 WebSocket connection closed');
          _handleConnectionFailure();
        },
        cancelOnError:
            false, // Don't cancel on error, let us handle reconnection
      );

      // Start heartbeat to monitor connection health
      _startHeartbeat();

      // Force an initial health check
      _updateConnectionStatus(true);
      _isHealthy = true;

      print('✅ WebSocket connected successfully');
    } catch (e) {
      print('❌ Failed to connect to WebSocket: $e');
      _updateConnectionStatus(false);
      _isHealthy = false;
      _handleConnectionFailure();
    }
  }

  void _handleMessage(String message) {
    // Reset health indicators on successful message
    _isHealthy = true;
    _consecutiveFailures = 0;

    // For ping messages, skip verbose processing
    if (message == 'pong' || message == 'ping') {
      return;
    }

    // Debounce messages to prevent spam
    if (_lastMessage == message &&
        _lastMessageTime != null &&
        DateTime.now().difference(_lastMessageTime!) < _debounceDelay) {
      return;
    }

    _lastMessage = message;
    _lastMessageTime = DateTime.now();

    // Cancel any existing debounce timer
    _debounceTimer?.cancel();

    // Debounce the message emission
    _debounceTimer = Timer(_debounceDelay, () {
      try {
        // Check if controllers are still active before adding events
        if (_messageController?.isClosed == false &&
            _legacyMessageController?.isClosed == false) {
          // Try to parse as structured message
          final wsMessage = WebSocketMessage.fromString(message);

          if (wsMessage.isLegacy) {
            // Handle legacy string messages
            _legacyMessageController?.add(message);
          } else {
            // Handle structured messages
            _messageController?.add(wsMessage);
          }
        }
      } catch (e) {
        print('❌ Error parsing WebSocket message: $e');
        // Fallback to legacy handling only if controller is still active
        if (_legacyMessageController?.isClosed == false) {
          _legacyMessageController?.add(message);
        }
      }
    });
  }

  void _handleConnectionFailure() {
    _updateConnectionStatus(false);
    _isHealthy = false;
    _consecutiveFailures++;

    // Log only on first failure or every third failure to reduce spam
    if (_consecutiveFailures == 1 || _consecutiveFailures % 3 == 0) {
      print('🔌 Connection failure #$_consecutiveFailures');
    }

    // Close the existing channel
    _channel?.sink.close();
    _channel = null;

    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      print('⚠️ Too many consecutive failures, resetting connection state');
      _resetConnectionState();
      return;
    }

    _scheduleReconnect();
  }

  void _resetConnectionState() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _isHealthy = false;
    _consecutiveFailures = 0;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _debounceTimer?.cancel();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_isConnected && _channel != null) {
        try {
          // Send a ping to check connection health
          _channel!.sink.add('ping');
          // Only log heartbeat failures, not successful pings
        } catch (e) {
          print('❌ Heartbeat failed: $e');
          _handleConnectionFailure();
        }
      }
    });
  }

  void disconnect() {
    print('🔌 Disconnecting WebSocket');
    _resetConnectionState();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('❌ Max reconnection attempts reached');
      return;
    }

    _reconnectAttempts++;
    final delay = _reconnectDelay * _reconnectAttempts;

    print('🔄 Scheduling WebSocket reconnection in ${delay.inSeconds} seconds... (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(delay, () {
      if (!_isConnected && !_isConnecting) {
        connect();
      }
    });
  }

  void dispose() {
    print('🔌 Disposing WebSocket service');

    // Cancel all timers first
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _debounceTimer?.cancel();

    // Close the WebSocket connection
    try {
      _channel?.sink.close();
    } catch (e) {
      print('⚠️ Error closing WebSocket channel: $e');
    }

    // Reset connection state
    _resetConnectionState();

    // Close controllers safely
    try {
      if (_messageController?.isClosed == false) {
        _messageController?.close();
      }
      if (_legacyMessageController?.isClosed == false) {
        _legacyMessageController?.close();
      }
      if (_connectionStatusController?.isClosed == false) {
        _connectionStatusController?.close();
      }
    } catch (e) {
      print('⚠️ Error closing WebSocket controllers: $e');
    }

    // Clear references
    _messageController = null;
    _legacyMessageController = null;
    _connectionStatusController = null;
    _channel = null;

    print('✅ WebSocket service disposed successfully');
  }

  // Get connection statistics
  Map<String, dynamic> getConnectionStats() {
    return {
      'isConnected': _isConnected,
      'isHealthy': _isHealthy,
      'reconnectAttempts': _reconnectAttempts,
      'consecutiveFailures': _consecutiveFailures,
      'lastConnectionTime': _lastConnectionTime?.toIso8601String(),
      'lastMessageTime': _lastMessageTime?.toIso8601String(),
      'serverUrl': _serverUrl,
    };
  }
}
