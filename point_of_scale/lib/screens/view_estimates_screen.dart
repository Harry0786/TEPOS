import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'package:printing/printing.dart';
import '../services/pdf_service.dart';

class ViewEstimatesScreen extends StatefulWidget {
  const ViewEstimatesScreen({super.key});

  @override
  State<ViewEstimatesScreen> createState() => _ViewEstimatesScreenState();
}

class _ViewEstimatesScreenState extends State<ViewEstimatesScreen> {
  List<Map<String, dynamic>> _estimates = [];
  List<Map<String, dynamic>> _filteredEstimates = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  late WebSocketService _webSocketService;

  final List<String> _filterOptions = [
    'All',
    'Pending',
    'Accepted',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _webSocketService = WebSocketService(serverUrl: ApiService.webSocketUrl);
    _webSocketService.connect();

    // Listen for real-time updates
    _webSocketService.messageStream.listen((message) {
      print('🔄 Real-time update received in estimates screen: $message');
      if (message == 'estimate_updated' ||
          message == 'order_updated' ||
          message == 'sale_completed') {
        // Refresh estimates when backend notifies of changes
        if (mounted) {
          _loadEstimates();
        }
      }
    });
    _loadEstimates();
  }

  Future<void> _loadEstimates() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final estimates = await ApiService.fetchEstimates();
      setState(() {
        _estimates = estimates;
        _filteredEstimates = estimates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading estimates: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    super.dispose();
  }

  void _filterEstimates() {
    setState(() {
      _filteredEstimates =
          _estimates.where((estimate) {
            final matchesSearch =
                estimate['customer_name'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                estimate['estimate_number'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );

            final matchesFilter =
                _selectedFilter == 'All' ||
                estimate['status'] == _selectedFilter;

            return matchesSearch && matchesFilter;
          }).toList();
    });
  }

  void _showEstimateDetails(Map<String, dynamic> estimate) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            'Estimate ${estimate['estimate_number']}',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Customer', estimate['customer_name']),
                _buildDetailRow('Phone', estimate['customer_phone']),
                _buildDetailRow('Address', estimate['customer_address']),
                _buildDetailRow('Sale By', estimate['sale_by']),
                _buildDetailRow('Status', estimate['status']),
                _buildDetailRow(
                  'Date',
                  estimate['created_at'].toString().split(' ')[0],
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
                ...estimate['items']
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
                  'Rs. ${estimate['subtotal'].toStringAsFixed(2)}',
                ),
                if (estimate['discount_amount'] > 0)
                  _buildDetailRow(
                    'Discount',
                    estimate['is_percentage_discount']
                        ? '${estimate['discount_amount']}%'
                        : 'Rs. ${estimate['discount_amount'].toStringAsFixed(2)}',
                  ),
                _buildDetailRow(
                  'Total',
                  'Rs. ${estimate['total'].toStringAsFixed(2)}',
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
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await _printEstimateFromData(estimate);
              },
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Print Estimate'),
            ),
            if (estimate['status'] == 'Pending') ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _updateEstimateStatus(estimate['id'], 'Accepted');
                },
                child: const Text('Accept'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.of(context).pop();
                  _updateEstimateStatus(estimate['id'], 'Rejected');
                },
                child: const Text('Reject'),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _printEstimateFromData(Map<String, dynamic> estimate) async {
    try {
      final pdfFile = await PdfService.generateEstimatePdf(
        estimateNumber: estimate['estimate_number'] ?? 'EST',
        customerName: estimate['customer_name'] ?? '',
        customerPhone: estimate['customer_phone'] ?? '',
        customerAddress: estimate['customer_address'] ?? '',
        saleBy: estimate['sale_by'] ?? '',
        items: List<Map<String, dynamic>>.from(estimate['items'] ?? []),
        subtotal: estimate['subtotal']?.toDouble() ?? 0.0,
        discountAmount: estimate['discount_amount']?.toDouble() ?? 0.0,
        isPercentageDiscount: estimate['is_percentage_discount'] ?? true,
        total: estimate['total']?.toDouble() ?? 0.0,
        createdAt:
            DateTime.tryParse(estimate['created_at'] ?? '') ?? DateTime.now(),
      );
      final bytes = await pdfFile.readAsBytes();
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing estimate:  [31m${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  void _updateEstimateStatus(String estimateId, String newStatus) async {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Updating status...'),
        backgroundColor: Color(0xFF6B8E7F),
        duration: Duration(seconds: 1),
      ),
    );

    // Call API to update status
    final result = await ApiService.updateOrderStatus(estimateId, newStatus);

    if (result['success']) {
      // Update local state
      setState(() {
        final index = _estimates.indexWhere((e) => e['id'] == estimateId);
        if (index != -1) {
          _estimates[index]['status'] = newStatus;
          _filterEstimates();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estimate status updated to $newStatus'),
          backgroundColor: const Color(0xFF6B8E7F),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
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
                // Search Bar
                TextField(
                  onChanged: (value) {
                    _searchQuery = value;
                    _filterEstimates();
                  },
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
                // Filter Buttons
                Row(
                  children:
                      _filterOptions.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedFilter = filter;
                                  _filterEstimates();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isSelected
                                        ? const Color(0xFF6B8E7F)
                                        : const Color(0xFF2A2A2A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Text(
                                filter,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
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
                    : RefreshIndicator(
                      color: const Color(0xFF6B8E7F),
                      backgroundColor: const Color(0xFF1A1A1A),
                      onRefresh: _loadEstimates,
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
                                            estimate['estimate_number'],
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
                                              color: _getStatusColor(
                                                estimate['status'],
                                              ).withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              estimate['status'],
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
                                            estimate['customer_name'],
                                            style: TextStyle(
                                              color: Colors.grey[300],
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Sale by: ${estimate['sale_by']}',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            estimate['created_at']
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
                                            'Rs. ${estimate['total'].toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: Color(0xFF6B8E7F),
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${estimate['items'].length} items',
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
