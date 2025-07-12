import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class SmsService {
  /// Send WhatsApp message by calling the backend API
  static Future<Map<String, dynamic>> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final url = Uri.parse(
        '${ApiService.baseUrl.replaceFirst('/api', '')}/api/whatsapp/send',
      );
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone_number': phoneNumber, 'message': message}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, ...data};
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? 'Failed to send WhatsApp message',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Generate estimate WhatsApp message
  static String generateEstimateMessage({
    required String customerName,
    required String estimateNumber,
    required double totalAmount,
    required String companyName,
  }) {
    return '''
Hello $customerName,

Thank you for your interest in our services. Your estimate has been prepared.

Estimate Number: $estimateNumber
Total Amount: Rs. ${totalAmount.toStringAsFixed(2)}

Please review the estimate and contact us for any queries.

Best regards,
$companyName
    '''.trim();
  }

  /// Generate detailed estimate WhatsApp message with items
  static String generateDetailedEstimateMessage({
    required String customerName,
    required String estimateNumber,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discountAmount,
    required bool isPercentageDiscount,
    required double totalAmount,
    required String companyName,
    required String saleBy,
  }) {
    final discountText =
        discountAmount > 0
            ? (isPercentageDiscount
                ? 'Discount: ${discountAmount.toStringAsFixed(0)}%'
                : 'Discount: Rs. ${discountAmount.toStringAsFixed(2)}')
            : '';

    final itemsText = items
        .map((item) {
          final itemTotal = (item['price'] * item['quantity']);
          return '• ${item['name']} x${item['quantity']} = Rs. ${itemTotal.toStringAsFixed(2)}';
        })
        .join('\n');

    return '''
Hello $customerName,

Your estimate has been prepared by $saleBy.

Estimate Number: $estimateNumber

Items:
$itemsText

Subtotal: Rs. ${subtotal.toStringAsFixed(2)}
$discountText
Total Amount: Rs. ${totalAmount.toStringAsFixed(2)}

Please review the attached PDF for complete details.

Best regards,
$companyName
    '''.trim();
  }

  /// Generate order completion WhatsApp message
  static String generateOrderCompletionMessage({
    required String customerName,
    required String orderNumber,
    required double totalAmount,
    required String companyName,
  }) {
    return '''
Hello $customerName,

Your order has been completed successfully!

Order Number: $orderNumber
Total Amount: Rs. ${totalAmount.toStringAsFixed(2)}

Thank you for choosing $companyName.

Best regards,
$companyName
    '''.trim();
  }

  /// Generate bill WhatsApp message
  static String generateBillMessage({
    required String customerName,
    required String billNumber,
    required double totalAmount,
    required String paymentMode,
    required String companyName,
  }) {
    return '''
Hello $customerName,

Your bill has been generated successfully!

Bill Number: $billNumber
Total Amount: Rs. ${totalAmount.toStringAsFixed(2)}
Payment Mode: $paymentMode

Thank you for your business!

Best regards,
$companyName
    '''.trim();
  }

  /// Send estimate via WhatsApp with PDF attachment
  static Future<Map<String, dynamic>> sendEstimateWhatsApp({
    required String phoneNumber,
    required String customerName,
    required String estimateNumber,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discountAmount,
    required bool isPercentageDiscount,
    required double totalAmount,
    required String saleBy,
    required String companyName,
  }) async {
    try {
      // Format phone number
      String formattedPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      if (formattedPhone.length == 10) {
        formattedPhone = '91$formattedPhone';
      } else if (formattedPhone.length != 12) {
        return {
          'success': false,
          'message': 'Invalid phone number. Please enter a 10-digit number.',
        };
      }

      // Generate message
      final message = generateDetailedEstimateMessage(
        customerName: customerName,
        estimateNumber: estimateNumber,
        items: items,
        subtotal: subtotal,
        discountAmount: discountAmount,
        isPercentageDiscount: isPercentageDiscount,
        totalAmount: totalAmount,
        companyName: companyName,
        saleBy: saleBy,
      );

      // Send via backend API
      final url = Uri.parse(
        '${ApiService.baseUrl.replaceFirst('/api', '')}/api/whatsapp/send',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone_number': formattedPhone,
          'message': message,
          'caption': 'Estimate $estimateNumber - $companyName',
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, ...data};
      } else {
        return {
          'success': false,
          'message': data['detail'] ?? 'Failed to send estimate',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  /// Send simple text message (fallback)
  static Future<Map<String, dynamic>> sendTextMessage({
    required String phoneNumber,
    required String message,
  }) async {
    return sendSms(phoneNumber: phoneNumber, message: message);
  }

  /// Test SMS service connectivity
  static Future<Map<String, dynamic>> testSmsService({
    required String testPhoneNumber,
  }) async {
    try {
      // Format phone number
      String formattedPhone = testPhoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      if (formattedPhone.length == 10) {
        formattedPhone = '91$formattedPhone';
      } else if (formattedPhone.length != 12) {
        return {
          'success': false,
          'message':
              'Invalid test phone number. Please enter a 10-digit number.',
        };
      }

      // Send test message
      final testMessage =
          '''
Hello! This is a test message from TEPOS system.

If you receive this message, the SMS/WhatsApp service is working correctly.

Best regards,
Tirupati Electricals
      '''.trim();

      final result = await sendSms(
        phoneNumber: formattedPhone,
        message: testMessage,
      );

      return {
        'success': result['success'],
        'message':
            result['success']
                ? 'Test message sent successfully! Check your phone.'
                : result['message'],
        'details': result,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Test failed: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phoneNumber) {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    return cleaned.length == 10 || cleaned.length == 12;
  }

  /// Format phone number for API
  static String formatPhoneNumber(String phoneNumber) {
    String formatted = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (formatted.length == 10) {
      formatted = '91$formatted';
    }
    return formatted;
  }
}
