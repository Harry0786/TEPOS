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
  bool _isLoading = false;
  String _searchQuery = '';
  String? _errorMessage;
  late WebSocketService _webSocketService;

  @override
  void initState() {
    super.initState();
    _webSocketService = WebSocketService(serverUrl: ApiService.webSocketUrl);
    _webSocketService.connect();
    _webSocketService.messageStream.listen((message) {
      if (message == 'estimate_updated' ||
          message == 'order_updated' ||
          message == 'sale_completed') {
        if (mounted) _fetchEstimates();
      }
    });
    _fetchEstimates();
  }

  Future<void> _fetchEstimates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final estimates = await ApiService.fetchEstimates(forceClearCache: true);
      setState(() {
        _estimates = estimates ?? [];
        _filteredEstimates = _applyFilter(estimates ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load estimates. Please try again.';
      });
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
    setState(() {
      _searchQuery = value;
      _filteredEstimates = _applyFilter(_estimates);
    });
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    super.dispose();
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is DateTime) return date.toString().split(' ')[0];
    if (date is String)
      return DateTime.tryParse(date)?.toString().split(' ')[0] ??
          date.split('T').first;
    return 'N/A';
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
                                            'Sale by: ${estimate['sale_by'] ?? 'Unknown'}',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatDate(estimate['created_at']),
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

  void _showEstimateDetails(Map<String, dynamic> estimate) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            'Estimate ${estimate['estimate_number'] ?? ''}',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Customer', estimate['customer_name'] ?? ''),
                _buildDetailRow('Phone', estimate['customer_phone'] ?? ''),
                _buildDetailRow('Address', estimate['customer_address'] ?? ''),
                _buildDetailRow('Sale By', estimate['sale_by'] ?? ''),
                _buildDetailRow('Status', estimate['status'] ?? ''),
                _buildDetailRow('Date', _formatDate(estimate['created_at'])),
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
                ...(estimate['items'] as List?)
                        ?.map<Widget>(
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
                        ?.toList() ??
                    [],
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF3A3A3A)),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Subtotal',
                  'Rs. ${(estimate['subtotal'] ?? 0.0).toStringAsFixed(2)}',
                ),
                if ((estimate['discount_amount'] ?? 0.0) > 0)
                  _buildDetailRow(
                    'Discount',
                    (estimate['is_percentage_discount'] ?? false)
                        ? '${estimate['discount_amount']}%'
                        : 'Rs. ${(estimate['discount_amount'] ?? 0.0).toStringAsFixed(2)}',
                  ),
                _buildDetailRow(
                  'Total',
                  'Rs. ${(estimate['total'] ?? 0.0).toStringAsFixed(2)}',
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
            if ((estimate['is_converted_to_order'] ?? false) == false)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B8E7F),
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (context) => const AlertDialog(
                          backgroundColor: Color(0xFF1A1A1A),
                          content: Row(
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF6B8E7F),
                              ),
                              SizedBox(width: 16),
                              Text(
                                'Converting to order...',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                  );
                  final result = await ApiService.convertEstimateToOrder(
                    estimateId: estimate['estimate_id'] ?? estimate['id'],
                    paymentMode: 'Cash', // Optionally prompt for payment mode
                  );
                  if (!mounted) return;
                  Navigator.of(context).pop(); // Close loading dialog
                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Estimate converted to order!'),
                        backgroundColor: Color(0xFF6B8E7F),
                      ),
                    );
                    _fetchEstimates();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to convert: ${result['message'] ?? 'Unknown error'}',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Convert to Order'),
              ),
            if ((estimate['is_converted_to_order'] ?? false) == false)
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
                            'Delete Estimate',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: const Text(
                            'Are you sure you want to delete this estimate? This action cannot be undone.',
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

                  if (shouldDelete == true) {
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
                                  'Deleting estimate...',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                    );

                    final result = await ApiService.deleteEstimate(
                      estimateId: estimate['estimate_id'] ?? estimate['id'],
                    );

                    if (!mounted) return;
                    Navigator.of(context).pop(); // Close loading dialog

                    if (result['success'] == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Estimate deleted successfully!'),
                          backgroundColor: Color(0xFF6B8E7F),
                        ),
                      );
                      _fetchEstimates();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to delete: ${result['message'] ?? 'Unknown error'}',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Delete Estimate'),
              ),
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
        subtotal: (estimate['subtotal'] ?? 0.0).toDouble(),
        discountAmount: (estimate['discount_amount'] ?? 0.0).toDouble(),
        isPercentageDiscount: estimate['is_percentage_discount'] ?? true,
        total: (estimate['total'] ?? 0.0).toDouble(),
        createdAt:
            DateTime.tryParse(estimate['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
      final bytes = await pdfFile.readAsBytes();
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing estimate: ${e.toString()}'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Updating status...'),
        backgroundColor: Color(0xFF6B8E7F),
        duration: Duration(seconds: 1),
      ),
    );
    final result = await ApiService.updateOrderStatus(estimateId, newStatus);
    if (result['success']) {
      setState(() {
        final index = _estimates.indexWhere((e) => e['id'] == estimateId);
        if (index != -1) {
          _estimates[index]['status'] = newStatus;
          _filteredEstimates = _applyFilter(_estimates);
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
}
