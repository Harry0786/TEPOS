import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class TestSmsScreen extends StatefulWidget {
  const TestSmsScreen({super.key});

  @override
  State<TestSmsScreen> createState() => _TestSmsScreenState();
}

class _TestSmsScreenState extends State<TestSmsScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _testResult;
  bool _isSuccess = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _testWhatsAppService() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult = null;
    });

    try {
      // Format phone number
      String phoneNumber = _phoneController.text.trim();
      phoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      if (phoneNumber.length != 10) {
        throw Exception(
          'Invalid phone number. Please enter a 10-digit number.',
        );
      }

      // Generate test message
      final testMessage =
          '''
Hello! This is a test message from TEPOS system.

If you receive this message, the WhatsApp integration is working correctly.

Best regards,
Tirupati Electricals
      '''.trim();

      // Try to open WhatsApp
      final whatsappNumber = '91$phoneNumber';
      final whatsappUrl =
          'whatsapp://send?phone=$whatsappNumber&text=${Uri.encodeComponent(testMessage)}';

      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        setState(() {
          _isLoading = false;
          _testResult =
              'WhatsApp opened successfully! Check your WhatsApp app.';
          _isSuccess = true;
        });
      } else {
        setState(() {
          _isLoading = false;
          _testResult =
              'WhatsApp not found. Please install WhatsApp or use alternative sharing.';
          _isSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _testResult = 'Test failed: ${e.toString()}';
        _isSuccess = false;
      });
    }
  }

  Future<void> _testShareFunctionality() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult = null;
    });

    try {
      // Create a simple test message
      final testMessage =
          '''
Hello! This is a test message from TEPOS system.

Phone: ${_phoneController.text}
Time: ${DateTime.now().toString()}

If you receive this message, the sharing functionality is working correctly.

Best regards,
Tirupati Electricals
      '''.trim();

      // Use system share sheet
      await SharePlus.instance.share(
        ShareParams(
          text: testMessage,
          subject: 'TEPOS Test Message',
        ),
      );

      setState(() {
        _isLoading = false;
        _testResult =
            'Share sheet opened successfully! Choose your preferred app to send the message.';
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _testResult = 'Share test failed: ${e.toString()}';
        _isSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Test WhatsApp Integration',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.message, color: Color(0xFF6B8E7F), size: 32),
                  const SizedBox(height: 12),
                  const Text(
                    'Test WhatsApp Integration',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Test the direct WhatsApp integration without third-party services.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Phone Number Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Test Phone Number',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter 10-digit mobile number',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Color(0xFF6B8E7F)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0D0D0D),
                      prefixIcon: const Icon(Icons.phone, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your own number to test the integration',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Test Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testWhatsAppService,
                    icon: const Icon(Icons.message, size: 18),
                    label: const Text('Test WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testShareFunctionality,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Test Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B8E7F),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Result Display
            if (_testResult != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      _isSuccess
                          ? const Color(0xFF1B5E20).withOpacity(0.2)
                          : const Color(0xFFB71C1C).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        _isSuccess
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFF44336),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isSuccess ? Icons.check_circle : Icons.error,
                          color:
                              _isSuccess
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFF44336),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isSuccess ? 'Test Successful' : 'Test Failed',
                          style: TextStyle(
                            color:
                                _isSuccess
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFF44336),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _testResult!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),

            const Spacer(),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How It Works',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInstructionItem(
                    '1. Enter your 10-digit mobile number',
                    Icons.phone_android,
                  ),
                  _buildInstructionItem(
                    '2. Click "Test WhatsApp" to open WhatsApp directly',
                    Icons.message,
                  ),
                  _buildInstructionItem(
                    '3. Click "Test Share" to use system share sheet',
                    Icons.share,
                  ),
                  _buildInstructionItem(
                    '4. Choose your preferred app to send the message',
                    Icons.apps,
                  ),
                  _buildInstructionItem(
                    '5. No third-party services required!',
                    Icons.check_circle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B8E7F), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[300], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
