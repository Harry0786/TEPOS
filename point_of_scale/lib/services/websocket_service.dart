import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<String>? _messageController;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  final String _serverUrl;

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
          print('📨 WebSocket message received: $message');
          _messageController?.add(message.toString());
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

  void disconnect() {
    print('🔌 Disconnecting WebSocket');
    _reconnectTimer?.cancel();
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
