# TEPOS - Modern Point of Sale System

<div align="center">
  <img src="point_of_scale/assets/icon/TEPOS Logo.png" alt="TEPOS Logo" width="200"/>
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.7.2+-blue.svg)](https://flutter.dev/)
  [![FastAPI](https://img.shields.io/badge/FastAPI-0.104.1+-green.svg)](https://fastapi.tiangolo.com/)
  [![MongoDB](https://img.shields.io/badge/MongoDB-4.5.0+-orange.svg)](https://www.mongodb.com/)
  [![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
</div>

A comprehensive **Point of Sale (POS) system** built with **Flutter** for the frontend and **FastAPI** for the backend, designed specifically for **Tirupati Electricals**. This modern, cross-platform solution provides seamless sales management, estimate generation, and customer communication.

## 🚀 Features

### 💼 Core POS Features
- **Product Management**: Add, edit, and manage products in cart
- **Sales Tracking**: Track sales by different staff members
- **Discount Management**: Apply percentage or fixed amount discounts
- **Customer Management**: Store and manage customer details
- **Sequential Numbering**: Automatic estimate numbering (#001, #002, etc.)

### 📄 Estimate & Billing
- **Professional Estimates**: Create detailed estimates with PDF export
- **Bill Generation**: Generate and send bills to customers
- **PDF Generation**: High-quality PDFs with company branding
- **Multiple Formats**: Support for estimates and invoices

### 📱 Communication Integration
- **WhatsApp Integration**: Send estimates directly to customer WhatsApp
- **SMS Service**: Automated SMS notifications
- **Real-time Sync**: WebSocket-based real-time updates
- **File Sharing**: Share PDFs via any app or email

### 🔧 Technical Features
- **Cross-platform**: Works on Android, iOS, Windows, macOS, and Linux
- **Real-time Updates**: WebSocket integration for live data sync
- **Performance Optimized**: Optimized for smooth operation
- **Responsive Design**: Beautiful UI that adapts to different screen sizes

## 🏗️ Architecture

```
TEPOS POS System
├── 📱 Flutter Frontend (point_of_scale/)
│   ├── 🎨 UI Components
│   ├── 🔌 API Services
│   ├── 📄 PDF Generation
│   └── 📱 Platform-specific code
└── 🖥️ FastAPI Backend (pos_backend/)
    ├── 🗄️ MongoDB Database
    ├── 🔌 RESTful APIs
    ├── 📡 WebSocket Services
    └── 📧 Communication Services
```

## 🛠️ Tech Stack

### Frontend (Flutter)
- **Framework**: Flutter 3.7.2+
- **Language**: Dart
- **Key Packages**:
  - `pdf`: PDF generation
  - `path_provider`: File system access
  - `share_plus`: File sharing
  - `url_launcher`: WhatsApp integration
  - `http`: API communication
  - `web_socket_channel`: Real-time updates
  - `printing`: Advanced PDF printing

### Backend (FastAPI)
- **Framework**: FastAPI 0.104.1+
- **Language**: Python 3.8+
- **Database**: MongoDB with Motor (async driver)
- **Key Libraries**:
  - `uvicorn`: ASGI server
  - `motor`: Async MongoDB driver
  - `websockets`: WebSocket support
  - `python-multipart`: File uploads

## 📦 Installation & Setup

### Prerequisites
- **Flutter SDK** (3.7.2 or higher)
- **Python** (3.8 or higher)
- **MongoDB** (local or cloud instance)
- **Git**

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

# Create .env file
echo "MONGODB_URL=mongodb://localhost:27017" > .env
echo "DATABASE_NAME=pos_db" >> .env

# Start the server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 3. Frontend Setup

```bash
# Navigate to Flutter app directory
cd point_of_scale

# Install Flutter dependencies
flutter pub get

# Run the application
flutter run
```

## 🎯 Quick Start

### Creating an Estimate
1. **Add Products**: Select products and add to cart
2. **Apply Discounts**: Set percentage or fixed discounts
3. **Customer Details**: Enter customer information
4. **Generate Estimate**: Create professional PDF estimate
5. **Send via WhatsApp**: Share directly with customer

### Backend API Access
- **API Documentation**: http://localhost:8000/docs
- **Interactive Docs**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/health

## 📱 Screenshots

<div align="center">
  <img src="screenshots/home.png" alt="Home Screen" width="200"/>
  <img src="screenshots/sales.png" alt="Sales Screen" width="200"/>
  <img src="screenshots/estimates.png" alt="Estimates Screen" width="200"/>
</div>

## 🔌 API Endpoints

### Estimates
- `POST /api/estimates/create` - Create new estimate
- `GET /api/estimates/` - Get all estimates
- `GET /api/estimates/{estimate_id}` - Get specific estimate
- `GET /api/estimates/number/{estimate_number}` - Get by estimate number

### Orders
- `POST /api/orders/create` - Create new order
- `GET /api/orders/` - Get all orders
- `GET /api/orders/{order_id}` - Get specific order

## 🗄️ Database Schema

### Estimates Collection
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
  "total": 270.0,
  "created_at": "2024-01-01T12:00:00"
}
```

## 🚀 Deployment

### Backend Deployment
```bash
# Production server
uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
```

### Flutter App Build
```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release

# Windows
flutter build windows --release

# macOS
flutter build macos --release
```

## 🧪 Testing

### Backend Tests
```bash
cd pos_backend
python test_api.py
python test_websocket.py
```

### Flutter Tests
```bash
cd point_of_scale
flutter test
```

## 📚 Documentation

- [Backend Setup Guide](pos_backend/SETUP_GUIDE.md)
- [Real-time Sync Guide](pos_backend/REALTIME_SYNC_GUIDE.md)
- [WhatsApp Integration Guide](point_of_scale/WHATSAPP_INTEGRATION_GUIDE.md)
- [Performance Optimization Guide](point_of_scale/PERFORMANCE_OPTIMIZATION_GUIDE.md)
- [Backend Connection Setup](point_of_scale/BACKEND_CONNECTION_SETUP.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Team

- **Frontend Development**: Flutter Team
- **Backend Development**: FastAPI Team
- **UI/UX Design**: Design Team
- **Project Management**: Product Team

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/tepos-pos/issues)
- **Documentation**: [Wiki](https://github.com/yourusername/tepos-pos/wiki)
- **Email**: support@tepos.com

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- FastAPI for the high-performance backend
- MongoDB for the flexible database solution
- All contributors and testers

---

<div align="center">
  <strong>Built with ❤️ for Tirupati Electricals</strong>
</div> 