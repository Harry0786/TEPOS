import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<String>? _messageController;
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

  Stream<String> get messageStream {
    _messageController ??= StreamController<String>.broadcast();
    return _messageController!.stream;
  }

  void connect() {
    if (_isConnected) return;

    try {
      print('🔌 Connecting to WebSocket: $_serverUrl');
      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          _handleMessage(message.toString());
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
        _messageController?.add(message);
      } catch (e) {
        print('❌ Error emitting WebSocket message: $e');
      }
    });
  }

  void disconnect() {
    print('🔌 Disconnecting WebSocket');
    _reconnectTimer?.cancel();
    _debounceTimer?.cancel();
    _channel?.sink.close(status.goingAway);
    _isConnected = false;
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
    disconnect();
    _messageController?.close();
  }
}
