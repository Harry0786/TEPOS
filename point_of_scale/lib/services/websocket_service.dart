import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

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
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService({required String serverUrl}) {
    _instance._serverUrl = serverUrl;
    return _instance;
  }
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamController<WebSocketMessage>? _messageController;
  StreamController<String>? _legacyMessageController;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _debounceTimer;
  String _serverUrl = '';

  // Connection management
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10; // Increased from 5
  static const Duration _initialReconnectDelay = Duration(
    seconds: 1,
  ); // Reduced from 2
  static const Duration _maxReconnectDelay = Duration(seconds: 30);
  static const Duration _heartbeatInterval = Duration(
    seconds: 15,
  ); // Reduced from 30

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

  void connect() {
    if (_isConnected && _isHealthy) {
      print('🔌 WebSocket already connected and healthy');
      return;
    }

    try {
      print('🔌 Connecting to WebSocket: $_serverUrl');

      // Close existing connection if any
      _channel?.sink.close();
      _channel = null;

      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
      _isConnected = true;
      _lastConnectionTime = DateTime.now();

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

      print('✅ WebSocket connected successfully');
    } catch (e) {
      print('❌ Failed to connect to WebSocket: $e');
      _handleConnectionFailure();
    }
  }

  void _handleMessage(String message) {
    // Reset health indicators on successful message
    _isHealthy = true;
    _consecutiveFailures = 0;

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
    _isConnected = false;
    _isHealthy = false;
    _consecutiveFailures++;

    print('🔌 Connection failure #$_consecutiveFailures');

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

    // Exponential backoff with jitter
    final delay = Duration(
      milliseconds: (_initialReconnectDelay.inMilliseconds *
              (1 << _reconnectAttempts))
          .clamp(1, _maxReconnectDelay.inMilliseconds),
    );

    // Add jitter to prevent thundering herd
    final jitter = Duration(milliseconds: (DateTime.now().millisecond % 500));
    final totalDelay = delay + jitter;

    print(
      '🔄 Scheduling WebSocket reconnection in ${totalDelay.inSeconds} seconds... (attempt ${_reconnectAttempts + 1})',
    );

    _reconnectTimer = Timer(totalDelay, () {
      if (!_isConnected) {
        _reconnectAttempts++;
        if (_reconnectAttempts <= _maxReconnectAttempts) {
          print(
            '🔄 Attempting to reconnect WebSocket... (attempt $_reconnectAttempts)',
          );
          connect();
        } else {
          print('⚠️ Max reconnection attempts reached, giving up');
          _resetConnectionState();
        }
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
    } catch (e) {
      print('⚠️ Error closing WebSocket controllers: $e');
    }

    // Clear references
    _messageController = null;
    _legacyMessageController = null;
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
