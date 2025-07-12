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
}
