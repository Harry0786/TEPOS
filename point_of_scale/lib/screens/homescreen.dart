import 'package:flutter/material.dart';
import 'dart:async';
import 'new_sale_screen.dart';
import 'view_estimates_screen.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../utils/performance_service.dart';
import 'view_orders_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _estimates = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  late WebSocketService _webSocketService;
  DateTime? _lastRefreshTime;

  // Constants for memory management
  static const int _maxListSize = 1000;
  static const int _maxCacheSize = 50;

  // Performance monitoring
  final PerformanceService _performanceService = PerformanceService();

  // Auto refresh timers - optimized
  Timer? _periodicRefreshTimer;
  Timer? _connectionCheckTimer;
  
  // Debouncing for refresh operations
  DateTime? _lastRefreshAttempt;
  static const Duration _refreshDebounceTime = Duration(seconds: 2);

  // Computed values cache with lazy initialization  
  List<Map<String, dynamic>>? _cachedRecentOrders;

  // Widget cache with keys for better control
  final Map<String, Widget> _widgetCache = {};
  bool _cacheInvalidated = false;

  // Date parsing cache to avoid repeated expensive operations
  final Map<String, DateTime> _dateCache = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    print('🔄 Disposing HomeScreen...');

    // Cancel timers safely with additional protection
    try {
      _periodicRefreshTimer?.cancel();
      _periodicRefreshTimer = null;
    } catch (e) {
      print('⚠️ Error canceling periodic refresh timer: $e');
    }

    try {
      _connectionCheckTimer?.cancel();
      _connectionCheckTimer = null;
    } catch (e) {
      print('⚠️ Error canceling connection check timer: $e');
    }

    // Dispose services safely with enhanced error handling
    try {
      _webSocketService.dispose();
    } catch (e) {
      print('⚠️ Error disposing WebSocket service: $e');
    }

    try {
      _performanceService.dispose();
    } catch (e) {
      print('⚠️ Error disposing performance service: $e');
    }

    // Remove observer safely
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (e) {
      print('⚠️ Error removing app lifecycle observer: $e');
    }

    // Clear all caches and lists to prevent memory leaks with null checks
    try {
      _widgetCache.clear();
      _dateCache.clear();
      _orders.clear();
      _estimates.clear();
      _cachedRecentOrders = null;
      _cacheInvalidated = true;
      _lastRefreshTime = null;
      _lastRefreshAttempt = null;
    } catch (e) {
      print('⚠️ Error clearing caches: $e');
    }

    super.dispose();
    print('✅ HomeScreen disposed successfully');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.inactive:
        _onAppInactive();
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.hidden:
        _onAppHidden();
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _performanceService.startOperation('HomeScreen.initState');

    // Register for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Print current API configuration for debugging
    ApiService.printConfiguration();

    _initializeWebSocket();
    _loadData();
    _setupAutoRefresh();
    _performanceService.endOperation('HomeScreen.initState');
  }

  void _initializeWebSocket() {
    try {
      _webSocketService = WebSocketService(serverUrl: ApiService.webSocketUrl);
      
      // Connect with enhanced error handling
      _webSocketService.connect();

      // Handle structured WebSocket messages for efficient updates
      _webSocketService.messageStream.listen(
        (message) {
          if (mounted) {
            try {
              _handleWebSocketMessage(message);
            } catch (e) {
              print('❌ Error handling WebSocket message: $e');
              // Don't crash the app, continue operation
            }
          }
        },
        onError: (error) {
          print('❌ WebSocket message stream error: $error');
          // Enhanced error recovery - don't let stream errors crash the app
        },
      );

      // Handle legacy messages for backward compatibility
      _webSocketService.legacyMessageStream.listen(
        (message) {
          if (message == 'estimate_updated' ||
              message == 'order_updated' ||
              message == 'sale_completed' ||
              message == 'estimate_created' ||
              message == 'estimate_deleted' ||
              message == 'estimate_converted_to_order') {
            if (mounted) {
              print(
                '🔄 Legacy WebSocket message received: $message - refreshing data...',
              );
              // Add a small delay to prevent rapid successive calls
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && !_isRefreshing) {
                  _loadData();
                }
              });
            }
          }
        },
        onError: (error) {
          print('❌ WebSocket legacy message stream error: $error');
          // Enhanced error recovery
        },
      );
    } catch (e) {
      print('❌ Error initializing WebSocket: $e');
      // Continue without WebSocket - app will still work
      // Set up a retry mechanism for failed WebSocket initialization
      Timer(const Duration(seconds: 15), () {
        if (mounted) {
          print('🔄 Retrying WebSocket initialization after error...');
          try {
            _initializeWebSocket();
          } catch (retryError) {
            print('❌ WebSocket retry also failed: $retryError');
          }
        }
      });
    }
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
          _loadData();
      }
    } else if (message.isOrder) {
      switch (message.action) {
        case 'create':
          _handleOrderCreated(message);
          break;
        case 'delete':
          _handleOrderDeleted(message);
          break;
        case 'update':
          _handleOrderUpdated(message);
          break;
        default:
          // Unknown action, do full refresh
          print(
            '⚠️ Unknown order action: ${message.action} - doing full refresh',
          );
          _loadData();
      }
    } else {
      // Unknown message type, do full refresh
      print('⚠️ Unknown message type: ${message.type} - doing full refresh');
      _loadData();
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
        'type': 'estimate',
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
        // Limit list size to prevent memory issues
        if (_estimates.length > _maxListSize) {
          _estimates.removeLast();
        }
        _invalidateCache(); // Invalidate cache to force recalculation
      });

      print('✅ Estimate added to list: ${message.data!['estimate_number']}');
    } else {
      // No data provided, do full refresh
      print('⚠️ No data in create message - doing full refresh');
      ApiService.clearCache();
      _loadData();
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
      _invalidateCache(); // Invalidate cache to force recalculation
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
      _invalidateCache(); // Invalidate cache to force recalculation
    });

    print('✅ Estimate converted to order and removed from list: ${message.id}');
  }

  void _handleOrderCreated(WebSocketMessage message) {
    print('➕ Handling order created: ${message.id}');
    if (message.data != null) {
      // Add the new order to the list
      final newOrder = {
        'id': message.id,
        'order_id': message.data!['order_id'],
        'sale_number': message.data!['sale_number'],
        'customer_name': message.data!['customer_name'],
        'total': message.data!['total'],
        'created_at': message.data!['created_at'],
        'status': 'Completed',
        'type': 'order',
        // Add other required fields with defaults
        'customer_phone': '',
        'customer_address': '',
        'sale_by': '',
        'items': [],
        'subtotal': 0.0,
        'discount_amount': 0.0,
        'is_percentage_discount': false,
        'payment_mode': 'Cash',
      };

      setState(() {
        _orders.insert(0, newOrder);
        // Limit list size to prevent memory issues
        if (_orders.length > _maxListSize) {
          _orders.removeLast();
        }
        _invalidateCache(); // Invalidate cache to force recalculation
      });

      print('✅ Order added to list: ${message.data!['sale_number']}');
    } else {
      // No data provided, do full refresh
      print('⚠️ No data in create message - doing full refresh');
      ApiService.clearCache();
      _loadData();
    }
  }

  void _handleOrderDeleted(WebSocketMessage message) {
    print('🗑️ Handling order deleted: ${message.id}');

    setState(() {
      _orders.removeWhere(
        (order) => order['order_id'] == message.id || order['id'] == message.id,
      );
      _invalidateCache(); // Invalidate cache to force recalculation
    });

    print('✅ Order removed from list: ${message.id}');
  }

  void _handleOrderUpdated(WebSocketMessage message) {
    print('✏️ Handling order updated: ${message.id}');

    // For updates, we need to refresh the specific order or do a full refresh
    // Since we don't have the updated data, do a full refresh for now
    print('🔄 Order updated - doing full refresh');
    ApiService.clearCache();
    _loadData();
  }

  Future<void> _loadData() async {
    if (_isRefreshing) return;

    _performanceService.startOperation('HomeScreen.loadData');

    if (mounted) {
      setState(() {
        _isRefreshing = true;
      });
    }

    try {
      // Use the new force refresh method with enhanced error handling
      final refreshResult = await ApiService.forceRefreshAllData().timeout(
        const Duration(seconds: 30), // Increased timeout for better reliability
        onTimeout: () {
          throw Exception('Data refresh timeout - server may be slow, please try again');
        },
      );

      if (refreshResult['success'] == true) {
        if (mounted) {
          setState(() {
            final newOrders = List<Map<String, dynamic>>.from(
              refreshResult['orders'] ?? [],
            );
            final newEstimates = List<Map<String, dynamic>>.from(
              refreshResult['estimates'] ?? [],
            );
            
            // Debug: Print loaded data counts
            print('🔍 Debug _loadData - Raw orders: ${newOrders.length}, Raw estimates: ${newEstimates.length}');
            
            // Limit list sizes to prevent memory issues
            _orders = newOrders.take(_maxListSize).toList();
            _estimates = newEstimates.take(_maxListSize).toList();
            
            // Debug: Print final counts after limiting
            print('🔍 Debug _loadData - Final orders: ${_orders.length}, Final estimates: ${_estimates.length}');
            
            _isLoading = false;
            _isRefreshing = false;
            _lastRefreshTime = DateTime.now();
            // Invalidate cache to force recalculation
            _invalidateCache();
          });
        }
      } else {
        throw Exception(refreshResult['error'] ?? 'Failed to refresh data');
      }
    } catch (e) {
      print('❌ Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        
        // Enhanced error message for network issues with specific handling
        String errorMessage = 'Failed to load data';
        bool isNetworkIssue = false;
        
        if (e.toString().contains('Connection reset') || 
            e.toString().contains('SocketException') ||
            e.toString().contains('Connection refused') ||
            e.toString().contains('Network is unreachable')) {
          errorMessage = 'Network connection issue - please check your internet and try again';
          isNetworkIssue = true;
        } else if (e.toString().contains('timeout') || 
                   e.toString().contains('TimeoutException')) {
          errorMessage = 'Server is slow - please try again in a moment';
        } else if (e.toString().contains('FormatException') ||
                   e.toString().contains('Invalid JSON')) {
          errorMessage = 'Server response error - please try again';
        } else {
          errorMessage = 'Failed to load data: ${e.toString().length > 100 ? e.toString().substring(0, 100) + '...' : e.toString()}';
        }
        
        // Only show error message if this isn't a background refresh
        if (!_isRefreshing || isNetworkIssue) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    isNetworkIssue ? Icons.wifi_off : Icons.error_outline, 
                    color: Colors.white, 
                    size: 20
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(errorMessage)),
                ],
              ),
              backgroundColor: isNetworkIssue ? Colors.orange : Colors.red,
              duration: Duration(seconds: isNetworkIssue ? 3 : 4),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () {
                  // Retry after a short delay with exponential backoff concept
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    if (mounted) {
                      _loadData();
                    }
                  });
                },
              ),
            ),
          );
        }
      }
    }

    _performanceService.endOperation('HomeScreen.loadData');
  }

  void _invalidateCache() {
    // Only invalidate if not already invalidated to reduce unnecessary work
    if (!_cacheInvalidated) {
      _cachedRecentOrders = null;
      _cacheInvalidated = true;
      
      // Manage widget cache size to prevent memory issues
      if (_widgetCache.length > _maxCacheSize) {
        _widgetCache.clear();
        print('🧹 Widget cache cleared due to size limit (${_maxCacheSize})');
      }
    }
  }

  // Helper to check if a date is today
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Optimized computed values with single pass calculation
  Map<String, dynamic> get _orderStats {
    double totalSales = 0.0;
    int totalOrders = 0;
    int totalEstimates = 0;
    int completedSales = 0;

    final now = DateTime.now();

    for (final order in _orders) {
      final status = (order['status'] ?? '').toString().toLowerCase();
      final createdAt = _parseDate(order['created_at']);
      final isToday =
          createdAt.year == now.year &&
          createdAt.month == now.month &&
          createdAt.day == now.day;
      if (status == 'completed' && isToday) {
        completedSales++;
        totalOrders++;
        // Use amount_paid instead of total for sales calculations
        final amount = order['amount_paid'] ?? order['amount'] ?? order['total'] ?? 0.0;
        totalSales += (amount is num) ? amount.toDouble() : 0.0;
      }
    }

    for (final estimate in _estimates) {
      final createdAt = _parseDate(estimate['created_at']);
      final isToday =
          createdAt.year == now.year &&
          createdAt.month == now.month &&
          createdAt.day == now.day;
      if (isToday) {
        totalEstimates++;
      }
    }

    return {
      'totalSales': totalSales,
      'totalOrders': totalOrders,
      'totalEstimates': totalEstimates,
      'completedSales': completedSales,
    };
  }

  double get _totalSales => _orderStats['totalSales'];
  int get _totalOrders => _orderStats['totalOrders'];
  int get _totalEstimates => _orderStats['totalEstimates'];

  List<Map<String, dynamic>> get _recentOrders {
    if (_cachedRecentOrders != null && !_cacheInvalidated) {
      return _cachedRecentOrders!;
    }

    _performanceService.startOperation('HomeScreen.computeRecentOrders');

    try {
      // Debug: Print the raw data available
      print('🔍 Debug Recent Orders - Orders count: ${_orders.length}, Estimates count: ${_estimates.length}');
      
      // Create empty list to hold all items
      final allItems = <Map<String, dynamic>>[];

      // Add orders with type indicator
      for (final order in _orders) {
        try {
          allItems.add({
            ...order,
            'type': 'order',
            'display_id': order['sale_number'] ?? order['order_id'] ?? order['id'],
          });
        } catch (e) {
          print('⚠️ Error processing order: $e, Order: $order');
        }
      }

      // Add estimates with type indicator
      for (final estimate in _estimates) {
        try {
          allItems.add({
            ...estimate,
            'type': 'estimate',
            'display_id': estimate['estimate_number'] ?? estimate['id'],
          });
        } catch (e) {
          print('⚠️ Error processing estimate: $e, Estimate: $estimate');
        }
      }

      // Debug: Print combined data
      print('🔍 Debug Recent Orders - Combined items count: ${allItems.length}');
      if (allItems.isNotEmpty) {
        print('🔍 Debug Recent Orders - First item: ${allItems.first['display_id']} (${allItems.first['type']})');
      }

      // Sort by created_at date (newest first)
      if (allItems.length > 1) {
        allItems.sort((a, b) {
          try {
            final aDate = _parseDate(a['created_at']);
            final bDate = _parseDate(b['created_at']);
            return bDate.compareTo(aDate);
          } catch (e) {
            print('⚠️ Error sorting recent orders: $e');
            return 0;
          }
        });
      }

      // Take only the first 5 items for recent orders
      _cachedRecentOrders = allItems.take(5).toList();
      
      // Debug: Print final result
      print('🔍 Debug Recent Orders - Final cached count: ${_cachedRecentOrders?.length ?? 0}');
      
      // Mark cache as valid
      _cacheInvalidated = false;
    } catch (e) {
      print('❌ Error computing recent orders: $e');
      _cachedRecentOrders = [];
      _cacheInvalidated = false;
    }

    _performanceService.endOperation('HomeScreen.computeRecentOrders');

    return _cachedRecentOrders!;
  }

  DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime(1970); // clearly invalid
    if (dateValue is DateTime)
      return dateValue.toUtc().add(const Duration(hours: 5, minutes: 30));
    
    final key = dateValue.toString();
    
    // Check cache first
    if (_dateCache.containsKey(key)) {
      return _dateCache[key]!;
    }
    
    try {
      // Try parsing ISO8601 and convert to IST
      final parsed = DateTime.tryParse(key)?.toUtc().add(const Duration(hours: 5, minutes: 30)) ?? DateTime(1970);
      
      // Cache the result (limit cache size for memory efficiency)
      if (_dateCache.length >= 100) {
        // Remove oldest entries to prevent memory bloat
        final keysToRemove = _dateCache.keys.take(20).toList();
        for (final keyToRemove in keysToRemove) {
          _dateCache.remove(keyToRemove);
        }
      }
      _dateCache[key] = parsed;
      
      return parsed;
    } catch (_) {
      final fallback = DateTime(1970);
      _dateCache[key] = fallback;
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Skip performance tracking during rapid rebuilds to prevent overhead
    final shouldTrackPerformance = !_isRefreshing && !_isLoading;
    if (shouldTrackPerformance) {
      _performanceService.startOperation('HomeScreen.build');
    }

    // Add safety check for context validity
    if (!mounted) {
      return const SizedBox.shrink();
    }

    // Debug: Check recent orders computation
    try {
      final recentOrdersCount = _recentOrders.length;
      print('🔍 Debug Build - Recent orders available: $recentOrdersCount');
    } catch (e) {
      print('❌ Error in build getting recent orders: $e');
    }

    final widget = Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0, // Hide the app bar visually
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _forceRefresh,
          color: const Color(0xFF6B8E7F),
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF6B8E7F),
                      ),
                    ),
                  )
                  : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header - always rebuild for connection status
                        _buildHeader(),
                        const SizedBox(height: 16),
                        // Today's Report - use cached version when possible
                        _buildTodayReport(),
                        const SizedBox(height: 24),
                        // Quick Actions - highly cacheable
                        _buildQuickActions(),
                        const SizedBox(height: 20),
                        // Recent Orders - use optimized computation
                        _buildRecentOrders(),
                        const SizedBox(height: 20), // Bottom padding
                      ],
                    ),
                  ),
        ),
      ),
    );

    if (shouldTrackPerformance) {
      try {
        _performanceService.endOperation('HomeScreen.build');
      } catch (e) {
        print('⚠️ Error ending performance tracking: $e');
      }
    }
    
    return widget;
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Logo with optimized image loading and curved edges
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14), // Rounded corners for the logo
                child: Image.asset(
                  'assets/icon/TEPOS Logo.png',
                  height: 42,
                  width: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if image fails to load
                    return Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B8E7F),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.store,
                        color: Colors.white,
                        size: 24,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tirupati Electricals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Point of Sale System',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayReport() {
    const cacheKey = 'todayReport';
    if (_widgetCache.containsKey(cacheKey) && !_cacheInvalidated) {
      return _widgetCache[cacheKey]!;
    }

    final widget = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Today's Report",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_lastRefreshTime != null)
                Text(
                  'Last updated: ${_formatTime(_lastRefreshTime!)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Large Total Sales Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF3A3A3A)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Total Sales',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Rs. ${_totalSales.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFFB9F6CA), // lighter green
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(
                  color: Color(0xFF232526),
                  thickness: 1,
                  height: 16,
                ),
                // Payment Breakdown Inline
                Builder(
                  builder: (context) {
                    final paymentBreakdown = _getPaymentBreakdownToday();
                    final totalAmount = paymentBreakdown.values.fold<double>(
                      0.0,
                      (sum, data) => sum + (data['amount'] as double),
                    );
                    if (paymentBreakdown.isEmpty || totalAmount == 0.0) {
                      return const Center(
                        child: Text(
                          'No payment data available',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Removed 'Payment Breakdown' label and spacing
                        ...paymentBreakdown.entries
                            .where(
                              (entry) => (entry.value['amount'] as double) > 0,
                            )
                            .map((entry) {
                              final mode = entry.key;
                              final data = entry.value;
                              final amount = data['amount'] as double;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Payment breakdown (smallest)
                                    Text(
                                      mode,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    // Payment breakdown amount (lighter color)
                                    Text(
                                      'Rs. ${amount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Color(
                                          0xFFB9F6CA,
                                        ), // lighter green
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            })
                            .toList(),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Orders and Estimates cards underneath
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Orders',
                  '$_totalOrders',
                  Icons.receipt,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Estimates',
                  '$_totalEstimates',
                  Icons.description,
                  const Color(0xFFFF9800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ),
    );

    _widgetCache[cacheKey] = widget;
    return widget;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A3A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Payment breakdown for today's completed orders only
  Map<String, Map<String, dynamic>> _getPaymentBreakdownToday() {
    final breakdown = <String, Map<String, dynamic>>{};

    for (final order in _orders) {
      final status = order['status']?.toString().toLowerCase() ?? '';
      final createdAt = _parseDate(order['created_at']);
      if (status == 'completed' && _isToday(createdAt)) {
        final paymentMode = order['payment_mode']?.toString() ?? 'Other';
        // Use amount_paid instead of total for accurate payment breakdown
        final amount = order['amount_paid'] ?? order['amount'] ?? order['total'] ?? 0.0;
        if (!breakdown.containsKey(paymentMode)) {
          breakdown[paymentMode] = {'count': 0, 'amount': 0.0};
        }
        breakdown[paymentMode]!['count'] =
            (breakdown[paymentMode]!['count'] as int) + 1;
        breakdown[paymentMode]!['amount'] =
            (breakdown[paymentMode]!['amount'] as double) +
            (amount is num ? amount.toDouble() : 0.0);
      }
    }
    return breakdown;
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF232526),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    const cacheKey = 'quickActions';
    if (_widgetCache.containsKey(cacheKey) && !_cacheInvalidated) {
      return _widgetCache[cacheKey]!;
    }

    final widget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flash_on, color: Color(0xFF6B8E7F), size: 18),
            const SizedBox(width: 6),
            const Text(
              'Quick Actions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Card(
          elevation: 3,
          color: const Color(0xFF181A1B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildQuickActionCard(
                  'New Sale',
                  Icons.add_shopping_cart,
                  const Color(0xFF6B8E7F),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NewSaleScreen(),
                      ),
                    );
                  },
                ),
                _buildQuickActionCard(
                  'View Estimates',
                  Icons.receipt_long,
                  const Color(0xFF6B8E7F),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ViewEstimatesScreen(),
                      ),
                    );
                  },
                ),
                _buildQuickActionCard(
                  'View Orders',
                  Icons.list_alt,
                  const Color(0xFF6B8E7F),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ViewOrdersScreen(),
                      ),
                    );
                  },
                ),
                _buildQuickActionCard(
                  'Reports',
                  Icons.analytics,
                  const Color(0xFF6B8E7F),
                  () {
                    _showComingSoonDialog('Reports');
                  },
                ),
                _buildQuickActionCard(
                  'Inventory',
                  Icons.inventory,
                  const Color(0xFF6B8E7F),
                  () {
                    _showComingSoonDialog('Inventory');
                  },
                ),
                _buildQuickActionCard(
                  'Settings',
                  Icons.settings,
                  const Color(0xFF6B8E7F),
                  () {
                    _showComingSoonDialog('Settings');
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );

    _widgetCache[cacheKey] = widget;
    return widget;
  }

  Widget _buildRecentOrders() {
    const cacheKey = 'recentOrders';
    if (_widgetCache.containsKey(cacheKey) && !_cacheInvalidated) {
      return _widgetCache[cacheKey]!;
    }

    final widget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history, color: Color(0xFF2196F3), size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Recent Activity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Card(
          elevation: 2,
          color: const Color(0xFF181A1B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child:
                _recentOrders.isEmpty
                    ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Center(
                        child: Text(
                          'No recent orders or estimates',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                    : Column(
                      children: [
                        // Data rows
                        ..._recentOrders
                            .asMap()
                            .entries
                            .take(5)
                            .map((entry) => _OrderItemWidget(
                              key: ValueKey('order_${entry.value['id']}_${entry.key}'),
                              item: entry.value,
                              isLast: entry.key == _recentOrders.length - 1,
                            ))
                            .toList(),
                      ],
                    ),
          ),
        ),
      ],
    );

    _widgetCache[cacheKey] = widget;
    return widget;
  }

  // ===== AUTO REFRESH FUNCTIONALITY =====

  void _setupAutoRefresh() {
    // Set up periodic refresh every 5 minutes (optimized for better performance)
    _periodicRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted && !_isRefreshing) {
        print('🔄 Auto-refreshing data...');
        _loadData();
      }
    });

    // Set up pull-to-refresh gesture
    _setupPullToRefresh();
  }

  void _setupPullToRefresh() {
    // This will be handled by the RefreshIndicator widget in the build method
  }

  void _showComingSoonDialog(String featureName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.construction,
                  color: const Color(0xFF6B8E7F),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  '$featureName Coming Soon!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'We\'re working hard to bring you this feature. Stay tuned for updates!',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B8E7F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Got it!',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onAppResumed() {
    print('📱 App resumed - checking for updates...');

    // Check if it's been more than 3 minutes since last refresh (optimized)
    if (_lastRefreshTime == null ||
        DateTime.now().difference(_lastRefreshTime!).inMinutes >= 3) {
      _loadData();
    }

    // Reconnect WebSocket if needed
    _webSocketService.connect();
  }

  void _onAppPaused() {
    print('📱 App paused');
    // Pause periodic refresh to save resources
    _periodicRefreshTimer?.cancel();
  }

  void _onAppInactive() {
    print('📱 App inactive');
    // App is in background but not fully paused
  }

  void _onAppDetached() {
    print('📱 App detached');
    // App is being terminated
  }

  void _onAppHidden() {
    print('📱 App hidden');
    // App is hidden (e.g., by system UI)
  }

  Future<void> _forceRefresh() async {
    print('🔄 Force refreshing data...');

    // Prevent multiple simultaneous refreshes
    if (_isRefreshing) {
      print('⚠️ Refresh already in progress, skipping...');
      return;
    }

    // Debounce rapid refresh attempts
    final now = DateTime.now();
    if (_lastRefreshAttempt != null && 
        now.difference(_lastRefreshAttempt!) < _refreshDebounceTime) {
      print('⚠️ Refresh debounced - too soon since last attempt');
      return;
    }
    _lastRefreshAttempt = now;

    try {
      // Invalidate cache and load fresh data
      _invalidateCache();

      await _loadData();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Data refreshed successfully!'),
            backgroundColor: const Color(0xFF6B8E7F),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error during force refresh: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _forceRefresh(),
            ),
          ),
        );
      }
    }
  }
}

