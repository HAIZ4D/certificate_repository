import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/totp_service.dart';
import '../../../../core/services/logger_service.dart';

class TwoFactorSetupDialog extends ConsumerStatefulWidget {
  const TwoFactorSetupDialog({super.key});

  @override
  ConsumerState<TwoFactorSetupDialog> createState() => _TwoFactorSetupDialogState();
}

class _TwoFactorSetupDialogState extends ConsumerState<TwoFactorSetupDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _secret;
  String? _qrCodeUri;
  bool _setupComplete = false;

  @override
  void initState() {
    super.initState();
    _initiate2FASetup();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _initiate2FASetup() async {
    setState(() => _isLoading = true);
    
    try {
      final totpService = TOTPService();
      final result = await totpService.enable2FA();
      
      setState(() {
        _secret = result['secret'];
        _qrCodeUri = result['qrCodeURI'];
        _isLoading = false;
      });
    } catch (e) {
      LoggerService.error('Failed to initiate 2FA setup', error: e);
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to setup 2FA: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _verify2FACode() async {
    if (_codeController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit code'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final totpService = TOTPService();
      final isValid = await totpService.verify2FACode(
        _secret!,
        _codeController.text.trim(),
      );

      if (isValid) {
        await totpService.confirm2FASetup(_secret!);
        
        setState(() {
          _setupComplete = true;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Two-factor authentication enabled successfully!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        setState(() => _isLoading = false);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid verification code. Please try again.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      LoggerService.error('2FA verification failed', error: e);
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Setup Two-Factor Authentication'),
      content: SizedBox(
        width: 400,
        child: _isLoading
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Setting up 2FA...'),
                ],
              )
            : _setupComplete
                ? _buildSuccessView()
                : _buildSetupView(),
      ),
      actions: _buildActions(),
    );
  }

  Widget _buildSetupView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 1: Install an authenticator app',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Download Google Authenticator, Authy, or another TOTP app.'),
        const SizedBox(height: 16),
        
        const Text(
          'Step 2: Scan QR code or enter secret manually',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        
        if (_qrCodeUri != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Text('QR Code would be displayed here'),
                const SizedBox(height: 8),
                const Text('Manual entry key:', style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(
                  _secret ?? '',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    backgroundColor: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        const Text(
          'Step 3: Enter verification code',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _codeController,
          decoration: const InputDecoration(
            labelText: '6-digit code',
            border: OutlineInputBorder(),
            hintText: '123456',
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle,
          color: AppTheme.successColor,
          size: 64,
        ),
        SizedBox(height: 16),
        Text(
          'Two-Factor Authentication Enabled!',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.successColor,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Your account is now protected with 2FA. You will be prompted for a verification code on future logins.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  List<Widget> _buildActions() {
    if (_setupComplete) {
      return [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: _isLoading || _secret == null ? null : _verify2FACode,
        child: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Verify'),
      ),
    ];
  }
} 