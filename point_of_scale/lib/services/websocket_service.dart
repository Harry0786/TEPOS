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
  WebSocketChannel? _channel;
  StreamController<WebSocketMessage>? _messageController;
  StreamController<String>? _legacyMessageController;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  Timer? _debounceTimer;
  final String _serverUrl;

  // Debouncing configuration
  static const Duration _debounceDelay = Duration(milliseconds: 500);
  String? _lastMessage;
  DateTime? _lastMessageTime;

  WebSocketService({required String serverUrl}) : _serverUrl = serverUrl;

  bool get isConnected => _isConnected;

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
    if (_isConnected) return;

    try {
      print('🔌 Connecting to WebSocket: $_serverUrl');
      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          // Check if service is still active before handling message
          if (_isConnected && _messageController?.isClosed == false) {
            _handleMessage(message.toString());
          }
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          print('🔌 WebSocket connection closed');
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      print('✅ WebSocket connected successfully');
    } catch (e) {
      print('❌ Failed to connect to WebSocket: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _handleMessage(String message) {
    // Debounce messages to prevent spam
    if (_lastMessage == message &&
        _lastMessageTime != null &&
        DateTime.now().difference(_lastMessageTime!) < _debounceDelay) {
      print('🔄 Debouncing duplicate message: $message');
      return;
    }

    _lastMessage = message;
    _lastMessageTime = DateTime.now();

    print('📨 WebSocket message received: $message');

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
        } else {
          print(
            '⚠️ WebSocket controllers are closed, skipping message: $message',
          );
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

  void disconnect() {
    print('🔌 Disconnecting WebSocket');
    _isConnected = false; // Set this first to prevent new messages
    _reconnectTimer?.cancel();
    _debounceTimer?.cancel();
    _channel?.sink.close(status.goingAway);
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;

    print('🔄 Scheduling WebSocket reconnection in 5 seconds...');
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        print('🔄 Attempting to reconnect WebSocket...');
        connect();
      }
    });
  }

  void dispose() {
    print('🔌 Disposing WebSocket service');
    disconnect();

    // Cancel timers first
    _reconnectTimer?.cancel();
    _debounceTimer?.cancel();

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
  }
}
