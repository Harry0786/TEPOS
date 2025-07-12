import socket
import requests

def get_local_ip():
    """Get the local IP address"""
    try:
        # Get local IP by connecting to a remote server
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except Exception as e:
        print(f"Error getting local IP: {e}")
        return None

def get_public_ip():
    """Get the public IP address"""
    try:
        response = requests.get('https://api.ipify.org', timeout=5)
        return response.text
    except Exception as e:
        print(f"Error getting public IP: {e}")
        return None

if __name__ == "__main__":
    print("🔍 Finding your IP addresses...")
    print("=" * 50)
    
    local_ip = get_local_ip()
    public_ip = get_public_ip()
    
    print(f"🏠 Local IP Address: {local_ip}")
    print(f"🌐 Public IP Address: {public_ip}")
    print()
    
    if local_ip:
        print("📱 For Flutter app connection, use one of these URLs:")
        print(f"   • http://{local_ip}:8000/api (Recommended for same network)")
        print("   • http://10.0.2.2:8000/api (Android Emulator)")
        print("   • http://localhost:8000/api (iOS Simulator)")
        print("   • http://127.0.0.1:8000/api (Same machine)")
        print()
        print("💡 Update the baseUrl in point_of_scale/lib/services/api_service.dart")
        print(f"   with: static const String baseUrl = 'http://{local_ip}:8000/api';")
    else:
        print("❌ Could not determine local IP address")
        print("💡 Please manually find your IP address using:")
        print("   • Windows: ipconfig")
        print("   • Mac/Linux: ifconfig")
        print("   • Or check your router settings") 