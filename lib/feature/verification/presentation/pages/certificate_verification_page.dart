import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:animate_do/animate_do.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/certificate_model.dart';
import '../../../certificates/providers/certificate_providers.dart';

// Certificate Verification Result class
class CertificateVerificationResult {
  final bool isValid;
  final CertificateModel? certificate;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  const CertificateVerificationResult({
    required this.isValid,
    this.certificate,
    this.errorMessage,
    this.metadata,
  });

  String get status {
    if (isValid) {
      return 'Certificate is valid and verified';
    } else {
      return errorMessage ?? 'Certificate verification failed';
    }
  }
}

class CertificateVerificationPage extends ConsumerStatefulWidget {
  const CertificateVerificationPage({super.key});

  @override
  ConsumerState<CertificateVerificationPage> createState() => _CertificateVerificationPageState();
}

class _CertificateVerificationPageState extends ConsumerState<CertificateVerificationPage> 
    with TickerProviderStateMixin {
  final _certificateIdController = TextEditingController();
  bool _isScanning = true;
  bool _isVerifying = false;
  CertificateVerificationResult? _verificationResult;

  late AnimationController _animationController;
  final _verificationIdController = TextEditingController();
  
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scannerController = MobileScannerController();
  }

  @override
  void reassemble() {
    super.reassemble();
    // MobileScanner handles camera state automatically
  }

  @override
  void dispose() {
    _certificateIdController.dispose();
    _animationController.dispose();
    _verificationIdController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Verify Certificate'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.keyboard : Icons.qr_code_scanner),
            onPressed: () {
              setState(() {
                _isScanning = !_isScanning;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.verified_user,
                  size: 60,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  _isScanning ? 'Scan QR Code' : 'Enter Certificate ID',
                  style: AppTheme.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _isScanning 
                      ? 'Position the QR code within the frame'
                      : 'Type the certificate ID to verify',
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          
          // Main content
          Expanded(
            child: _isScanning ? _buildQRScanner() : _buildManualInput(),
          ),
          
          // Verification result
          if (_verificationResult != null)
            _buildVerificationResult(),
        ],
      ),
    );
  }

  Widget _buildQRScanner() {
    return Container(
      height: 300,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: MobileScanner(
          controller: _scannerController,
          onDetect: (BarcodeCapture capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                _onQRCodeDetected(barcode.rawValue!);
                break;
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildManualInput() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          FadeInUp(
            duration: const Duration(milliseconds: 600),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _certificateIdController,
                    decoration: InputDecoration(
                      labelText: 'Certificate ID',
                      hintText: 'Enter certificate ID',
                      prefixIcon: const Icon(Icons.fingerprint),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isVerifying 
                          ? null 
                          : () => _verifyCertificate(_certificateIdController.text),
                      icon: _isVerifying 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.search),
                      label: Text(_isVerifying ? 'Verifying...' : 'Verify'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FadeInUp(
            delay: const Duration(milliseconds: 800),
            child: Text(
              'Example: CERT-ABC123-XYZ789',
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationResult() {
    final isValid = _verificationResult!.isValid;
    final color = isValid ? AppTheme.successColor : AppTheme.errorColor;
    final icon = isValid ? Icons.check_circle : Icons.cancel;
    
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 60, color: color),
            const SizedBox(height: 12),
            Text(
              _verificationResult!.status,
              style: AppTheme.titleLarge.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (_verificationResult!.certificate != null) ...[
              const SizedBox(height: 16),
              _buildCertificateInfo(_verificationResult!.certificate!),
            ],
            const SizedBox(height: 16),
            if (isValid)
              ElevatedButton.icon(
                onPressed: () => _viewCertificateDetails(_verificationResult!.certificate!),
                icon: const Icon(Icons.visibility),
                label: const Text('View Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                ),
              )
            else
              TextButton(
                onPressed: _resetVerification,
                child: const Text('Try Again'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateInfo(CertificateModel certificate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildInfoRow('Certificate:', certificate.title),
          _buildInfoRow('Type:', certificate.typeDisplayName),
          _buildInfoRow('Organization:', certificate.organizationName),
          _buildInfoRow('Status:', certificate.statusDisplayName),
          _buildInfoRow('Issued:', _formatDate(certificate.issuedAt)),
          if (certificate.expiresAt != null)
            _buildInfoRow('Expires:', _formatDate(certificate.expiresAt!)),
          if (certificate.expiresAt != null && certificate.isExpired)
            _buildInfoRow('Status:', 'EXPIRED', isError: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isError = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              color: isError ? AppTheme.errorColor : AppTheme.textPrimary,
              fontWeight: isError ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  void _onQRCodeDetected(String qrData) {
    setState(() {
      _isScanning = false;
    });
    
    try {
      // Try to parse QR data as JSON
      final data = json.decode(qrData);
      if (data['certificateId'] != null) {
        _verificationIdController.text = data['certificateId'];
        _verifyCertificate(_verificationIdController.text);
      } else {
        // If not JSON, treat as direct certificate ID
        _verificationIdController.text = qrData;
        _verifyCertificate(_verificationIdController.text);
      }
    } catch (e) {
      // If JSON parsing fails, treat as direct certificate ID
      _verificationIdController.text = qrData;
      _verifyCertificate(_verificationIdController.text);
    }
  }

  Future<void> _verifyCertificate(String certificateId) async {
    if (certificateId.isEmpty) return;

    setState(() {
      _isVerifying = true;
      _verificationResult = null;
    });

    try {
      final certificateService = ref.read(certificateServiceProvider);
      
      // Get certificate by ID (using the existing method)
      final certificate = await certificateService.getCertificateById(certificateId);
      
      setState(() {
        if (certificate != null && certificate.isActive) {
          _verificationResult = CertificateVerificationResult(
            isValid: true,
            certificate: certificate,
          );
        } else {
          _verificationResult = CertificateVerificationResult(
            isValid: false,
            errorMessage: certificate == null 
                ? 'Certificate not found' 
                : 'Certificate is not active',
          );
        }
        _isVerifying = false;
      });
      
      // Stop scanning when verification is complete
      if (_isScanning) {
        setState(() {
          _isScanning = false;
        });
      }
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _verificationResult = CertificateVerificationResult(
          isValid: false,
          errorMessage: 'Verification failed: ${e.toString()}',
        );
      });
    }
  }

  void _viewCertificateDetails(CertificateModel certificate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Certificate header
                      Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.verified,
                              size: 80,
                              color: AppTheme.successColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Valid Certificate',
                              style: AppTheme.headlineMedium.copyWith(
                                color: AppTheme.successColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Certificate details
                      _buildDetailSection('Certificate Information', [
                        _buildDetailRow('Name', certificate.title),
                        _buildDetailRow('Type', certificate.typeDisplayName),
                        _buildDetailRow('ID', certificate.id),
                        _buildDetailRow('Status', certificate.statusDisplayName),
                      ]),
                      
                      const SizedBox(height: 24),
                      
                      _buildDetailSection('Recipient Information', [
                        _buildDetailRow('Name', certificate.recipientName),
                        _buildDetailRow('Email', certificate.recipientEmail),
                      ]),
                      
                      const SizedBox(height: 24),
                      
                      _buildDetailSection('Issuer Information', [
                        _buildDetailRow('Organization', certificate.organizationName),
                        _buildDetailRow('Authority', certificate.recipientName),
                      ]),
                      
                      const SizedBox(height: 24),
                      
                      _buildDetailSection('Certificate Validity', [
                        _buildDetailRow('Issue Date', _formatDate(certificate.issuedAt)),
                        if (certificate.expiresAt != null)
                          _buildDetailRow(
                            'Expiry Date', 
                            _formatDate(certificate.expiresAt!),
                            isHighlighted: certificate.isExpired,
                          ),
                        _buildDetailRow('Verification ID', certificate.verificationId),
                      ]),
                      
                      const SizedBox(height: 32),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _shareCertificate();
                              },
                              icon: const Icon(Icons.share),
                              label: const Text('Share'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium.copyWith(
                color: isHighlighted ? AppTheme.errorColor : AppTheme.textPrimary,
                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetVerification() {
    setState(() {
      _verificationResult = null;
      _certificateIdController.clear();
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _shareCertificate() {
    if (_verificationResult == null) return;
    
    final shareText = '''
Certificate Verification Details

Certificate: ${_verificationResult!.certificate!.title}
Recipient: ${_verificationResult!.certificate!.recipientName}
Organization: ${_verificationResult!.certificate!.organizationName}
Status: ${_verificationResult!.status}
Verification ID: ${_verificationResult!.certificate!.verificationId}

Verified at: ${DateTime.now().toString()}
Verification URL: https://verify.upm.edu.my/${_verificationResult!.certificate!.verificationId}

Digital Certificate Repository - UPM
''';

    Share.share(
      shareText,
      subject: 'Certificate Verification - ${_verificationResult!.certificate!.title}',
    );
  }
} 