# TEPOS - Tirupati Electricals Point of Sale System

A modern, feature-rich Flutter-based Point of Sale (POS) application designed specifically for Tirupati Electricals. The system includes a robust FastAPI backend with real-time WebSocket communication, comprehensive reporting, and seamless customer communication.

![TEPOS Logo](assets/icon/TEPOS%20Logo.png)

## 🚀 Features

### Core POS Features
- **Product Management**: Add, edit, and manage products in cart with real-time calculations
- **Estimate Generation**: Create professional estimates with automatic PDF generation
- **Order Management**: Complete order lifecycle from creation to completion
- **Customer Management**: Store and manage customer details for estimates and orders
- **Staff Tracking**: Track sales by different staff members
- **Sequential Numbering**: Automatic sequential numbering for estimates (#001, #002, etc.)

### Communication & Sharing
- **WhatsApp Integration**: Send estimates directly to customers via WhatsApp
- **SMS Service**: Send notifications and updates via SMS
- **PDF Generation**: Professional PDF estimates with company branding
- **Multi-platform Sharing**: Share PDFs via email, messaging apps, or cloud storage

### Payment & Financial
- **Multiple Payment Modes**: Cash, Card, UPI, Online, Bank Transfer, Cheque
- **Payment Breakdown**: Detailed payment mode analysis with amounts and counts
- **Discount Management**: Apply percentage or fixed amount discounts
- **Financial Reporting**: Comprehensive sales and payment reports

### Real-time Features
- **WebSocket Communication**: Real-time updates across all connected devices
- **Live Data Sync**: Automatic synchronization of estimates, orders, and sales
- **Auto-refresh**: Smart data refresh with optimized backend load
- **Connection Health Monitoring**: Robust connection management with automatic reconnection

### Performance & Stability
- **Optimized Performance**: Reduced frame drops and improved responsiveness
- **Memory Management**: Proper resource cleanup and memory leak prevention
- **Error Handling**: Comprehensive error handling with graceful recovery
- **Timeout Protection**: Request timeouts to prevent hanging operations

## 🏗️ Architecture

### Frontend (Flutter)
```
lib/
├── main.dart                 # App entry point with error handling
├── screens/                  # UI screens
│   ├── homescreen.dart       # Main dashboard with analytics
│   ├── new_sale_screen.dart  # Sales and estimate creation
│   ├── view_orders_screen.dart # Order management
│   ├── view_estimates_screen.dart # Estimate management
│   ├── reports_screen.dart   # Financial reporting
│   ├── settings_screen.dart  # App configuration
│   └── splash_screen.dart    # App loading screen
├── services/                 # Business logic and API services
│   ├── api_service.dart      # REST API communication
│   ├── websocket_service.dart # Real-time WebSocket handling
│   ├── pdf_service.dart      # PDF generation
│   ├── whatsapp_service.dart # WhatsApp integration
│   ├── sms_service.dart      # SMS functionality
│   ├── performance_service.dart # Performance monitoring
│   └── auto_refresh_service.dart # Smart data refresh
└── widgets/                  # Reusable UI components
```

### Backend (FastAPI + MongoDB)
```
pos_backend/
├── main.py                   # FastAPI application entry point
├── config.py                 # Configuration management
├── routers/                  # API route handlers
│   ├── estimate_route_new.py # Estimate CRUD operations
│   ├── orders_route_new.py   # Order CRUD operations
│   ├── reports_route.py      # Financial reporting APIs
│   └── sms_route.py          # SMS service endpoints
├── models/                   # Data models
│   ├── estimate.py           # Estimate data model
│   └── order.py              # Order data model
├── services/                 # Backend services
│   ├── websocket_service.py  # WebSocket management
│   └── sms_service.py        # SMS service implementation
└── database/                 # Database configuration
```

## 📱 Screenshots & Features

### Dashboard
- Real-time sales analytics
- Payment breakdown by mode
- Recent orders and estimates
- Staff performance tracking

### Sales & Estimates
- Intuitive product selection
- Real-time price calculations
- Professional PDF generation
- WhatsApp integration

### Order Management
- Complete order lifecycle
- Status tracking
- Payment mode management
- Order history

### Reporting
- Daily, weekly, monthly reports
- Payment mode analysis
- Staff performance metrics
- Financial summaries

## 🛠️ Setup Instructions

### Prerequisites
- Flutter SDK (^3.7.2)
- Python 3.8+
- MongoDB
- Android Studio / VS Code

### Frontend Setup
1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd point_of_scale
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure API endpoints**
   - Update `lib/services/api_service.dart` with your backend URL
   - Ensure WebSocket URL is correctly configured

4. **Run the application**
   ```bash
   flutter run
   ```

### Backend Setup
1. **Navigate to backend directory**
   ```bash
   cd pos_backend
   ```

2. **Create virtual environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment**
   - Set up MongoDB connection
   - Configure SMS service credentials
   - Set environment variables

5. **Run the server**
   ```bash
   uvicorn main:app --host 0.0.0.0 --port 8000
   ```

## 📦 Dependencies

### Frontend Dependencies
```yaml
dependencies:
  flutter: sdk: flutter
  cupertino_icons: ^1.0.8
  http: ^1.1.0                    # API communication
  pdf: ^3.11.3                    # PDF generation
  flutter_pdfview: ^1.4.1+1       # PDF viewing
  path_provider: ^2.1.5           # File system access
  share_plus: ^11.0.0             # File sharing
  intl: ^0.20.2                   # Date formatting
  url_launcher: ^6.2.5            # WhatsApp integration
  web_socket_channel: ^2.4.0      # Real-time communication
  printing: ^5.12.0               # PDF printing
```

### Backend Dependencies
```
fastapi==0.104.1          # Web framework
uvicorn==0.24.0           # ASGI server
motor==3.3.1              # MongoDB async driver
pymongo==4.5.0            # MongoDB driver
python-dotenv             # Environment management
requests==2.31.0          # HTTP requests
python-multipart==0.0.6   # File uploads
websockets==12.0          # WebSocket support
python-dateutil           # Date utilities
```

## 🔧 Configuration

### API Configuration
The app supports multiple environments:
- **Development**: Local development server
- **Production**: Render deployment
- **Custom**: Configurable endpoints

### WebSocket Configuration
- Real-time data synchronization
- Automatic reconnection
- Connection health monitoring
- Error handling and recovery

### SMS Service
- Twilio integration for SMS
- WhatsApp Business API support
- Custom SMS templates

## 📊 Recent Improvements

### Performance Optimizations
- **Reduced Frame Drops**: From 131+ frames to minimal drops
- **Memory Management**: Proper resource cleanup and disposal
- **Async Operations**: Non-blocking main thread operations
- **Caching**: Smart data caching with invalidation

### Stability Enhancements
- **Error Handling**: Comprehensive error handling throughout the app
- **Timeout Protection**: Request timeouts to prevent hanging
- **Connection Management**: Robust WebSocket connection handling
- **Crash Prevention**: Safe state management and disposal

### User Experience
- **Loading States**: Proper loading indicators for all operations
- **Error Messages**: Clear and informative error messages
- **Responsive Design**: Optimized for various screen sizes
- **Accessibility**: Improved accessibility features

## 🧪 Testing

### Test Applications
- `test_stability.dart` - WebSocket and connection stability testing
- `test_delete_fix.dart` - Delete operation testing
- `test_optimization.dart` - Performance optimization testing

### Running Tests
```bash
# Stability test
flutter run test_stability.dart

# Delete operation test
flutter run test_delete_fix.dart

# Performance test
flutter run test_optimization.dart
```

## 📚 Documentation

### Implementation Guides
- [Payment Breakdown Implementation](PAYMENT_BREAKDOWN_IMPLEMENTATION.md)
- [WhatsApp Integration Guide](WHATSAPP_INTEGRATION_GUIDE.md)
- [Performance Optimization Guide](PERFORMANCE_OPTIMIZATION_GUIDE.md)
- [Backend Load Optimization](BACKEND_LOAD_OPTIMIZATION.md)

### Fix Documentation
- [Stability Fixes](STABILITY_FIXES.md)
- [Delete Order Fixes](DELETE_ORDER_FIXES.md)
- [Performance Fixes](PERFORMANCE_FIXES.md)

## 🚀 Deployment

### Frontend Deployment
- **Android**: Generate APK with `flutter build apk`
- **iOS**: Build for App Store with `flutter build ios`
- **Web**: Deploy to web with `flutter build web`

### Backend Deployment
- **Render**: Automated deployment from GitHub
- **Docker**: Containerized deployment
- **VPS**: Manual server deployment

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is proprietary software developed for Tirupati Electricals.

## 📞 Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation files

## 🔄 Version History

### v1.0.0+1 (Current)
- Complete POS system with real-time features
- WhatsApp integration
- Comprehensive reporting
- Performance optimizations
- Stability improvements

---

**TEPOS** - Empowering Tirupati Electricals with modern point-of-sale technology.
