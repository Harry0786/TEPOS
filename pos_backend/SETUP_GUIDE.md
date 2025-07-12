# POS System Setup Guide

This guide will help you set up the POS backend and connect it with the Flutter app.

## 🚀 Quick Setup

### 1. Start the Backend Server

```bash
cd pos_backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**Important:** Use `--host 0.0.0.0` to allow connections from other devices on your network.

### 2. Find Your IP Address

Run this command to get your local IP address:
```bash
python get_ip.py
```

This will show you the correct IP address to use in the Flutter app.

### 3. Update Flutter App

In `point_of_scale/lib/services/api_service.dart`, update the `baseUrl` with your IP address:

```dart
static const String baseUrl = 'http://YOUR_IP_ADDRESS:8000/api';
```

### 4. Test Connection

1. Run the Flutter app
2. On the home screen, tap "Test API Connection"
3. If successful, you'll see "✅ Connection Successful"

## 🔧 Troubleshooting

### Network Error Issues

**Problem:** "Network error occurred" when sending estimates

**Solutions:**

1. **Check Backend is Running:**
   ```bash
   curl http://YOUR_IP:8000/api/
   ```
   Should return: `{"message":"POS API is running"}`

2. **Check IP Address:**
   - Make sure you're using the correct IP address
   - Run `python get_ip.py` to get the current IP
   - Update `api_service.dart` with the correct IP

3. **Check Firewall:**
   - Windows: Allow Python/uvicorn through Windows Firewall
   - Make sure port 8000 is not blocked

4. **Check Network:**
   - Ensure both devices are on the same network
   - Try using `10.0.2.2` for Android emulator
   - Try using `localhost` for iOS simulator

### Different Device Scenarios

| Device Type | Use This URL |
|-------------|--------------|
| Android Emulator | `http://10.0.2.2:8000/api` |
| iOS Simulator | `http://localhost:8000/api` |
| Physical Device (same network) | `http://YOUR_IP:8000/api` |
| Same Machine | `http://127.0.0.1:8000/api` |

### Common Error Messages

**"Connection timeout"**
- Backend server not running
- Wrong IP address
- Firewall blocking connection

**"Connection refused"**
- Backend not running on port 8000
- Wrong port number

**"Network unreachable"**
- Devices not on same network
- IP address changed

## 📱 Testing the App

1. **Test Connection:** Use the "Test API Connection" button on home screen
2. **Create Estimate:** 
   - Go to "New Sale"
   - Add products
   - Fill customer details
   - Tap "Send Estimate"

3. **Check Console:** Look for debug messages in the Flutter console:
   ```
   🌐 API Request URL: http://172.20.10.3:8000/api/estimates/create
   📤 Sending data to API...
   📋 Request Body: {...}
   📥 Response Status: 201
   📥 Response Body: {...}
   ```

## 🛠️ Development Tips

### Backend Development
- Use `--reload` flag for auto-restart on code changes
- Check logs in the terminal where uvicorn is running
- Use `http://127.0.0.1:8000/docs` for API documentation

### Flutter Development
- Use `flutter run` with verbose logging: `flutter run -v`
- Check the debug console for API request/response logs
- Use the connection test button to verify API connectivity

### Database
- MongoDB should be running locally or on cloud
- Check `.env` file for correct MongoDB connection string
- Test database connection with `python test_api.py`

## 🔄 Updating IP Address

If your IP address changes (e.g., after reconnecting to WiFi):

1. Run `python get_ip.py` to get new IP
2. Update `point_of_scale/lib/services/api_service.dart`
3. Hot reload the Flutter app: `r` in terminal
4. Test connection again

## 📞 Support

If you're still having issues:

1. Check the Flutter console for detailed error messages
2. Verify backend is running and accessible
3. Test with curl: `curl -X POST http://YOUR_IP:8000/api/estimates/create -H "Content-Type: application/json" -d "{}"`
4. Check network connectivity between devices 