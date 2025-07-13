# 🔗 Estimate-Order Relationship System

This document describes the new relationship system between **Estimates** and **Orders** in TEPOS, ensuring proper separation and linking capabilities.

## 🎯 **Key Changes**

### **Before (Legacy System)**
- Estimates and orders were mixed together
- Estimates had "Accept/Reject" status
- No proper linking between estimates and orders
- Confusing business logic

### **After (New System)**
- **Estimates**: Pure quotes/proposals (potential business)
- **Orders**: Completed sales (actual business)
- **Convert to Order**: Transform estimate into order
- **Bidirectional Linking**: Track relationships between estimates and orders
- **Separate Counting**: Accurate business metrics

## 📊 **Business Logic**

### **Estimates**
- **Purpose**: Quotes and proposals for potential customers
- **Status**: Pending (not converted) or Converted (has linked order)
- **Revenue**: Potential revenue (not actual)
- **Actions**: Delete, Convert to Order
- **Counting**: Separate from orders

### **Orders**
- **Purpose**: Completed sales with payment
- **Status**: Completed
- **Payment**: Cash, Card, Online
- **Revenue**: Actual revenue
- **Source**: Direct sale or converted from estimate
- **Counting**: Separate from estimates

### **Relationship**
- **One-to-One**: One estimate can be converted to one order
- **Bidirectional**: Both entities track the relationship
- **Immutable**: Once converted, estimate cannot be deleted
- **Traceable**: Full audit trail of conversions

## 🔧 **Database Schema**

### **Estimates Collection**
```json
{
  "_id": "ObjectId",
  "estimate_id": "EST-ABC12345",
  "estimate_number": "#001",
  "customer_name": "John Doe",
  "customer_phone": "9876543210",
  "customer_address": "123 Main Street",
  "sale_by": "Rajesh Goyal",
  "items": [...],
  "subtotal": 300.0,
  "discount_amount": 30.0,
  "is_percentage_discount": true,
  "discount_percentage": 10.0,
  "total": 270.0,
  "created_at": "2024-01-01T12:00:00",
  "is_converted_to_order": false,
  "linked_order_id": null,
  "linked_order_number": null
}
```

### **Orders Collection**
```json
{
  "_id": "ObjectId",
  "order_id": "ORDER-DEF67890",
  "sale_number": "#001",
  "customer_name": "John Doe",
  "customer_phone": "9876543210",
  "customer_address": "123 Main Street",
  "sale_by": "Rajesh Goyal",
  "items": [...],
  "subtotal": 300.0,
  "discount_amount": 30.0,
  "is_percentage_discount": true,
  "discount_percentage": 10.0,
  "total": 270.0,
  "payment_mode": "Cash",
  "status": "Completed",
  "created_at": "2024-01-01T14:00:00",
  "source_estimate_id": "EST-ABC12345",
  "source_estimate_number": "#001",
  "is_from_estimate": true
}
```

## 📋 **API Endpoints**

### **Estimate Management**

#### **1. Create Estimate**
```http
POST /api/estimates/create
```
**Response:**
```json
{
  "success": true,
  "message": "Estimate created successfully!",
  "data": {
    "estimate_id": "EST-ABC12345",
    "estimate_number": "#001",
    "customer_name": "John Doe",
    "total": 270.0,
    "created_at": "2024-01-01T12:00:00"
  }
}
```

#### **2. Get All Estimates**
```http
GET /api/estimates/all
```
**Response:**
```json
[
  {
    "id": "507f1f77bcf86cd799439011",
    "estimate_id": "EST-ABC12345",
    "estimate_number": "#001",
    "customer_name": "John Doe",
    "total": 270.0,
    "is_converted_to_order": false,
    "linked_order_id": null,
    "linked_order_number": null,
    "created_at": "2024-01-01T12:00:00"
  },
  {
    "id": "507f1f77bcf86cd799439012",
    "estimate_id": "EST-DEF67890",
    "estimate_number": "#002",
    "customer_name": "Jane Smith",
    "total": 500.0,
    "is_converted_to_order": true,
    "linked_order_id": "ORDER-GHI11111",
    "linked_order_number": "#001",
    "created_at": "2024-01-01T10:00:00"
  }
]
```

#### **3. Get Pending Estimates**
```http
GET /api/estimates/pending
```
**Response:** Only estimates that haven't been converted to orders

#### **4. Get Converted Estimates**
```http
GET /api/estimates/converted
```
**Response:** Only estimates that have been converted to orders

#### **5. Delete Estimate**
```http
DELETE /api/estimates/{estimate_id}
```
**Note:** Cannot delete estimates that have been converted to orders

#### **6. Convert Estimate to Order**
```http
POST /api/estimates/{estimate_id}/convert-to-order?payment_mode=Cash
```
**Response:**
```json
{
  "success": true,
  "message": "Estimate converted to order successfully!",
  "data": {
    "order_id": "ORDER-GHI11111",
    "sale_number": "#001",
    "estimate_id": "EST-DEF67890",
    "estimate_number": "#002",
    "customer_name": "Jane Smith",
    "total": 500.0,
    "payment_mode": "Cash",
    "created_at": "2024-01-01T14:00:00"
  }
}
```

### **Order Management**

#### **1. Create Direct Order**
```http
POST /api/orders/create-sale
```
**Note:** Creates order without estimate link

#### **2. Get Orders with Estimate Links**
```http
GET /api/orders/all
```
**Response:** Shows `is_from_estimate` and `source_estimate_number` fields

#### **3. Get Orders Only**
```http
GET /api/orders/orders-only
```
**Response:** Only completed orders

