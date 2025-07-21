import 'dart:async';
import 'package:flutter/material.dart';
import 'lib/services/api_service.dart';

void main() {
  runApp(const DeleteTestApp());
}

class DeleteTestApp extends StatelessWidget {
  const DeleteTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delete Order Test',
      theme: ThemeData.dark(),
      home: const DeleteTestScreen(),
    );
  }
}

class DeleteTestScreen extends StatefulWidget {
  const DeleteTestScreen({super.key});

  @override
  State<DeleteTestScreen> createState() => _DeleteTestScreenState();
}

class _DeleteTestScreenState extends State<DeleteTestScreen> {
  List<String> _logs = [];
  bool _isDeleting = false;
  String _testOrderId = '';

  @override
  void initState() {
    super.initState();
    _addLog('🚀 Delete Order Test Started');
    _addLog('🌐 API Base URL: ${ApiService.baseUrl}');
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
      if (_logs.length > 50) {
        _logs.removeAt(0);
      }
    });
  }

  Future<void> _testDeleteOrder() async {
    if (_testOrderId.isEmpty) {
      _addLog('❌ Please enter an order ID first');
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    _addLog('🗑️ Testing delete order: $_testOrderId');

    try {
      final result = await ApiService.deleteOrder(
        orderId: _testOrderId,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          return {
            'success': false,
            'message': 'Request timeout - please try again',
          };
        },
      );

      _addLog('📡 Delete result: ${result['success']}');
      _addLog('📡 Message: ${result['message']}');

      if (result['success'] == true) {
        _addLog('✅ Delete successful!');
      } else {
        _addLog('❌ Delete failed: ${result['message']}');
      }
    } catch (e) {
      _addLog('❌ Error during delete: $e');
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Order Test'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      backgroundColor: const Color(0xFF0A0A0A),
      body: Column(
        children: [
          // Test controls
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    _testOrderId = value;
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter Order ID to test delete...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: const Color(0xFF1A1A1A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isDeleting ? null : _testDeleteOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child:
                      _isDeleting
                          ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Deleting...'),
                            ],
                          )
                          : const Text('Test Delete Order'),
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

          // Clear logs button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _logs.clear();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Clear Logs'),
            ),
          ),
        ],
      ),
    );
  }
}
