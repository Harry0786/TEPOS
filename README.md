# TEPOS - Modern Point of Sale System

<div align="center">
  <img src="point_of_scale/assets/icon/TEPOS Logo.png" alt="TEPOS Logo" width="200"/>
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.7.2+-blue.svg)](https://flutter.dev/)
  [![FastAPI](https://img.shields.io/badge/FastAPI-0.104.1+-green.svg)](https://fastapi.tiangolo.com/)
  [![MongoDB](https://img.shields.io/badge/MongoDB-4.5.0+-orange.svg)](https://www.mongodb.com/)
  [![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
  [![Production](https://img.shields.io/badge/Status-Production%20Ready-green.svg)](https://pos-2wc9.onrender.com)
</div>

A comprehensive **Point of Sale (POS) system** built with **Flutter** for the frontend and **FastAPI** for the backend, designed specifically for **Tirupati Electricals**. This modern, cross-platform solution provides seamless sales management, estimate generation, and customer communication with **real-time synchronization** and **production deployment**.

## 🚀 Features

### 💼 Core POS Features
- **Product Management**: Add, edit, and manage products in cart with real-time inventory
- **Sales Tracking**: Track sales by different staff members with detailed analytics
- **Discount Management**: Apply percentage or fixed amount discounts with validation
- **Customer Management**: Store and manage customer details with history
- **Sequential Numbering**: Automatic estimate numbering (#001, #002, etc.) with collision prevention
- **Multi-platform Support**: Android, iOS, Windows, macOS, and Linux compatibility

### 📄 Estimate & Billing
- **Professional Estimates**: Create detailed estimates with PDF export and custom branding
- **Bill Generation**: Generate and send bills to customers with payment tracking
- **PDF Generation**: High-quality PDFs with company branding and professional layout
- **Multiple Formats**: Support for estimates, invoices, and order confirmations
- **Print Integration**: Direct printing support for receipts and documents
- **Template Customization**: Customizable PDF templates for different document types

### 📱 Communication Integration
- **WhatsApp Integration**: Send estimates directly to customer WhatsApp with one-click sharing
- **SMS Service**: Automated SMS notifications via Twilio integration
- **Real-time Sync**: WebSocket-based real-time updates across all connected devices
- **File Sharing**: Share PDFs via any app or email with built-in sharing capabilities
- **Notification System**: Push notifications for order updates and system alerts

### 🔧 Technical Features
- **Cross-platform**: Works on Android, iOS, Windows, macOS, and Linux
- **Real-time Updates**: WebSocket integration for live data sync and instant notifications
- **Performance Optimized**: Advanced caching, retry logic, and memory optimization
- **Responsive Design**: Beautiful UI that adapts to different screen sizes and orientations
- **Offline Support**: Local caching for continued operation during network issues
- **Security**: Secure API endpoints with proper authentication and data validation
- **Scalable Architecture**: Microservices-ready backend with MongoDB clustering support

## 🏗️ Architecture

```
TEPOS POS System
├── 📱 Flutter Frontend (point_of_scale/)
│   ├── 🎨 UI Components (Material Design 3)
│   ├── 🔌 API Services (HTTP + WebSocket)
│   ├── 📄 PDF Generation (Advanced printing)
│   ├── 🗄️ Local Storage (Caching + Offline)
│   └── 📱 Platform-specific code (Android/iOS/Desktop)
└── 🖥️ FastAPI Backend (pos_backend/)
    ├── 🗄️ MongoDB Database (Cloud Atlas)
    ├── 🔌 RESTful APIs (Auto-documented)
    ├── 📡 WebSocket Services (Real-time)
    ├── 📧 Communication Services (SMS/WhatsApp)
    └── ☁️ Cloud Deployment (Render.com)
```

## 🛠️ Tech Stack

### Frontend (Flutter)
- **Framework**: Flutter 3.7.2+ with Dart 3.7.2+
- **State Management**: Built-in Flutter state management with AutomaticKeepAliveClientMixin
- **UI Framework**: Material Design 3 with custom theming and dark mode support
- **Key Packages**:
  - `pdf: ^3.11.3`: Advanced PDF generation and printing
  - `path_provider: ^2.1.5`: Cross-platform file system access
  - `share_plus: ^7.2.2`: Native sharing capabilities
  - `url_launcher: ^6.2.2`: WhatsApp and external app integration
  - `http: ^1.1.0`: Optimized API communication with retry logic
  - `web_socket_channel: ^2.4.5`: Real-time WebSocket updates
  - `printing: ^5.12.0`: Advanced PDF printing and preview

### Backend (FastAPI)
- **Framework**: FastAPI 0.104.1+ with Python 3.8+
- **Database**: MongoDB Atlas with Motor async driver for scalability
- **Deployment**: Render.com with auto-deployment and scaling
- **Key Libraries**:
  - `uvicorn: ^0.24.0`: High-performance ASGI server
  - `motor: ^3.3.2`: Async MongoDB driver for better performance
  - `websockets: ^12.0`: WebSocket support for real-time features
  - `python-multipart: ^0.0.6`: File upload and form handling
  - `pydantic: ^2.5.0`: Data validation and settings management

### Cloud Infrastructure
- **Backend Hosting**: Render.com (Production: https://pos-2wc9.onrender.com)
- **Database**: MongoDB Atlas with automatic backups and monitoring
- **CDN**: Integrated file serving for PDFs and static assets
- **SSL/TLS**: Automatic HTTPS with security headers
- **Monitoring**: Real-time performance monitoring and alerts

## 📦 Installation & Setup

### Prerequisites
- **Flutter SDK** (3.7.2 or higher) - [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Python** (3.8 or higher) - [Install Python](https://python.org/downloads)
- **MongoDB** (local or MongoDB Atlas account) - [MongoDB Setup](https://www.mongodb.com/docs/manual/installation)
- **Git** - [Install Git](https://git-scm.com/downloads)

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/tepos-pos.git
cd tepos-pos
```

### 2. Backend Setup

```bash
# Navigate to backend directory
cd pos_backend

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows
venv\Scripts\activate
# macOS/Linux
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Create .env file with your configuration
cat > .env << EOF
MONGODB_URL=mongodb+srv://username:password@cluster.mongodb.net
DATABASE_NAME=pos_system
CORS_ORIGINS=["http://localhost:3000","https://yourdomain.com"]
JWT_SECRET_KEY=your_secret_key_here
TWILIO_ACCOUNT_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_token
EOF

# Test database connection
python test_mongodb_connection.py

# Start the development server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 3. Frontend Setup

```bash
# Navigate to Flutter app directory
cd point_of_scale

# Install Flutter dependencies
flutter pub get

# Run code generation (if needed)
flutter packages pub run build_runner build

# Check Flutter setup
flutter doctor

# Run the application
flutter run

# For specific platforms:
# Android: flutter run -d android
# iOS: flutter run -d ios
# Windows: flutter run -d windows
# macOS: flutter run -d macos
# Linux: flutter run -d linux
```

## 🎯 Quick Start

### Production Deployment (Ready to Use)
The system is already deployed and ready for production use:

**Backend**: https://pos-2wc9.onrender.com
**API Documentation**: https://pos-2wc9.onrender.com/docs
**Database**: MongoDB Atlas (Fully configured)

### Local Development Setup
1. **Start Backend**: `cd pos_backend && uvicorn main:app --reload`
2. **Start Frontend**: `cd point_of_scale && flutter run`
3. **Access API Docs**: http://localhost:8000/docs
4. **Test Connection**: Use the "Test API Connection" button in the app

### First Time Setup
1. **Create Products**: Add your electrical products to the inventory
2. **Configure Settings**: Update company details and PDF templates
3. **Test Features**: Create a sample estimate and test WhatsApp sharing
4. **Train Staff**: Provide training on the POS interface and features

## 📱 Screenshots

### Home Dashboard
- Real-time sales overview with live updates
- Quick access to all major functions
- Performance metrics and recent activity

### Sales Interface
- Intuitive product selection with search and categories
- Real-time cart updates with instant calculations
- Professional estimate generation with preview

### Order Management
- Comprehensive order tracking with status updates
- Bulk operations for efficient processing
- Advanced filtering and search capabilities

### Reports & Analytics
- Detailed sales reports with customizable date ranges
- Staff performance tracking and analytics
- Export capabilities for external analysis

## 🔌 API Endpoints

### Core Endpoints
- **POST** `/api/estimates/create` - Create new estimate with validation
- **GET** `/api/estimates/` - List all estimates with pagination
- **PUT** `/api/estimates/{id}` - Update estimate with conflict resolution
- **DELETE** `/api/estimates/{id}` - Delete estimate with safety checks
- **POST** `/api/estimates/{id}/convert-to-order` - Convert estimate to order
- **GET** `/api/orders/` - List all orders with advanced filtering
- **PUT** `/api/orders/{id}/status` - Update order status with notifications
- **GET** `/api/reports/sales` - Generate sales reports with analytics
- **WebSocket** `/ws` - Real-time updates and notifications

### Authentication Endpoints
- **POST** `/api/auth/login` - User authentication with JWT tokens
- **POST** `/api/auth/refresh` - Token refresh for extended sessions
- **GET** `/api/auth/profile` - User profile management

### Utility Endpoints
- **GET** `/api/health` - System health check and status
- **GET** `/api/version` - API version and build information
- **POST** `/api/backup` - Database backup operations

## 🗄️ Database Schema

### Estimates Collection
```json
{
  "_id": "ObjectId",
  "estimate_id": "EST-ABC12345",
  "estimate_number": "#001",
  "customer_name": "John Doe",
  "customer_phone": "9876543210",
  "customer_address": "123 Main Street, City",
  "sale_by": "Rajesh Goyal",
  "items": [
    {
      "name": "LED Bulb 9W",
      "quantity": 10,
      "rate": 150.0,
      "amount": 1500.0
    }
  ],
  "subtotal": 1500.0,
  "discount_type": "percentage",
  "discount_amount": 150.0,
  "total": 1350.0,
  "status": "pending",
  "created_at": "2024-01-01T12:00:00Z",
  "updated_at": "2024-01-01T12:00:00Z",
  "metadata": {
    "source": "mobile_app",
    "version": "1.0.0"
  }
}
```

### Orders Collection
```json
{
  "_id": "ObjectId",
  "order_id": "ORD-XYZ98765",
  "estimate_id": "EST-ABC12345",
  "order_number": "#001",
  "status": "completed",
  "payment_status": "paid",
  "payment_method": "cash",
  "delivery_date": "2024-01-02T10:00:00Z",
  "notes": "Urgent delivery required",
  "created_at": "2024-01-01T15:00:00Z",
  "completed_at": "2024-01-02T09:30:00Z"
}
```

## 🚀 Deployment

### Production Backend (Render.com)
```bash
# Automatic deployment configured
# Push to main branch triggers deployment
git push origin main

# Manual deployment
render deploy

# Environment variables configured:
# - MONGODB_URL (MongoDB Atlas connection)
# - DATABASE_NAME (pos_system)
# - CORS_ORIGINS (Frontend domains)
# - JWT_SECRET_KEY (Authentication)
```

### Flutter App Build
```bash
# Android APK (Release)
flutter build apk --release --target-platform android-arm64

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS (App Store)
flutter build ios --release

# Windows Desktop
flutter build windows --release

# macOS Desktop
flutter build macos --release

# Linux Desktop
flutter build linux --release

# Web Build
flutter build web --release
```

### Docker Deployment (Optional)
```dockerfile
# Backend Dockerfile included
docker build -t tepos-backend .
docker run -p 8000:8000 tepos-backend

# Frontend can be built for web and served
flutter build web
docker run -p 80:80 -v $(pwd)/build/web:/usr/share/nginx/html nginx
```

## 🧪 Testing

### Backend Tests
```bash
cd pos_backend

# Run API tests
python test_api.py

# Test WebSocket connections
python test_websocket.py

# Test MongoDB connection
python test_mongodb_connection.py

# Test estimate to order conversion
python test_conversion_flow.py

# Run all tests
python -m pytest tests/ -v
```

### Flutter Tests
```bash
cd point_of_scale

# Run unit tests
flutter test

# Run integration tests
flutter test integration_test/

# Run specific test files
flutter test test/api_service_test.dart
flutter test test/websocket_test.dart

# Performance testing
flutter run test_optimization.dart
flutter run test_stability.dart
```

### Load Testing
```bash
# Install artillery for load testing
npm install -g artillery

# Run load tests
artillery run load_test.yml

# Test WebSocket performance
artillery run websocket_load_test.yml
```

## 📚 Documentation

### User Guides
- [Backend Connection Setup](point_of_scale/BACKEND_CONNECTION_SETUP.md) - Production API setup
- [Performance Optimization Guide](point_of_scale/PERFORMANCE_OPTIMIZATION_GUIDE.md) - App optimization
- [Project Overview](point_of_scale/PROJECT_OVERVIEW.md) - Complete system documentation

### Development Guides
- [Backend Setup Guide](pos_backend/SETUP_GUIDE.md) - Local development setup
- [Render Deployment Guide](pos_backend/RENDER_DEPLOYMENT_GUIDE.md) - Cloud deployment
- [Optimization Guide](point_of_scale/OPTIMIZATION_GUIDE.md) - Performance improvements

### API Documentation
- **Interactive Docs**: https://pos-2wc9.onrender.com/docs (Swagger UI)
- **ReDoc**: https://pos-2wc9.onrender.com/redoc (Alternative documentation)
- **OpenAPI Schema**: https://pos-2wc9.onrender.com/openapi.json

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Development Guidelines
- Follow Flutter and Python best practices
- Add tests for new features
- Update documentation for API changes
- Use conventional commit messages
- Ensure backward compatibility

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Commercial Use
This software is free for commercial use. Attribution is appreciated but not required.

## 👥 Team

- **Frontend Development**: Flutter Team (Cross-platform mobile & desktop)
- **Backend Development**: FastAPI Team (Cloud-native architecture)
- **UI/UX Design**: Design Team (Material Design 3 implementation)
- **Project Management**: Product Team (Agile development process)
- **DevOps**: Infrastructure Team (Cloud deployment & monitoring)

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/tepos-pos/issues)
- **Documentation**: [Project Wiki](https://github.com/yourusername/tepos-pos/wiki)
- **Email**: support@tepos.com
- **Live Demo**: https://pos-2wc9.onrender.com
- **API Status**: https://pos-2wc9.onrender.com/health

### Getting Help
1. Check the documentation and FAQ
2. Search existing GitHub issues
3. Create a new issue with detailed information
4. Include system information and error logs

## 🙏 Acknowledgments

- **Flutter Team** for the amazing cross-platform framework
- **FastAPI** for the high-performance, easy-to-use backend framework
- **MongoDB** for the flexible, scalable database solution
- **Render.com** for seamless cloud deployment and hosting
- **Material Design** for the beautiful and intuitive UI guidelines
- **Open Source Community** for the excellent packages and libraries
- **Tirupati Electricals** for the business requirements and testing

### Third-Party Services
- **Twilio** for SMS notifications
- **MongoDB Atlas** for cloud database hosting
- **Render.com** for backend hosting and deployment

---

<div align="center">
  <strong>Built with ❤️ for Tirupati Electricals</strong><br>
  <em>A modern, scalable, and production-ready POS solution</em>
</div>