# Production Setup Guide

This POS system is configured to run on Render only (production environment).

## 🚀 **Quick Start**

### **Frontend (Flutter)**
```bash
cd point_of_scale
flutter run
```

### **Backend (Render)**
The backend automatically deploys to Render when you push to git:
```bash
git add .
git commit -m "Update"
git push
```

## 📋 **Configuration**

### **Frontend Configuration**
- **API URL**: `https://pos-2wc9.onrender.com/api`
- **WebSocket URL**: `wss://pos-2wc9.onrender.com/ws`
- **File**: `point_of_scale/lib/services/api_service.dart`

### **Backend Configuration**
- **MongoDB**: `mongodb+srv://jayes:jayes123@cluster0.mongodb.net`
- **Database**: `pos_system`
- **CORS**: `https://pos-2wc9.onrender.com`
- **File**: `pos_backend/config.py`

## 🔧 **Files**

- **`config.json`** - Production configuration
- **`point_of_scale/lib/services/api_service.dart`** - Frontend API service
- **`pos_backend/config.py`** - Backend configuration
- **`pos_backend/main.py`** - Backend server

## 📊 **Current Setup**

```
🌐 Frontend Configuration:
   Environment: PRODUCTION (Render)
   API Base URL: https://pos-2wc9.onrender.com/api
   WebSocket URL: wss://pos-2wc9.onrender.com/ws

🔧 Backend Configuration:
   Environment: PRODUCTION (Render)
   MongoDB URL: mongodb+srv://...
   Database Name: pos_system
   CORS Origins: ['https://pos-2wc9.onrender.com']
   Server: 0.0.0.0:8000
```

## 🎯 **Usage**

1. **Run Flutter app**: `cd point_of_scale && flutter run`
2. **Backend auto-deploys** to Render on git push
3. **All data** is stored in MongoDB Atlas
4. **Real-time updates** via WebSocket

## 🚨 **Troubleshooting**

- **Connection issues**: Check if Render service is running
- **Database issues**: Verify MongoDB Atlas connection
- **CORS errors**: Check if frontend domain is in CORS origins

---

**Note**: This system is configured for production use only. All local development code has been removed. 