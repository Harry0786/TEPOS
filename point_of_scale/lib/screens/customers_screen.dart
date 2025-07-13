import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auto_refresh_service.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen>
    with AutoRefreshMixin {
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void _onRefresh() {
    if (mounted) {
      _loadCustomers();
    }
  }

  @override
  void _onAppResume() {
    if (mounted) {
      _loadCustomers();
    }
  }

  Future<void> _loadCustomers() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final customers = await ApiService.fetchCustomers();
      if (mounted) {
        setState(() {
          _customers = customers ?? [];
          _isLoading = false;
          _isRefreshing = false;
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
            content: Text('Error loading customers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredAndSortedCustomers {
    List<Map<String, dynamic>> filtered = _customers;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((customer) {
            final name = customer['name']?.toString().toLowerCase() ?? '';
            final phone = customer['phone']?.toString().toLowerCase() ?? '';
            final email = customer['email']?.toString().toLowerCase() ?? '';
            final address = customer['address']?.toString().toLowerCase() ?? '';
            final query = _searchQuery.toLowerCase();

            return name.contains(query) ||
                phone.contains(query) ||
                email.contains(query) ||
                address.contains(query);
          }).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      dynamic aValue = a[_sortBy] ?? '';
      dynamic bValue = b[_sortBy] ?? '';

      if (aValue is String && bValue is String) {
        aValue = aValue.toLowerCase();
        bValue = bValue.toLowerCase();
      }

      int comparison = aValue.compareTo(bValue);
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Customers',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: forceRefresh,
            icon: Icon(isRefreshing ? Icons.hourglass_empty : Icons.refresh),
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: _onSortOptionSelected,
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'name',
                    child: Text('Sort by Name'),
                  ),
                  const PopupMenuItem(
                    value: 'phone',
                    child: Text('Sort by Phone'),
                  ),
                  const PopupMenuItem(
                    value: 'email',
                    child: Text('Sort by Email'),
                  ),
                  const PopupMenuItem(
                    value: 'created_at',
                    child: Text('Sort by Date Added'),
                  ),
                ],
            child: const Icon(Icons.sort),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          _buildSearchBar(),

          // Customer Count
          _buildCustomerCount(),

          // Customers List
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF6B8E7F),
                        ),
                      ),
                    )
                    : _filteredAndSortedCustomers.isEmpty
                    ? _buildEmptyState()
                    : _buildCustomersList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCustomerDialog,
        backgroundColor: const Color(0xFF6B8E7F),
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Add Customer',
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade600),
      ),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Search customers...',
          hintStyle: TextStyle(color: Colors.grey),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Color(0xFF6B8E7F)),
        ),
      ),
    );
  }

  Widget _buildCustomerCount() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.people, color: const Color(0xFF6B8E7F), size: 16),
          const SizedBox(width: 8),
          Text(
            '${_filteredAndSortedCustomers.length} customer${_filteredAndSortedCustomers.length == 1 ? '' : 's'}',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              'filtered from ${_customers.length} total',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No customers found matching "$_searchQuery"'
                : 'No customers yet',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try adjusting your search terms'
                : 'Add your first customer to get started',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (!_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddCustomerDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Customer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E7F),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredAndSortedCustomers.length,
      itemBuilder: (context, index) {
        final customer = _filteredAndSortedCustomers[index];
        return _buildCustomerCard(customer);
      },
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    final name = customer['name'] ?? 'Unknown';
    final phone = customer['phone'] ?? 'No phone';
    final email = customer['email'] ?? 'No email';
    final address = customer['address'] ?? 'No address';
    final totalOrders = customer['total_orders'] ?? 0;
    final totalSpent = customer['total_spent'] ?? 0.0;
    final lastOrderDate = customer['last_order_date'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF6B8E7F),
          radius: 25,
          child: Text(
            name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  phone,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
            if (email != 'No email') ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.email, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    email,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.shopping_cart,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 4),
                Text(
                  '$totalOrders orders • Rs. ${totalSpent.toStringAsFixed(0)} spent',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _onCustomerActionSelected(value, customer),
          itemBuilder:
              (context) => [
                const PopupMenuItem(value: 'view', child: Text('View Details')),
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'orders',
                  child: Text('View Orders'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
          child: const Icon(Icons.more_vert, color: Colors.grey),
        ),
        onTap: () => _showCustomerDetails(customer),
      ),
    );
  }

  void _onSortOptionSelected(String option) {
    setState(() {
      if (_sortBy == option) {
        _sortAscending = !_sortAscending;
      } else {
        _sortBy = option;
        _sortAscending = true;
      }
    });
  }

  void _onCustomerActionSelected(String action, Map<String, dynamic> customer) {
    switch (action) {
      case 'view':
        _showCustomerDetails(customer);
        break;
      case 'edit':
        _showEditCustomerDialog(customer);
        break;
      case 'orders':
        _viewCustomerOrders(customer);
        break;
      case 'delete':
        _showDeleteConfirmation(customer);
        break;
    }
  }

  void _showCustomerDetails(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Text(
              customer['name'] ?? 'Customer Details',
              style: const TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Name', customer['name'] ?? 'N/A'),
                _buildDetailRow('Phone', customer['phone'] ?? 'N/A'),
                _buildDetailRow('Email', customer['email'] ?? 'N/A'),
                _buildDetailRow('Address', customer['address'] ?? 'N/A'),
                _buildDetailRow(
                  'Total Orders',
                  '${customer['total_orders'] ?? 0}',
                ),
                _buildDetailRow(
                  'Total Spent',
                  'Rs. ${(customer['total_spent'] ?? 0.0).toStringAsFixed(0)}',
                ),
                if (customer['last_order_date'] != null)
                  _buildDetailRow('Last Order', customer['last_order_date']),
                _buildDetailRow(
                  'Customer Since',
                  customer['created_at'] ?? 'N/A',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Color(0xFF6B8E7F)),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showEditCustomerDialog(customer);
                },
                child: const Text(
                  'Edit',
                  style: TextStyle(color: Color(0xFF6B8E7F)),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog() {
    _showCustomerFormDialog(null);
  }

  void _showEditCustomerDialog(Map<String, dynamic> customer) {
    _showCustomerFormDialog(customer);
  }

  void _showCustomerFormDialog(Map<String, dynamic>? customer) {
    final isEditing = customer != null;
    final nameController = TextEditingController(text: customer?['name'] ?? '');
    final phoneController = TextEditingController(
      text: customer?['phone'] ?? '',
    );
    final emailController = TextEditingController(
      text: customer?['email'] ?? '',
    );
    final addressController = TextEditingController(
      text: customer?['address'] ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Text(
              isEditing ? 'Edit Customer' : 'Add New Customer',
              style: const TextStyle(color: Colors.white),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Name *',
                        labelStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Phone *',
                        labelStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Phone is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: addressController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        labelStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(context).pop();
                    await _saveCustomer(isEditing ? customer!['id'] : null, {
                      'name': nameController.text,
                      'phone': phoneController.text,
                      'email': emailController.text,
                      'address': addressController.text,
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B8E7F),
                ),
                child: Text(isEditing ? 'Update' : 'Add'),
              ),
            ],
          ),
    );
  }

  Future<void> _saveCustomer(
    String? customerId,
    Map<String, dynamic> customerData,
  ) async {
    try {
      Map<String, dynamic>? result;

      if (customerId != null) {
        result = await ApiService.updateCustomer(customerId, customerData);
      } else {
        result = await ApiService.createCustomer(customerData);
      }

      if (result != null) {
        await _loadCustomers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                customerId != null
                    ? 'Customer updated successfully!'
                    : 'Customer added successfully!',
              ),
              backgroundColor: const Color(0xFF6B8E7F),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save customer. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving customer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text(
              'Delete Customer',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Are you sure you want to delete ${customer['name']}? This action cannot be undone.',
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _deleteCustomer(customer['id']);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteCustomer(String customerId) async {
    try {
      final success = await ApiService.deleteCustomer(customerId);

      if (success) {
        await _loadCustomers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer deleted successfully!'),
              backgroundColor: Color(0xFF6B8E7F),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete customer. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting customer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewCustomerOrders(Map<String, dynamic> customer) {
    // This would navigate to a customer orders screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing orders for ${customer['name']}'),
        backgroundColor: const Color(0xFF6B8E7F),
      ),
    );
  }
}
