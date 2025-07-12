import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

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
    _initializeWebSocket();
    _loadOrders();
  }

  void _initializeWebSocket() {
    _webSocketService = WebSocketService(
      serverUrl: 'wss://pos-2wc9.onrender.com/ws',
    );
    _webSocketService.connect();
    _webSocketService.messageStream.listen((message) {
      if (message == 'order_updated' || message == 'estimate_updated') {
        _loadOrders();
      }
    });
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });
    final orders = await ApiService.fetchOrders();
    setState(() {
      _orders = orders.where((o) => o['status'] == 'Completed').toList();
      _filteredOrders = _orders;
      _isLoading = false;
    });
  }

  void _filterOrders() {
    setState(() {
      _filteredOrders =
          _orders.where((order) {
            final matchesSearch =
                order['customer_name'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                order['estimate_number'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );
            return matchesSearch;
          }).toList();
    });
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            'Order ${order['estimate_number'] ?? order['id']}',
            style: const TextStyle(color: Colors.white),
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
                _buildDetailRow(
                  'Date',
                  order['created_at'].toString().split(' ')[0],
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
    _webSocketService.dispose();
    super.dispose();
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
                                            order['estimate_number'] ??
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
                                            order['created_at']
                                                .toString()
                                                .split(' ')[0],
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
                                            'Rs. ${order['total'].toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: Color(0xFF6B8E7F),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${order['items'].length} items',
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
