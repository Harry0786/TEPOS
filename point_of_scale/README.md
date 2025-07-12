# TEPOS - Point of Sale System

A Flutter-based Point of Sale (POS) application for Tirupati Electricals.

## Features

- **Product Management**: Add, edit, and manage products in cart
- **Estimate Generation**: Create professional estimates with PDF export
- **WhatsApp Integration**: Send estimates directly to customers via WhatsApp
- **Bill Generation**: Create and send bills to customers
- **Discount Management**: Apply percentage or fixed amount discounts
- **Customer Management**: Store customer details for estimates and bills
- **Sequential Estimate Numbers**: Automatic sequential numbering (#001, #002, etc.)
- **Sale Tracking**: Track sales by different staff members

## New Features

### WhatsApp Integration
- Send estimates directly to customer WhatsApp numbers
- Automatic PDF generation with professional formatting
- Pre-filled WhatsApp messages with estimate details
- Manual file attachment instructions for users

### PDF Generation
- Professional estimate PDFs with company branding
- Complete customer and item details
- Automatic calculations and summaries
- Share PDFs via any app or email

## Setup Instructions

1. Install Flutter dependencies:
```bash
flutter pub get
```

2. Run the application:
```bash
flutter run
```

## Usage

### Creating an Estimate
1. Add products to cart
2. Apply discounts if needed
3. Click "Continue" to proceed
4. Select "Estimate" option
5. Fill in customer details
6. Review estimate preview
7. Click "Send Estimate" to generate PDF and send via WhatsApp

### WhatsApp Integration
- The app will open WhatsApp with a pre-filled message
- Users need to manually attach the generated PDF
- PDF is automatically saved to device storage
- Alternative sharing options available

## Dependencies

- `pdf`: PDF generation
- `path_provider`: File system access
- `share_plus`: File sharing
- `url_launcher`: WhatsApp integration
- `http`: API communication
- `intl`: Date formatting

## Backend Integration

The app connects to a FastAPI backend for estimate storage and management. Make sure the backend is running on the configured IP address.
