import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'package:intl/intl.dart';
import 'estimate_preview_screen.dart';

class ViewEstimatesScreen extends StatefulWidget {
  const ViewEstimatesScreen({super.key});

  @override
  State<ViewEstimatesScreen> createState() => _ViewEstimatesScreenState();
}

class _ViewEstimatesScreenState extends State<ViewEstimatesScreen> {
  List<Map<String, dynamic>> _estimates = [];
  List<Map<String, dynamic>> _filteredEstimates = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _errorMessage;
  late WebSocketService _webSocketService;

  // Dialog state management
  Timer? _conversionTimeoutTimer;

  @override
  void initState() {
    super.initState();
    
    // Use singleton instance instead of creating new instances
    _webSocketService = WebSocketService.instance;
    
    // Initialize with server URL
    WebSocketService(serverUrl: ApiService.webSocketUrl);
    
    _webSocketService.connect();

    // Handle structured WebSocket messages for efficient updates
    _webSocketService.messageStream.listen((message) {
      if (mounted) {
        _handleWebSocketMessage(message);
      }
    });

    // Handle legacy messages for backward compatibility
    _webSocketService.legacyMessageStream.listen((message) {
      if (message == 'estimate_updated' ||
          message == 'order_updated' ||
          message == 'sale_completed' ||
          message == 'estimate_created' ||
          message == 'estimate_deleted' ||
          message == 'estimate_converted_to_order') {
        if (mounted) {
          print(
            '🔄 Legacy WebSocket message received: $message - refreshing estimates...',
          );
          ApiService.clearCache();
          _fetchEstimates();
        }
      }
    });

    _fetchEstimates();
  }

  void _handleWebSocketMessage(WebSocketMessage message) {
    print(
      '📨 Handling WebSocket message: ${message.type} - ${message.action} - ${message.id}',
    );

    if (message.isEstimate) {
      switch (message.action) {
        case 'create':
          _handleEstimateCreated(message);
          break;
        case 'delete':
          _handleEstimateDeleted(message);
          break;
        case 'convert_to_order':
          _handleEstimateConvertedToOrder(message);
          break;
        default:
          // Unknown action, do full refresh
          print(
            '⚠️ Unknown estimate action: ${message.action} - doing full refresh',
          );
          ApiService.clearCache();
          _fetchEstimates();
      }
    } else if (message.isOrder) {
      // Order changes might affect estimates (e.g., if order was created from estimate)
      print('🔄 Order change detected - refreshing estimates...');
      ApiService.clearCache();
      _fetchEstimates();
    } else {
      // Unknown message type, do full refresh
      print('⚠️ Unknown message type: ${message.type} - doing full refresh');
      ApiService.clearCache();
      _fetchEstimates();
    }
  }

  void _handleEstimateCreated(WebSocketMessage message) {
    print('➕ Handling estimate created: ${message.id}');
    if (!mounted) return;
    
    if (message.data != null) {
      // Add the new estimate to the list
      final newEstimate = {
        'id': message.id,
        'estimate_id': message.data!['estimate_id'],
        'estimate_number': message.data!['estimate_number'],
        'customer_name': message.data!['customer_name'],
        'total': message.data!['total'],
        'created_at': message.data!['created_at'],
        'is_converted_to_order': false,
        // Add other required fields with defaults
        'customer_phone': '',
        'customer_address': '',
        'sale_by': '',
        'items': [],
        'subtotal': 0.0,
        'discount_amount': 0.0,
        'is_percentage_discount': false,
        'status': 'Pending',
      };

      if (mounted) {
        setState(() {
          _estimates.insert(0, newEstimate);
          _filteredEstimates = _applyFilter(_estimates);
        });
      }

      print('✅ Estimate added to list: ${message.data!['estimate_number']}');
    } else {
      // No data provided, do full refresh
      print('⚠️ No data in create message - doing full refresh');
      ApiService.clearCache();
      if (mounted) {
        _fetchEstimates();
      }
    }
  }

  void _handleEstimateDeleted(WebSocketMessage message) {
    print('🗑️ Handling estimate deleted: ${message.id}');
    if (!mounted) return;

    setState(() {
      _estimates.removeWhere(
        (estimate) =>
            estimate['estimate_id'] == message.id ||
            estimate['id'] == message.id,
      );
      _filteredEstimates = _applyFilter(_estimates);
    });

    print('✅ Estimate removed from list: ${message.id}');
  }

