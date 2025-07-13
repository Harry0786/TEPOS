from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
import os
from dotenv import load_dotenv
import asyncio
from config import Config
from typing import Optional

load_dotenv()

class MongoDB:
    client: Optional[AsyncIOMotorClient] = None
    database: Optional[AsyncIOMotorDatabase] = None

mongodb = MongoDB()

async def connect_to_mongo():
    """Create database connection"""
    try:
        # Use configuration for MongoDB connection
        mongodb_url = Config.get_mongodb_url()
        database_name = Config.get_db_name()
        
        print(f"🔗 Connecting to MongoDB: {mongodb_url}")
        print(f"📊 Database: {database_name}")
        
        mongodb.client = AsyncIOMotorClient(
            mongodb_url,
            serverSelectionTimeoutMS=10000,
            connectTimeoutMS=10000,
            socketTimeoutMS=10000,
            maxPoolSize=10,
            minPoolSize=1
        )
        mongodb.database = mongodb.client.get_database(database_name)
        
        # Test the connection
        await mongodb.client.admin.command('ping')
        print("✅ Connected to MongoDB successfully")
    except Exception as e:
        print(f"❌ Failed to connect to MongoDB: {e}")
        raise

async def close_mongo_connection():
    """Close database connection"""
    if mongodb.client:
        mongodb.client.close()
        print("🔌 Disconnected from MongoDB")

def get_database() -> AsyncIOMotorDatabase:
    if mongodb.database is None:
        raise Exception("Database not connected. Call connect_to_mongo() first.")
    return mongodb.database