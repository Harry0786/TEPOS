import 'dart:async';
import 'package:flutter/material.dart';
import 'lib/services/websocket_service.dart';
import 'lib/services/api_service.dart';

void main() {
  runApp(const StabilityTestApp());
}

class StabilityTestApp extends StatelessWidget {
  const StabilityTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TEPOS Stability Test',
      theme: ThemeData.dark(),
      home: const StabilityTestScreen(),
    );
  }
}

class StabilityTestScreen extends StatefulWidget {
  const StabilityTestScreen({super.key});

  @override
  State<StabilityTestScreen> createState() => _StabilityTestScreenState();
}

class _StabilityTestScreenState extends State<StabilityTestScreen> {
  late WebSocketService _webSocketService;
  List<String> _logs = [];
  bool _isConnected = false;
  int _messageCount = 0;
  Timer? _testTimer;

  @override
  void initState() {
    super.initState();
    _initializeTest();
  }

  void _initializeTest() {
    _addLog('🚀 Starting stability test...');

    try {
      _webSocketService = WebSocketService(serverUrl: ApiService.webSocketUrl);
      _webSocketService.connect();

      _webSocketService.messageStream.listen(
        (message) {
          _messageCount++;
          _addLog('📨 Message received: ${message.type} - ${message.action}');
        },
        onError: (error) {
          _addLog('❌ WebSocket error: $error');
        },
      );

      _webSocketService.legacyMessageStream.listen(
        (message) {
          _messageCount++;
          _addLog('📨 Legacy message: $message');
        },
        onError: (error) {
          _addLog('❌ Legacy stream error: $error');
        },
      );

      // Test connection health
      _testTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        final stats = _webSocketService.getConnectionStats();
        _isConnected = stats['isConnected'] ?? false;

        _addLog(
          '🔍 Connection stats: ${stats['isConnected']} - Healthy: ${stats['isHealthy']}',
        );

        if (!_isConnected) {
          _addLog('🔄 Attempting to reconnect...');
          _webSocketService.connect();
        }
      });

      _addLog('✅ WebSocket service initialized');
    } catch (e) {
      _addLog('❌ Error initializing WebSocket: $e');
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
      if (_logs.length > 50) {
        _logs.removeAt(0);
      }
    });
  }

  @override
  void dispose() {
    _testTimer?.cancel();
    _webSocketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TEPOS Stability Test'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      backgroundColor: const Color(0xFF0A0A0A),
      body: Column(
        children: [
          // Status indicators
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'Connected' : 'Disconnected',
                  style: const TextStyle(color: Colors.white),
                ),
                const Spacer(),
                Text(
                  'Messages: $_messageCount',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),

          // Logs
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      log,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Control buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _addLog('🔄 Manual reconnect triggered');
                      _webSocketService.connect();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B8E7F),
                    ),
                    child: const Text('Reconnect'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _logs.clear();
                        _messageCount = 0;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Clear Logs'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
