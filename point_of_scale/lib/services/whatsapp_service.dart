import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppService {
  static Future<bool> sendMessage({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // Format phone number (remove +91 if present and add it back)
      String formattedPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      // If it's a 10-digit number, add country code
      if (formattedPhone.length == 10) {
        formattedPhone = '91$formattedPhone';
      }

      // Remove any leading zeros
      formattedPhone = formattedPhone.replaceFirst(RegExp(r'^0+'), '');

      // Create WhatsApp URL
      final url = Uri.parse(
        'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}',
      );

      print('📱 Opening WhatsApp with URL: $url');

      // Launch WhatsApp
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      } else {
        print('❌ Could not launch WhatsApp URL');
        return false;
      }
    } catch (e) {
      print('❌ Error sending WhatsApp message: $e');
      return false;
    }
  }

  static Future<bool> sendFile({
    required String phoneNumber,
    required File file,
    String? message,
  }) async {
    try {
      // Format phone number (remove +91 if present and add it back)
      String formattedPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      // If it's a 10-digit number, add country code
      if (formattedPhone.length == 10) {
        formattedPhone = '91$formattedPhone';
      }

      // Remove any leading zeros
      formattedPhone = formattedPhone.replaceFirst(RegExp(r'^0+'), '');

      // Create WhatsApp URL with file
      String urlString = 'https://wa.me/$formattedPhone';
      if (message != null && message.isNotEmpty) {
        urlString += '?text=${Uri.encodeComponent(message)}';
      }

      final url = Uri.parse(urlString);

      print('📱 Opening WhatsApp with file: $url');
      print('📄 File path: ${file.path}');

      // Launch WhatsApp
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);

        // Note: WhatsApp Web API doesn't support direct file sending via URL
        // The user will need to manually attach the file after WhatsApp opens
        // We can show instructions to the user
        return true;
      } else {
        print('❌ Could not launch WhatsApp URL');
        return false;
      }
    } catch (e) {
      print('❌ Error sending file via WhatsApp: $e');
      return false;
    }
  }

  static Future<bool> openWhatsAppChat({required String phoneNumber}) async {
    try {
      // Format phone number
      String formattedPhone = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      // If it's a 10-digit number, add country code
      if (formattedPhone.length == 10) {
        formattedPhone = '91$formattedPhone';
      }

      // Remove any leading zeros
      formattedPhone = formattedPhone.replaceFirst(RegExp(r'^0+'), '');

      // Create WhatsApp URL
      final url = Uri.parse('https://wa.me/$formattedPhone');

      print('📱 Opening WhatsApp chat: $url');

      // Launch WhatsApp
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      } else {
        print('❌ Could not launch WhatsApp URL');
        return false;
      }
    } catch (e) {
      print('❌ Error opening WhatsApp chat: $e');
      return false;
    }
  }

  static String formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String formatted = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // If it's a 10-digit number, add country code
    if (formatted.length == 10) {
      formatted = '+91$formatted';
    } else if (formatted.length == 12 && formatted.startsWith('91')) {
      formatted = '+$formatted';
    }

    return formatted;
  }
}
