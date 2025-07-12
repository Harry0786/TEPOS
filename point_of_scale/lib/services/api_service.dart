import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Use your computer's actual IP address instead of localhost
  // You can find your IP by running 'ipconfig' on Windows or 'ifconfig' on Mac/Linux
  // For development, you can also use 10.0.2.2 for Android emulator
  static const String baseUrl =
      'https://pos-2wc9.onrender.com/api'; // Updated to Render live backend

  // Alternative URLs for different scenarios:
  // static const String baseUrl = 'http://10.0.2.2:8000/api'; // Android Emulator
  // static const String baseUrl = 'http://localhost:8000/api'; // iOS Simulator
  // static const String baseUrl = 'http://127.0.0.1:8000/api'; // Same machine

  // Send Estimate endpoint
  static Future<Map<String, dynamic>> sendEstimate({
    required String customerName,
    required String customerPhone,
    required String customerAddress,
    required String saleBy,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discountAmount,
    required bool isPercentageDiscount,
    required double total,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/estimates/create');

      print('🌐 API Request URL: $url');
      print('📤 Sending data to API...');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final body = json.encode({
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_address': customerAddress,
        'sale_by': saleBy,
        'items': items,
        'subtotal': subtotal,
        'discount_amount': discountAmount,
        'is_percentage_discount': isPercentageDiscount,
        'discount_percentage':
            isPercentageDiscount
                ? discountAmount
                : (discountAmount / subtotal) * 100,
        'total': total,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('📋 Request Body: $body');

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timeout - server not responding');
            },
          );

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Estimate sent successfully!',
          'data': responseData['data'] ?? {},
          'estimate_id': responseData['estimate_id'] ?? '',
          'estimate_number': responseData['estimate_number'] ?? '',
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to send estimate',
          'error':
              responseData['error'] ??
              'Server returned status ${response.statusCode}',
        };
      }
    } on FormatException catch (e) {
      print('❌ JSON Format Error: $e');
      return {
        'success': false,
        'message': 'Invalid response format from server',
        'error': e.toString(),
      };
    } on http.ClientException catch (e) {
      print('❌ Network Error: $e');
      return {
        'success': false,
        'message': 'Network connection failed. Please check:',
        'error': '''
1. Backend server is running (uvicorn main:app --reload --host 0.0.0.0 --port 8000)
2. IP address is correct in api_service.dart
3. Device/emulator can reach the server
4. No firewall blocking the connection

Error: ${e.toString()}''',
      };
    } catch (e) {
      print('❌ Unexpected Error: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred',
        'error': e.toString(),
      };
    }
  }

  // Test connection method
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final url = Uri.parse('$baseUrl/');
      print('🔍 Testing connection to: $url');

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Connection timeout');
            },
          );

      print('✅ Connection test successful: ${response.statusCode}');
      return {
        'success': true,
        'message': 'Connection successful',
        'status_code': response.statusCode,
        'response': response.body,
      };
    } catch (e) {
      print('❌ Connection test failed: $e');
      return {
        'success': false,
        'message': 'Connection failed',
        'error': e.toString(),
      };
    }
  }

  // Fetch all estimates from backend
  static Future<List<Map<String, dynamic>>> fetchEstimates() async {
    try {
      final url = Uri.parse('$baseUrl/estimates/all');
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data['estimates'] != null) {
          return List<Map<String, dynamic>>.from(data['estimates']);
        }
      }
      return [];
    } catch (e) {
      print('❌ Error fetching estimates: $e');
      return [];
    }
  }

  // Fetch all orders (estimates + completed sales) from backend
  static Future<List<Map<String, dynamic>>> fetchOrders() async {
    try {
      final url = Uri.parse('$baseUrl/orders/all');
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data['orders'] != null) {
          return List<Map<String, dynamic>>.from(data['orders']);
        }
      }
      return [];
    } catch (e) {
      print('❌ Error fetching orders: $e');
      return [];
    }
  }

  // Update order/estimate status
  static Future<Map<String, dynamic>> updateOrderStatus(
    String orderId,
    String status,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/orders/$orderId/status?status=$status');
      final response = await http.put(url).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Status updated successfully',
          'data': data,
        };
      } else {
        final data = json.decode(response.body);
        return {
          'success': false,
          'message': data['detail'] ?? 'Failed to update status',
          'error': 'Server returned status ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error updating order status: $e');
      return {
        'success': false,
        'message': 'Network error occurred',
        'error': e.toString(),
      };
    }
  }
}
