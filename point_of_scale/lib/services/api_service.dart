import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // ===== PRODUCTION CONFIGURATION =====
  // Railway production URLs
  static const String baseUrl = 'https://tepos.railway.internal/api';
  static const String webSocketUrl = 'wss://tepos.railway.internal/ws';

  // Helper method to print current configuration
  static void printConfiguration() {
    print('🌐 API Configuration:');
    print('   Environment: PRODUCTION (Railway)');
    print('   API Base URL: $baseUrl');
    print('   WebSocket URL: $webSocketUrl');
  }

  // Enhanced cache for API responses with better TTL management
  static final Map<String, dynamic> _cache = {};
  static const Duration _cacheExpiry = Duration(
    minutes: 3,
  ); // Increased from 1m
  static const Duration _shortCacheExpiry = Duration(
    minutes: 1,
  ); // For frequently changing data

  // Retry configuration
  static const int _maxRetries = 2; // Reduced from 3
  static const Duration _retryDelay = Duration(seconds: 3); // Increased from 2s

  // Request tracking to prevent duplicate calls
  static final Set<String> _activeRequests = {};
  static const Duration _requestTimeout = Duration(
    seconds: 25,
  ); // Reduced from 30s

  // Request deduplication with cooldown
  static final Map<String, DateTime> _lastRequestTimes = {};
  static const Duration _requestCooldown = Duration(seconds: 5);

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
    String? createdAt,
  }) async {
    final requestKey = 'sendEstimate_${DateTime.now().millisecondsSinceEpoch}';
    return _preventDuplicateRequest(
      requestKey,
      () => _retryRequest(() async {
        final url = Uri.parse('$baseUrl/estimates/create');

        print('🌐 API Request URL: $url');
        print('📤 Sending data to API...');

        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        };

        final body = {
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'customer_address': customerAddress,
          'sale_by': saleBy,
          'items': items,
          'subtotal': subtotal,
          'discount_amount': discountAmount,
          'is_percentage_discount': isPercentageDiscount,
          'total': total,
          'created_at': createdAt ?? DateTime.now().toIso8601String(),
        };

        print('📤 Request body: ${json.encode(body)}');

        final response = await http
            .post(url, headers: headers, body: json.encode(body))
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () {
                throw Exception('Request timeout - please try again');
              },
            );

        print('📡 Response status: ${response.statusCode}');
        print('📡 Response body: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);

          // Invalidate cache for estimates
          _invalidateCache('estimates');

          return {
            'success': true,
            'message': 'Estimate sent successfully',
            'data': data,
          };
        } else {
          final errorData = json.decode(response.body);
          return {
            'success': false,
            'message': errorData['detail'] ?? 'Failed to send estimate',
            'error': 'Server returned status ${response.statusCode}',
          };
        }
      }),
    );
  }

  // Convert estimate to order endpoint
  static Future<Map<String, dynamic>> convertEstimateToOrder({
    required String estimateId,
    String? paymentMode,
    String? saleBy,
    double? amountPaid,
  }) async {
    final requestKey = 'convertEstimate_$estimateId';
    return _preventDuplicateRequest(
      requestKey,
      () => _retryRequest(() async {
        final url = Uri.parse(
          '$baseUrl/estimates/$estimateId/convert-to-order',
        );

        print('🌐 Converting estimate to order: $url');

        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        };

        // Prepare request body with optional parameters
        final Map<String, dynamic> requestBody = {};
        if (paymentMode != null) requestBody['payment_mode'] = paymentMode;
        if (saleBy != null) requestBody['sale_by'] = saleBy;
        if (amountPaid != null) requestBody['amount_paid'] = amountPaid;

        final response = await http
            .post(url, headers: headers, body: json.encode(requestBody))
            .timeout(
              const Duration(seconds: 25),
              onTimeout: () {
                throw Exception('Conversion timeout - please try again');
              },
            );

        print('📡 Conversion response status: ${response.statusCode}');
        print('📡 Conversion response body: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);

          // Invalidate both estimates and orders cache
          _invalidateCache('estimates');
          _invalidateCache('orders');

          return {
            'success': true,
            'message': 'Estimate converted to order successfully',
            'data': data,
          };
        } else {
          final errorData = json.decode(response.body);
          return {
            'success': false,
            'message': errorData['detail'] ?? 'Failed to convert estimate',
            'error': 'Server returned status ${response.statusCode}',
          };
        }
      }),
    );
  }

  // Create completed sale endpoint
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
    String? paymentMode,
    String? createdAt,
    double? amountPaid,
  }) async {
    final requestKey =
        'createCompletedSale_${DateTime.now().millisecondsSinceEpoch}';
    return _preventDuplicateRequest(
      requestKey,
      () => _retryRequest(() async {
        final url = Uri.parse('$baseUrl/orders/create-sale');

        print('🌐 API Request URL: $url');
        print('📤 Creating completed sale...');

        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        };

        final body = {
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'customer_address': customerAddress,
          'sale_by': saleBy,
          'items': items,
          'subtotal': subtotal,
          'discount_amount': discountAmount,
          'is_percentage_discount': isPercentageDiscount,
          'total': total,
          'created_at': createdAt ?? DateTime.now().toIso8601String(),
          'amount_paid': amountPaid ?? total, // Default to total if not provided
        };
        // Add payment mode if provided
        if (paymentMode != null) {
          body['payment_mode'] = paymentMode;
        }

        print('📤 Request body: ${json.encode(body)}');

        final response = await http
            .post(url, headers: headers, body: json.encode(body))
            .timeout(
              const Duration(seconds: 20),
              onTimeout: () {
                throw Exception('Request timeout - please try again');
              },
            );

        print('📡 Response status: ${response.statusCode}');
        print('📡 Response body: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);

          // Invalidate cache for orders
          _invalidateCache('orders');

          return {
            'success': true,
            'message': 'Sale completed successfully',
            'data': data,
          };
        } else {
          final errorData = json.decode(response.body);
          return {
            'success': false,
            'message': errorData['detail'] ?? 'Failed to complete sale',
            'error': 'Server returned status ${response.statusCode}',
          };
        }
      }),
    );
  }

  // Test connection endpoint
  static Future<Map<String, dynamic>> testConnection() async {
    return _retryRequest(() async {
      final url = Uri.parse('$baseUrl/');
      print('🌐 Testing connection to: $url');

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Connection test timeout');
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
            const Duration(seconds: 10), // Reduced from 15s
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

  // Fetch all estimates from backend with enhanced caching
  static Future<List<Map<String, dynamic>>> fetchEstimates({
    bool forceClearCache = false,
  }) async {
    const cacheKey = 'estimates';

    if (forceClearCache) {
      print('🧹 Forcing cache clear for estimates');
      _invalidateCache(cacheKey);
    }

    // Check cache first with cooldown
    if (_isCacheValid(cacheKey) && !_isRequestInCooldown(cacheKey)) {
      print('📋 Returning cached estimates');
      return List<Map<String, dynamic>>.from(_cache[cacheKey]['data']);
    }

    return _retryRequest(() async {
      print('🌐 Fetching estimates from: $baseUrl/estimates/all');
      final url = Uri.parse('$baseUrl/estimates/all');
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 15)); // Reduced from 20s

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> estimates = [];

        if (data is List) {
          estimates = List<Map<String, dynamic>>.from(data);
          print('📋 Parsed estimates as List: ${estimates.length} items');
        } else if (data['estimates'] != null) {
          estimates = List<Map<String, dynamic>>.from(data['estimates']);
          print(
            '📋 Parsed estimates from data.estimates: ${estimates.length} items',
          );
        } else {
          print('⚠️ No estimates found in response data: $data');
        }

        // Cache the result with timestamp
        _cache[cacheKey] = {'data': estimates, 'timestamp': DateTime.now()};
        _updateRequestCooldown(cacheKey);
        print('💾 Cached ${estimates.length} estimates');

        return estimates;
      } else {
        print('❌ HTTP Error: ${response.statusCode} - ${response.body}');
        return [];
      }
    });
  }

  // Fetch all orders (completed sales only) from backend with enhanced caching
  static Future<List<Map<String, dynamic>>> fetchOrders({
    bool forceClearCache = false,
  }) async {
    const cacheKey = 'orders';

    if (forceClearCache) {
      print('🧹 Forcing cache clear for orders');
      _invalidateCache(cacheKey);
    }

    // Check cache first with cooldown
    if (_isCacheValid(cacheKey) && !_isRequestInCooldown(cacheKey)) {
      print('📦 Returning cached orders');
      return List<Map<String, dynamic>>.from(_cache[cacheKey]['data']);
    }

    return _retryRequest(() async {
      final url = Uri.parse('$baseUrl/orders/orders-only');
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 15)); // Reduced from 20s

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> orders = [];

        if (data['orders'] != null && data['orders']['items'] != null) {
          orders = List<Map<String, dynamic>>.from(data['orders']['items']);
        }

        // Cache the result with timestamp
        _cache[cacheKey] = {'data': orders, 'timestamp': DateTime.now()};
        _updateRequestCooldown(cacheKey);

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
      final response = await http
          .put(url)
          .timeout(const Duration(seconds: 15)); // Reduced from 20s

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Invalidate cache when data is updated
        _invalidateCache('orders');
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

      final response = await http
          .get(Uri.parse('$baseUrl/reports/today'), headers: headers)
          .timeout(const Duration(seconds: 15)); // Added timeout

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

  // Delete estimate
  static Future<Map<String, dynamic>> deleteEstimate({
    required String estimateId,
  }) async {
    return _retryRequest(() async {
      final url = Uri.parse('$baseUrl/estimates/$estimateId');
      print('🗑️ Deleting estimate: $url');
      final response = await http
          .delete(url)
          .timeout(const Duration(seconds: 10)); // Reduced timeout
      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');
      final data = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 204) {
        _invalidateCache('estimates');
        return {'success': true, 'message': 'Estimate deleted successfully!'};
      } else {
        return {
          'success': false,
          'message':
              data['detail'] ?? data['message'] ?? 'Failed to delete estimate',
          'error': 'Server returned status ${response.statusCode}',
        };
      }
    });
  }

  // Delete order
  static Future<Map<String, dynamic>> deleteOrder({
    required String orderId,
  }) async {
    return _retryRequest(() async {
      final url = Uri.parse('$baseUrl/orders/$orderId');
      print('🗑️ Deleting order: $url');
      final response = await http
          .delete(url)
          .timeout(const Duration(seconds: 10)); // Reduced timeout
      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');
      final data = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 204) {
        _invalidateCache('orders');
        _invalidateCache(
          'estimates',
        ); // Also invalidate estimates cache in case linked estimate was deleted
        return {'success': true, 'message': 'Order deleted successfully!'};
      } else {
        return {
          'success': false,
          'message':
              data['detail'] ?? data['message'] ?? 'Failed to delete order',
          'error': 'Server returned status ${response.statusCode}',
        };
      }
    });
  }

  // Customer Management API Methods
  static Future<List<Map<String, dynamic>>?> fetchCustomers() async {
    const cacheKey = 'customers';

    // Check cache first
    if (_isCacheValid(cacheKey)) {
      print('👥 Returning cached customers');
      return List<Map<String, dynamic>>.from(_cache[cacheKey]['data']);
    }

    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http
          .get(Uri.parse('$baseUrl/customers'), headers: headers)
          .timeout(const Duration(seconds: 15)); // Added timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> customers = [];

        if (data['customers'] != null) {
          customers = List<Map<String, dynamic>>.from(data['customers']);
        }

        // Cache the result
        _cache[cacheKey] = {'data': customers, 'timestamp': DateTime.now()};

        return customers;
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
    const cacheKey = 'settings';

    // Check cache first
    if (_isCacheValid(cacheKey)) {
      print('⚙️ Returning cached settings');
      return Map<String, dynamic>.from(_cache[cacheKey]['data']);
    }

    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      final response = await http
          .get(Uri.parse('$baseUrl/settings'), headers: headers)
          .timeout(const Duration(seconds: 15)); // Added timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Cache the result
        _cache[cacheKey] = {'data': data, 'timestamp': DateTime.now()};

        return data;
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

      final response = await http
          .put(
            Uri.parse('$baseUrl/settings'),
            headers: headers,
            body: jsonEncode(settingsData),
          )
          .timeout(const Duration(seconds: 15)); // Added timeout

      if (response.statusCode == 200) {
        // Invalidate settings cache
        _invalidateCache('settings');
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

      final response = await http
          .get(Uri.parse('$baseUrl/health'), headers: headers)
          .timeout(const Duration(seconds: 8)); // Reduced timeout

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

        // Wait before retrying with exponential backoff
        await Future.delayed(_retryDelay * attempts);
      }
    }
    throw Exception('Max retries exceeded');
  }

  // Prevent duplicate requests with cooldown
  static Future<T> _preventDuplicateRequest<T>(
    String requestKey,
    Future<T> Function() request,
  ) async {
    if (_activeRequests.contains(requestKey)) {
      print('⚠️ Duplicate request detected: $requestKey - skipping');
      throw Exception('Request already in progress');
    }

    // Check cooldown
    if (_isRequestInCooldown(requestKey)) {
      print('⏰ Request in cooldown: $requestKey - skipping');
      throw Exception('Request in cooldown period');
    }

    _activeRequests.add(requestKey);

    try {
      final result = await request().timeout(_requestTimeout);
      _updateRequestCooldown(requestKey);
      return result;
    } finally {
      _activeRequests.remove(requestKey);
    }
  }

  // Enhanced cache management
  static bool _isCacheValid(String key) {
    if (!_cache.containsKey(key)) return false;

    final cacheEntry = _cache[key];
    final timestamp = cacheEntry['timestamp'] as DateTime;
    final now = DateTime.now();

    // Use different expiry times for different data types
    final expiry =
        key == 'estimates' || key == 'orders'
            ? _shortCacheExpiry
            : _cacheExpiry;

    return now.difference(timestamp) < expiry;
  }

  // Request cooldown management
  static bool _isRequestInCooldown(String key) {
    if (!_lastRequestTimes.containsKey(key)) return false;

    final lastRequest = _lastRequestTimes[key]!;
    final now = DateTime.now();

    return now.difference(lastRequest) < _requestCooldown;
  }

  static void _updateRequestCooldown(String key) {
    _lastRequestTimes[key] = DateTime.now();
  }

  // Smart cache invalidation
  static void _invalidateCache(String key) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
      print('🗑️ Cache invalidated: $key');
    }
  }

  static void _clearCache() {
    _cache.clear();
    _lastRequestTimes.clear();
    print('🗑️ All cache cleared');
  }

  static void clearCache() {
    _clearCache();
  }

  // Force refresh all data (clear cache and fetch fresh data)
  static Future<Map<String, dynamic>> forceRefreshAllData() async {
    print('🔄 Force refreshing all data...');

    // Clear all cache
    _clearCache();

    try {
      // Fetch fresh data with shorter timeouts
      final orders = await fetchOrders(forceClearCache: true);
      final estimates = await fetchEstimates(forceClearCache: true);

      return {
        'success': true,
        'orders': orders,
        'estimates': estimates,
        'timestamp': DateTime.now(),
      };
    } catch (e) {
      print('❌ Error force refreshing data: $e');
      return {
        'success': false,
        'error': e.toString(),
        'timestamp': DateTime.now(),
      };
    }
  }

  // Get service statistics
  static Map<String, dynamic> getServiceStats() {
    return {
      'cacheSize': _cache.length,
      'activeRequests': _activeRequests.length,
      'lastRequestTimes': _lastRequestTimes.length,
      'cacheKeys': _cache.keys.toList(),
      'activeRequestKeys': _activeRequests.toList(),
    };
  }
}
