from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from dateutil import tz

from routers import estimate_route_new, orders_route_new, sms_route, reports_route
from database.database import connect_to_mongo, close_mongo_connection
from services.websocket_service import websocket_manager
from config import Config

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await connect_to_mongo()
    yield
    # Shutdown
    await close_mongo_connection()

app = FastAPI(lifespan=lifespan)

# Print configuration for debugging
Config.print_configuration()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=Config.get_cors_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers with API prefix
app.include_router(estimate_route_new.router, prefix="/api")
app.include_router(orders_route_new.router, prefix="/api")
app.include_router(reports_route.router, prefix="/api")
app.include_router(sms_route.router)

# Serve static files (for public PDF access)
static_dir = Config.get_static_dir()
if not os.path.exists(f'{static_dir}/estimates'):
    os.makedirs(f'{static_dir}/estimates')
app.mount("/static", StaticFiles(directory=static_dir), name="static")

@app.get("/")
async def root():
    return {"message": "Welcome to POS Backend API"}

@app.get("/api/")
async def api_root():
    return {"message": "POS API is running"}

@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "service": "TEPOS Backend API",
        "version": "1.0.0"
    }

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

@app.get("/debug/time")
async def debug_time():
    ist = tz.gettz('Asia/Kolkata')
    return {
        "utc_now": datetime.now(timezone.utc).isoformat(),
        "local_now": datetime.now().isoformat(),
        "ist_now": datetime.now(ist).isoformat()
    }