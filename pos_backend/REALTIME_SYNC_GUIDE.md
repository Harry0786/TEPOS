# Real-Time Sync Guide

This guide explains how the real-time synchronization works in the POS system using WebSockets.

## Overview

The POS system now supports real-time updates across all connected clients. When data changes in the backend (new estimates, status updates, etc.), all connected Flutter apps are automatically notified and their data is refreshed.

## How It Works

### Backend (FastAPI + WebSockets)

1. **WebSocket Server**: The backend maintains a WebSocket server at `/ws` endpoint
2. **Client Management**: All connected clients are stored in a list
3. **Broadcast System**: When data changes, a message is broadcast to all connected clients
4. **Automatic Reconnection**: Clients automatically reconnect if the connection is lost

### Frontend (Flutter)

1. **WebSocket Client**: Each screen connects to the WebSocket server
2. **Message Listening**: Screens listen for specific messages from the backend
3. **Auto Refresh**: When a message is received, the screen automatically refreshes its data
4. **Connection Management**: Automatic reconnection on connection loss

## Backend Implementation

### WebSocket Endpoint (`main.py`)

```python
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    connected_clients.append(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        if websocket in connected_clients:
            connected_clients.remove(websocket)
```

### Broadcast Function

```python
async def broadcast_update(message: str):
    to_remove = []
    for ws in connected_clients:
        try:
            await ws.send_text(message)
        except Exception:
            to_remove.append(ws)
    for ws in to_remove:
        if ws in connected_clients:
            connected_clients.remove(ws)
```

### Triggering Broadcasts

Broadcasts are triggered in the following scenarios:

1. **New Estimate Created** (`estimate_route.py`)
   ```python
   asyncio.create_task(broadcast_update("estimate_updated"))
   ```

2. **Order Status Updated** (`orders_route.py`)
   ```python
   asyncio.create_task(broadcast_update("order_updated"))
   ```

## Frontend Implementation

### WebSocket Service (`websocket_service.dart`)

```dart
class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<String>? _messageController;
  
  void connect() {
    _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
    _channel!.stream.listen((message) {
      _messageController?.add(message.toString());
    });
  }
}
```

### Screen Integration

```dart
class HomeScreen extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    _initializeWebSocket();
    _loadOrders();
  }

  void _initializeWebSocket() {
    _webSocketService = WebSocketService(
      serverUrl: 'ws://172.20.10.3:8000/ws',
    );
    
    _webSocketService.messageStream.listen((message) {
      if (message == 'estimate_updated' || message == 'order_updated') {
        _loadOrders(); // Refresh data
      }
    });
  }
}
```

## Message Types

The system uses the following message types:

- `"estimate_updated"` - Triggered when a new estimate is created
- `"order_updated"` - Triggered when an order status is changed

## Testing

### Backend Testing

Run the WebSocket test script:

```bash
cd pos_backend
python test_websocket.py
```

This will:
1. Test WebSocket connection
2. Create a test estimate to trigger broadcast
3. Verify message reception

### Frontend Testing

1. Start the backend server
2. Run the Flutter app
3. Create a new estimate from another device/app
4. Verify the home screen updates automatically

## Configuration

### IP Address

Update the WebSocket URL in your Flutter screens:

```dart
// In HomeScreen and ViewEstimatesScreen
_webSocketService = WebSocketService(
  serverUrl: 'ws://YOUR_SERVER_IP:8000/ws',
);
```

Replace `YOUR_SERVER_IP` with your actual server IP address.

### Port Configuration

The WebSocket server runs on the same port as your FastAPI server (8000 by default).

## Troubleshooting

### Common Issues

1. **Connection Failed**
   - Check if the backend server is running
   - Verify the IP address is correct
   - Ensure no firewall is blocking the connection

2. **No Real-Time Updates**
   - Check if WebSocket connection is established
   - Verify broadcast messages are being sent
   - Check console logs for error messages

3. **Multiple Connections**
   - Each screen creates its own WebSocket connection
   - This is normal and allows for independent updates

### Debug Logs

The system includes comprehensive logging:

- Backend: WebSocket connection/disconnection events
- Frontend: Connection status and received messages
- Both: Error messages and reconnection attempts

## Performance Considerations

- **Connection Limits**: The current implementation supports unlimited connections
- **Memory Usage**: Each connection uses minimal memory
- **Network**: WebSocket connections are lightweight and efficient
- **Battery**: Flutter apps handle connection management efficiently

## Security Notes

- WebSocket connections are not encrypted by default
- For production, consider using WSS (WebSocket Secure)
- Implement authentication if needed
- Rate limiting may be required for high-traffic scenarios

## Future Enhancements

Potential improvements:

1. **Message Filtering**: Send specific data instead of just notification
2. **User-Specific Updates**: Only send updates to relevant users
3. **Connection Pooling**: Optimize for many concurrent connections
4. **Message Queuing**: Handle offline scenarios
5. **Encryption**: Add WSS support for security 