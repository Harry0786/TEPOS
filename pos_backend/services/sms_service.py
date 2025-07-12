import os
import requests
from dotenv import load_dotenv

load_dotenv()

FAST2SMS_API_KEY = os.getenv('FAST2SMS_API_KEY')
FAST2SMS_WHATSAPP_URL = 'https://www.fast2sms.com/dev/whatsapp'  # Updated to WhatsApp template endpoint
SENDER_ID = os.getenv('FAST2SMS_SENDER_ID', 'TEPOS')

# Hardcoded template for estimate PDF (adjust as needed)
ESTIMATE_TEMPLATE_ID = '2576'  # Example: offer_template from your screenshot
# The template expects 3 variables: Var1|Var2|Var3
# We'll use: Var1 = customer name, Var2 = estimate number, Var3 = PDF URL

def send_whatsapp(phone_number: str, message: str, pdf_url: str = None, caption: str = None) -> dict:
    """
    Send a WhatsApp message (text or PDF) using Fast2SMS WhatsApp Business API (template-based).
    If pdf_url is provided, sends as a media message using the template.
    Returns a dict with success, message, and data.
    """
    if not FAST2SMS_API_KEY:
        return {
            'success': False,
            'message': 'Fast2SMS API key not configured in backend',
            'error': 'API key missing',
        }

    # Format phone number (remove non-digits and add country code if needed)
    formatted_phone = ''.join(filter(str.isdigit, phone_number))
    if len(formatted_phone) == 10:
        formatted_phone = '91' + formatted_phone
    elif len(formatted_phone) != 12:
        return {
            'success': False,
            'message': 'Invalid phone number. Please enter a 10-digit number.',
            'error': 'Phone number must be 10 digits',
        }

    # For estimate PDF, use the template with 3 variables: customer name, estimate number, PDF URL
    if pdf_url:
        # Parse message for variables (simple split, adjust as needed)
        # Example message: "Hello John, Estimate #123, Rs. 5000"
        # We'll extract customer name and estimate number if possible
        customer_name = "Customer"
        estimate_number = "Estimate"
        try:
            # Try to extract from message (customize as needed)
            lines = message.split('\n')
            for line in lines:
                if line.lower().startswith('hello'):
                    customer_name = line.split(' ', 1)[1].strip()
                if 'estimate' in line.lower() and '#' in line:
                    estimate_number = line.split(':')[-1].strip()
        except Exception:
            pass
        variables_values = f"{customer_name}|{estimate_number}|{pdf_url}"
        params = {
            'authorization': FAST2SMS_API_KEY,
            'message_id': ESTIMATE_TEMPLATE_ID,
            'numbers': formatted_phone,
            'variables_values': variables_values,
        }
        url = FAST2SMS_WHATSAPP_URL
        try:
            print(f"📱 Sending WhatsApp (PDF) to: {formatted_phone}")
            print(f"🔗 PDF URL: {pdf_url}")
            print(f"📝 Variables: {variables_values}")
            response = requests.get(url, params=params, timeout=30)
            print(f"📥 Response Status: {response.status_code}")
            print(f"📥 Response Body: {response.text}")
            if response.status_code == 200:
                data = response.json()
                if data.get('return') is True:
                    return {
                        'success': True,
                        'message': 'WhatsApp message sent successfully!',
                        'data': data,
                        'request_id': data.get('request_id', ''),
                    }
                else:
                    return {
                        'success': False,
                        'message': data.get('message', 'Failed to send WhatsApp message'),
                        'error': data,
                    }
            else:
                return {
                    'success': False,
                    'message': f'HTTP {response.status_code}: {response.reason}',
                    'error': response.text,
                }
        except Exception as e:
            return {
                'success': False,
                'message': 'Exception occurred while sending WhatsApp message',
                'error': str(e),
            }
    else:
        # For plain text, you may want to use a different template or fallback
        return {
            'success': False,
            'message': 'Plain text WhatsApp sending not implemented for template API. Please provide a PDF URL.',
            'error': 'No PDF URL provided',
        }

# Keep the old SMS function for backward compatibility
def send_sms(phone_number: str, message: str) -> dict:
    """
    Send an SMS using Fast2SMS API (legacy function).
    Returns a dict with success, message, and data.
    """
    return send_whatsapp(phone_number, message) 