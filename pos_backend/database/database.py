from motor.motor_asyncio import AsyncIOMotorClient
import os
from dotenv import load_dotenv
import asyncio
from config import Config

load_dotenv()

class MongoDB:
    client: AsyncIOMotorClient = None
    database = None

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
            serverSelectionTimeoutMS=5000
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

def get_database():
    if mongodb.database is None:
        raise Exception("Database not connected. Call connect_to_mongo() first.")
    return mongodb.database