#!/usr/bin/env python3
"""
MongoDB Connection Test Script
This script helps test and debug MongoDB Atlas connection issues.
"""

import asyncio
import os
from motor.motor_asyncio import AsyncIOMotorClient
from config import Config

async def test_mongodb_connection():
    """Test MongoDB connection with detailed error reporting"""
    
    print("🔍 MongoDB Connection Test")
    print("=" * 50)
    
    # Get configuration
    mongodb_url = Config.get_mongodb_url()
    database_name = Config.get_db_name()
    
    print(f"📋 Configuration:")
    print(f"   MongoDB URL: {mongodb_url}")
    print(f"   Database Name: {database_name}")
    print()
    
    # Test connection
    try:
        print("🔗 Attempting to connect to MongoDB...")
        
        # Create client with extended timeout
        client = AsyncIOMotorClient(
            mongodb_url,
            serverSelectionTimeoutMS=15000,
            connectTimeoutMS=15000,
            socketTimeoutMS=15000,
            maxPoolSize=1,
            minPoolSize=1
        )
        
        # Test connection
        await client.admin.command('ping')
        print("✅ MongoDB connection successful!")
        
        # Test database access
        db = client.get_database(database_name)
        collections = await db.list_collection_names()
        print(f"📊 Database '{database_name}' accessible")
        print(f"📁 Collections found: {collections}")
        
        # Close connection
        client.close()
        print("🔌 Connection closed successfully")
        
        return True
        
    except Exception as e:
        print(f"❌ MongoDB connection failed: {e}")
        print()
        print("🔧 Troubleshooting Tips:")
        print("1. Check your MongoDB Atlas connection string")
        print("2. Verify username and password are correct")
        print("3. Ensure network access allows connections from all IPs (0.0.0.0/0)")
        print("4. Check if your MongoDB Atlas cluster is running")
        print("5. Verify the cluster name in the connection string")
        print()
        print("📝 Common connection string format:")
        print("mongodb+srv://username:password@cluster-name.xxxxx.mongodb.net/database?retryWrites=true&w=majority")
        
        return False

def test_environment_variables():
    """Test if environment variables are set correctly"""
    
    print("🔍 Environment Variables Test")
    print("=" * 50)
    
    # Check for environment variables
    mongodb_url_env = os.getenv("MONGODB_URL")
    database_name_env = os.getenv("DATABASE_NAME")
    render_env = os.getenv("RENDER")
    
    print(f"📋 Environment Variables:")
    print(f"   MONGODB_URL: {'✅ Set' if mongodb_url_env else '❌ Not set'}")
    print(f"   DATABASE_NAME: {'✅ Set' if database_name_env else '❌ Not set'}")
    print(f"   RENDER: {'✅ Set' if render_env else '❌ Not set'}")
    
    if mongodb_url_env:
        print(f"   MONGODB_URL value: {mongodb_url_env[:50]}...")
    
    print()

async def main():
    """Main test function"""
    
    print("🚀 TEPOS Backend - MongoDB Connection Test")
    print("=" * 60)
    print()
    
    # Test environment variables
    test_environment_variables()
    
    # Test MongoDB connection
    success = await test_mongodb_connection()
    
    print()
    print("=" * 60)
    if success:
        print("🎉 All tests passed! Your MongoDB connection is working correctly.")
    else:
        print("⚠️  Tests failed. Please check the troubleshooting tips above.")
    
    print("=" * 60)

if __name__ == "__main__":
    asyncio.run(main()) 