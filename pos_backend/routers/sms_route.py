from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from pydantic import BaseModel
import sys
import os
from fastapi.responses import JSONResponse
from uuid import uuid4
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from services.sms_service import send_whatsapp

router = APIRouter(prefix="/api/whatsapp", tags=["WhatsApp"])

class WhatsAppRequest(BaseModel):
    phone_number: str
    message: str
    pdf_url: str = None  # Optional public PDF URL
    caption: str = None  # Optional caption for media

@router.post("/send")
def send_whatsapp_endpoint(request: WhatsAppRequest):
    """
    Send a WhatsApp message (text or PDF) using Fast2SMS WhatsApp Business API.
    If pdf_url is provided, sends as a media message.
    """
    result = send_whatsapp(request.phone_number, request.message, pdf_url=request.pdf_url, caption=request.caption)
    if not result.get('success'):
        raise HTTPException(status_code=400, detail=result.get('message', 'Failed to send WhatsApp message'))
    return result

# New endpoint: Upload PDF and send via WhatsApp
@router.post("/send-estimate-pdf")
async def send_estimate_pdf(
    phone_number: str = Form(...),
    message: str = Form(...),
    caption: str = Form(None),
    file: UploadFile = File(...)
):
    """
    Upload a PDF, save it, and send it via WhatsApp using Fast2SMS.
    """
    # Save the PDF to static/estimates/
    ext = os.path.splitext(file.filename)[-1].lower()
    if ext != ".pdf":
        return JSONResponse(status_code=400, content={"success": False, "message": "Only PDF files are allowed."})
    filename = f"estimate_{uuid4().hex}.pdf"
    save_path = os.path.join("static", "estimates", filename)
    with open(save_path, "wb") as f:
        f.write(await file.read())
    # Generate public URL
    # Assume backend is running on 0.0.0.0:8000 and accessible via IP
    # You may want to make this dynamic based on request
    public_url = f"/static/estimates/{filename}"
    # Try to get host from environment or default to localhost
    base_url = os.getenv("PUBLIC_BASE_URL", "http://localhost:8000")
    pdf_url = base_url + public_url
    # Send WhatsApp message with PDF
    result = send_whatsapp(phone_number, message, pdf_url=pdf_url, caption=caption)
    if not result.get('success'):
        return JSONResponse(status_code=400, content=result)
    return {"success": True, "pdf_url": pdf_url, **result}

# Keep backward compatibility with SMS endpoint
@router.post("/sms/send")
def send_sms_endpoint(request: WhatsAppRequest):
    """
    Legacy SMS endpoint - now sends WhatsApp messages.
    """
    return send_whatsapp_endpoint(request) 