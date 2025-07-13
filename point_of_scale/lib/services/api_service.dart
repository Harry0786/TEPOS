import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ===== PRODUCTION CONFIGURATION =====
  // Render production URLs only
  static const String baseUrl = 'https://pos-2wc9.onrender.com/api';
  static const String webSocketUrl = 'wss://pos-2wc9.onrender.com/ws';

  // Helper method to print current configuration
  static void printConfiguration() {
    print('🌐 API Configuration:');
    print('   Environment: PRODUCTION (Render)');
    print('   API Base URL: $baseUrl');
    print('   WebSocket URL: $webSocketUrl');
  }

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
    String paymentMode = "Cash",
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
        'payment_mode': paymentMode,
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

  // Fetch all orders (completed sales only) from backend with caching
  static Future<List<Map<String, dynamic>>> fetchOrders() async {
    const cacheKey = 'orders';

    // Check cache first
    if (_isCacheValid(cacheKey)) {
      print('📦 Returning cached orders');
      return List<Map<String, dynamic>>.from(_cache[cacheKey]['data']);
    }

    return _retryRequest(() async {
      final url = Uri.parse('$baseUrl/orders/orders-only');
      final response = await http.get(url).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> orders = [];

        if (data['orders'] != null && data['orders']['items'] != null) {
          orders = List<Map<String, dynamic>>.from(data['orders']['items']);
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

  // Reports API Methods
  static Future<Map<String, dynamic>?> fetchTodayReport() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/reports/today'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Error fetching today\'s report: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception fetching today\'s report: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchDateRangeReport(
    String startDate,
    String endDate,
  ) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.get(
        Uri.parse(
          '$baseUrl/reports/date-range?start_date=$startDate&end_date=$endDate',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Error fetching date range report: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception fetching date range report: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchMonthlyReport(
    int year,
    int month,
  ) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/reports/monthly/$year/$month'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Error fetching monthly report: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception fetching monthly report: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchStaffPerformanceReport() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/reports/staff-performance'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print(
          '❌ Error fetching staff performance report: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      print('❌ Exception fetching staff performance report: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchEstimatesOnlyReport() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/reports/estimates-only'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Error fetching estimates report: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception fetching estimates report: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchOrdersOnlyReport() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/reports/orders-only'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Error fetching orders report: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception fetching orders report: $e');
      return null;
    }
  }

  // Estimate Management API Methods
  static Future<List<Map<String, dynamic>>?> fetchAllEstimates() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/estimates/all'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print('❌ Error fetching estimates: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception fetching estimates: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchPendingEstimates() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/estimates/pending'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print('❌ Error fetching pending estimates: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception fetching pending estimates: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>?> fetchConvertedEstimates() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/estimates/converted'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print('❌ Error fetching converted estimates: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception fetching converted estimates: $e');
      return null;
    }
  }

  static Future<bool> deleteEstimate(String estimateId) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.delete(
        Uri.parse('$baseUrl/estimates/$estimateId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('❌ Error deleting estimate: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Exception deleting estimate: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> convertEstimateToOrder(
    String estimateId,
    String paymentMode,
  ) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.post(
        Uri.parse(
          '$baseUrl/estimates/$estimateId/convert-to-order?payment_mode=$paymentMode',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Error converting estimate to order: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception converting estimate to order: $e');
      return null;
    }
  }

  // Customer Management API Methods
  static Future<List<Map<String, dynamic>>?> fetchCustomers() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/customers/all'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print('❌ Error fetching customers: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception fetching customers: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> createCustomer(
    Map<String, dynamic> customerData,
  ) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.post(
        Uri.parse('$baseUrl/customers/create'),
        headers: headers,
        body: jsonEncode(customerData),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        print('❌ Error creating customer: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception creating customer: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateCustomer(
    String customerId,
    Map<String, dynamic> customerData,
  ) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.put(
        Uri.parse('$baseUrl/customers/$customerId'),
        headers: headers,
        body: jsonEncode(customerData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Error updating customer: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception updating customer: $e');
      return null;
    }
  }

  static Future<bool> deleteCustomer(String customerId) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.delete(
        Uri.parse('$baseUrl/customers/$customerId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('❌ Error deleting customer: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Exception deleting customer: $e');
      return false;
    }
  }

  // Settings API Methods
  static Future<Map<String, dynamic>?> fetchSettings() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/settings'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Error fetching settings: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception fetching settings: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateSettings(
    Map<String, dynamic> settingsData,
  ) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.put(
        Uri.parse('$baseUrl/settings'),
        headers: headers,
        body: jsonEncode(settingsData),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('❌ Error updating settings: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception updating settings: $e');
      return null;
    }
  }

  // Health Check
  static Future<bool> checkServerHealth() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Exception checking server health: $e');
      return false;
    }
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
