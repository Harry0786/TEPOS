import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/pdf_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';

class ViewOrdersScreen extends StatefulWidget {
  const ViewOrdersScreen({super.key});

  @override
  State<ViewOrdersScreen> createState() => _ViewOrdersScreenState();
}

class _ViewOrdersScreenState extends State<ViewOrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  bool _isLoading = true;
  String _searchQuery = '';
  late WebSocketService _webSocketService;

  @override
  void initState() {
    super.initState();

    try {
      _webSocketService = WebSocketService(serverUrl: ApiService.webSocketUrl);
      _webSocketService.connect();

      // Handle structured WebSocket messages for efficient updates
      _webSocketService.messageStream.listen(
        (message) {
          if (mounted) {
            _handleWebSocketMessage(message);
          }
        },
        onError: (error) {
          print('❌ WebSocket message stream error: $error');
        },
      );

      // Handle legacy messages for backward compatibility
      _webSocketService.legacyMessageStream.listen(
        (message) {
          if (message == 'order_updated' ||
              message == 'estimate_updated' ||
              message == 'sale_completed' ||
              message == 'estimate_created' ||
              message == 'estimate_deleted' ||
              message == 'estimate_converted_to_order') {
            if (mounted) {
              print(
                '🔄 Legacy WebSocket message received: $message - refreshing orders...',
              );
              ApiService.clearCache();
              _loadOrders();
            }
          }
        },
        onError: (error) {
          print('❌ WebSocket legacy message stream error: $error');
        },
      );
    } catch (e) {
      print('❌ Error initializing WebSocket: $e');
      // Continue without WebSocket - app will still work
    }

    _loadOrders();
  }

  void _handleWebSocketMessage(WebSocketMessage message) {
    print(
      '📨 Handling WebSocket message: ${message.type} - ${message.action} - ${message.id}',
    );

    if (message.isOrder) {
      switch (message.action) {
        case 'create':
          _handleOrderCreated(message);
          break;
        case 'delete':
          _handleOrderDeleted(message);
          break;
        case 'update':
          _handleOrderUpdated(message);
          break;
        default:
          // Unknown action, do full refresh
          print(
            '⚠️ Unknown order action: ${message.action} - doing full refresh',
          );
          ApiService.clearCache();
          _loadOrders();
      }
    } else if (message.isEstimate && message.isConvertToOrder) {
      // Estimate converted to order - refresh orders to show the new order
      print('🔄 Estimate converted to order - refreshing orders...');
      ApiService.clearCache();
      _loadOrders();
    } else {
      // Unknown message type, do full refresh
      print('⚠️ Unknown message type: ${message.type} - doing full refresh');
      ApiService.clearCache();
      _loadOrders();
    }
  }

  void _handleOrderCreated(WebSocketMessage message) {
    print('➕ Handling order created: ${message.id}');
    if (message.data != null) {
      // Add the new order to the list
      final newOrder = {
        'id': message.id,
        'order_id': message.data!['order_id'],
        'sale_number': message.data!['sale_number'],
        'customer_name': message.data!['customer_name'],
        'total': message.data!['total'],
        'created_at': message.data!['created_at'],
        'status': 'Completed',
        // Add other required fields with defaults
        'customer_phone': '',
        'customer_address': '',
        'sale_by': '',
        'items': [],
        'subtotal': 0.0,
        'discount_amount': 0.0,
        'is_percentage_discount': false,
        'payment_mode': 'Cash',
      };

      setState(() {
        _orders.insert(0, newOrder);
        _filteredOrders = _orders;
      });

      print('✅ Order added to list: ${message.data!['sale_number']}');
    } else {
      // No data provided, do full refresh
      print('⚠️ No data in create message - doing full refresh');
      ApiService.clearCache();
      _loadOrders();
    }
  }

  void _handleOrderDeleted(WebSocketMessage message) {
    print('🗑️ Handling order deleted: ${message.id}');

    setState(() {
      _orders.removeWhere(
        (order) => order['order_id'] == message.id || order['id'] == message.id,
      );
      _filteredOrders = _orders;
    });

    print('✅ Order removed from list: ${message.id}');
  }

  void _handleOrderUpdated(WebSocketMessage message) {
    print('✏️ Handling order updated: ${message.id}');

    // For updates, we need to refresh the specific order or do a full refresh
    // Since we don't have the updated data, do a full refresh for now
    print('🔄 Order updated - doing full refresh');
    ApiService.clearCache();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final orders = await ApiService.fetchOrders(
        forceClearCache: true,
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          print('⚠️ Orders fetch timeout');
          return <Map<String, dynamic>>[];
        },
      );

      if (mounted) {
        setState(() {
          _orders = orders;
          _filteredOrders = _orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading orders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading orders: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterOrders() {
    setState(() {
      _filteredOrders =
          _orders.where((order) {
            final matchesSearch =
                order['customer_name'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                (order['sale_number']?.toString().toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false);
            return matchesSearch;
          }).toList();
    });
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final String orderNumber =
        order['sale_number'] ?? order['order_id'] ?? 'Unknown';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Row(
            children: [
              const Icon(Icons.receipt, color: Color(0xFF4CAF50), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Order $orderNumber',
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Customer', order['customer_name'] ?? ''),
                _buildDetailRow('Phone', order['customer_phone'] ?? ''),
                _buildDetailRow('Address', order['customer_address'] ?? ''),
                _buildDetailRow('Sale By', order['sale_by'] ?? ''),
                _buildDetailRow('Status', order['status'] ?? ''),
                if (order['payment_mode'] != null)
                  _buildDetailRow('Payment Mode', order['payment_mode'] ?? ''),
                _buildDetailRow(
                  'Date',
                  (() {
                    final dateTimeStr = order['created_at']?.toString() ?? '';
                    DateTime? dateTime;
                    try {
                      dateTime = DateTime.tryParse(
                        dateTimeStr,
                      )?.toUtc().add(const Duration(hours: 5, minutes: 30));
                    } catch (_) {
                      dateTime = null;
                    }
                    return dateTime != null
                        ? DateFormat('yyyy-MM-dd hh:mm a').format(dateTime)
                        : '';
                  })(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Items:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...order['items']
                    .map<Widget>(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '${item['name']} x${item['quantity']}',
                                style: TextStyle(color: Colors.grey[300]),
                              ),
                            ),
                            Text(
                              'Rs. ${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                              style: TextStyle(color: Colors.grey[300]),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF3A3A3A)),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Subtotal',
                  'Rs. ${order['subtotal'].toStringAsFixed(2)}',
                ),
                if (order['discount_amount'] > 0)
                  _buildDetailRow(
                    'Discount',
                    order['is_percentage_discount']
                        ? '${order['discount_amount']}%'
                        : 'Rs. ${order['discount_amount'].toStringAsFixed(2)}',
                  ),
                _buildDetailRow(
                  'Total',
                  'Rs. ${order['total'].toStringAsFixed(2)}',
                  isTotal: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E7F),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _printOrderPdf(order);
              },
              child: const Text('Print PDF'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.of(context).pop();

                // Show confirmation dialog
                final shouldDelete = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1A1A1A),
                        title: const Text(
                          'Delete Order',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          'Are you sure you want to delete this order? This action cannot be undone. If this order was created from an estimate, the estimate will also be deleted.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                );

                if (shouldDelete == true && mounted) {
                  await _deleteOrderSafely(order);
                }
              },
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Delete Order'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isTotal ? const Color(0xFF6B8E7F) : Colors.white,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    try {
      _webSocketService.dispose();
    } catch (e) {
      print('⚠️ Error disposing WebSocket service: $e');
    }
    super.dispose();
  }

  Future<void> _deleteOrderSafely(Map<String, dynamic> order) async {
    if (!mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            backgroundColor: Color(0xFF1A1A1A),
            content: Row(
              children: [
                CircularProgressIndicator(color: Colors.red),
                SizedBox(width: 16),
                Text(
                  'Deleting order...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
    );

    try {
      // Use a timeout to prevent hanging
      final result = await ApiService.deleteOrder(
        orderId: order['order_id'] ?? order['id'],
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          return {
            'success': false,
            'message': 'Request timeout - please try again',
          };
        },
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      if (result['success'] == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order deleted successfully!'),
            backgroundColor: Color(0xFF6B8E7F),
          ),
        );

        // Refresh orders list
        await _loadOrders();
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete: ${result['message'] ?? 'Unknown error'}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting order: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );

      print('❌ Error deleting order: $e');
    }
  }

  Future<void> _printOrderPdf(Map<String, dynamic> order) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            backgroundColor: Color(0xFF1A1A1A),
            content: Row(
              children: [
                CircularProgressIndicator(color: Color(0xFF6B8E7F)),
                SizedBox(width: 20),
                Text(
                  'Generating PDF...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        },
      );

      // Generate order PDF
      final pdfFile = await PdfService.generateSalePdf(
        saleNumber: order['sale_number'] ?? 'Unknown',
        customerName: order['customer_name'] ?? '',
        customerPhone: order['customer_phone'] ?? '',
        customerAddress: order['customer_address'] ?? '',
        saleBy: order['sale_by'] ?? '',
        items: List<Map<String, dynamic>>.from(order['items'] ?? []),
        subtotal: order['subtotal'] ?? 0.0,
        discountAmount: order['discount_amount'] ?? 0.0,
        isPercentageDiscount: order['is_percentage_discount'] ?? false,
        total: order['total'] ?? order['amount'] ?? 0.0,
        createdAt:
            DateTime.tryParse(order['created_at'].toString()) ?? DateTime.now(),
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Print the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfFile.readAsBytesSync(),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text(
              'Print Error',
              style: TextStyle(color: Colors.red),
            ),
            content: Text(
              'Failed to print PDF: $e',
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B8E7F),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('View Orders', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              border: Border(bottom: BorderSide(color: Color(0xFF3A3A3A))),
            ),
            child: TextField(
              onChanged: (value) {
                _searchQuery = value;
                _filterOrders();
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search orders...',
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
          ),
          // Orders List
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
                    : RefreshIndicator(
                      color: const Color(0xFF6B8E7F),
                      backgroundColor: const Color(0xFF1A1A1A),
                      onRefresh: _loadOrders,
                      child:
                          _filteredOrders.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.list_alt,
                                      size: 64,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No orders found',
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
                                itemCount: _filteredOrders.length,
                                itemBuilder: (context, index) {
                                  final order = _filteredOrders[index];
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
                                      onTap: () => _showOrderDetails(order),
                                      title: Row(
                                        children: [
                                          Text(
                                            order['sale_number'] ??
                                                order['order_id'] ??
                                                order['id'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF4CAF50,
                                              ).withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'Completed',
                                              style: TextStyle(
                                                color: Color(0xFF4CAF50),
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
                                            order['customer_name'] ?? '',
                                            style: TextStyle(
                                              color: Colors.grey[300],
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Sale by: ${order['sale_by'] ?? ''}',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (() {
                                              final dateTimeStr =
                                                  order['created_at']
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
                                            'Rs. ${(order['total'] ?? order['amount'] ?? 0.0).toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: Color(0xFF6B8E7F),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${(order['items'] as List<dynamic>?)?.length ?? order['items_count'] ?? 0} items',
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
}
