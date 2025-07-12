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

  // Cache for API responses
  static final Map<String, dynamic> _cache = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

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
    return _retryRequest(() async {
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
        // Clear cache when new data is created
        _clearCache();
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
    });
  }

  // Create Completed Sale endpoint
  static Future<Map<String, dynamic>> createCompletedSale({
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
    return _retryRequest(() async {
      final url = Uri.parse('$baseUrl/orders/create-sale');

      print('🌐 API Request URL: $url');
      print('📤 Sending completed sale data to API...');

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
        // Clear cache when new data is created
        _clearCache();
        return {
          'success': true,
          'message': responseData['message'] ?? 'Sale completed successfully!',
          'data': responseData['data'] ?? {},
          'sale_id': responseData['sale_id'] ?? '',
          'sale_number': responseData['sale_number'] ?? '',
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to complete sale',
          'error':
              responseData['error'] ??
              'Server returned status ${response.statusCode}',
        };
      }
    });
  }

  // Test connection method
  static Future<Map<String, dynamic>> testConnection() async {
    return _retryRequest(() async {
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
    });
  }

  // Test backend health endpoint
  static Future<Map<String, dynamic>> testBackendHealth() async {
    return _retryRequest(() async {
      final url = Uri.parse('$baseUrl/health');
      print('🏥 Testing backend health at: $url');

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception('Backend health check timeout');
            },
          );

      print('✅ Backend health check successful: ${response.statusCode}');
      return {
        'success': true,
        'message': 'Backend is healthy',
        'status_code': response.statusCode,
        'response': response.body,
      };
    });
  }

  // Fetch all estimates from backend with caching
  static Future<List<Map<String, dynamic>>> fetchEstimates() async {
    const cacheKey = 'estimates';

    // Check cache first
    if (_isCacheValid(cacheKey)) {
      print('📋 Returning cached estimates');
      return List<Map<String, dynamic>>.from(_cache[cacheKey]['data']);
    }

    return _retryRequest(() async {
      final url = Uri.parse('$baseUrl/estimates/all');
      final response = await http.get(url).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> estimates = [];

        if (data is List) {
          estimates = List<Map<String, dynamic>>.from(data);
        } else if (data['estimates'] != null) {
          estimates = List<Map<String, dynamic>>.from(data['estimates']);
        }

        // Cache the result
        _cache[cacheKey] = {'data': estimates, 'timestamp': DateTime.now()};

        return estimates;
      }
      return [];
    });
  }

  // Fetch all orders (estimates + completed sales) from backend with caching
  static Future<List<Map<String, dynamic>>> fetchOrders() async {
    const cacheKey = 'orders';

    // Check cache first
    if (_isCacheValid(cacheKey)) {
      print('📦 Returning cached orders');
      return List<Map<String, dynamic>>.from(_cache[cacheKey]['data']);
    }

    return _retryRequest(() async {
      final url = Uri.parse('$baseUrl/orders/all');
      final response = await http.get(url).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> orders = [];

        if (data is List) {
          orders = List<Map<String, dynamic>>.from(data);
        } else if (data['orders'] != null) {
          orders = List<Map<String, dynamic>>.from(data['orders']);
        }

        // Cache the result
        _cache[cacheKey] = {'data': orders, 'timestamp': DateTime.now()};

        return orders;
      }
      return [];
    });
  }

  // Update order/estimate status
  static Future<Map<String, dynamic>> updateOrderStatus(
    String orderId,
    String status,
  ) async {
    return _retryRequest(() async {
      final url = Uri.parse('$baseUrl/orders/$orderId/status?status=$status');
      final response = await http.put(url).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Clear cache when data is updated
        _clearCache();
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
    });
  }

  // Retry logic for failed requests
  static Future<T> _retryRequest<T>(Future<T> Function() request) async {
    int attempts = 0;
    while (attempts < _maxRetries) {
      try {
        return await request();
      } catch (e) {
        attempts++;
        print('❌ Request failed (attempt $attempts/$_maxRetries): $e');

        if (attempts >= _maxRetries) {
          rethrow;
        }

        // Wait before retrying
        await Future.delayed(_retryDelay * attempts);
      }
    }
    throw Exception('Max retries exceeded');
  }

  // Cache management
  static bool _isCacheValid(String key) {
    if (!_cache.containsKey(key)) return false;

    final cacheEntry = _cache[key];
    final timestamp = cacheEntry['timestamp'] as DateTime;
    final now = DateTime.now();

    return now.difference(timestamp) < _cacheExpiry;
  }

  static void _clearCache() {
    _cache.clear();
    print('🗑️ Cache cleared');
  }

  static void clearCache() {
    _clearCache();
  }
}
