import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/totp_service.dart';

class PrivacySettingsDialog extends ConsumerStatefulWidget {
  const PrivacySettingsDialog({super.key});

  @override
  ConsumerState<PrivacySettingsDialog> createState() => _PrivacySettingsDialogState();
}

class _PrivacySettingsDialogState extends ConsumerState<PrivacySettingsDialog> {
  bool _allowPublicProfile = false;
  bool _allowCertificateVerification = true;
  bool _shareActivityStatus = false;
  bool _allowDataAnalytics = false;
  bool _enableTwoFactorAuth = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _allowPublicProfile = prefs.getBool('privacy_public_profile') ?? false;
        _allowCertificateVerification = prefs.getBool('privacy_cert_verification') ?? true;
        _shareActivityStatus = prefs.getBool('privacy_activity_status') ?? false;
        _allowDataAnalytics = prefs.getBool('privacy_data_analytics') ?? false;
        _enableTwoFactorAuth = prefs.getBool('privacy_two_factor') ?? false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load privacy settings: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            FadeInDown(
              duration: const Duration(milliseconds: 300),
              child: _buildHeader(),
            ),
            const SizedBox(height: AppTheme.spacingL),

            // Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    FadeInLeft(
                      duration: const Duration(milliseconds: 400),
                      child: _buildPrivacySettings(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spacingL),

            // Error Message
            if (_errorMessage != null)
              FadeInUp(
                duration: const Duration(milliseconds: 300),
                child: _buildErrorMessage(),
              ),

            // Action Buttons
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: _buildActionButtons(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.security,
            color: AppTheme.primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Settings',
                style: AppTheme.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Manage your privacy preferences',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.surfaceColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySettings() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: AppTheme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Privacy Controls',
            style: AppTheme.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),

          // Public Profile
          _buildPrivacyToggle(
            'Public Profile',
            'Allow others to view your public profile information',
            Icons.public,
            _allowPublicProfile,
            (value) => setState(() => _allowPublicProfile = value),
          ),

          // Certificate Verification
          _buildPrivacyToggle(
            'Certificate Verification',
            'Allow public verification of your certificates',
            Icons.verified,
            _allowCertificateVerification,
            (value) => setState(() => _allowCertificateVerification = value),
          ),

          // Activity Status
          _buildPrivacyToggle(
            'Activity Status',
            'Share your last login and activity status',
            Icons.timeline,
            _shareActivityStatus,
            (value) => setState(() => _shareActivityStatus = value),
          ),

          // Data Analytics
          _buildPrivacyToggle(
            'Data Analytics',
            'Allow usage data to improve our services',
            Icons.analytics,
            _allowDataAnalytics,
            (value) => setState(() => _allowDataAnalytics = value),
          ),

          // Two-Factor Authentication
          _buildPrivacyToggle(
            'Two-Factor Authentication',
            'Enable 2FA for enhanced security',
            Icons.security,
            _enableTwoFactorAuth,
            (value) => _handleTwoFactorToggle(value),
            enabled: true,
          ),

          const SizedBox(height: AppTheme.spacingM),