// Optimized stateless widget for order items
class _OrderItemWidget extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isLast;

  const _OrderItemWidget({
    Key? key,
    required this.item,
    required this.isLast,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String typeLabel = (item['type'] == 'order') ? 'Order' : 'Estimate';
    final Color typeColor =
        (item['type'] == 'order')
            ? const Color(0xFF4CAF50)
            : const Color(0xFFFF9800);
    final String number =
        item['display_id'] ??
        item['estimate_number'] ??
        item['sale_number'] ??
        item['order_id'] ??
        item['id'] ??
        '';
    // For orders, use amount_paid; for estimates, use total
    final double amount =
        (item['type'] == 'order') 
            ? ((item['amount_paid'] ?? item['total'] ?? 0.0) is num
                ? (item['amount_paid'] ?? item['total'] ?? 0.0).toDouble()
                : 0.0)
            : ((item['total'] ?? 0.0) is num
                ? (item['total'] ?? 0.0).toDouble()
                : 0.0);
    final String dateTimeStr = item['created_at']?.toString() ?? '';
    DateTime? dateTime;
    try {
      dateTime = DateTime.tryParse(
        dateTimeStr,
      )?.toUtc().add(const Duration(hours: 5, minutes: 30));
    } catch (_) {
      dateTime = null;
    }
    String formattedTime =
        dateTime != null ? DateFormat('hh:mm a').format(dateTime) : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border:
            isLast
                ? null
                : const Border(
                  bottom: BorderSide(color: Color(0xFF3A3A3A), width: 0.5),
                ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                typeLabel,
                style: TextStyle(
                  color: typeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Rs. ${amount.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Color(0xFF6B8E7F),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formattedTime,
              style: TextStyle(
                color: Colors.grey[400], 
                fontSize: 11,
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
