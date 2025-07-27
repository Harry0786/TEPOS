import 'package:flutter/material.dart';
import 'package:point_of_scale/services/websocket_service.dart';
import 'package:point_of_scale/services/api_service.dart';

/// Widget that displays the current connection status to the user
class ConnectionStatusWidget extends StatelessWidget {
  const ConnectionStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Create a WebSocket service instance with the proper URL
    final webSocketService = WebSocketService(serverUrl: ApiService.webSocketUrl);
    
    return StreamBuilder<bool>(
      stream: webSocketService.connectionStream,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? true; // Default to connected
        
        // Only show banner when disconnected
        if (isConnected) {
          return const SizedBox.shrink();
        }
        
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.orange.shade700,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '⚠️ Reconnecting to server...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Widget that shows connection status as a small indicator
class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final webSocketService = WebSocketService(serverUrl: ApiService.webSocketUrl);
    
    return StreamBuilder<bool>(
      stream: webSocketService.connectionStream,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? true;
        
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isConnected ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

/// Widget that shows detailed connection information for debugging
class ConnectionDebugInfo extends StatelessWidget {
  const ConnectionDebugInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final webSocketService = WebSocketService(serverUrl: ApiService.webSocketUrl);
    
    return StreamBuilder<bool>(
      stream: webSocketService.connectionStream,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? true;
        
        return Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Connection Status',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  ConnectionIndicator(),
                  const SizedBox(width: 8),
                  Text(
                    isConnected ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      color: isConnected ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
