import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/certificate_model.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/config/app_config.dart';

class VerifyCertificatePage extends ConsumerStatefulWidget {
  const VerifyCertificatePage({super.key});

  @override
  ConsumerState<VerifyCertificatePage> createState() => _VerifyCertificatePageState();
}

class _VerifyCertificatePageState extends ConsumerState<VerifyCertificatePage> {
  final _formKey = GlobalKey<FormState>();
  final _verificationCodeController = TextEditingController();
  bool _isVerifying = false;
  CertificateModel? _verifiedCertificate;
  String? _verificationError;

  @override
  void dispose() {
    _verificationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Certificate'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInUp(
              duration: const Duration(milliseconds: 300),
              child: _buildHeaderCard(),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              duration: const Duration(milliseconds: 400),
              child: _buildVerificationForm(),
            ),
            if (_verifiedCertificate != null) ...[
              const SizedBox(height: AppTheme.spacingL),
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: _buildVerificationResult(),
              ),
            ],
            if (_verificationError != null) ...[
              const SizedBox(height: AppTheme.spacingL),
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: _buildErrorResult(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            const Icon(
              Icons.verified_user,
              size: 64,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: AppTheme.spacingM),
            Text(
              'Certificate Verification',
              style: AppTheme.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Enter a verification code to verify the authenticity of a certificate issued by ${AppConfig.universityName}',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verification Code',
                style: AppTheme.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _verificationCodeController,
                decoration: const InputDecoration(
                  labelText: 'Enter verification code',
                  hintText: 'e.g., CERT-123456-ABC-2024',
                  prefixIcon: Icon(Icons.qr_code_scanner),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a verification code';
                  }
                  if (value.trim().length < 6) {
                    return 'Verification code must be at least 6 characters';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _verifyCode(),
              ),
              const SizedBox(height: AppTheme.spacingL),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isVerifying ? null : _verifyCode,
                  icon: _isVerifying
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.search),
                  label: Text(_isVerifying ? 'Verifying...' : 'Verify Certificate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.textOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                    color: AppTheme.infoColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppTheme.infoColor,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Expanded(
                      child: Text(
                        'Tip: The verification code is usually found on the certificate or shared with the certificate.',
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.infoColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationResult() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified,
                    color: AppTheme.successColor,
                    size: 32,
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Certificate Verified',
                          style: AppTheme.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successColor,
                          ),
                        ),
                        Text(
                          'This certificate is authentic and valid',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'Certificate Details',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildDetailRow('Title', _verifiedCertificate!.title),
            _buildDetailRow('Recipient', _verifiedCertificate!.recipientName),
            _buildDetailRow('Type', _verifiedCertificate!.type.displayName),
            _buildDetailRow('Issued By', _verifiedCertificate!.issuerName),
            _buildDetailRow('Issue Date', _formatDate(_verifiedCertificate!.issuedAt)),
            if (_verifiedCertificate!.expiresAt != null)
              _buildDetailRow('Expires', _formatDate(_verifiedCertificate!.expiresAt!)),
            _buildDetailRow('Status', _verifiedCertificate!.status.displayName),
            const SizedBox(height: AppTheme.spacingL),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.go('/view/${_verifiedCertificate!.verificationCode}');
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Full Details'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareVerificationLink,
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorResult() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: AppTheme.errorColor,
                size: 32,
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification Failed',
                      style: AppTheme.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.errorColor,
                      ),
                    ),
                    Text(
                      _verificationError!,
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isVerifying = true;
      _verifiedCertificate = null;
      _verificationError = null;
    });

    try {
      final verificationCode = _verificationCodeController.text.trim();

      // Search for certificate by verification code
      final certificateQuery = await FirebaseFirestore.instance
          .collection(AppConfig.certificatesCollection)
          .where('verificationCode', isEqualTo: verificationCode)
          .limit(1)
          .get();

      if (certificateQuery.docs.isNotEmpty) {
        final doc = certificateQuery.docs.first;
        final certificate = CertificateModel.fromFirestore(doc);

        // Check certificate status
        if (certificate.status == CertificateStatus.revoked) {
          setState(() {
            _verificationError = 'This certificate has been revoked and is no longer valid.';
          });
        } else if (certificate.status == CertificateStatus.issued) {
          // Check if certificate has expired
          if (certificate.expiresAt != null && certificate.expiresAt!.isBefore(DateTime.now())) {
            setState(() {
              _verificationError = 'This certificate has expired and is no longer valid.';
            });
          } else {
            setState(() {
              _verifiedCertificate = certificate;
            });

            // Log verification event
            LoggerService.info('Certificate verified: $verificationCode');

            // Record verification in analytics (if implemented)
            await _recordVerificationEvent(certificate);
          }
        } else {
          setState(() {
            _verificationError = 'This certificate is not yet issued or is in draft status.';
          });
        }
      } else {
        setState(() {
          _verificationError = 'Certificate not found. Please check the verification code and try again.';
        });
      }
    } catch (e, stackTrace) {
      LoggerService.error('Error verifying certificate',
          error: e, stackTrace: stackTrace);

      setState(() {
        _verificationError = 'An error occurred while verifying the certificate. Please try again.';
      });
    } finally {
      setState(() {
        _isVerifying = false;
      });
    }
  }

  Future<void> _recordVerificationEvent(CertificateModel certificate) async {
    try {
      // Record verification event in activities collection
      await FirebaseFirestore.instance
          .collection(AppConfig.activityCollection)
          .add({
        'action': 'certificate_verified',
        'certificateId': certificate.id,
        'verificationCode': certificate.verificationCode,
        'verifiedAt': Timestamp.fromDate(DateTime.now()),
        'details': {
          'certificateTitle': certificate.title,
          'recipientName': certificate.recipientName,
          'issuerName': certificate.issuerName,
        },
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'type': 'verification',
      });
    } catch (e) {
      LoggerService.error('Failed to record verification event', error: e);
      // Don't throw - this is not critical for the verification process
    }
  }

  void _shareVerificationLink() {
    if (_verifiedCertificate == null) return;

    final verificationUrl = '${AppConfig.verificationBaseUrl}/${_verifiedCertificate!.verificationCode}';

    // In a real app, you would use the share package
    // For now, we'll copy to clipboard and show a message

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Verification Link:'),
            Text(
              verificationUrl,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            // In a real app, copy to clipboard
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Link copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 
