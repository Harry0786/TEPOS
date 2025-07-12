from fastapi import WebSocket, WebSocketDisconnect
import asyncio

class WebSocketManager:
    def __init__(self):
        self.connected_clients = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.connected_clients.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.connected_clients:
            self.connected_clients.remove(websocket)

    async def broadcast_update(self, message: str):
        """Broadcast a message to all connected clients"""
        to_remove = []
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