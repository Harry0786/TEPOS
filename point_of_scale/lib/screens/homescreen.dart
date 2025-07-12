import 'package:flutter/material.dart';
import 'dart:async';
import 'new_sale_screen.dart';
import 'view_estimates_screen.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../services/performance_service.dart';
import '../services/pdf_service.dart';
import 'view_orders_screen.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _orders = [];
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
  void initState() {
    super.initState();
    _performanceService.startOperation('HomeScreen.initState');
    _initializeWebSocket();
    _loadOrders();
    _performanceService.endOperation('HomeScreen.initState');
  }

  void _initializeWebSocket() {
    _webSocketService = WebSocketService(
      serverUrl: 'wss://pos-2wc9.onrender.com/ws',
    );
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

    _webSocketService.messageStream.listen((message) {
      if (message == 'estimate_updated' || message == 'order_updated') {
        _loadOrders();
      }
    });
  }

  Future<void> _loadOrders() async {
    if (_isRefreshing) return;

    _performanceService.startOperation('HomeScreen.loadOrders');

    setState(() {
      _isRefreshing = true;
    });

    try {
      final orders = await ApiService.fetchOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
          _isRefreshing = false;
          _lastRefreshTime = DateTime.now();
          // Invalidate cache to force recalculation
          _invalidateCache();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load orders: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    _performanceService.endOperation('HomeScreen.loadOrders');
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
    int totalOrders = _orders.length;
    int totalEstimates = 0;
    int completedSales = 0;

    for (final order in _orders) {
      final status = order['status']?.toString().toLowerCase() ?? '';

      if (status == 'completed') {
        completedSales++;
        final amount = order['amount'];
        final total = order['total'];
        final value = (amount ?? total ?? 0.0);
        totalSales += (value is num ? value.toDouble() : 0.0);
      } else if (status == 'estimate' || status == 'pending') {
        totalEstimates++;
      }
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

    // Use a more efficient sorting approach
    final sorted = List<Map<String, dynamic>>.from(_orders);
    sorted.sort((a, b) {
      final aDate = _parseDate(a['created_at']);
      final bDate = _parseDate(b['created_at']);
      return bDate.compareTo(aDate);
    });

    _cachedRecentOrders = sorted.take(5).toList();
    _performanceService.endOperation('HomeScreen.computeRecentOrders');

    return _cachedRecentOrders!;
  }

  DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is DateTime) return dateValue;
    return DateTime.tryParse(dateValue.toString()) ?? DateTime.now();
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
              _buildStatusRow(
                'Server',
                'wss://pos-2wc9.onrender.com/ws',
                Colors.grey,
              ),
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
  void dispose() {
    _webSocketService.dispose();
    _performanceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    _performanceService.startOperation('HomeScreen.build');

    final widget = Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadOrders,
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
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        _buildHeader(),
                        const SizedBox(height: 10),
                        // Today's Report
                        _buildTodayReport(),
                        const SizedBox(height: 22),
                        // Quick Actions
                        _buildQuickActions(),
                        const SizedBox(height: 14),
                        // Recent Orders and Estimates
                        _buildRecentOrders(),
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
          // Status indicator
          GestureDetector(
            onTap: _showConnectionStatus,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    _isConnected
                        ? const Color(0xFF4CAF50).withOpacity(0.2)
                        : const Color(0xFFFF5722).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color:
                          _isConnected
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF5722),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isConnected ? 'Online' : 'Offline',
                    style: TextStyle(
                      color:
                          _isConnected
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF5722),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                    child: _buildSummaryCard(
                      'Total Sales',
                      'Rs. ${_totalSales.toStringAsFixed(0)}',
                      Icons.attach_money,
                      const Color(0xFF6B8E7F),
                    ),
                  ),
                  const SizedBox(width: 6),
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
              const SizedBox(height: 6),
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
                  const SizedBox(width: 6),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reports - Coming Soon!'),
                        backgroundColor: Color(0xFF6B8E7F),
                      ),
                    );
                  },
                ),
                _buildQuickActionCard(
                  'Customers',
                  Icons.people,
                  const Color(0xFF6B8E7F),
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Customers - Coming Soon!'),
                        backgroundColor: Color(0xFF6B8E7F),
                      ),
                    );
                  },
                ),
                _buildQuickActionCard(
                  'Settings',
                  Icons.settings,
                  const Color(0xFF6B8E7F),
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings - Coming Soon!'),
                        backgroundColor: Color(0xFF6B8E7F),
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

  Widget _buildOrderItem(Map<String, dynamic> order) {
    final bool isLast =
        _recentOrders.indexOf(order) == _recentOrders.length - 1;
    final int itemCount =
        (order['items'] is List)
            ? order['items'].length
            : (order['items_count'] ?? 0);

    return GestureDetector(
      onTap: () => _showOrderDetails(order),
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
                    order['status'] == 'Completed'
                        ? const Color(0xFF4CAF50).withOpacity(0.2)
                        : const Color(0xFFFF9800).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                order['status'] == 'Completed'
                    ? Icons.check_circle
                    : Icons.description,
                color:
                    order['status'] == 'Completed'
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
                    order['id'] ?? order['estimate_number'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order['customer'] ?? order['customer_name'] ?? '',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  Text(
                    ' ${itemCount} items',
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ' Rs.  ${((order['amount'] ?? order['total'] ?? 0.0).toStringAsFixed(0))}',
                  style: const TextStyle(
                    color: Color(0xFF6B8E7F),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (order['time'] ??
                      (order['created_at']?.toString().split(' ')[0] ?? '')),
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        order['status'] == 'Completed'
                            ? const Color(0xFF4CAF50).withOpacity(0.2)
                            : const Color(0xFFFF9800).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order['status'],
                    style: TextStyle(
                      color:
                          order['status'] == 'Completed'
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

  void _showOrderDetails(Map<String, dynamic> order) {
    final bool isOrder =
        order['type'] == 'order' || order['status'] == 'Completed';
    final String orderNumber =
        isOrder
            ? (order['sale_number'] ?? order['order_id'] ?? 'Unknown')
            : (order['estimate_number'] ?? order['estimate_id'] ?? 'Unknown');

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
                  '${isOrder ? 'Order' : 'Estimate'} $orderNumber',
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
                _buildDetailRow('Customer', order['customer_name'] ?? ''),
                _buildDetailRow('Phone', order['customer_phone'] ?? ''),
                _buildDetailRow('Address', order['customer_address'] ?? ''),
                _buildDetailRow('Sale By', order['sale_by'] ?? ''),
                _buildDetailRow('Status', order['status'] ?? ''),
                if (isOrder && order['payment_mode'] != null)
                  _buildDetailRow('Payment Mode', order['payment_mode'] ?? ''),
                _buildDetailRow(
                  'Date',
                  order['time'] ?? order['created_at'].toString().split(' ')[0],
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
                ...(order['items'] as List<dynamic>?)
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
                  'Rs. ${(order['subtotal'] ?? 0.0).toStringAsFixed(2)}',
                ),
                if ((order['discount_amount'] ?? 0.0) > 0)
                  _buildDetailRow(
                    'Discount',
                    (order['is_percentage_discount'] ?? false)
                        ? '${order['discount_amount']}%'
                        : 'Rs. ${order['discount_amount'].toStringAsFixed(2)}',
                  ),
                _buildDetailRow(
                  'Total',
                  'Rs. ${(order['total'] ?? order['amount'] ?? 0.0).toStringAsFixed(2)}',
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
                  _printOrderPdf(order);
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
}
