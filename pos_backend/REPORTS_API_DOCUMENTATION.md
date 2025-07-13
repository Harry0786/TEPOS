# 📊 TEPOS Reports API Documentation

This document describes the new reporting system that properly separates **Orders** and **Estimates** for accurate business analytics.

## 🎯 **Key Changes**

### **Before (Legacy)**
- Orders and estimates were mixed together
- Single count for all transactions
- No distinction in reporting

### **After (New System)**
- **Orders**: Completed sales with payment
- **Estimates**: Pending quotes/proposals
- **Separate counting** for accurate business metrics
- **Detailed breakdowns** by type, status, and payment method

## 📋 **API Endpoints**

### **1. Today's Report**
Get today's business summary with separate counts.

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
    "status_breakdown": {
      "pending": 8,
      "accepted": 5,
      "rejected": 2
    },
    "items": [...]
  },
  "orders": {
    "count": 10,
    "total_amount": 20000.00,
    "payment_breakdown": {
      "cash": 6,
      "card": 3,
      "online": 1
    },
    "items": [...]
  }
}
```

### **2. Date Range Report**
Get report for a specific date range.

```http
GET /api/reports/date-range?start_date=2024-01-01&end_date=2024-01-31
```

**Response:**
```json
{
  "date_range": {
    "start": "2024-01-01",
    "end": "2024-01-31"
  },
  "summary": {
    "total_transactions": 150,
    "total_revenue": 250000.00,
    "estimates_count": 90,
    "orders_count": 60
  },
  "estimates": {
    "count": 90,
    "total_amount": 150000.00,
    "items": [...]
  },
  "orders": {
    "count": 60,
    "total_amount": 100000.00,
    "items": [...]
  }
}
```

### **3. Monthly Report**
Get detailed monthly report with daily breakdown.

```http
GET /api/reports/monthly/2024/1
```

**Response:**
```json
{
  "period": {
    "year": 2024,
    "month": 1,
    "start_date": "2024-01-01T00:00:00",
    "end_date": "2024-01-31T23:59:59"
  },
  "summary": {
    "total_estimates": 90,
    "total_orders": 60,
    "total_estimates_amount": 150000.00,
    "total_orders_amount": 100000.00
  },
  "daily_breakdown": {
    "estimates": {
      "2024-01-01": {"count": 3, "total": 5000.00},
      "2024-01-02": {"count": 5, "total": 8000.00}
    },
    "orders": {
      "2024-01-01": {"count": 2, "total": 3000.00},
      "2024-01-02": {"count": 4, "total": 6000.00}
    }
  }
}
```

### **4. Staff Performance Report**
Get staff performance with separate order and estimate counts.

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
    },
    {
      "staff_name": "Priya Sharma",
      "estimates_count": 30,
      "estimates_total": 50000.00,
      "orders_count": 20,
      "orders_total": 35000.00,
      "total_transactions": 50,
      "total_revenue": 85000.00
    }
  ],
  "summary": {
    "total_staff": 2,
    "total_estimates": 75,
    "total_orders": 50,
    "total_revenue": 210000.00
  }
}
```

### **5. Estimates-Only Report**
Get detailed estimates report.

```http
GET /api/reports/estimates-only
```

**Response:**
```json
{
  "estimates": {
    "total_count": 90,
    "total_amount": 150000.00,
    "status_breakdown": {
      "pending": 45,
      "accepted": 35,
      "rejected": 10
    },
    "items": [...]
  }
}
```

### **6. Orders-Only Report**
Get detailed orders report.

```http
GET /api/reports/orders-only
```

**Response:**
```json
{
  "orders": {
    "total_count": 60,
    "total_amount": 100000.00,
    "payment_breakdown": {
      "cash": 35,
      "card": 20,
      "online": 5
    },
    "items": [...]
  }
}
```

### **7. Separate Data Endpoint**
Get orders and estimates as separate lists (new endpoint).

```http
GET /api/orders/separate
```

**Response:**
```json
{
  "estimates": {
    "count": 90,
    "total_amount": 150000.00,
    "items": [...]
  },
  "orders": {
    "count": 60,
    "total_amount": 100000.00,
    "items": [...]
  },
  "summary": {
    "total_estimates": 90,
    "total_orders": 60,
    "total_transactions": 150,
    "total_revenue": 250000.00
  }
}
```

