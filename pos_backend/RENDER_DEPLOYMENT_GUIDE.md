# Render Deployment Guide for TEPOS Backend

This guide will help you deploy the TEPOS backend on Render with MongoDB Atlas.

## 🚀 Prerequisites

1. **MongoDB Atlas Account**: You need a MongoDB Atlas cluster
2. **Render Account**: Sign up at [render.com](https://render.com)
3. **GitHub Repository**: Your code should be on GitHub

## 📋 Step 1: MongoDB Atlas Setup

### 1.1 Create MongoDB Atlas Cluster

1. Go to [MongoDB Atlas](https://cloud.mongodb.com/)
2. Create a new project or use existing one
3. Create a new cluster (Free tier is sufficient)
4. Choose your preferred cloud provider and region

### 1.2 Configure Database Access

1. Go to **Database Access** in the left sidebar
2. Click **Add New Database User**
3. Create a user with username and password
4. Set privileges to **Read and write to any database**
5. Click **Add User**

### 1.3 Configure Network Access

1. Go to **Network Access** in the left sidebar
2. Click **Add IP Address**
3. For Render deployment, add: `0.0.0.0/0` (allows all IPs)
4. Click **Confirm**

### 1.4 Get Connection String

1. Go to **Database** in the left sidebar
2. Click **Connect** on your cluster
3. Choose **Connect your application**
4. Copy the connection string

**Example connection string:**
```
mongodb+srv://username:password@cluster0.xxxxx.mongodb.net/?retryWrites=true&w=majority
```

**⚠️ Important**: Replace `username`, `password`, and `cluster0.xxxxx.mongodb.net` with your actual values.

## 📋 Step 2: Render Deployment

### 2.1 Create New Web Service

1. Go to [Render Dashboard](https://dashboard.render.com/)
2. Click **New +** → **Web Service**
3. Connect your GitHub repository
4. Select the repository containing your backend code

### 2.2 Configure Service Settings

**Basic Settings:**
- **Name**: `tepos-backend` (or your preferred name)
- **Environment**: `Python 3`
- **Region**: Choose closest to your users
- **Branch**: `main` (or your default branch)
- **Root Directory**: `pos_backend` (if your backend is in a subdirectory)

**Build Command:**
```bash
pip install -r requirements.txt
```

**Start Command:**
```bash
uvicorn main:app --host 0.0.0.0 --port $PORT
```

### 2.3 Environment Variables

Add these environment variables in Render:

| Variable | Value | Description |
|----------|-------|-------------|
| `MONGODB_URL` | `mongodb+srv://username:password@cluster0.xxxxx.mongodb.net/pos_system?retryWrites=true&w=majority` | Your MongoDB Atlas connection string |
| `DATABASE_NAME` | `pos_system` | Database name |
| `RENDER` | `true` | Indicates running on Render |

**⚠️ Important**: 
- Replace `username`, `password`, and `cluster0.xxxxx.mongodb.net` with your actual MongoDB Atlas values
- Make sure to include the database name in the URL (`/pos_system`)

### 2.4 Advanced Settings

**Auto-Deploy**: Enable to automatically deploy on code changes
**Health Check Path**: `/api/` (optional)

## 📋 Step 3: Verify Deployment

### 3.1 Check Service Status

1. Wait for the build to complete (usually 2-5 minutes)
2. Check the **Logs** tab for any errors
3. Your service URL will be: `https://your-service-name.onrender.com`

### 3.2 Test API Endpoints

Test these endpoints to verify everything is working:

```bash
# Health check
curl https://your-service-name.onrender.com/

# API status
curl https://your-service-name.onrender.com/api/

# API documentation
curl https://your-service-name.onrender.com/docs
```

## 🔧 Troubleshooting

### Common Issues

#### 1. MongoDB Connection Error
**Error**: `The DNS query name does not exist: _mongodb._tcp.cluster0.mongodb.net`

**Solution**: 
- Check your MongoDB Atlas connection string
- Make sure you've included the full cluster name
- Verify network access allows all IPs (`0.0.0.0/0`)

#### 2. Authentication Error
**Error**: `Authentication failed`

**Solution**:
- Verify username and password in connection string
- Check database user permissions in MongoDB Atlas
- Ensure the user has read/write access

#### 3. Network Access Error
**Error**: `Connection refused`

**Solution**:
- Add `0.0.0.0/0` to MongoDB Atlas Network Access
- Wait a few minutes for changes to propagate

### Debug Steps

1. **Check Render Logs**: Go to your service → Logs tab
2. **Verify Environment Variables**: Check if all variables are set correctly
3. **Test MongoDB Connection**: Use MongoDB Compass to test connection string
4. **Check Build Logs**: Ensure all dependencies are installed

## 🔄 Update Frontend Configuration

After successful deployment, update your Flutter app's API base URL:

```dart
// In your Flutter app's api_service.dart
const String baseUrl = 'https://your-service-name.onrender.com/api';
```

## 📊 Monitoring

### Render Dashboard
- **Metrics**: CPU, memory usage
- **Logs**: Real-time application logs
- **Deployments**: Build and deployment history

### MongoDB Atlas
- **Database Metrics**: Connection count, operation count
- **Performance**: Query performance, index usage
- **Alerts**: Set up alerts for connection issues

## 🔒 Security Best Practices

1. **Environment Variables**: Never commit sensitive data to code
2. **Network Access**: Use specific IP ranges when possible
3. **Database Users**: Use least privilege principle
4. **Regular Updates**: Keep dependencies updated
5. **Monitoring**: Set up alerts for unusual activity

## 📞 Support

If you encounter issues:

1. Check Render documentation: [docs.render.com](https://docs.render.com/)
2. Check MongoDB Atlas documentation: [docs.atlas.mongodb.com](https://docs.atlas.mongodb.com/)
3. Review application logs in Render dashboard
4. Test MongoDB connection with MongoDB Compass

---

**🎉 Congratulations!** Your TEPOS backend is now deployed on Render with MongoDB Atlas. 