import 'package:flutter/material.dart';

// Test widget to verify payment breakdown dialog functionality
class PaymentDialogTest extends StatelessWidget {
  const PaymentDialogTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Dialog Test'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _showTestPaymentDialog(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B8E7F),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            'Test Payment Breakdown Dialog',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    );
  }

  void _showTestPaymentDialog(BuildContext context) {
    // Sample payment breakdown data
    final paymentBreakdown = {
      'cash': {'count': 3, 'amount': 4500.0},
      'card': {'count': 2, 'amount': 3000.0},
      'online': {'count': 2, 'amount': 2500.0},
      'upi': {'count': 1, 'amount': 1500.0},
      'bank_transfer': {'count': 1, 'amount': 2000.0},
      'cheque': {'count': 1, 'amount': 1500.0},
    };

    // Calculate total from payment breakdown
    final totalAmount = paymentBreakdown.values.fold<double>(
      0.0,
      (sum, data) => sum + (data['amount'] as double),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Row(
            children: [
              const Icon(Icons.payment, color: Color(0xFF4CAF50), size: 24),
              const SizedBox(width: 8),
              const Text(
                'Payment Breakdown',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D0D),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF3A3A3A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.attach_money,
                        color: Color(0xFF6B8E7F),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Total Sales: Rs. ${totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...paymentBreakdown.entries.map((entry) {
                  final mode = entry.key;
                  final data = entry.value;
                  final count = data['count'] as int;
                  final amount = data['amount'] as double;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF3A3A3A)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getPaymentModeColor(mode),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _getPaymentModeDisplayName(mode),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          'Rs. ${amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Color(0xFF6B8E7F)),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getPaymentModeDisplayName(String mode) {
    switch (mode) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'online':
        return 'Online';
      case 'upi':
        return 'UPI';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'cheque':
        return 'Cheque';
      case 'other':
        return 'Other';
      default:
        return mode.toUpperCase();
    }
  }

  Color _getPaymentModeColor(String mode) {
    switch (mode) {
      case 'cash':
        return const Color(0xFF4CAF50);
      case 'card':
        return const Color(0xFF2196F3);
      case 'online':
        return const Color(0xFF9C27B0);
      case 'upi':
        return const Color(0xFF673AB7);
      case 'bank_transfer':
        return const Color(0xFFFF9800);
      case 'cheque':
        return const Color(0xFF607D8B);
      case 'other':
        return const Color(0xFF795548);
      default:
        return const Color(0xFF757575);
    }
  }
}
