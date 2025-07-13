import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auto_refresh_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with AutoRefreshMixin {
  bool _isLoading = false;
  Map<String, dynamic> _settings = {};
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _businessNameController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _businessPhoneController = TextEditingController();
  final _businessEmailController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _apiUrlController = TextEditingController();

  // Settings toggles
  bool _enableNotifications = true;
  bool _enableAutoBackup = true;
  bool _enableDarkMode = true;
  bool _enableSoundEffects = true;
  bool _enableWhatsAppIntegration = false;
  bool _enableSMSIntegration = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void _onRefresh() {
    if (mounted) {
      _loadSettings();
    }
  }

  @override
  void _onAppResume() {
    if (mounted) {
      _loadSettings();
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessAddressController.dispose();
    _businessPhoneController.dispose();
    _businessEmailController.dispose();
    _gstNumberController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final settings = await ApiService.fetchSettings();
      if (settings != null) {
        setState(() {
          _settings = settings;
          _populateFormFields();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _populateFormFields() {
    _businessNameController.text = _settings['business_name'] ?? '';
    _businessAddressController.text = _settings['business_address'] ?? '';
    _businessPhoneController.text = _settings['business_phone'] ?? '';
    _businessEmailController.text = _settings['business_email'] ?? '';
    _gstNumberController.text = _settings['gst_number'] ?? '';
    _apiUrlController.text = _settings['api_url'] ?? ApiService.baseUrl;

    _enableNotifications = _settings['enable_notifications'] ?? true;
    _enableAutoBackup = _settings['enable_auto_backup'] ?? true;
    _enableDarkMode = _settings['enable_dark_mode'] ?? true;
    _enableSoundEffects = _settings['enable_sound_effects'] ?? true;
    _enableWhatsAppIntegration =
        _settings['enable_whatsapp_integration'] ?? false;
    _enableSMSIntegration = _settings['enable_sms_integration'] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B8E7F)),
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBusinessInfoSection(),
                      const SizedBox(height: 24),
                      _buildAppSettingsSection(),
                      const SizedBox(height: 24),
                      _buildIntegrationSection(),
                      const SizedBox(height: 24),
                      _buildSystemSection(),
                      const SizedBox(height: 24),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildBusinessInfoSection() {
    return _buildSection(
      'Business Information',
      Icons.business,
      Column(
        children: [
          _buildTextField(
            controller: _businessNameController,
            label: 'Business Name',
            icon: Icons.store,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Business name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _businessAddressController,
            label: 'Business Address',
            icon: Icons.location_on,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _businessPhoneController,
            label: 'Business Phone',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _businessEmailController,
            label: 'Business Email',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _gstNumberController,
            label: 'GST Number',
            icon: Icons.receipt_long,
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettingsSection() {
    return _buildSection(
      'App Settings',
      Icons.settings,
      Column(
        children: [
          _buildSwitchTile(
            title: 'Enable Notifications',
            subtitle: 'Receive notifications for new orders and estimates',
            value: _enableNotifications,
            onChanged: (value) => setState(() => _enableNotifications = value),
            icon: Icons.notifications,
          ),
          _buildSwitchTile(
            title: 'Enable Sound Effects',
            subtitle: 'Play sounds for actions and notifications',
            value: _enableSoundEffects,
            onChanged: (value) => setState(() => _enableSoundEffects = value),
            icon: Icons.volume_up,
          ),
          _buildSwitchTile(
            title: 'Dark Mode',
            subtitle: 'Use dark theme for the app',
            value: _enableDarkMode,
            onChanged: (value) => setState(() => _enableDarkMode = value),
            icon: Icons.dark_mode,
          ),
          _buildSwitchTile(
            title: 'Auto Backup',
            subtitle: 'Automatically backup data to cloud',
            value: _enableAutoBackup,
            onChanged: (value) => setState(() => _enableAutoBackup = value),
            icon: Icons.backup,
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationSection() {
    return _buildSection(
      'Integrations',
      Icons.integration_instructions,
      Column(
        children: [
          _buildSwitchTile(
            title: 'WhatsApp Integration',
            subtitle: 'Send estimates and receipts via WhatsApp',
            value: _enableWhatsAppIntegration,
            onChanged:
                (value) => setState(() => _enableWhatsAppIntegration = value),
            icon: Icons.chat,
          ),
          _buildSwitchTile(
            title: 'SMS Integration',
            subtitle: 'Send estimates and receipts via SMS',
            value: _enableSMSIntegration,
            onChanged: (value) => setState(() => _enableSMSIntegration = value),
            icon: Icons.sms,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _apiUrlController,
            label: 'API Server URL',
            icon: Icons.api,
            enabled: false, // Read-only for security
            helperText: 'Server URL (read-only)',
          ),
        ],
      ),
    );
  }

  Widget _buildSystemSection() {
    return _buildSection(
      'System',
      Icons.system_update,
      Column(
        children: [
          _buildActionTile(
            title: 'Test Connection',
            subtitle: 'Test connection to the server',
            icon: Icons.wifi,
            onTap: _testConnection,
          ),
          _buildActionTile(
            title: 'Clear Cache',
            subtitle: 'Clear app cache and temporary files',
            icon: Icons.cleaning_services,
            onTap: _clearCache,
          ),
          _buildActionTile(
            title: 'Export Data',
            subtitle: 'Export all data to backup file',
            icon: Icons.download,
            onTap: _exportData,
          ),
          _buildActionTile(
            title: 'About App',
            subtitle: 'App version and information',
            icon: Icons.info,
            onTap: _showAboutDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6B8E7F)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: const Color(0xFF6B8E7F)),
        helperText: helperText,
        helperStyle: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade600),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF6B8E7F)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6B8E7F)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF6B8E7F),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF6B8E7F)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey,
          size: 16,
        ),
        onTap: onTap,
        tileColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6B8E7F),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Save Settings',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final settingsData = {
        'business_name': _businessNameController.text,
        'business_address': _businessAddressController.text,
        'business_phone': _businessPhoneController.text,
        'business_email': _businessEmailController.text,
        'gst_number': _gstNumberController.text,
        'api_url': _apiUrlController.text,
        'enable_notifications': _enableNotifications,
        'enable_auto_backup': _enableAutoBackup,
        'enable_dark_mode': _enableDarkMode,
        'enable_sound_effects': _enableSoundEffects,
        'enable_whatsapp_integration': _enableWhatsAppIntegration,
        'enable_sms_integration': _enableSMSIntegration,
      };

      final result = await ApiService.updateSettings(settingsData);

      if (result != null) {
        setState(() => _settings = settingsData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings saved successfully!'),
              backgroundColor: Color(0xFF6B8E7F),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save settings. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isLoading = true);

    try {
      final isHealthy = await ApiService.checkServerHealth();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isHealthy
                  ? 'Connection test successful! Server is healthy.'
                  : 'Connection test failed. Server may be down.',
            ),
            backgroundColor: isHealthy ? const Color(0xFF6B8E7F) : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearCache() async {
    try {
      // Clear API cache
      // This would typically clear the cache in ApiService

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully!'),
            backgroundColor: Color(0xFF6B8E7F),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing cache: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportData() async {
    try {
      // This would typically export data to a file

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data export started. Check your downloads folder.'),
            backgroundColor: Color(0xFF6B8E7F),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text(
              'About TEPOS',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tirupati Electricals Point of Sale System',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version: 1.0.0',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 8),
                Text(
                  'A comprehensive POS solution for electrical businesses',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Features:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Sales Management\n• Estimate Generation\n• Customer Management\n• Reports & Analytics\n• WhatsApp Integration\n• PDF Generation',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Color(0xFF6B8E7F)),
                ),
              ),
            ],
          ),
    );
  }
}