#### **4. Get Separate Data**
```http
GET /api/orders/separate
```
**Response:**
```json
{
  "estimates": {
    "count": 10,
    "total_amount": 5000.0,
    "items": [...]
  },
  "orders": {
    "count": 8,
    "total_amount": 4000.0,
    "items": [...]
  },
  "summary": {
    "total_estimates": 10,
    "total_orders": 8,
    "total_transactions": 18,
    "total_revenue": 9000.0
  }
}
```

## 📈 **Reporting System**

### **Today's Report**
```http
GET /api/reports/today
```
**Response:**
```json
{
  "date": "2024-01-15",
  "summary": {
    "total_transactions": 25,
    "total_revenue": 45000.00,
    "estimates_count": 15,
    "orders_count": 10
  },
  "estimates": {
    "count": 15,
    "total_amount": 25000.00,
    "conversion_breakdown": {
      "pending": 8,
      "converted": 7
    }
  },
  "orders": {
    "count": 10,
    "total_amount": 20000.00,
    "payment_breakdown": {
      "cash": 6,
      "card": 3,
      "online": 1
    }
  }
}
```

### **Staff Performance**
```http
GET /api/reports/staff-performance
```
**Response:**
```json
{
  "staff_performance": [
    {
      "staff_name": "Rajesh Goyal",
      "estimates_count": 45,
      "estimates_total": 75000.00,
      "orders_count": 30,
      "orders_total": 50000.00,
      "total_transactions": 75,
      "total_revenue": 125000.00
    }
  ]
}
```

## 🔄 **Workflow Examples**

### **Scenario 1: Estimate to Order Conversion**
1. **Create Estimate**: Customer requests quote
2. **Send Estimate**: Share PDF with customer
3. **Customer Accepts**: Convert estimate to order
4. **Process Payment**: Complete the sale
5. **Track Relationship**: Both entities linked

### **Scenario 2: Direct Sale**
1. **Create Order**: Customer buys immediately
2. **Process Payment**: Complete the sale
3. **No Estimate**: Order created directly

### **Scenario 3: Estimate Deletion**
1. **Create Estimate**: Customer requests quote
2. **Customer Rejects**: Delete estimate
3. **No Order**: Estimate removed from system

## 🎯 **Benefits**

### **1. Accurate Business Metrics**
- Separate counting of estimates and orders
- Clear distinction between potential and actual revenue
- Proper conversion rate tracking

### **2. Better Customer Management**
- Track estimate-to-order conversion rates
- Identify high-value prospects
- Monitor customer decision patterns

### **3. Improved Staff Performance**
- Fair evaluation of estimate generation vs order completion
- Separate metrics for different skills
- Better incentive structures

### **4. Enhanced Reporting**
- Detailed conversion analytics
- Staff performance breakdowns
- Business forecasting capabilities

### **5. Data Integrity**
- Immutable relationships once established
- Full audit trail of conversions
- No data loss or confusion

## 🔧 **Frontend Integration**

### **Estimate List View**
```dart
Widget buildEstimateList() {
  return FutureBuilder(
    future: getEstimates(),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final estimates = snapshot.data!;
        return ListView.builder(
          itemCount: estimates.length,
          itemBuilder: (context, index) {
            final estimate = estimates[index];
            return ListTile(
              title: Text(estimate['estimate_number']),
              subtitle: Text(estimate['customer_name']),
              trailing: estimate['is_converted_to_order'] 
                ? Icon(Icons.check_circle, color: Colors.green)
                : Icon(Icons.pending, color: Colors.orange),
              onTap: () => showEstimateDetails(estimate),
            );
          },
        );
      }
      return CircularProgressIndicator();
    },
  );
}
```

### **Estimate Details View**
```dart
Widget buildEstimateDetails(Map<String, dynamic> estimate) {
  return Column(
    children: [
      // Estimate details
      Text('Estimate: ${estimate['estimate_number']}'),
      Text('Customer: ${estimate['customer_name']}'),
      Text('Total: ₹${estimate['total']}'),
      
      // Conversion status
      if (estimate['is_converted_to_order']) ...[
        Text('✅ Converted to Order'),
        Text('Order: ${estimate['linked_order_number']}'),
      ] else ...[
        ElevatedButton(
          onPressed: () => convertToOrder(estimate['estimate_id']),
          child: Text('Convert to Order'),
        ),
        ElevatedButton(
          onPressed: () => deleteEstimate(estimate['estimate_id']),
          child: Text('Delete Estimate'),
        ),
      ],
    ],
  );
}
```

### **Order Details View**
```dart
Widget buildOrderDetails(Map<String, dynamic> order) {
  return Column(
    children: [
      // Order details
      Text('Order: ${order['sale_number']}'),
      Text('Customer: ${order['customer_name']}'),
      Text('Total: ₹${order['total']}'),
      Text('Payment: ${order['payment_mode']}'),
      
      // Source information
      if (order['is_from_estimate']) ...[
        Text('📋 Created from Estimate'),
        Text('Estimate: ${order['source_estimate_number']}'),
      ] else ...[
        Text('💰 Direct Sale'),
      ],
    ],
  );
}
```

## 🚀 **Migration Guide**

### **For Existing Data**
1. **Backup**: Export current data
2. **Update**: Add new fields to existing records
3. **Migrate**: Convert old status-based logic to new relationship system
4. **Test**: Verify all functionality works correctly

### **For Frontend Apps**
1. **Update API calls**: Use new endpoints
2. **Modify UI**: Show conversion status instead of accept/reject
3. **Add functionality**: Convert to order and delete options
4. **Update reports**: Use new reporting endpoints

---

**🎉 Your TEPOS system now has a proper estimate-order relationship system with accurate business metrics!** 