  void _handleEstimateConvertedToOrder(WebSocketMessage message) {
    print('🔄 Handling estimate converted to order: ${message.id}');
    if (!mounted) return;

    // Remove the estimate from the list since it's now an order
    setState(() {
      _estimates.removeWhere(
        (estimate) =>
            estimate['estimate_id'] == message.id ||
            estimate['id'] == message.id,
      );
      _filteredEstimates = _applyFilter(_estimates);
    });

    print('✅ Estimate converted to order and removed from list: ${message.id}');

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estimate converted to order successfully!'),
          backgroundColor: const Color(0xFF6B8E7F),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _fetchEstimates() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final estimates = await ApiService.fetchEstimates(forceClearCache: true);
      if (mounted) {
        setState(() {
          _estimates = estimates;
          _filteredEstimates = _applyFilter(estimates);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load estimates. Please try again.';
        });
      }
    }
  }

  List<Map<String, dynamic>> _applyFilter(
    List<Map<String, dynamic>> estimates,
  ) {
    return estimates.where((estimate) {
      final matchesSearch =
          (estimate['customer_name'] ?? '').toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (estimate['estimate_number'] ?? '').toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      return matchesSearch;
    }).toList();
  }

  void _onSearchChanged(String value) {
    if (!mounted) return;
    
    setState(() {
      _searchQuery = value;
      _filteredEstimates = _applyFilter(_estimates);
    });
  }

  @override
  void dispose() {
    _conversionTimeoutTimer?.cancel();
    // Don't dispose WebSocket singleton - let app lifecycle manage it
    print('📱 WebSocket singleton preserved for app lifecycle management');
    super.dispose();
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Accepted':
        return const Color(0xFF4CAF50);
      case 'Rejected':
        return Colors.red;
      case 'Pending':
        return const Color(0xFFFF9800);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'View Estimates',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              border: Border(bottom: BorderSide(color: Color(0xFF3A3A3A))),
            ),
            child: Column(
              children: [
                TextField(
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search estimates...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF0D0D0D),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF6B8E7F)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Removed filter options
              ],
            ),
          ),
          // Estimates List
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF6B8E7F),
                        ),
                      ),
                    )
                    : _errorMessage != null
                    ? Center(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                    : RefreshIndicator(
                      color: const Color(0xFF6B8E7F),
                      backgroundColor: const Color(0xFF1A1A1A),
                      onRefresh: _fetchEstimates,
                      child:
                          _filteredEstimates.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      size: 64,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No estimates found',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredEstimates.length,
                                itemBuilder: (context, index) {
                                  final estimate = _filteredEstimates[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1A1A),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF3A3A3A),
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      onTap:
                                          () => _showEstimateDetails(estimate),
                                      title: Row(
                                        children: [
                                          Text(
                                            estimate['estimate_number'] ??
                                                'No Number',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if ((estimate['status'] ?? '')
                                              .isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(
                                                  estimate['status'],
                                                ).withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                estimate['status'] ?? '',
                                                style: TextStyle(
                                                  color: _getStatusColor(
                                                    estimate['status'],
                                                  ),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 8),
                                          Text(
                                            estimate['customer_name'] ??
                                                'No Name',
                                            style: TextStyle(
                                              color: Colors.grey[300],
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Made by: ${estimate['sale_by'] ?? 'Unknown'}',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (() {
                                              final dateTimeStr =
                                                  estimate['created_at']
                                                      ?.toString() ??
                                                  '';
                                              DateTime? dateTime;
                                              try {
                                                dateTime = DateTime.tryParse(
                                                  dateTimeStr,
                                                )?.toUtc().add(
                                                  const Duration(
                                                    hours: 5,
                                                    minutes: 30,
                                                  ),
                                                );
                                              } catch (_) {
                                                dateTime = null;
                                              }
                                              return dateTime != null
                                                  ? DateFormat(
                                                    'yyyy-MM-dd hh:mm a',
                                                  ).format(dateTime)
                                                  : '';
                                            })(),
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'Rs. ${(estimate['total'] ?? 0.0).toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: Color(0xFF6B8E7F),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${(estimate['items'] as List?)?.length ?? 0} items',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
          ),
        ],
      ),
    );
  }

  void _showEstimateDetails(Map<String, dynamic> estimate) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EstimatePreviewScreen(estimate: estimate),
      ),
    );
    
    // If estimate was deleted or converted, refresh the list
    if (result == true && mounted) {
      _fetchEstimates();
    }
  }
}
