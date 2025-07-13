import os
from typing import Dict, Any

class Config:
    """Production configuration for POS backend - Render only"""
    
    # ===== PRODUCTION CONFIGURATION =====
    # MongoDB settings (Render) - Use environment variable if available
    MONGODB_URL = os.getenv("MONGODB_URL", "mongodb+srv://jayesh:jayesh@cluster0.xvxk1fu.mongodb.net/pos?retryWrites=true&w=majority")
    DATABASE_NAME = os.getenv("DATABASE_NAME", "pos")
    
    # CORS origins (Production)
    CORS_ORIGINS = [
        "https://pos-2wc9.onrender.com"
    ]
    
    # Server configuration
    HOST = "0.0.0.0"
    PORT = 8000
    
    # Static files configuration
    STATIC_DIR = "static"
    
    @classmethod
    def get_mongodb_url(cls) -> str:
        """Get MongoDB URL"""
        return cls.MONGODB_URL
    
    @classmethod
    def get_db_name(cls) -> str:
        """Get database name"""
        return cls.DATABASE_NAME
    
    @classmethod
    def get_cors_origins(cls) -> list:
        """Get CORS origins"""
        return cls.CORS_ORIGINS
    
    @classmethod
    def get_static_dir(cls) -> str:
        """Get static files directory"""
        return cls.STATIC_DIR
    
    @classmethod
    def get_server_config(cls) -> Dict[str, Any]:
        """Get server configuration"""
        return {
            "host": cls.HOST,
            "port": cls.PORT,
        }
    
    @classmethod
    def print_configuration(cls):
        """Print current configuration for debugging"""
        print("🔧 Backend Configuration:")
        print("   Environment: PRODUCTION (Render)")
        print(f"   MongoDB URL: {cls.get_mongodb_url()}")
        print(f"   Database Name: {cls.get_db_name()}")
        print(f"   CORS Origins: {cls.get_cors_origins()}")
        print(f"   Static Directory: {cls.get_static_dir()}")
        print(f"   Server: {cls.HOST}:{cls.PORT}")

# Environment-specific overrides
if os.getenv("RENDER"):
    print("🚀 Running in Render environment - production settings active") 