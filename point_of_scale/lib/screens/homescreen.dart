import 'package:flutter/material.dart';
import 'dart:async';
import 'new_sale_screen.dart';
import 'view_estimates_screen.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/performance_service.dart';
import '../services/pdf_service.dart';
import 'view_orders_screen.dart';
import 'reports_screen.dart';
import 'customers_screen.dart';
import 'settings_screen.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';

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

  // Performance monitoring
  final PerformanceService _performanceService = PerformanceService();

  // Connection status
  bool _isConnected = false;
  String _connectionStatus = 'Connecting...';
  DateTime? _lastConnectionTime;

  // Auto refresh timers - optimized
  Timer? _periodicRefreshTimer;
  DateTime? _lastAppResumeTime;

  // Computed values cache with lazy initialization
  double? _cachedTotalSales;
  int? _cachedTotalOrders;
  int? _cachedTotalEstimates;
  int? _cachedCompletedSales;
  List<Map<String, dynamic>>? _cachedRecentOrders;
  Map<String, dynamic>? _cachedOrderStats;

  // Widget cache with keys for better control
  final Map<String, Widget> _widgetCache = {};
  bool _cacheInvalidated = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    // Cancel timers
    _periodicRefreshTimer?.cancel();

    // Dispose services
    _webSocketService.dispose();
    _performanceService.dispose();

    // Remove observer
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
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
    _webSocketService = WebSocketService(serverUrl: ApiService.webSocketUrl);
    _webSocketService.connect();

    // Monitor connection status periodically
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _isConnected = _webSocketService.isConnected;
          _connectionStatus = _isConnected ? 'Connected' : 'Disconnected';
          if (_isConnected && _lastConnectionTime == null) {
            _lastConnectionTime = DateTime.now();
          }
        });
      }
    });

    // Handle structured WebSocket messages for efficient updates
    _webSocketService.messageStream.listen((message) {
      if (mounted) {
        _handleWebSocketMessage(message);
      }
    });

    // Handle legacy messages for backward compatibility
    _webSocketService.legacyMessageStream.listen((message) {
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
          _loadData();
        }
      }
    });
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
      // Use the new force refresh method for better reliability
      final refreshResult = await ApiService.forceRefreshAllData().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception('Data refresh timeout - please try again');
        },
      );

      if (refreshResult['success'] == true) {
        if (mounted) {
          setState(() {
            _orders = List<Map<String, dynamic>>.from(
              refreshResult['orders'] ?? [],
            );
            _estimates = List<Map<String, dynamic>>.from(
              refreshResult['estimates'] ?? [],
            );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    _performanceService.endOperation('HomeScreen.loadData');
  }

  void _invalidateCache() {
    _cachedTotalSales = null;
    _cachedTotalOrders = null;
    _cachedTotalEstimates = null;
    _cachedCompletedSales = null;
    _cachedRecentOrders = null;
    _cachedOrderStats = null;
    _widgetCache.clear();
    _cacheInvalidated = true;
  }

  // Optimized computed values with single pass calculation
  Map<String, dynamic> get _orderStats {
    if (_cachedOrderStats != null && !_cacheInvalidated) {
      return _cachedOrderStats!;
    }

    _performanceService.startOperation('HomeScreen.computeStats');

    double totalSales = 0.0;
    int totalOrders = 0;
    int totalEstimates = _estimates.length;
    int completedSales = 0;

    try {
      // Process orders (only completed sales count as orders)
      for (final order in _orders) {
        final status = order['status']?.toString().toLowerCase() ?? '';

        if (status == 'completed') {
          completedSales++;
          totalOrders++;
          final amount = order['amount'];
          final total = order['total'];
          final value = (amount ?? total ?? 0.0);
          totalSales += (value is num ? value.toDouble() : 0.0);
        }
      }

      // Process estimates (count all estimates)
      for (final estimate in _estimates) {
        final status = estimate['status']?.toString().toLowerCase() ?? '';
        // Estimates are counted separately, not as orders
      }
    } catch (e) {
      print('❌ Error computing order stats: $e');
      // Use safe defaults
      totalSales = 0.0;
      totalOrders = 0;
      totalEstimates = _estimates.length;
      completedSales = 0;
    }

    _cachedOrderStats = {
      'totalSales': totalSales,
      'totalOrders': totalOrders,
      'totalEstimates': totalEstimates,
      'completedSales': completedSales,
    };

    _cacheInvalidated = false;
    _performanceService.endOperation('HomeScreen.computeStats');

    return _cachedOrderStats!;
  }

  double get _totalSales => _orderStats['totalSales'];
  int get _totalOrders => _orderStats['totalOrders'];
  int get _totalEstimates => _orderStats['totalEstimates'];
  int get _completedSales => _orderStats['completedSales'];

  List<Map<String, dynamic>> get _recentOrders {
    if (_cachedRecentOrders != null && !_cacheInvalidated) {
      return _cachedRecentOrders!;
    }

    _performanceService.startOperation('HomeScreen.computeRecentOrders');

    try {
      // Combine orders and estimates for recent display
      final allItems = <Map<String, dynamic>>[];

      // Add orders with type indicator
      for (final order in _orders) {
        allItems.add({
          ...order,
          'type': 'order',
          'display_id':
              order['sale_number'] ?? order['order_id'] ?? order['id'],
        });
      }

      // Add estimates with type indicator
      for (final estimate in _estimates) {
        allItems.add({
          ...estimate,
          'type': 'estimate',
          'display_id': estimate['estimate_number'] ?? estimate['id'],
        });
      }

      // Sort by creation date
      allItems.sort((a, b) {
        try {
          final aDate = _parseDate(a['created_at']);
          final bDate = _parseDate(b['created_at']);
          return bDate.compareTo(aDate);
        } catch (e) {
          print('❌ Error sorting items: $e');
          return 0;
        }
      });

      _cachedRecentOrders = allItems.take(5).toList();
    } catch (e) {
      print('❌ Error computing recent orders: $e');
      _cachedRecentOrders = [];
    }

    _performanceService.endOperation('HomeScreen.computeRecentOrders');

    return _cachedRecentOrders!;
  }

  DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is DateTime) return dateValue;
    try {
      return DateTime.tryParse(dateValue.toString()) ?? DateTime.now();
    } catch (e) {
      print('❌ Error parsing date: $dateValue, error: $e');
      return DateTime.now();
    }
  }

  void _showConnectionStatus() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Row(
            children: [
              Icon(
                _isConnected ? Icons.wifi : Icons.wifi_off,
                color:
                    _isConnected
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF5722),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Connection Status',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusRow(
                'Status',
                _isConnected ? 'Connected' : 'Disconnected',
                _isConnected
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF5722),
              ),
              _buildStatusRow('Server', ApiService.webSocketUrl, Colors.grey),
              if (_lastConnectionTime != null)
                _buildStatusRow(
                  'Last Connected',
                  _formatTime(_lastConnectionTime!),
                  Colors.grey,
                ),
              _buildStatusRow(
                'WebSocket',
                _webSocketService.isConnected ? 'Active' : 'Inactive',
                _webSocketService.isConnected
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF5722),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.grey)),
            ),
            if (!_isConnected)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B8E7F),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _webSocketService.connect();
                },
                child: const Text('Reconnect'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    _performanceService.startOperation('HomeScreen.build');

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
                        // Header
                        _buildHeader(),
                        const SizedBox(height: 16),
                        // Today's Report
                        _buildTodayReport(),
                        const SizedBox(height: 24),
                        // Quick Actions
                        _buildQuickActions(),
                        const SizedBox(height: 20),
                        // Recent Orders and Estimates
                        _buildRecentOrders(),
                        const SizedBox(height: 20), // Bottom padding
                      ],
                    ),
                  ),
        ),
      ),
    );

    _performanceService.endOperation('HomeScreen.build');
    return widget;
  }

  Widget _buildHeader() {
    const cacheKey = 'header';
    if (_widgetCache.containsKey(cacheKey) && !_cacheInvalidated) {
      return _widgetCache[cacheKey]!;
    }

    final widget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Logo with optimized image loading
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6B8E7F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              'assets/icon/TEPOS Logo.png',
              height: 28,
              width: 28,
              cacheWidth: 56,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Tirupati Electricals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Point of Sale System',
                  style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 11),
                ),
              ],
            ),
          ),
          // Removed empty Row for better alignment
        ],
      ),
    );

    _widgetCache[cacheKey] = widget;
    return widget;
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
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showPaymentBreakdownDialog(),
                      child: _buildSummaryCard(
                        'Total Sales',
                        'Rs. ${_totalSales.toStringAsFixed(0)}',
                        Icons.attach_money,
                        const Color(0xFF6B8E7F),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      'Orders',
                      '$_totalOrders',
                      Icons.receipt,
                      const Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Estimates',
                      '$_totalEstimates',
                      Icons.description,
                      const Color(0xFFFF9800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      'Completed',
                      '$_completedSales',
                      Icons.check_circle,
                      const Color(0xFF2196F3),
                    ),
                  ),
                ],
              ),
            ],
          ),
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

  Map<String, Map<String, dynamic>> _getPaymentBreakdown() {
    final breakdown = <String, Map<String, dynamic>>{
      'cash': {'count': 0, 'amount': 0.0},
      'card': {'count': 0, 'amount': 0.0},
      'online': {'count': 0, 'amount': 0.0},
      'upi': {'count': 0, 'amount': 0.0},
      'bank_transfer': {'count': 0, 'amount': 0.0},
      'cheque': {'count': 0, 'amount': 0.0},
      'other': {'count': 0, 'amount': 0.0},
    };

    for (final order in _orders) {
      final status = order['status']?.toString().toLowerCase() ?? '';
      if (status == 'completed') {
        final paymentMode =
            order['payment_mode']?.toString().toLowerCase() ?? 'other';
        final amount = order['total'] ?? order['amount'] ?? 0.0;

        if (breakdown.containsKey(paymentMode)) {
          breakdown[paymentMode]!['count'] =
              (breakdown[paymentMode]!['count'] as int) + 1;
          breakdown[paymentMode]!['amount'] =
              (breakdown[paymentMode]!['amount'] as double) +
              (amount is num ? amount.toDouble() : 0.0);
        } else {
          breakdown['other']!['count'] =
              (breakdown['other']!['count'] as int) + 1;
          breakdown['other']!['amount'] =
              (breakdown['other']!['amount'] as double) +
              (amount is num ? amount.toDouble() : 0.0);
        }
      }
    }

    return breakdown;
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

  void _showPaymentBreakdownDialog() {
    final paymentBreakdown = _getPaymentBreakdown();
    // Calculate total from payment breakdown to ensure accuracy
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
                // Total Sales row (improved)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.attach_money,
                      color: Color(0xFF6B8E7F),
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Sales',
                          style: TextStyle(
                            color: Color(0xFFB0B0B0),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rs. ${totalAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(color: Color(0xFF232526), thickness: 1),
                const SizedBox(height: 10),
                if (paymentBreakdown.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Payment Modes',
                      style: TextStyle(
                        color: Color(0xFFB0B0B0),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (paymentBreakdown.isEmpty)
                  const Center(
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey, size: 32),
                        SizedBox(height: 8),
                        Text(
                          'No payment data available',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        paymentBreakdown.entries.map((entry) {
                          final mode = entry.key;
                          final data = entry.value;
                          final count = data['count'] as int;
                          final amount = data['amount'] as double;
                          if (count == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: _getPaymentModeColor(mode),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _getPaymentModeDisplayName(mode),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
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
                  ),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReportsScreen(),
                      ),
                    );
                  },
                ),
                _buildQuickActionCard(
                  'Customers',
                  Icons.people,
                  const Color(0xFF6B8E7F),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CustomersScreen(),
                      ),
                    );
                  },
                ),
                _buildQuickActionCard(
                  'Settings',
                  Icons.settings,
                  const Color(0xFF6B8E7F),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
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
                'Recent Orders and Estimates',
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
                      children:
                          _recentOrders
                              .take(5)
                              .map((order) => _buildOrderItem(order))
                              .toList(),
                    ),
          ),
        ),
      ],
    );

    _widgetCache[cacheKey] = widget;
    return widget;
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    final bool isLast = _recentOrders.indexOf(item) == _recentOrders.length - 1;
    final int itemCount =
        (item['items'] is List)
            ? item['items'].length
            : (item['items_count'] ?? 0);

    final bool isOrder = item['type'] == 'order';
    final bool isCompleted = item['status'] == 'Completed';

    return GestureDetector(
      onTap: () => _showOrderDetails(item),
      child: Container(
        padding: const EdgeInsets.all(12),
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
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:
                    isOrder && isCompleted
                        ? const Color(0xFF4CAF50).withOpacity(0.2)
                        : const Color(0xFFFF9800).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isOrder && isCompleted ? Icons.check_circle : Icons.description,
                color:
                    isOrder && isCompleted
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF9800),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['display_id'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['customer_name'] ?? item['customer'] ?? '',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  Text(
                    '${itemCount} items',
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs. ${((item['amount'] ?? item['total'] ?? 0.0).toStringAsFixed(0))}',
                  style: const TextStyle(
                    color: Color(0xFF6B8E7F),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (item['time'] ??
                      (item['created_at']?.toString().split(' ')[0] ?? '')),
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isOrder && isCompleted
                            ? const Color(0xFF4CAF50).withOpacity(0.2)
                            : const Color(0xFFFF9800).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOrder
                        ? (isCompleted ? 'Completed' : 'Order')
                        : 'Estimate',
                    style: TextStyle(
                      color:
                          isOrder && isCompleted
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF9800),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> item) {
    final bool isOrder = item['type'] == 'order';
    final String itemNumber = item['display_id'] ?? 'Unknown';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Row(
            children: [
              Icon(
                isOrder ? Icons.receipt : Icons.description,
                color:
                    isOrder ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${isOrder ? 'Order' : 'Estimate'} $itemNumber',
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Customer', item['customer_name'] ?? ''),
                _buildDetailRow('Phone', item['customer_phone'] ?? ''),
                _buildDetailRow('Address', item['customer_address'] ?? ''),
                _buildDetailRow('Sale By', item['sale_by'] ?? ''),
                _buildDetailRow(
                  'Status',
                  isOrder ? (item['status'] ?? '') : (item['status'] ?? ''),
                ),
                _buildDetailRow(
                  'Date',
                  item['created_at'].toString().split(' ')[0],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Items:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...(item['items'] as List<dynamic>?)
                        ?.map<Widget>(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item['name']} x${item['quantity']}',
                                    style: TextStyle(color: Colors.grey[300]),
                                  ),
                                ),
                                Text(
                                  'Rs. ${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                                  style: TextStyle(color: Colors.grey[300]),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList() ??
                    [],
                const SizedBox(height: 12),
                const Divider(color: Color(0xFF3A3A3A)),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Subtotal',
                  'Rs. ${(item['subtotal'] ?? 0.0).toStringAsFixed(2)}',
                ),
                if ((item['discount_amount'] ?? 0.0) > 0)
                  _buildDetailRow(
                    'Discount',
                    (item['is_percentage_discount'] ?? false)
                        ? '${item['discount_amount']}%'
                        : 'Rs. ${item['discount_amount'].toStringAsFixed(2)}',
                  ),
                _buildDetailRow(
                  'Total',
                  'Rs. ${(item['total'] ?? item['amount'] ?? 0.0).toStringAsFixed(2)}',
                  isTotal: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.grey)),
            ),
            if (isOrder)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B8E7F),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _printOrderPdf(item);
                },
                child: const Text('Print PDF'),
              ),
          ],
        );
      },
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
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isTotal ? const Color(0xFF6B8E7F) : Colors.white,
                fontSize: isTotal ? 16 : 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printOrderPdf(Map<String, dynamic> order) async {
    try {
      // Show loading dialog
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
                  'Generating PDF...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
        },
      );

      // Generate order PDF
      final pdfFile = await PdfService.generateSalePdf(
        saleNumber: order['sale_number'] ?? 'Unknown',
        customerName: order['customer_name'] ?? '',
        customerPhone: order['customer_phone'] ?? '',
        customerAddress: order['customer_address'] ?? '',
        saleBy: order['sale_by'] ?? '',
        items: List<Map<String, dynamic>>.from(order['items'] ?? []),
        subtotal: order['subtotal'] ?? 0.0,
        discountAmount: order['discount_amount'] ?? 0.0,
        isPercentageDiscount: order['is_percentage_discount'] ?? false,
        total: order['total'] ?? order['amount'] ?? 0.0,
        createdAt:
            DateTime.tryParse(order['created_at'].toString()) ?? DateTime.now(),
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

  // ===== AUTO REFRESH FUNCTIONALITY =====

  void _setupAutoRefresh() {
    // Set up periodic refresh every 2 minutes (optimized)
    _periodicRefreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
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

  void _onAppResumed() {
    print('📱 App resumed - checking for updates...');
    _lastAppResumeTime = DateTime.now();

    // Check if it's been more than 3 minutes since last refresh (optimized)
    if (_lastRefreshTime == null ||
        DateTime.now().difference(_lastRefreshTime!).inMinutes >= 3) {
      _loadData();
    }

    // Reconnect WebSocket if needed
    if (!_webSocketService.isConnected) {
      _webSocketService.connect();
    }
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

    // Invalidate cache and load fresh data
    _invalidateCache();

    await _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data refreshed successfully!'),
          backgroundColor: Color(0xFF6B8E7F),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _checkForUpdates() async {
    try {
      // Check server health first with shorter timeout
      final isHealthy = await ApiService.checkServerHealth().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⚠️ Server health check timeout');
          return false;
        },
      );

      if (!isHealthy) {
        print('⚠️ Server health check failed');
        return;
      }

      // Check if there are any new orders/estimates
      final currentOrders = await ApiService.fetchOrders();
      if (currentOrders != null && currentOrders.length != _orders.length) {
        print('🆕 New data detected - refreshing...');
        _loadData();
      }
    } catch (e) {
      print('❌ Error checking for updates: $e');
    }
  }
}
