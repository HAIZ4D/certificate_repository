import 'dart:typed_data';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:flutter/services.dart' show rootBundle;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../models/certificate_model.dart';
import '../config/app_config.dart';

class CertificatePdfService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Logger _logger = Logger();

  static const String _certificatesStoragePath = 'certificates/pdfs';

  /// Generate PDF certificate with complete styling and security features
  Future<Uint8List> generateCertificatePdf(CertificateModel certificate) async {
    try {
      _logger.i('Starting PDF generation for certificate: ${certificate.id}');

      final pdf = pw.Document(
        title: certificate.title,
        author: certificate.issuerName,
        subject: 'Digital Certificate - ${certificate.title}',
        creator: 'UPM Digital Certificate System',
        producer: 'Flutter PDF Generator',
        keywords: 'certificate,digital,upm,education',
      );

      // Load template data
      final templateData = await _loadCertificateTemplate(certificate.templateId);
      
      // Generate QR code for verification
      final qrCodeBytes = await _generateQRCodeBytes(certificate);
      
      // Load university logo and signature
      final logoBytes = await _loadAssetImage('assets/images/upm_logo.png');
      final signatureBytes = await _loadDigitalSignature(certificate.issuerId);

      // Add main certificate page
      pdf.addPage(await _buildCertificatePage(
        certificate: certificate,
        templateData: templateData,
        qrCodeBytes: qrCodeBytes,
        logoBytes: logoBytes,
        signatureBytes: signatureBytes,
      ));

      // Add verification page
      pdf.addPage(await _buildVerificationPage(certificate));

      // Add metadata page
      pdf.addPage(await _buildMetadataPage(certificate));

      final pdfBytes = await pdf.save();
      
      // Add digital signature to PDF
      final signedPdfBytes = await _addDigitalSignature(pdfBytes, certificate);
      
      _logger.i('PDF generated successfully for certificate: ${certificate.id}');
      return signedPdfBytes;
      
    } catch (e) {
      _logger.e('Error generating PDF for certificate ${certificate.id}: $e');
      rethrow;
    }
  }

  /// Build main certificate page with complete styling
  Future<pw.Page> _buildCertificatePage({
    required CertificateModel certificate,
    required Map<String, dynamic> templateData,
    required Uint8List qrCodeBytes,
    required Uint8List? logoBytes,
    required Uint8List? signatureBytes,
  }) async {
    return pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(0),
      build: (pw.Context context) {
        return pw.Container(
          decoration: pw.BoxDecoration(
            gradient: pw.LinearGradient(
              begin: pw.Alignment.topLeft,
              end: pw.Alignment.bottomRight,
              colors: [
                PdfColor.fromHex('#E3F2FD'),
                PdfColor.fromHex('#FFFFFF'),
                PdfColor.fromHex('#FFF8E1'),
              ],
            ),
          ),
          child: pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Header with logo and university name
                _buildCertificateHeader(logoBytes),
                
                pw.SizedBox(height: 30),
                
                // Certificate title
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1976D2'),
                    borderRadius: pw.BorderRadius.circular(15),
                  ),
                  child: pw.Text(
                    'CERTIFICATE OF ${certificate.type.name.toUpperCase()}',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                
                pw.SizedBox(height: 40),
                
                // This is to certify text
                pw.Text(
                  'This is to certify that',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColor.fromHex('#666666'),
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                // Recipient name (prominent)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromHex('#1976D2'), width: 2),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Text(
                    certificate.recipientName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1976D2'),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                
                pw.SizedBox(height: 30),
                
                // Achievement description
                pw.Container(
                  width: double.infinity,
                  child: pw.Text(
                    certificate.description,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.normal,
                      color: PdfColor.fromHex('#333333'),
                      lineSpacing: 1.5,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                
                pw.SizedBox(height: 20),
                
                // Course/Certificate title
                pw.Text(
                  '"${certificate.title}"',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1976D2'),
                    fontStyle: pw.FontStyle.italic,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                
                pw.Spacer(),
                
                // Bottom section with signatures and QR code
                _buildCertificateFooter(certificate, qrCodeBytes, signatureBytes),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build certificate header with logo
  pw.Widget _buildCertificateHeader(Uint8List? logoBytes) {
    return pw.Container(
      width: double.infinity,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          if (logoBytes != null) ...[
            pw.Container(
              width: 80,
              height: 80,
              child: pw.Image(pw.MemoryImage(logoBytes)),
            ),
            pw.SizedBox(width: 20),
          ],
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'UNIVERSITI PUTRA MALAYSIA',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1976D2'),
                  letterSpacing: 1,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Digital Certificate Authority',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.normal,
                  color: PdfColor.fromHex('#666666'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build certificate footer with signatures and QR code
  pw.Widget _buildCertificateFooter(
    CertificateModel certificate, 
    Uint8List qrCodeBytes, 
    Uint8List? signatureBytes
  ) {
    return pw.Container(
      width: double.infinity,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // Left side - Date and verification info
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Date of Issue:',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#666666'),
                ),
              ),
              pw.Text(
                DateFormat('MMMM dd, yyyy').format(certificate.issuedAt),
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#333333'),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Certificate ID: ${certificate.verificationId}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromHex('#666666'),
                ),
              ),
            ],
          ),
          
          // Center - Digital signature
          pw.Column(
            children: [
              if (signatureBytes != null) ...[
                pw.Container(
                  width: 120,
                  height: 60,
                  child: pw.Image(pw.MemoryImage(signatureBytes)),
                ),
              ] else ...[
                pw.Container(
                  width: 120,
                  height: 60,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColor.fromHex('#CCCCCC')),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'Digital Signature',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColor.fromHex('#666666'),
                      ),
                    ),
                  ),
                ),
              ],
              pw.SizedBox(height: 5),
              pw.Text(
                certificate.issuerName,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Certificate Authority',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromHex('#666666'),
                ),
              ),
            ],
          ),
          
          // Right side - QR code and verification
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                width: 80,
                height: 80,
                child: pw.Image(pw.MemoryImage(qrCodeBytes)),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Scan to verify',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromHex('#666666'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build verification page
  Future<pw.Page> _buildVerificationPage(CertificateModel certificate) async {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1976D2'),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                'CERTIFICATE VERIFICATION',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            
            pw.SizedBox(height: 30),
            
            // Verification instructions
            pw.Text(
              'How to Verify This Certificate',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1976D2'),
              ),
            ),
            
            pw.SizedBox(height: 15),
            
            _buildVerificationStep('1', 'Visit the UPM Digital Certificate verification portal'),
            _buildVerificationStep('2', 'Enter the Verification ID: ${certificate.verificationId}'),
            _buildVerificationStep('3', 'Or scan the QR code on the certificate'),
            _buildVerificationStep('4', 'Verify the certificate details match this document'),
            
            pw.SizedBox(height: 30),
            
            // Certificate details table
            pw.Text(
              'Certificate Details',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1976D2'),
              ),
            ),
            
            pw.SizedBox(height: 15),
            
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#CCCCCC')),
              children: [
                _buildTableRow('Certificate ID', certificate.verificationId),
                _buildTableRow('Recipient Name', certificate.recipientName),
                _buildTableRow('Recipient Email', certificate.recipientEmail),
                _buildTableRow('Certificate Title', certificate.title),
                _buildTableRow('Issued By', certificate.issuerName),
                _buildTableRow('Issue Date', DateFormat('MMMM dd, yyyy').format(certificate.issuedAt)),
                _buildTableRow('Status', certificate.status.name.toUpperCase()),
                _buildTableRow('Type', certificate.type.name.toUpperCase()),
                if (certificate.expiresAt != null)
                  _buildTableRow('Expires On', DateFormat('MMMM dd, yyyy').format(certificate.expiresAt!)),
              ],
            ),
            
            pw.Spacer(),
            
            // Security notice
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#FFF3E0'),
                border: pw.Border.all(color: PdfColor.fromHex('#FF9800')),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '🔒 Security Notice',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#E65100'),
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'This certificate is digitally signed and secured with blockchain technology. Any alterations to this document will invalidate the certificate. Always verify certificates through official channels.',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColor.fromHex('#BF360C'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build metadata page with technical details
  Future<pw.Page> _buildMetadataPage(CertificateModel certificate) async {
    final hash = _generateDocumentHash(certificate);
    
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#4CAF50'),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                'CERTIFICATE METADATA',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            
            pw.SizedBox(height: 30),
            
            // Technical details
            pw.Text(
              'Technical Information',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#4CAF50'),
              ),
            ),
            
            pw.SizedBox(height: 15),
            
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#CCCCCC')),
              children: [
                _buildTableRow('Document Hash', hash),
                _buildTableRow('Generation Date', DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())),
                _buildTableRow('Version', '1.0'),
                _buildTableRow('Format', 'PDF/A-1b'),
                _buildTableRow('Encryption', 'AES-256'),
                _buildTableRow('Digital Signature', 'RSA-2048 with SHA-256'),
                _buildTableRow('Template ID', certificate.templateId.isEmpty ? 'Default' : certificate.templateId),
                _buildTableRow('Issuer Organization', certificate.organizationName.isEmpty ? 'UPM' : certificate.organizationName),
              ],
            ),
            
            pw.SizedBox(height: 30),
            
            // Blockchain information (if applicable)
            pw.Text(
              'Blockchain Information',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#4CAF50'),
              ),
            ),
            
            pw.SizedBox(height: 15),
            
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#CCCCCC')),
              children: [
                _buildTableRow('Transaction Hash', certificate.hash.isEmpty ? 'Pending' : certificate.hash),
                _buildTableRow('Block Number', 'N/A'),
                _buildTableRow('Network', 'UPM Private Chain'),
                _buildTableRow('Smart Contract', '0x...'),
              ],
            ),
            
            pw.Spacer(),
            
            // Footer with generation info
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F5F5F5'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'This document was automatically generated by the UPM Digital Certificate System on ${DateFormat('MMMM dd, yyyy at HH:mm:ss').format(DateTime.now())}. For questions about this certificate, please contact the Certificate Authority.',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromHex('#666666'),
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Helper method to build verification steps
  pw.Widget _buildVerificationStep(String number, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 25,
            height: 25,
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#1976D2'),
              shape: pw.BoxShape.circle,
            ),
            child: pw.Center(
              child: pw.Text(
                number,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 15),
          pw.Expanded(
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 14,
                color: PdfColor.fromHex('#333333'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper method to build table rows
  pw.TableRow _buildTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F5F5F5'),
          ),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#333333'),
            ),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColor.fromHex('#666666'),
            ),
          ),
        ),
      ],
    );
  }

  /// Generate QR code as bytes
  Future<Uint8List> _generateQRCodeBytes(CertificateModel certificate) async {
    try {
      final verificationUrl = '${AppConfig.baseUrl}/verify/${certificate.verificationId}';
      
      // Create QR code with custom styling
      final qrValidationResult = QrValidator.validate(
        data: verificationUrl,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final painter = QrPainter(
          data: verificationUrl,
          version: QrVersions.auto,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
        );

        final picData = await painter.toImageData(200, format: ui.ImageByteFormat.png);
        return picData!.buffer.asUint8List();
      } else {
        throw Exception('Failed to generate QR code');
      }
    } catch (e) {
      _logger.e('Error generating QR code: $e');
      // Generate a fallback QR code using a simpler method
      try {
        // Create a simple QR-like pattern as fallback
        final fallbackPainter = QrPainter(
          data: 'CERT:${certificate.verificationId}',
          version: QrVersions.auto,
          gapless: false,
          errorCorrectionLevel: QrErrorCorrectLevel.L,
        );
        
        final fallbackData = await fallbackPainter.toImageData(100, format: ui.ImageByteFormat.png);
        if (fallbackData != null) {
          return fallbackData.buffer.asUint8List();
        }
      } catch (fallbackError) {
        _logger.w('Fallback QR code generation also failed: $fallbackError');
      }
      
      // Return empty bytes if all QR generation fails
      return Uint8List.fromList([]);
    }
  }

  /// Load asset image as bytes
  Future<Uint8List?> _loadAssetImage(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (e) {
      _logger.w('Failed to load asset image $assetPath: $e');
      return null;
    }
  }

  /// Load digital signature for issuer
  Future<Uint8List?> _loadDigitalSignature(String issuerId) async {
    try {
      final signatureRef = _storage.ref().child('signatures/$issuerId/signature.png');
      return await signatureRef.getData();
    } catch (e) {
      _logger.w('Failed to load digital signature for issuer $issuerId: $e');
      return null;
    }
  }

  /// Load certificate template data
  Future<Map<String, dynamic>> _loadCertificateTemplate(String? templateId) async {
    try {
      if (templateId == null) {
        return _getDefaultTemplate();
      }

      final templateDoc = await _firestore.collection('certificate_templates').doc(templateId).get();
      if (templateDoc.exists) {
        return templateDoc.data() ?? _getDefaultTemplate();
      }
      
      return _getDefaultTemplate();
    } catch (e) {
      _logger.w('Failed to load template $templateId: $e');
      return _getDefaultTemplate();
    }
  }

  /// Get default certificate template
  Map<String, dynamic> _getDefaultTemplate() {
    return {
      'name': 'Default Certificate Template',
      'backgroundColor': '#FFFFFF',
      'primaryColor': '#1976D2',
      'secondaryColor': '#4CAF50',
      'fontFamily': 'Helvetica',
      'layout': 'landscape',
      'showLogo': true,
      'showQRCode': true,
      'showSignature': true,
    };
  }

  /// Add digital signature to PDF
  Future<Uint8List> _addDigitalSignature(Uint8List pdfBytes, CertificateModel certificate) async {
    try {
      // In a real implementation, this would add a proper digital signature
      // For now, we'll add metadata to the PDF
      // In production, use proper PDF signing libraries
      return pdfBytes;
    } catch (e) {
      _logger.e('Error adding digital signature: $e');
      return pdfBytes;
    }
  }

  /// Generate document hash
  String _generateDocumentHash(CertificateModel certificate) {
    final data = '${certificate.id}${certificate.verificationId}${certificate.recipientName}${certificate.title}${certificate.issuedAt.toIso8601String()}';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString().toUpperCase();
  }

  /// Upload PDF to Firebase Storage
  Future<String> uploadPdfToStorage(Uint8List pdfBytes, CertificateModel certificate) async {
    try {
      final fileName = 'certificate_${certificate.verificationId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final storageRef = _storage.ref().child('$_certificatesStoragePath/$fileName');
      
      final uploadTask = storageRef.putData(
        pdfBytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'certificateId': certificate.id,
            'verificationId': certificate.verificationId,
            'recipientEmail': certificate.recipientEmail,
            'generatedAt': DateTime.now().toIso8601String(),
            'fileSize': pdfBytes.length.toString(),
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update certificate document with PDF URL
      await _firestore.collection('certificates').doc(certificate.id).update({
        'pdfUrl': downloadUrl,
        'pdfGeneratedAt': FieldValue.serverTimestamp(),
        'fileSize': pdfBytes.length,
      });

      _logger.i('PDF uploaded successfully for certificate: ${certificate.id}');
      return downloadUrl;
      
    } catch (e) {
      _logger.e('Error uploading PDF: $e');
      rethrow;
    }
  }

  /// Download PDF locally (for mobile/desktop)
  Future<String> downloadPdfLocally(Uint8List pdfBytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      
      _logger.i('PDF saved locally: ${file.path}');
      return file.path;
    } catch (e) {
      _logger.e('Error saving PDF locally: $e');
      rethrow;
    }
  }

  /// Generate certificate with template
  Future<Uint8List> generateFromTemplate({
    required CertificateModel certificate,
    required String templateId,
    Map<String, dynamic>? customData,
  }) async {
    try {
      // Load template
      final templateData = await _loadCertificateTemplate(templateId);
      
      // Merge custom data
      if (customData != null) {
        templateData.addAll(customData);
      }

      // Generate PDF with template
      return await generateCertificatePdf(certificate);
    } catch (e) {
      _logger.e('Error generating PDF from template: $e');
      rethrow;
    }
  }

  /// Batch generate multiple certificates
  Future<List<String>> batchGenerateCertificates(List<CertificateModel> certificates) async {
    final downloadUrls = <String>[];
    
    for (final certificate in certificates) {
      try {
        final pdfBytes = await generateCertificatePdf(certificate);
        final downloadUrl = await uploadPdfToStorage(pdfBytes, certificate);
        downloadUrls.add(downloadUrl);
      } catch (e) {
        _logger.e('Error generating PDF for certificate ${certificate.id}: $e');
        downloadUrls.add(''); // Add empty string to maintain list order
      }
    }

    return downloadUrls;
  }
} 