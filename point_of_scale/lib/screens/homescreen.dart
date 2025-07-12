import 'package:flutter/material.dart';
import 'new_sale_screen.dart';
import 'view_estimates_screen.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import 'view_orders_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  late WebSocketService _webSocketService;

  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
    _loadOrders();
  }

  void _initializeWebSocket() {
    _webSocketService = WebSocketService(
      serverUrl: 'wss://pos-2wc9.onrender.com/ws',
    );
    _webSocketService.connect();
    _webSocketService.messageStream.listen((message) {
      if (message == 'estimate_updated' || message == 'order_updated') {
        _loadOrders();
      }
    });
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });
    final orders = await ApiService.fetchOrders();
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    super.dispose();
  }

  double get _totalSales => _orders
      .where((order) => order['status'] == 'Completed')
      .fold(
        0.0,
        (sum, order) => sum + (order['amount'] ?? order['total'] ?? 0.0),
      );
  int get _totalOrders => _orders.length;
  int get _totalEstimates =>
      _orders
          .where(
            (order) =>
                order['status'] == 'Estimate' || order['status'] == 'Pending',
          )
          .length;
  int get _completedSales =>
      _orders.where((order) => order['status'] == 'Completed').length;

  List<Map<String, dynamic>> get _recentOrders {
    final sorted = List<Map<String, dynamic>>.from(_orders);
    sorted.sort((a, b) {
      final aDate =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.now();
      final bDate =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.now();
      return bDate.compareTo(aDate);
    });
    return sorted.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
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
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            // Logo
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
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Status indicator
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4CAF50),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Online',
                                    style: TextStyle(
                                      color: const Color(0xFF4CAF50),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Today's Report
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Today's Report",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
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
                      ),
                      const SizedBox(height: 22),
                      // Quick Actions
                      Row(
                        children: [
                          const Icon(
                            Icons.flash_on,
                            color: Color(0xFF6B8E7F),
                            size: 18,
                          ),
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
                            crossAxisCount: 3, // 3 in a row
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
                                      builder:
                                          (context) => const NewSaleScreen(),
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
                                      builder:
                                          (context) =>
                                              const ViewEstimatesScreen(),
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
                                      builder:
                                          (context) => const ViewOrdersScreen(),
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
                      const SizedBox(height: 14),
                      // Recent Orders and Estimates
                      Row(
                        children: [
                          const Icon(
                            Icons.history,
                            color: Color(0xFF2196F3),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Recent Orders and Estimates',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Spacer(),
                          if (_recentOrders.length > 3)
                            TextButton(
                              onPressed: () {},
                              child: const Text(
                                'See All',
                                style: TextStyle(color: Color(0xFF6B8E7F)),
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
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
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
                                            .take(3)
                                            .map(
                                              (order) => _buildOrderItem(order),
                                            )
                                            .toList(),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
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

  Widget _buildOrderItem(Map<String, dynamic> order) {
    final bool isLast =
        _recentOrders.indexOf(order) == _recentOrders.length - 1;
    final int itemCount =
        (order['items'] is List)
            ? order['items'].length
            : (order['items_count'] ?? 0);
    return Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    );
  }
}
