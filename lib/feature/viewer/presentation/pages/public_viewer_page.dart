import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/models/certificate_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/logger_service.dart';
import '../../../dashboard/services/activity_service.dart';

class PublicViewerPage extends ConsumerStatefulWidget {
  final String token;

  const PublicViewerPage({
    super.key,
    required this.token,
  });

  @override
  ConsumerState<PublicViewerPage> createState() => _PublicViewerPageState();
}

class _PublicViewerPageState extends ConsumerState<PublicViewerPage> {
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ActivityService _activityService = ActivityService();

  bool _isLoading = true;
  CertificateModel? _certificate;
  String? _error;
  bool _isPasswordProtected = false;

  @override
  void initState() {
    super.initState();
    _loadCertificate();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadCertificate() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      LoggerService.info('Loading certificate with verification token: ${widget.token}');

      // Query Firebase for certificate with this verification token
      final querySnapshot = await _firestore
          .collection(AppConfig.certificatesCollection)
          .where('verificationId', isEqualTo: widget.token)
          .where('status', isEqualTo: CertificateStatus.issued.name)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _error = 'Certificate not found or invalid verification token';
          _isLoading = false;
        });

        // Log verification attempt
        await _activityService.logActivity(
          action: 'certificate_verification_failed',
          details: 'Invalid verification token: ${widget.token}',
          metadata: {'token': widget.token, 'result': 'not_found'},
        );
        return;
      }

      final doc = querySnapshot.docs.first;
      final certificateData = {
        'id': doc.id,
        ...doc.data(),
      };

      final certificate = CertificateModel.fromMap(certificateData);

      // Check if certificate requires password
      if (certificateData['passwordProtected'] == true) {
        setState(() {
          _isPasswordProtected = true;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _certificate = certificate;
        _isLoading = false;
      });

      // Log successful verification
      await _activityService.logCertificateActivity(
        action: 'certificate_verified',
        certificateId: certificate.id,
        details: 'Certificate successfully verified via public link',
        metadata: {
          'verification_token': widget.token,
          'certificate_title': certificate.title,
          'recipient': certificate.recipientName,
        },
      );

      LoggerService.info('Certificate loaded successfully: ${certificate.id}');

    } catch (e, stackTrace) {
      LoggerService.error('Failed to load certificate', error: e, stackTrace: stackTrace);

      setState(() {
        _error = 'Failed to verify certificate: ${e.toString()}';
        _isLoading = false;
      });

      // Log verification error
      await _activityService.logActivity(
        action: 'certificate_verification_error',
        details: 'Error verifying certificate with token: ${widget.token}',
        metadata: {'token': widget.token, 'error': e.toString()},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Certificate Verification'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_certificate != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareCertificate,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_isPasswordProtected) {
      return _buildPasswordPrompt();
    }

    if (_certificate == null) {
      return _buildNotFoundState();
    }

    return _buildCertificateView();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Verifying certificate...',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'Verification Failed',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadCertificate,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordPrompt() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock,
            size: 80,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 16),
          const Text(
            'Password Protected',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This certificate requires a password to view',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _verifyPassword,
              child: const Text('Verify'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 80,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Certificate Not Found',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No certificate found with token: ${widget.token}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVerificationHeader(),
          const SizedBox(height: 24),
          _buildCertificateCard(),
          const SizedBox(height: 24),
          _buildVerificationDetails(),
          const SizedBox(height: 24),
          _buildQRCode(),
        ],
      ),
    );
  }

  Widget _buildVerificationHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.successColor, Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.verified,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          const Text(
            'Certificate Verified',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Issued by ${_certificate!.organizationName}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _certificate!.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _certificate!.description,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          _buildInfoRow('Recipient', _certificate!.recipientName),
          _buildInfoRow('Issued By', _certificate!.organizationName),
          _buildInfoRow('Organization', _certificate!.organizationName),
          _buildInfoRow('Issue Date', _formatDate(_certificate!.issuedAt)),
          if (_certificate!.metadata['gpa'] != null)
            _buildInfoRow('GPA', _certificate!.metadata['gpa'].toString()),
          if (_certificate!.metadata['honors'] != null)
            _buildInfoRow('Honors', _certificate!.metadata['honors'].toString()),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.security, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text(
                'Verification Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildVerificationRow('Verification ID', _certificate!.verificationId),
          _buildVerificationRow('Status', 'Valid & Verified'),
          _buildVerificationRow('Verified On', _formatDate(DateTime.now())),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _copyVerificationId,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy ID'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareCertificate,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCode() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'QR Code for Verification',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: QrImageView(
              data: 'https://verify.upm.edu.my/${widget.token}',
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Scan this QR code to verify the certificate',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _verifyPassword() async {
    if (_passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the password'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Query certificate with password verification
      final querySnapshot = await _firestore
          .collection(AppConfig.certificatesCollection)
          .where('verificationId', isEqualTo: widget.token)
          .where('status', isEqualTo: CertificateStatus.issued.name)
          .where('accessPassword', isEqualTo: _passwordController.text.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid password'),
            backgroundColor: AppTheme.errorColor,
          ),
        );

        // Log failed password attempt
        await _activityService.logActivity(
          action: 'certificate_password_failed',
          details: 'Invalid password for certificate: ${widget.token}',
          metadata: {'token': widget.token},
        );
        return;
      }

      final doc = querySnapshot.docs.first;
      final certificateData = {
        'id': doc.id,
        ...doc.data(),
      };

      final certificate = CertificateModel.fromMap(certificateData);

      setState(() {
        _certificate = certificate;
        _isPasswordProtected = false;
        _isLoading = false;
      });

      // Log successful password verification
      await _activityService.logCertificateActivity(
        action: 'certificate_password_verified',
        certificateId: certificate.id,
        details: 'Password-protected certificate accessed',
        metadata: {'verification_token': widget.token},
      );

    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _copyVerificationId() {
    Clipboard.setData(ClipboardData(text: _certificate!.verificationId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verification ID copied to clipboard'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _shareCertificate() {
    final shareText = '''
Certificate Verification

Title: ${_certificate!.title}
Recipient: ${_certificate!.recipientName}
Issued by: ${_certificate!.organizationName}
Verification ID: ${_certificate!.verificationId}

Verify at: https://verify.upm.edu.my/${widget.token}
''';

    Share.share(shareText, subject: 'Certificate Verification');
  }
} 
