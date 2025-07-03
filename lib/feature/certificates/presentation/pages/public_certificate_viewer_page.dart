// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:pdf/pdf.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/certificate_model.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/config/app_config.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:flutter/services.dart';

class PublicCertificateViewerPage extends ConsumerStatefulWidget {
  final String token;

  const PublicCertificateViewerPage({
    super.key,
    required this.token,
  });

  @override
  ConsumerState<PublicCertificateViewerPage> createState() =>
      _PublicCertificateViewerPageState();
}

class _PublicCertificateViewerPageState
    extends ConsumerState<PublicCertificateViewerPage> {
  bool _isLoading = false;
  CertificateModel? _certificate;
  String? _error;
  final TextEditingController _tokenController = TextEditingController();

  Future<Uint8List> _generateCertificatePdf(
      CertificateModel certificate) async {
    final pdf = pw.Document();

    // Load images
    final bgImage = pw.MemoryImage(
      (await rootBundle.load('assets/certificate_template.jpg'))
          .buffer
          .asUint8List(),
    );

    final upmLogo = pw.MemoryImage(
      (await rootBundle.load('assets/ca_signature.png')).buffer.asUint8List(),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => pw.Stack(
          children: [
            // Background template
            pw.Positioned.fill(
              child: pw.Image(bgImage, fit: pw.BoxFit.cover),
            ),
            // UPM logo watermark
            pw.Positioned.fill(
              child: pw.Opacity(
                opacity: 0.08,
                child: pw.Center(
                  child: pw.Image(upmLogo, width: 300),
                ),
              ),
            ),
            // Certificate text
            pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 40),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.SizedBox(height: 160),
                    pw.Text(certificate.recipientName,
                        style: pw.TextStyle(
                            fontSize: 28, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 16),
                    pw.Text('has successfully completed',
                        style: pw.TextStyle(fontSize: 16)),
                    pw.Text(certificate.courseName,
                        style: pw.TextStyle(
                            fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 30),
                    pw.Text(
                        'Issued on: ${_formatDate(certificate.issuedAt)}',
                        style: pw.TextStyle(fontSize: 14)),
                    pw.SizedBox(height: 20),
                    pw.Text('Issuer: ${certificate.issuerName}',
                        style: pw.TextStyle(fontSize: 14)),
                    if (certificate.issuerTitle?.isNotEmpty == true)
                      pw.Text(certificate.issuerTitle!,
                          style: pw.TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  @override
  void initState() {
    super.initState();
    // Do NOT load the certificate on init. Wait for user input.
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndLoadCertificate() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _certificate = null;
    });
    try {
      final enteredToken = _tokenController.text.trim();
      if (enteredToken.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'Please enter the access token.';
        });
        return;
      }
      final certificateQuery = await FirebaseFirestore.instance
          .collection(AppConfig.certificatesCollection)
          .where('verificationCode', isEqualTo: widget.token)
          .where('accessToken', isEqualTo: enteredToken)
          .limit(1)
          .get();

      if (certificateQuery.docs.isNotEmpty) {
        final doc = certificateQuery.docs.first;
        _certificate = CertificateModel.fromFirestore(doc);
        if (_certificate?.status != CertificateStatus.issued) {
          _error = 'Certificate is not available (not issued or revoked).';
          _certificate = null;
        }
      } else {
        _error = 'Invalid access token or certificate not found.';
      }
    } catch (e, stackTrace) {
      LoggerService.error('Error loading public certificate',
          error: e, stackTrace: stackTrace);
      _error = 'Failed to load certificate: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificate Verification'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textOnPrimary,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppTheme.spacingM),
            Text('Verifying certificate...'),
          ],
        ),
      );
    }

    // Show token prompt if certificate is not loaded yet
    if (_certificate == null) {
      return _buildTokenPrompt();
    }

    if (_error != null) {
      return _buildErrorView();
    }

    return _buildCertificateView();
  }

  Widget _buildTokenPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 48, color: AppTheme.primaryColor),
                const SizedBox(height: AppTheme.spacingL),
                Text(
                  'Enter Access Token',
                  style:
                      AppTheme.titleLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppTheme.spacingM),
                TextField(
                  controller: _tokenController,
                  decoration: const InputDecoration(
                    labelText: 'Access Token / OTP',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  onChanged: (_) {
                    if (_error != null) {
                      setState(() {
                        _error = null;
                      });
                    }
                  },
                  onSubmitted: (_) => _verifyAndLoadCertificate(),
                ),
                const SizedBox(height: AppTheme.spacingL),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _verifyAndLoadCertificate,
                    icon: const Icon(Icons.verified_user),
                    label: const Text('Verify'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeIn(
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Text(
                'Verification Failed',
                style: AppTheme.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.errorColor,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: Text(
                _error!,
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              delay: const Duration(milliseconds: 600),
              child: ElevatedButton.icon(
                onPressed: _verifyAndLoadCertificate,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateView() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    child: _buildVerificationStatusCard()),
                const SizedBox(height: AppTheme.spacingL),
                FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    child: _buildCertificateInfoCard()),
                const SizedBox(height: AppTheme.spacingL),
                FadeInUp(
                    duration: const Duration(milliseconds: 500),
                    child: _buildRecipientInfoCard()),
                const SizedBox(height: AppTheme.spacingL),
                FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    child: _buildIssuerInfoCard()),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: ElevatedButton.icon(
            onPressed: () async {
              final pdfBytes = await _generateCertificatePdf(_certificate!);
              await Printing.layoutPdf(onLayout: (_) => pdfBytes);
            },
            icon: const Icon(Icons.download),
            label: const Text('Download Certificate'),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationStatusCard() {
    final certificate = _certificate!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.verified,
                    size: 64,
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    'Certificate Verified',
                    style: AppTheme.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'This is a genuine certificate issued by ${AppConfig.universityName}',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            _buildInfoRow('Verification Code', certificate.verificationCode),
            _buildInfoRow('Verification URL',
                '${AppConfig.verificationBaseUrl}/${certificate.verificationCode}'),
            _buildInfoRow('Issued Date', _formatDate(certificate.issuedAt)),
            if (certificate.expiresAt != null)
              _buildInfoRow('Expires', _formatDate(certificate.expiresAt!)),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificateInfoCard() {
    final certificate = _certificate!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Certificate Details',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildInfoRow('Title', certificate.title),
            _buildInfoRow('Type', certificate.type.displayName),
            _buildInfoRow(
                'Description',
                certificate.description.isNotEmpty
                    ? certificate.description
                    : 'No description'),
            if (certificate.grade.isNotEmpty)
              _buildInfoRow('Grade/Score', certificate.grade),
            if (certificate.creditsEarned != null)
              _buildInfoRow('Credits', certificate.creditsEarned.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientInfoCard() {
    final certificate = _certificate!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recipient Information',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildInfoRow('Name', certificate.recipientName),
            _buildInfoRow('Email', certificate.recipientEmail),
            if (certificate.recipientId.isNotEmpty)
              _buildInfoRow('Student/Staff ID', certificate.recipientId),
          ],
        ),
      ),
    );
  }

  Widget _buildIssuerInfoCard() {
    final certificate = _certificate!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Issuer Information',
              style: AppTheme.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildInfoRow('Issued by', certificate.issuerName),
            if (certificate.issuerTitle?.isNotEmpty == true)
              _buildInfoRow('Title', certificate.issuerTitle!),
            _buildInfoRow('Institution', AppConfig.universityName),
            _buildInfoRow(
                'Digital Signature',
                certificate.digitalSignature.isNotEmpty
                    ? certificate.digitalSignature.substring(0, 32)
                    : 'Not available'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
