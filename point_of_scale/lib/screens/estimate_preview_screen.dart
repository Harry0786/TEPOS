import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/pdf_service.dart';

class EstimatePreviewScreen extends StatefulWidget {
  final Map<String, dynamic> estimate;

  const EstimatePreviewScreen({
    Key? key,
    required this.estimate,
  }) : super(key: key);

  @override
  State<EstimatePreviewScreen> createState() => _EstimatePreviewScreenState();
}

class _EstimatePreviewScreenState extends State<EstimatePreviewScreen> {
  // Dialog state management
  bool _isConversionDialogShown = false;
  Timer? _conversionTimeoutTimer;

  @override
  void dispose() {
    _conversionTimeoutTimer?.cancel();
    super.dispose();
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
        if (mounted) {
          setState(() {
            _isConversionDialogShown = false;
          });
        }
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
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        print('✅ Force closed dialog');
      }
    } catch (e) {
      print('⚠️ Force close failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isConversionDialogShown = false;
        });
      }
      _conversionTimeoutTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'Estimate ${widget.estimate['estimate_number'] ?? ''}',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Details Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3A3A3A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Customer', widget.estimate['customer_name'] ?? ''),
                  _buildDetailRow('Phone', widget.estimate['customer_phone'] ?? ''),
                  _buildDetailRow('Address', widget.estimate['customer_address'] ?? ''),
                  _buildDetailRow('Made By', widget.estimate['sale_by'] ?? ''),
                  _buildDetailRow(
                    'Date',
                    (() {
                      final dateTimeStr = widget.estimate['created_at']?.toString() ?? '';
                      DateTime? dateTime;
                      try {
                        dateTime = DateTime.tryParse(dateTimeStr)?.toUtc().add(
                          const Duration(hours: 5, minutes: 30),
                        );
                      } catch (_) {
                        dateTime = null;
                      }
                      return dateTime != null
                          ? DateFormat('yyyy-MM-dd hh:mm a').format(dateTime)
                          : '';
                    })(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Items Table Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3A3A3A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Tabular format for items
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF2A2A2A)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0D0D0D),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(8),
                              topRight: Radius.circular(8),
                            ),
                            border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Container(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Item',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Rate',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Qty',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Container(
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Disc',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'Total',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Table Rows
                        ...(widget.estimate['items'] as List?)?.map(
                          (item) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: const Color(0xFF2A2A2A).withOpacity(0.5),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Container(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      item['name'] ?? '',
                                      style: TextStyle(
                                        color: Colors.grey[300],
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Rs.${(item['price'] ?? 0.0).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: Colors.grey[300],
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${item['quantity'] ?? 0}',
                                      style: TextStyle(
                                        color: Colors.grey[300],
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${(item['discount'] ?? 0).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Rs.${((item['price'] ?? 0.0) * (item['quantity'] ?? 0) * (1 - ((item['discount'] ?? 0) / 100))).toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: const Color(0xFF6B8E7F),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).toList() ?? [],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Total Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3A3A3A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Subtotal',
                    'Rs. ${(widget.estimate['subtotal'] ?? 0.0).toStringAsFixed(2)}',
                  ),
                  if ((widget.estimate['discount_amount'] ?? 0.0) > 0)
                    _buildDetailRow(
                      'Discount',
                      (widget.estimate['is_percentage_discount'] ?? false)
                          ? '${widget.estimate['discount_amount']}%'
                          : 'Rs. ${(widget.estimate['discount_amount'] ?? 0.0).toStringAsFixed(2)}',
                    ),
                  const Divider(color: Color(0xFF3A3A3A)),
                  _buildDetailRow(
                    'Total',
                    'Rs. ${(widget.estimate['total'] ?? 0.0).toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          border: Border(top: BorderSide(color: Color(0xFF3A3A3A))),
        ),
        child: Row(
          children: [
            // Print Button
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  await _printEstimateFromData(widget.estimate);
                },
                icon: const Icon(Icons.print, size: 20),
                label: const Text('Print'),
              ),
            ),
            const SizedBox(width: 12),
            
            // Convert to Order Button (if not converted)
            if ((widget.estimate['is_converted_to_order'] ?? false) == false) ...[
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B8E7F),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    _showConvertToOrderDialog(widget.estimate);
                  },
                  icon: const Icon(Icons.swap_horiz, size: 20),
                  label: const Text('Convert'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            
            // Delete Button (if not converted)
            if ((widget.estimate['is_converted_to_order'] ?? false) == false)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
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
                      await _deleteEstimateSafely(widget.estimate);
                    }
                  },
                  icon: const Icon(Icons.delete, size: 20),
                  label: const Text('Delete'),
                ),
              ),
          ],
        ),
      ),
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
                      items: paymentModeOptions
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
                      items: saleByOptions
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

                    if (_isConversionDialogShown) {
                      print('⚠️ Conversion dialog already shown, skipping');
                      return;
                    }

                    try {
                      if (mounted) {
                        setState(() {
                          _isConversionDialogShown = true;
                        });
                      }

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const AlertDialog(
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

                      _conversionTimeoutTimer?.cancel();
                      _conversionTimeoutTimer = Timer(
                        const Duration(seconds: 30),
                        () {
                          print('🕐 Safety timeout triggered - force closing dialog');
                          _forceCloseConversionDialog();
                        },
                      );
                    } catch (dialogError) {
                      print('⚠️ Error showing loading dialog: $dialogError');
                      if (mounted) {
                        setState(() {
                          _isConversionDialogShown = false;
                        });
                      }
                    }

                    try {
                      final result = await ApiService.convertEstimateToOrder(
                        estimateId: estimate['estimate_id'] ?? estimate['id'],
                        paymentMode: selectedPaymentMode,
                        saleBy: selectedSaleBy,
                        amountPaid: double.tryParse(amountPaidController.text) ?? 
                          (estimate['total'] ?? 0.0),
                      ).timeout(
                        const Duration(seconds: 25),
                        onTimeout: () {
                          throw Exception('Request timeout - please check your connection');
                        },
                      );

                      if (!mounted) return;

                      _closeConversionDialog();

                      if (result['success'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Estimate converted to order successfully!'),
                            backgroundColor: Color(0xFF6B8E7F),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        // Navigate back to the estimates list
                        Navigator.of(context).pop(true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to convert: ${result['message'] ?? 'Unknown error'}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      if (!mounted) return;
                      _closeConversionDialog();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error converting estimate: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Convert to Order'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEstimateSafely(Map<String, dynamic> estimate) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
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
        // Navigate back to the estimates list
        Navigator.of(context).pop(true);
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
