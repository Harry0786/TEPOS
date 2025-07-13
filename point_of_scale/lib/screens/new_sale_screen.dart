import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/pdf_service.dart';
import '../services/performance_service.dart';
import 'dart:io'; // Added for File
import 'dart:convert'; // Added for json
import 'package:http/http.dart' as http; // Added for http
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final List<Map<String, dynamic>> _cartItems = [];

  // Performance monitoring
  final PerformanceService _performanceService = PerformanceService();

  // Controllers for add product dialog
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  // Discount variables
  double _discountAmount = 0.0;
  bool _isPercentageDiscount = true;
  final TextEditingController _discountController = TextEditingController();

  // Customer details controllers
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerWhatsAppController =
      TextEditingController();
  final TextEditingController _customerAddressController =
      TextEditingController();

  // Payment mode variable
  String _selectedPaymentMode = 'Cash';

  // Sale by variable
  String _selectedSaleBy = 'Rajesh Goyal'; // Default selection
  final List<String> _saleByOptions = [
    'Rajesh Goyal',
    'Rupendra',
    'Deepak',
    'Major',
  ];

  // Estimate number variable
  String _currentEstimateNumber = '';

  // Cache for expensive computations
  double? _cachedSubtotal;
  double? _cachedTotal;
  double? _cachedDiscountAmount;
  bool _cacheInvalidated = true;

  @override
  void initState() {
    super.initState();
    _performanceService.startOperation('NewSaleScreen.initState');
    _performanceService.endOperation('NewSaleScreen.initState');
  }

  void _invalidateCache() {
    _cachedSubtotal = null;
    _cachedTotal = null;
    _cachedDiscountAmount = null;
    _cacheInvalidated = true;
  }

  void _showAddProductDialog() {
    _performanceService.startOperation('NewSaleScreen.showAddProductDialog');

    _nameController.clear();
    _priceController.clear();
    _quantityController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Add New Product',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInputField('Product Name', _nameController),
                const SizedBox(height: 16),
                _buildInputField('Rate', _priceController, isNumber: true),
                const SizedBox(height: 16),
                _buildInputField(
                  'Quantity',
                  _quantityController,
                  isNumber: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E7F),
              ),
              onPressed: () {
                _addNewProduct();
                Navigator.of(context).pop();
              },
              child: const Text('Add Product'),
            ),
          ],
        );
      },
    );

    _performanceService.endOperation('NewSaleScreen.showAddProductDialog');
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF6B8E7F)),
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: const Color(0xFF0D0D0D),
      ),
    );
  }

  void _addNewProduct() {
    _performanceService.startOperation('NewSaleScreen.addNewProduct');

    if (_nameController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final double? price = double.tryParse(_priceController.text);
    final int? quantity = int.tryParse(_quantityController.text);

    if (price == null || quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid price and quantity'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _cartItems.add({
        'id':
            DateTime.now().millisecondsSinceEpoch, // Use timestamp as unique ID
        'name': _nameController.text,
        'price': price,
        'quantity': quantity,
      });
      _invalidateCache();
    });

    _performanceService.endOperation('NewSaleScreen.addNewProduct');
  }

  double get _subtotal {
    if (_cachedSubtotal != null && !_cacheInvalidated) {
      return _cachedSubtotal!;
    }

    _performanceService.startOperation('NewSaleScreen.computeSubtotal');

    _cachedSubtotal = _cartItems.fold<double>(0.0, (sum, item) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      return sum + (price * quantity);
    });

    _performanceService.endOperation('NewSaleScreen.computeSubtotal');
    return _cachedSubtotal ?? 0.0;
  }

  double get _total {
    if (_cachedTotal != null && !_cacheInvalidated) {
      return _cachedTotal!;
    }

    _cachedTotal = _subtotal - _getDiscountAmount();
    return _cachedTotal!;
  }

  double _getDiscountAmount() {
    if (_cachedDiscountAmount != null && !_cacheInvalidated) {
      return _cachedDiscountAmount!;
    }

    _performanceService.startOperation('NewSaleScreen.computeDiscount');

    if (_isPercentageDiscount) {
      _cachedDiscountAmount = (_subtotal * _discountAmount) / 100;
    } else {
      _cachedDiscountAmount = _discountAmount;
    }

    _performanceService.endOperation('NewSaleScreen.computeDiscount');
    return _cachedDiscountAmount ?? 0.0;
  }

  // Get discount percentage equivalent when fixed amount is used
  String _getDiscountPercentage() {
    if (_isPercentageDiscount) {
      return "${_discountAmount.toStringAsFixed(0)}%";
    } else {
      // Calculate what percentage of the subtotal the discount amount represents
      if (_subtotal <= 0) return "0%";
      double percentage = (_discountAmount / _subtotal) * 100;
      return "${percentage.toStringAsFixed(1)}%";
    }
  }

  void _showEditItemDialog(Map<String, dynamic> item) {
    _performanceService.startOperation('NewSaleScreen.showEditItemDialog');

    final TextEditingController nameController = TextEditingController(
      text: item['name'],
    );
    final TextEditingController priceController = TextEditingController(
      text: item['price'].toString(),
    );
    final TextEditingController quantityController = TextEditingController(
      text: item['quantity'].toString(),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Edit Product',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInputField('Product Name', nameController),
                const SizedBox(height: 16),
                _buildInputField('Rate', priceController, isNumber: true),
                const SizedBox(height: 16),
                _buildInputField(
                  'Quantity',
                  quantityController,
                  isNumber: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                _removeFromCart(item['id']);
                Navigator.of(context).pop();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E7F),
              ),
              onPressed: () {
                _updateItem(
                  item['id'],
                  nameController,
                  priceController,
                  quantityController,
                );
                Navigator.of(context).pop();
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );

    _performanceService.endOperation('NewSaleScreen.showEditItemDialog');
  }

  void _updateItem(
    int itemId,
    TextEditingController nameController,
    TextEditingController priceController,
    TextEditingController quantityController,
  ) {
    _performanceService.startOperation('NewSaleScreen.updateItem');

    if (nameController.text.isEmpty ||
        priceController.text.isEmpty ||
        quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final double? price = double.tryParse(priceController.text);
    final int? quantity = int.tryParse(quantityController.text);

    if (price == null || quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid price and quantity'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      final index = _cartItems.indexWhere((item) => item['id'] == itemId);
      if (index >= 0) {
        _cartItems[index]['name'] = nameController.text;
        _cartItems[index]['price'] = price;
        _cartItems[index]['quantity'] = quantity;
      }
      _invalidateCache();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Product "${nameController.text}" updated successfully'),
        backgroundColor: const Color(0xFF6B8E7F),
      ),
    );

    _performanceService.endOperation('NewSaleScreen.updateItem');
  }

  void _removeFromCart(int productId) {
    _performanceService.startOperation('NewSaleScreen.removeFromCart');

    setState(() {
      _cartItems.removeWhere((item) => item['id'] == productId);
      _invalidateCache();
    });

    _performanceService.endOperation('NewSaleScreen.removeFromCart');
  }

  void _completeSale() {
    _performanceService.startOperation('NewSaleScreen.completeSale');

    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add items to cart before completing sale'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _showContinueOptionsDialog();

    _performanceService.endOperation('NewSaleScreen.completeSale');
  }

  void _showContinueOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Choose Option',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Estimate Option
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showEstimateDialog();
                  },
                  icon: const Icon(Icons.receipt_outlined, size: 18),
                  label: const Text('Estimate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A2A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Bill Option
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showBillDialog();
                  },
                  icon: const Icon(Icons.receipt, size: 18),
                  label: const Text('Bill'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B8E7F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  void _showEstimateDialog() {
    _customerNameController.clear();
    _customerWhatsAppController.clear();
    _customerAddressController.clear();
    _selectedSaleBy = 'Rajesh Goyal'; // Reset to default

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text(
                'Customer Details',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter customer details for estimate:',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    // Customer Name
                    _buildInputField('Customer Name', _customerNameController),
                    const SizedBox(height: 12),

                    // Phone Number (for reference only)
                    _buildInputField(
                      'Phone Number (Optional)',
                      _customerWhatsAppController,
                      isNumber: true,
                    ),
                    const SizedBox(height: 12),

                    // Sale By Dropdown
                    const Text(
                      'Sale By:',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSaleBy,
                          dropdownColor: const Color(0xFF0D0D0D),
                          style: const TextStyle(color: Colors.white),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey,
                          ),
                          onChanged: (String? newValue) {
                            setDialogState(() {
                              _selectedSaleBy = newValue!;
                            });
                          },
                          items:
                              _saleByOptions.map<DropdownMenuItem<String>>((
                                String value,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Address
                    TextField(
                      controller: _customerAddressController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Address',
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
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B8E7F),
                  ),
                  onPressed: () {
                    if (_customerNameController.text.isEmpty ||
                        _customerAddressController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please fill customer name and address',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop();
                    _showEstimatePreview();
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEstimatePreview() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Order Estimate',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TIRUPATI ELECTRICALS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Estimate $_currentEstimateNumber',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Date: ${DateTime.now().toString().split(' ')[0]}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Customer Details
                const Text(
                  'Customer Details:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Name: ${_customerNameController.text}',
                  style: TextStyle(color: Colors.grey[300], fontSize: 12),
                ),
                const SizedBox(height: 2),
                if (_customerWhatsAppController.text.isNotEmpty) ...[
                  Text(
                    'Phone: ${_customerWhatsAppController.text}',
                    style: TextStyle(color: Colors.grey[300], fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  'Address: ${_customerAddressController.text}',
                  style: TextStyle(color: Colors.grey[300], fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sale By: $_selectedSaleBy',
                  style: TextStyle(color: Colors.grey[300], fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Items
                const Text(
                  'Items:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                ..._cartItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item['name']} x${item['quantity']}',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          'Rs. ${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                const Divider(color: Color(0xFF2A2A2A)),
                const SizedBox(height: 8),

                // Summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal:',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    Text(
                      'Rs. ${_subtotal.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),

                if (_discountAmount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Discount (${_getDiscountPercentage()}):',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      Text(
                        '- Rs. ${_getDiscountAmount().toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rs. ${_total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF6B8E7F),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
                backgroundColor: const Color(0xFF6B8E7F),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _sendEstimate();
              },
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Save Estimate'),
            ),
          ],
        );
      },
    );
  }

  void _sendEstimate() async {
    _performanceService.startOperation('NewSaleScreen.sendEstimate');

    // Show sending animation/loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          backgroundColor: Color(0xFF1A1A1A),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B8E7F)),
              ),
              SizedBox(height: 16),
              Text(
                'Sending estimate...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      },
    );

    try {
      // Send data to the API first
      final response = await ApiService.sendEstimate(
        customerName: _customerNameController.text,
        customerPhone: _customerWhatsAppController.text,
        customerAddress: _customerAddressController.text,
        saleBy: _selectedSaleBy,
        items: _cartItems,
        subtotal: _subtotal,
        discountAmount: _discountAmount,
        isPercentageDiscount: _isPercentageDiscount,
        total: _total,
      );

      // Close loading dialog safely
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (response['success']) {
        // Store the estimate number for display
        if (response['estimate_number'] != null) {
          _currentEstimateNumber = response['estimate_number'];
        }

        // Generate PDF in background to prevent freezing
        File? pdfFile;
        try {
          // Use compute to run PDF generation in background
          pdfFile = await compute(_generateEstimatePdfInBackground, {
            'estimateNumber':
                response['estimate_number'] ??
                'EST-${DateTime.now().millisecondsSinceEpoch}',
            'customerName': _customerNameController.text,
            'customerPhone': _customerWhatsAppController.text,
            'customerAddress': _customerAddressController.text,
            'saleBy': _selectedSaleBy,
            'items': _cartItems,
            'subtotal': _subtotal,
            'discountAmount': _discountAmount,
            'isPercentageDiscount': _isPercentageDiscount,
            'total': _total,
            'createdAt': DateTime.now().toIso8601String(),
          });
        } catch (pdfError) {
          print('PDF generation error: $pdfError');
          // Continue without PDF if generation fails
        }

        // Show success dialog with options
        if (mounted) {
          _showEstimateSuccessDialog(response, pdfFile);
        }
      } else {
        // Show error dialog
        if (mounted) {
          _showEstimateErrorDialog(
            response['message'] ?? 'Failed to send estimate',
          );
        }
      }
    } catch (error) {
      // Close loading dialog safely
      if (mounted) {
        Navigator.of(context).pop();
        _showEstimateErrorDialog('An error occurred: ${error.toString()}');
      }
    }

    _performanceService.endOperation('NewSaleScreen.sendEstimate');
  }

  // Static method for background PDF generation
  static Future<File?> _generateEstimatePdfInBackground(
    Map<String, dynamic> data,
  ) async {
    try {
      return await PdfService.generateEstimatePdf(
        estimateNumber: data['estimateNumber'],
        customerName: data['customerName'],
        customerPhone: data['customerPhone'],
        customerAddress: data['customerAddress'],
        saleBy: data['saleBy'],
        items: List<Map<String, dynamic>>.from(data['items']),
        subtotal: data['subtotal'].toDouble(),
        discountAmount: data['discountAmount'].toDouble(),
        isPercentageDiscount: data['isPercentageDiscount'],
        total: data['total'].toDouble(),
        createdAt: DateTime.parse(data['createdAt']),
      );
    } catch (e) {
      print('Background PDF generation error: $e');
      return null;
    }
  }

  void _showEstimateSuccessDialog(
    Map<String, dynamic> response,
    File? pdfFile,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Estimate Created Successfully!',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF6B8E7F),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Estimate has been created for ${_customerNameController.text}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Phone: ${_customerWhatsAppController.text}',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              if (response['estimate_number'] != null &&
                  response['estimate_number'].isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Estimate Number: ${response['estimate_number']}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Estimate saved successfully! You can now print it:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            // Print Estimate button (only show if PDF was generated)
            if (pdfFile != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _printEstimatePdf(pdfFile);
                  },
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Print Estimate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _clearCart();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B8E7F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEstimateErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Error', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
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

  void _printEstimatePdf(File? pdfFile) async {
    if (pdfFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No PDF file to print.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    try {
      final bytes = await pdfFile.readAsBytes();
      await Printing.layoutPdf(onLayout: (format) async => bytes);
    } catch (e) {
      _showEstimateErrorDialog('Error printing PDF:  [31m${e.toString()}');
    }
  }

  void _showBill() {
    // Show sending animation/loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          backgroundColor: Color(0xFF1A1A1A),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B8E7F)),
              ),
              SizedBox(height: 16),
              Text('Sending bill...', style: TextStyle(color: Colors.white)),
            ],
          ),
        );
      },
    );

    // Simulate sending delay
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop(); // Close loading dialog

      // Show success message
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text(
              'Bill Sent!',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF6B8E7F),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Bill has been sent to ${_customerNameController.text}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'WhatsApp: ${_customerWhatsAppController.text}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
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
    });
  }

  void _showBillDialog() {
    _customerNameController.clear();
    _customerWhatsAppController.clear();
    _customerAddressController.clear();
    _selectedSaleBy = 'Rajesh Goyal'; // Reset to default
    _selectedPaymentMode = 'Cash'; // Reset to default

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text(
                'Customer Details',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter customer details for bill:',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    _buildInputField('Customer Name', _customerNameController),
                    const SizedBox(height: 12),
                    _buildInputField(
                      'WhatsApp Number',
                      _customerWhatsAppController,
                      isNumber: true,
                    ),
                    const SizedBox(height: 12),

                    // Sale By Dropdown
                    const Text(
                      'Sale By:',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedSaleBy,
                          dropdownColor: const Color(0xFF0D0D0D),
                          style: const TextStyle(color: Colors.white),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey,
                          ),
                          onChanged: (String? newValue) {
                            setDialogState(() {
                              _selectedSaleBy = newValue!;
                            });
                          },
                          items:
                              _saleByOptions.map<DropdownMenuItem<String>>((
                                String value,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _customerAddressController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Address',
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
                    const SizedBox(height: 16),
                    const Text(
                      'Mode of Payment:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text(
                            'Cash',
                            style: TextStyle(color: Colors.white),
                          ),
                          value: 'Cash',
                          groupValue: _selectedPaymentMode,
                          onChanged: (value) {
                            setDialogState(() {
                              _selectedPaymentMode = value!;
                            });
                          },
                          activeColor: const Color(0xFF6B8E7F),
                        ),
                        RadioListTile<String>(
                          title: const Text(
                            'UPI: Ragini Bandl',
                            style: TextStyle(color: Colors.white),
                          ),
                          value: 'UPI: Ragini Bandl',
                          groupValue: _selectedPaymentMode,
                          onChanged: (value) {
                            setDialogState(() {
                              _selectedPaymentMode = value!;
                            });
                          },
                          activeColor: const Color(0xFF6B8E7F),
                        ),
                        RadioListTile<String>(
                          title: const Text(
                            'UPI: Rajesh Goyal',
                            style: TextStyle(color: Colors.white),
                          ),
                          value: 'UPI: Rajesh Goyal',
                          groupValue: _selectedPaymentMode,
                          onChanged: (value) {
                            setDialogState(() {
                              _selectedPaymentMode = value!;
                            });
                          },
                          activeColor: const Color(0xFF6B8E7F),
                        ),
                      ],
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
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B8E7F),
                  ),
                  onPressed: () {
                    if (_customerNameController.text.isEmpty ||
                        _customerWhatsAppController.text.isEmpty ||
                        _customerAddressController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all customer details'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop();
                    _showBillPreview(_selectedPaymentMode);
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBillPreview(String paymentMode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Sale Bill', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TIRUPATI ELECTRICALS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bill #${DateTime.now().millisecondsSinceEpoch}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Date: ${DateTime.now().toString().split(' ')[0]}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 16),
                // Customer Details
                const Text(
                  'Customer Details:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Name: ${_customerNameController.text}',
                  style: TextStyle(color: Colors.grey[300], fontSize: 12),
                ),
                const SizedBox(height: 2),
                if (_customerWhatsAppController.text.isNotEmpty) ...[
                  Text(
                    'Phone: ${_customerWhatsAppController.text}',
                    style: TextStyle(color: Colors.grey[300], fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  'Address: ${_customerAddressController.text}',
                  style: TextStyle(color: Colors.grey[300], fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sale By: $_selectedSaleBy',
                  style: TextStyle(color: Colors.grey[300], fontSize: 12),
                ),
                const SizedBox(height: 16),
                // Payment Mode
                Row(
                  children: [
                    const Text(
                      'Payment Mode: ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      paymentMode,
                      style: const TextStyle(
                        color: Color(0xFF6B8E7F),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Items
                const Text(
                  'Items:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ..._cartItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item['name']} x${item['quantity']}',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          'Rs. ${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF2A2A2A)),
                const SizedBox(height: 8),
                // Summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal:',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    Text(
                      'Rs. ${_subtotal.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
                if (_discountAmount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Discount (${_getDiscountPercentage()}):',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      Text(
                        '- Rs. ${_getDiscountAmount().toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Paid:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rs. ${_total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF6B8E7F),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Thank you for your business!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
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
                _showSaleCompletedDialog();
              },
              child: const Text('Complete Sale'),
            ),
          ],
        );
      },
    );
  }

  void _showDiscountDialog() {
    _discountController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text(
                'Apply Discount',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Discount type selection
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setDialogState(() {
                              _isPercentageDiscount = true;
                            });
                          },
                          child: Row(
                            children: [
                              Radio<bool>(
                                value: true,
                                groupValue: _isPercentageDiscount,
                                onChanged: (value) {
                                  setDialogState(() {
                                    _isPercentageDiscount = value!;
                                  });
                                },
                                activeColor: const Color(0xFF6B8E7F),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              const Expanded(
                                child: Text(
                                  '%',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setDialogState(() {
                              _isPercentageDiscount = false;
                            });
                          },
                          child: Row(
                            children: [
                              Radio<bool>(
                                value: false,
                                groupValue: _isPercentageDiscount,
                                onChanged: (value) {
                                  setDialogState(() {
                                    _isPercentageDiscount = value!;
                                  });
                                },
                                activeColor: const Color(0xFF6B8E7F),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              const Expanded(
                                child: Text(
                                  'Rs.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Discount input
                  TextField(
                    controller: _discountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText:
                          _isPercentageDiscount
                              ? 'Discount (%)'
                              : 'Amount (Rs.)',
                      labelStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF6B8E7F)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0D0D0D),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _applyDiscount();
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Apply',
                    style: TextStyle(color: Color(0xFF6B8E7F), fontSize: 12),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _applyDiscount() {
    final double? discount = double.tryParse(_discountController.text);
    if (discount != null && discount >= 0) {
      setState(() {
        _discountAmount = discount;
        _invalidateCache();
      });
    }
  }

  void _showSaleCompletedDialog() async {
    // Show loading dialog first
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
                'Saving sale data...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      },
    );

    try {
      // Save sale data to backend with timeout
      final result = await ApiService.createCompletedSale(
        customerName: _customerNameController.text,
        customerPhone: _customerWhatsAppController.text,
        customerAddress: _customerAddressController.text,
        saleBy: _selectedSaleBy,
        items: _cartItems,
        subtotal: _subtotal,
        discountAmount: _discountAmount,
        isPercentageDiscount: _isPercentageDiscount,
        total: _total,
        paymentMode: _selectedPaymentMode,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout - please check your connection');
        },
      );

      // Close loading dialog safely
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (result['success']) {
        // Show success dialog with PDF options
        if (mounted) {
          _showSaleSuccessDialog(result['sale_number'] ?? 'Unknown');
        }
      } else {
        // Show error dialog
        if (mounted) {
          _showSaleErrorDialog(result['message'] ?? 'Failed to save sale data');
        }
      }
    } catch (e) {
      // Close loading dialog safely
      if (mounted) {
        Navigator.of(context).pop();
        _showSaleErrorDialog('Error: $e');
      }
    }
  }

  void _showSaleSuccessDialog(String saleNumber) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4CAF50),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Sale Completed!',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sale Number: $saleNumber',
                style: const TextStyle(
                  color: Color(0xFF6B8E7F),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total Amount: Rs. ${_total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Payment Mode: $_selectedPaymentMode',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                'Items: ${_cartItems.length}',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'What would you like to do next?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            // Print PDF Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A2A2A),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await _printSalePdf(saleNumber);
              },
              icon: const Icon(Icons.print, size: 16),
              label: const Text('Print PDF'),
            ),
            SizedBox(width: 8),
            // New Sale Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E7F),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _cartItems.clear();
                  _discountAmount = 0.0;
                  _invalidateCache();
                });
              },
              icon: const Icon(Icons.add_shopping_cart, size: 16),
              label: const Text('New Sale'),
            ),
            SizedBox(width: 8),
            // Home Button
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to home screen
              },
              icon: const Icon(Icons.home, size: 16, color: Colors.grey),
              label: const Text('Home', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  void _showSaleErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Row(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Error',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Failed to save sale data:',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Text(
                'Please check your connection and try again.',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
          actions: [
            // Retry Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E7F),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _showSaleCompletedDialog(); // Retry the operation
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
            const SizedBox(width: 8),
            // Cancel Button
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.close, size: 16, color: Colors.grey),
              label: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _printSalePdf(String saleNumber) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Color(0xFF1A1A1A),
            content: Row(
              children: [
                const CircularProgressIndicator(color: Color(0xFF6B8E7F)),
                const SizedBox(width: 20),
                const Text(
                  'Generating PDF...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        },
      );

      // Generate sale PDF
      final pdfFile = await PdfService.generateSalePdf(
        saleNumber: saleNumber,
        customerName: _customerNameController.text,
        customerPhone: _customerWhatsAppController.text,
        customerAddress: _customerAddressController.text,
        saleBy: _selectedSaleBy,
        items: _cartItems,
        subtotal: _subtotal,
        discountAmount: _discountAmount,
        isPercentageDiscount: _isPercentageDiscount,
        total: _total,
        createdAt: DateTime.now(),
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

  void _clearCart() {
    setState(() {
      _cartItems.clear();
      _discountAmount = 0.0;
      _invalidateCache();
    });
  }

  void _sendBill() {
    // Placeholder for bill sending logic
    // For now, just show a dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Bill Sent!',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'The bill has been processed (placeholder).',
            style: TextStyle(color: Colors.white),
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

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _discountController.dispose();
    _customerNameController.dispose();
    _customerWhatsAppController.dispose();
    _customerAddressController.dispose();
    _performanceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('New Sale', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add Product Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showAddProductDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B8E7F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Order Estimate Section
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFF2A2A2A)),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            color: Color(0xFF6B8E7F),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Order Estimate',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (_cartItems.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6B8E7F).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_cartItems.length} items',
                                style: const TextStyle(
                                  color: Color(0xFF6B8E7F),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Order Items or Empty State
                    _cartItems.isEmpty
                        ? Container(
                          padding: const EdgeInsets.all(32),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.add_shopping_cart,
                                color: Colors.grey,
                                size: 40,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Add products to start order',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                        : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Column Headers
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D0D0D),
                                border: Border.all(
                                  color: const Color(0xFF2A2A2A),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Product',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 60,
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Rate',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 45,
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Qty',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 65,
                                    alignment: Alignment.centerRight,
                                    child: const Text(
                                      'Amount',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Items List
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              itemCount: _cartItems.length,
                              itemBuilder: (context, index) {
                                final item = _cartItems[index];
                                return _buildOrderItem(item);
                              },
                            ),

                            // Bill Summary
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Color(0xFF2A2A2A)),
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Subtotal
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Subtotal',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'Rs. ${_subtotal.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Discount row (if discount applied)
                                  if (_discountAmount > 0) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Discount (${_getDiscountPercentage()}):',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          '- Rs. ${_getDiscountAmount().toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],

                                  const SizedBox(height: 8),

                                  // Divider
                                  Container(
                                    height: 1,
                                    color: const Color(0xFF2A2A2A),
                                  ),
                                  const SizedBox(height: 8),

                                  // Total
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Total Amount',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Rs. ${_total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Color(0xFF6B8E7F),
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Discount Button (if items exist)
              if (_cartItems.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showDiscountDialog,
                    icon: const Icon(Icons.discount, size: 18),
                    label: const Text('Apply Discount'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A2A2A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Complete Sale Button (if items exist)
              if (_cartItems.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _completeSale,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B8E7F),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => _showEditItemDialog(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          border: Border.all(color: const Color(0xFF2A2A2A), width: 0.5),
        ),
        child: Row(
          children: [
            // Product name
            Expanded(
              flex: 3,
              child: Text(
                item['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(width: 8),

            // Rate
            SizedBox(
              width: 60,
              child: Text(
                'Rs. ${item['price'].toStringAsFixed(2)}',
                style: TextStyle(color: Colors.grey[300], fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(width: 8),

            // Quantity
            SizedBox(
              width: 45,
              child: Text(
                '${item['quantity']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(width: 8),

            // Line total
            SizedBox(
              width: 65,
              child: Text(
                'Rs. ${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF6B8E7F),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