          // Privacy Notice
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Privacy Notice',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Your privacy is important to us. These settings control how your information is shared and used within the system.',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyToggle(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged, {
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: enabled
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: enabled ? AppTheme.primaryColor : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w500,
                    color: enabled ? null : Colors.grey,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTheme.bodySmall.copyWith(
                    color: enabled ? AppTheme.textSecondary : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTheme.errorColor,
            size: 20,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.errorColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _savePrivacySettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: AppTheme.textOnPrimary,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Save Settings'),
          ),
        ),
      ],
    );
  }

  Future<void> _handleTwoFactorToggle(bool value) async {
    final totpService = TOTPService();
    
    try {
      if (value) {
        // Enable 2FA process
        final setupResult = await totpService.enable2FA();
        
        final confirmed = await _show2FASetupDialog(
          qrCodeURI: setupResult['qrCodeURI'],
          manualEntryKey: setupResult['manualEntryKey'],
          totpService: totpService,
        );
        
        if (confirmed) {
          setState(() => _enableTwoFactorAuth = true);
          // Save to preferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('privacy_two_factor', true);
        }
      } else {
        // Disable 2FA process
        final code = await _showDisable2FADialog();
        if (code != null) {
          await totpService.disable2FA(code);
          setState(() => _enableTwoFactorAuth = false);
          // Save to preferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('privacy_two_factor', false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('2FA operation failed: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<bool> _show2FASetupDialog({
    required String qrCodeURI,
    required String manualEntryKey,
    required TOTPService totpService,
  }) async {
    final codeController = TextEditingController();
    bool isVerifying = false;
    String? errorMessage;
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text('Set Up Two-Factor Authentication'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Follow these steps to enable 2FA:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // Step 1
                const Text('1. Download an authenticator app:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.smartphone, size: 16),
                      label: const Text('Google Authenticator'),
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    ),
                    Chip(
                      avatar: const Icon(Icons.security, size: 16),
                      label: const Text('Authy'),
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Step 2 - QR Code
                const Text('2. Scan this QR code:'),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: totpService.generateQRCodeWidget(qrCodeURI, size: 180),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Manual entry option
                ExpansionTile(
                  title: const Text('Or enter manually'),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              manualEntryKey,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(
                                text: manualEntryKey.replaceAll(' ', ''),
                              ));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Secret copied to clipboard')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Step 3 - Verification
                const Text('3. Enter the 6-digit code from your app:'),
                const SizedBox(height: 8),
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    hintText: '000000',
                    border: const OutlineInputBorder(),
                    errorText: errorMessage,
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                  ),
                ),
                
                if (isVerifying) ...[
                  const SizedBox(height: 8),
                  const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Verifying...'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isVerifying ? null : () async {
                final code = codeController.text.trim();
                if (code.length != 6) {
                  setDialogState(() {
                    errorMessage = 'Please enter a 6-digit code';
                  });
                  return;
                }
                
                setDialogState(() {
                  isVerifying = true;
                  errorMessage = null;
                });
                
                try {
                  await totpService.confirm2FASetup(code);
                  // If no exception thrown, setup was successful
                  Navigator.of(context).pop(true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text('Two-factor authentication enabled successfully!'),
                          ],
                        ),
                        backgroundColor: AppTheme.successColor,
                        duration: Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() {
                    isVerifying = false;
                    errorMessage = 'Verification failed: ${e.toString()}';
                  });
                }
              },
              child: const Text('Verify & Enable'),
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  Future<String?> _showDisable2FADialog() async {
    final codeController = TextEditingController();
    bool isVerifying = false;
    String? errorMessage;
    
    return await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('Disable Two-Factor Authentication'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Warning: Disabling 2FA will reduce your account security.',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'To confirm, enter a verification code from your authenticator app:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  hintText: '000000',
                  border: const OutlineInputBorder(),
                  errorText: errorMessage,
                  prefixIcon: const Icon(Icons.lock),
                  helperText: 'You can also use a backup code',
                ),
                keyboardType: TextInputType.number,
                maxLength: 8, // Allow backup codes (8 digits) and TOTP (6 digits)
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
              
              if (isVerifying) ...[
                const SizedBox(height: 8),
                const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Verifying...'),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isVerifying ? null : () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isVerifying ? null : () async {
                final code = codeController.text.trim();
                if (code.isEmpty) {
                  setDialogState(() {
                    errorMessage = 'Please enter a verification code';
                  });
                  return;
                }
                
                setDialogState(() {
                  isVerifying = true;
                  errorMessage = null;
                });
                
                try {
                  // Return the code for verification in the calling function
                  Navigator.of(context).pop(code);
                } catch (e) {
                  setDialogState(() {
                    isVerifying = false;
                    errorMessage = 'Error: ${e.toString()}';
                  });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Disable 2FA'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePrivacySettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      await Future.wait([
        prefs.setBool('privacy_public_profile', _allowPublicProfile),
        prefs.setBool('privacy_cert_verification', _allowCertificateVerification),
        prefs.setBool('privacy_activity_status', _shareActivityStatus),
        prefs.setBool('privacy_data_analytics', _allowDataAnalytics),
        prefs.setBool('privacy_two_factor', _enableTwoFactorAuth),
      ]);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 16,
                ),
                SizedBox(width: 8),
                Text('Privacy settings saved successfully!'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save privacy settings: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 