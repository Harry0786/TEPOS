import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'package:printing/printing.dart';
import '../services/pdf_service.dart';
import 'package:intl/intl.dart';

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
  bool _isConversionDialogShown = false;
  Timer? _conversionTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _webSocketService = WebSocketService(serverUrl: ApiService.webSocketUrl);
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

      setState(() {
        _estimates.insert(0, newEstimate);
        _filteredEstimates = _applyFilter(_estimates);
      });

      print('✅ Estimate added to list: ${message.data!['estimate_number']}');
    } else {
      // No data provided, do full refresh
      print('⚠️ No data in create message - doing full refresh');
      ApiService.clearCache();
      _fetchEstimates();
    }
  }

  void _handleEstimateDeleted(WebSocketMessage message) {
    print('🗑️ Handling estimate deleted: ${message.id}');

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

  // Helper method to close conversion dialog
  void _closeConversionDialog() {
    print(
      '🔍 Attempting to close conversion dialog. Dialog shown: $_isConversionDialogShown, Mounted: $mounted',
    );
    if (_isConversionDialogShown && mounted) {
      try {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          print('✅ Conversion dialog closed successfully');
        } else {
          print('⚠️ Cannot pop dialog - no dialogs in stack');
        }
      } catch (dialogError) {
        print('⚠️ Error closing conversion dialog: $dialogError');
        // Try alternative method
        try {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            print('✅ Conversion dialog closed with alternative method');
          }
        } catch (altError) {
          print('⚠️ Alternative dialog close also failed: $altError');
        }
      } finally {
        setState(() {
          _isConversionDialogShown = false;
        });
        _conversionTimeoutTimer?.cancel();
        print('🔄 Dialog state reset to false');
      }
    } else {
      print(
        '⚠️ Dialog not shown or widget not mounted. Dialog shown: $_isConversionDialogShown, Mounted: $mounted',
      );
    }
  }

  // Force close dialog method for emergency situations
  void _forceCloseConversionDialog() {
    print('🚨 Force closing conversion dialog');
    try {
      // Try to close any open dialogs
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        print('✅ Force closed dialog');
      }
    } catch (e) {
      print('⚠️ Force close failed: $e');
    } finally {
      setState(() {
        _isConversionDialogShown = false;
      });
      _conversionTimeoutTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _conversionTimeoutTimer?.cancel();
    _webSocketService.dispose();
    super.dispose();
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is DateTime) return date.toString().split(' ')[0];
    if (date is String)
      return DateTime.tryParse(date)
              ?.toUtc()
              .add(const Duration(hours: 5, minutes: 30))
              ?.toString()
              .split(' ')[0] ??
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
                _buildDetailRow(
                  'Date',
                  (() {
                    final dateTimeStr =
                        estimate['created_at']?.toString() ?? '';
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
                  _showConvertToOrderDialog(estimate);
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

                  if (shouldDelete == true && mounted) {
                    await _deleteEstimateSafely(estimate);
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

  void _showConvertToOrderDialog(Map<String, dynamic> estimate) async {
    String selectedPaymentMode = 'Cash';
    String selectedSaleBy = estimate['sale_by'] ?? 'Rajesh Goyal';
    final List<String> paymentModeOptions = [
      'Cash',
      'UPI: Ragini Bandl',
      'UPI: Rajesh Goyal',
      'Card',
      'Other',
    ];
    final List<String> saleByOptions = [
      'Rajesh Goyal',
      'Rupendra',
      'Deepak',
      'Major',
    ];
    final TextEditingController amountPaidController = TextEditingController(
      text: (estimate['total'] ?? '').toString(),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text(
                'Convert Estimate to Order',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer: ${estimate['customer_name'] ?? ''}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Payment Mode:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedPaymentMode,
                      dropdownColor: const Color(0xFF1A1A1A),
                      items:
                          paymentModeOptions
                              .map(
                                (mode) => DropdownMenuItem(
                                  value: mode,
                                  child: Text(
                                    mode,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedPaymentMode = value!;
                        });
                      },
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFF2A2A2A),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFF6B8E7F),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0D0D0D),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sale By:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedSaleBy,
                      dropdownColor: const Color(0xFF1A1A1A),
                      items:
                          saleByOptions
                              .map(
                                (name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(
                                    name,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedSaleBy = value!;
                        });
                      },
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFF2A2A2A),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFF6B8E7F),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0D0D0D),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Amount Paid field
                    TextField(
                      controller: amountPaidController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Amount Paid',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFF2A2A2A),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFF6B8E7F),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF0D0D0D),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B8E7F),
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop(); // Close dialog

                    // Show loading dialog with better error handling
                    if (_isConversionDialogShown) {
                      print('⚠️ Conversion dialog already shown, skipping');
                      return;
                    }

                    try {
                      setState(() {
                        _isConversionDialogShown = true;
                      });

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
                      print('✅ Loading dialog shown successfully');

                      // Set a safety timeout to close dialog if something goes wrong
                      _conversionTimeoutTimer?.cancel();
                      _conversionTimeoutTimer = Timer(
                        const Duration(seconds: 30),
                        () {
                          print(
                            '🕐 Safety timeout triggered - force closing dialog',
                          );
                          _forceCloseConversionDialog();
                        },
                      );
                    } catch (dialogError) {
                      print('⚠️ Error showing loading dialog: $dialogError');
                      setState(() {
                        _isConversionDialogShown = false;
                      });
                    }

                    try {
                      print('🔄 Starting estimate to order conversion...');
                      print('📋 Estimate data: ${estimate.toString()}');
                      print('👤 Sale By: $selectedSaleBy');
                      print('💳 Payment Mode: $selectedPaymentMode');
                      double paid =
                          double.tryParse(amountPaidController.text) ??
                          (estimate['total'] ?? 0.0);

                      // Use the proper convertEstimateToOrder function
                      final result = await ApiService.convertEstimateToOrder(
                        estimateId: estimate['estimate_id'] ?? estimate['id'],
                        paymentMode: selectedPaymentMode,
                        saleBy: selectedSaleBy,
                      ).timeout(
                        const Duration(
                          seconds: 25,
                        ), // Increased timeout for conversion
                        onTimeout: () {
                          throw Exception(
                            'Request timeout - please check your connection',
                          );
                        },
                      );

                      print(
                        '✅ API call completed. Result: ${result.toString()}',
                      );

                      // Check if widget is still mounted before proceeding
                      if (!mounted) {
                        print(
                          '⚠️ Widget no longer mounted, stopping operation',
                        );
                        return;
                      }

                      // Safely close loading dialog
                      _closeConversionDialog();

                      if (result['success'] == true) {
                        print('🎉 Order created successfully!');
                        // Safely show success message
                        try {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Estimate converted to order!'),
                                backgroundColor: Color(0xFF6B8E7F),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (snackbarError) {
                          print(
                            '⚠️ Error showing success message: $snackbarError',
                          );
                        }

                        // The backend conversion endpoint handles estimate linking automatically
                        // No need to manually delete or refresh - WebSocket will handle updates
                        print('✅ Estimate conversion completed successfully');
                      } else {
                        print('❌ Order creation failed: ${result['message']}');
                        // Safely show error message
                        try {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to convert: ${result['message'] ?? 'Unknown error'}',
                                ),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (snackbarError) {
                          print(
                            '⚠️ Error showing error message: $snackbarError',
                          );
                        }
                      }
                    } catch (e) {
                      print('Error converting estimate to order: $e');
                      print('🔍 Error details: ${e.toString()}');
                      // Safely handle errors
                      if (!mounted) {
                        print(
                          '⚠️ Widget no longer mounted during error handling',
                        );
                        return;
                      }

                      // Safely close loading dialog after error
                      _closeConversionDialog();

                      // Safely show error message
                      try {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      } catch (snackbarError) {
                        print(
                          '⚠️ Error showing error snackbar: $snackbarError',
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Convert to Order'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEstimateSafely(Map<String, dynamic> estimate) async {
    final loadingDialog = showDialog(
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

    try {
      final result = await ApiService.deleteEstimate(
        estimateId: estimate['estimate_id'] ?? estimate['id'],
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Request timeout for estimate deletion.');
        },
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
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting estimate: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