### **8. Orders-Only Data**
Get only completed orders.

```http
GET /api/orders/orders-only
```

**Response:**
```json
{
  "orders": {
    "count": 60,
    "total_amount": 100000.00,
    "items": [...]
  }
}
```

## 📊 **Business Logic**

### **Estimates**
- **Purpose**: Quotes and proposals for potential customers
- **Status**: Pending, Accepted, Rejected
- **Revenue**: Not actual revenue (potential)
- **Counting**: Separate from orders

### **Orders**
- **Purpose**: Completed sales with payment
- **Status**: Completed
- **Payment**: Cash, Card, Online
- **Revenue**: Actual revenue
- **Counting**: Separate from estimates

### **Key Metrics**
- **Total Transactions**: Estimates + Orders
- **Total Revenue**: Estimates (potential) + Orders (actual)
- **Conversion Rate**: Orders / (Estimates + Orders)
- **Staff Performance**: Separate counts for each type

## 🔄 **Migration Guide**

### **For Frontend Developers**

#### **Old Way (Legacy)**
```dart
// Single endpoint for all data
final response = await http.get(Uri.parse('$baseUrl/orders/all'));
final allData = jsonDecode(response.body);
// Mixed orders and estimates
```

#### **New Way (Recommended)**
```dart
// Separate endpoints for better control
final estimatesResponse = await http.get(Uri.parse('$baseUrl/reports/estimates-only'));
final ordersResponse = await http.get(Uri.parse('$baseUrl/reports/orders-only'));
final todayReport = await http.get(Uri.parse('$baseUrl/reports/today'));

// Or use the separate endpoint
final separateResponse = await http.get(Uri.parse('$baseUrl/orders/separate'));
final data = jsonDecode(separateResponse.body);
final estimates = data['estimates'];
final orders = data['orders'];
```

### **For Dashboard Development**

#### **Today's Summary**
```dart
Widget buildTodaySummary() {
  return FutureBuilder(
    future: getTodayReport(),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final data = snapshot.data!;
        return Column(
          children: [
            Text('Estimates: ${data['estimates']['count']}'),
            Text('Orders: ${data['orders']['count']}'),
            Text('Total Revenue: ₹${data['summary']['total_revenue']}'),
          ],
        );
      }
      return CircularProgressIndicator();
    },
  );
}
```

#### **Staff Performance**
```dart
Widget buildStaffPerformance() {
  return FutureBuilder(
    future: getStaffPerformance(),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final staff = snapshot.data!['staff_performance'];
        return ListView.builder(
          itemCount: staff.length,
          itemBuilder: (context, index) {
            final member = staff[index];
            return ListTile(
              title: Text(member['staff_name']),
              subtitle: Text('Estimates: ${member['estimates_count']} | Orders: ${member['orders_count']}'),
              trailing: Text('₹${member['total_revenue']}'),
            );
          },
        );
      }
      return CircularProgressIndicator();
    },
  );
}
```

## 📈 **Analytics Use Cases**

### **1. Sales Performance**
- Track estimate-to-order conversion rate
- Monitor staff performance separately
- Analyze payment method preferences

### **2. Business Planning**
- Separate potential vs actual revenue
- Plan inventory based on orders
- Forecast based on estimates

### **3. Staff Management**
- Compare estimate generation vs order completion
- Identify top performers in each category
- Set realistic targets

### **4. Customer Insights**
- Track estimate acceptance rates
- Analyze customer preferences
- Monitor seasonal trends

## 🔧 **Testing**

### **Test Today's Report**
```bash
curl https://pos-2wc9.onrender.com/api/reports/today
```

### **Test Staff Performance**
```bash
curl https://pos-2wc9.onrender.com/api/reports/staff-performance
```

### **Test Separate Data**
```bash
curl https://pos-2wc9.onrender.com/api/orders/separate
```

## 🎯 **Benefits**

1. **Accurate Reporting**: Separate counts for different business activities
2. **Better Analytics**: Detailed breakdowns for informed decisions
3. **Staff Performance**: Fair evaluation based on actual vs potential sales
4. **Business Planning**: Clear distinction between potential and actual revenue
5. **Customer Insights**: Track estimate conversion rates

---

**🎉 Your TEPOS system now provides accurate, separate reporting for orders and estimates!** 