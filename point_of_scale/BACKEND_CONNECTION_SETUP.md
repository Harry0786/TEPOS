# Backend Connection Setup

## Overview
Your Flutter app is now configured to connect to the online backend at `https://pos-2wc9.onrender.com`.

## Configuration Changes Made

### 1. API Service Configuration
- **File**: `lib/services/api_service.dart`
- **Base URL**: `https://pos-2wc9.onrender.com/api`
- **Status**: ✅ Already configured correctly

### 2. WebSocket Configuration
- **Files**: 
  - `lib/screens/homescreen.dart`
  - `lib/screens/view_orders_screen.dart`
  - `lib/screens/view_estimates_screen.dart`
- **WebSocket URL**: `wss://pos-2wc9.onrender.com/ws`
- **Status**: ✅ Already configured correctly

### 3. Android Permissions
- **File**: `android/app/src/main/AndroidManifest.xml`
- **Added Permissions**:
  - `android.permission.INTERNET`
  - `android.permission.ACCESS_NETWORK_STATE`
- **Status**: ✅ Added

### 4. Network Security Configuration
- **File**: `android/app/src/main/res/values/network_security_config.xml`
- **Purpose**: Ensures HTTPS connections work properly on Android
- **Status**: ✅ Created and configured

## Testing the Connection

### 1. Run the App
```bash
cd point_of_scale
flutter run
```

### 2. Test Features
1. **Create a New Sale**: Go to "New Sale" and try to create an estimate
2. **View Orders**: Check if orders are loading from the backend
3. **View Estimates**: Check if estimates are loading from the backend
4. **Real-time Updates**: Check if WebSocket connections are working

### 3. Debug Information
The app will print connection status in the console:
- ✅ Connection successful messages
- ❌ Connection failed messages
- 📡 API request/response logs

## API Endpoints Available

### Estimates
- `POST /api/estimates/create` - Create new estimate
- `GET /api/estimates/all` - Fetch all estimates

### Orders
- `GET /api/orders/all` - Fetch all orders
- `PUT /api/orders/{id}/status` - Update order status

### WhatsApp
- `POST /api/whatsapp/send` - Send WhatsApp messages

### Health Check
- `GET /api/health` - Backend health status

## Troubleshooting

### If Connection Fails:
1. **Check Internet**: Ensure device has internet connection
2. **Check Backend**: Verify backend is running at https://pos-2wc9.onrender.com
3. **Check Logs**: Look for error messages in Flutter console
4. **Test Manually**: Try accessing https://pos-2wc9.onrender.com/api in browser

### Common Issues:
1. **Timeout Errors**: Backend might be cold-starting (first request takes longer)
2. **SSL Errors**: Network security config should handle this
3. **Permission Errors**: Android permissions are now properly configured

## Real-time Features
- WebSocket connection for live updates
- Automatic reconnection on connection loss
- Real-time order/estimate status updates

## Security
- All connections use HTTPS/WSS
- Network security config ensures secure connections
- No cleartext traffic allowed 