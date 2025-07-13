from fastapi import WebSocket, WebSocketDisconnect
import asyncio
import json

class WebSocketManager:
    def __init__(self):
        self.connected_clients = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.connected_clients.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.connected_clients:
            self.connected_clients.remove(websocket)

    async def broadcast_update(self, message):
        """Broadcast a message (string or dict) to all connected clients as JSON string"""
        import json
        to_remove = []
        if not isinstance(message, str):
            try:
                message = json.dumps(message)
            except Exception as e:
                print(f"Error serializing broadcast message: {e}")
                return
        for ws in self.connected_clients:
            try:
                await ws.send_text(message)
            except Exception:
                to_remove.append(ws)
        for ws in to_remove:
            if ws in self.connected_clients:
                self.connected_clients.remove(ws)

    def get_connected_clients_count(self):
        return len(self.connected_clients)

# Global instance
websocket_manager = WebSocketManager() 