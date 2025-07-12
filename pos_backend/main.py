from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os
from contextlib import asynccontextmanager

from routers import estimate_route, orders_route, sms_route
from database.database import connect_to_mongo, close_mongo_connection
from services.websocket_service import websocket_manager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await connect_to_mongo()
    yield
    # Shutdown
    await close_mongo_connection()

app = FastAPI(lifespan=lifespan)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure this for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers with API prefix
app.include_router(estimate_route.router, prefix="/api")
app.include_router(orders_route.router, prefix="/api")
app.include_router(sms_route.router)

# Serve static files (for public PDF access)
if not os.path.exists('static/estimates'):
    os.makedirs('static/estimates')
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
async def root():
    return {"message": "Welcome to POS Backend API"}

@app.get("/api/")
async def api_root():
    return {"message": "POS API is running"}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket_manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()  # You can ignore or use this
    except WebSocketDisconnect:
        websocket_manager.disconnect(websocket)

@app.get("/api/websocket/status")
async def websocket_status():
    """Get WebSocket connection status"""
    return {
        "connected_clients": websocket_manager.get_connected_clients_count(),
        "status": "active"
    }