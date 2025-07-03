import 'dart:typed_data';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../models/certificate_model.dart';

class PdfGenerationService {
  final Logger _logger = Logger();

  // Generate certificate PDF
  Future<Uint8List> generateCertificatePdf({
    required CertificateModel certificate,
    String? logoPath,
    String? backgroundPath,
    String? signaturePath,
  }) async {
    try {
      final pdf = pw.Document();

      // Load fonts - using basic fonts instead of Google Fonts
      final fontRegular = pw.Font.helvetica();
      final fontBold = pw.Font.helveticaBold();

      // Load images
      pw.ImageProvider? logo;
      pw.ImageProvider? background;
      pw.ImageProvider? signature;

      try {
        if (logoPath != null) {
          final logoData = await rootBundle.load(logoPath);
          logo = pw.MemoryImage(logoData.buffer.asUint8List());
        }
        if (backgroundPath != null) {
          final bgData = await rootBundle.load(backgroundPath);
          background = pw.MemoryImage(bgData.buffer.asUint8List());
        }
        if (signaturePath != null) {
          final sigData = await rootBundle.load(signaturePath);
          signature = pw.MemoryImage(sigData.buffer.asUint8List());
        }
      } catch (e) {
        _logger.w('Error loading assets: $e');
      }

      // Generate QR code data
      final qrCodeData = _generateQRCodeData(certificate);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Container(
              decoration: background != null
                  ? pw.BoxDecoration(
                      image: pw.DecorationImage(
                        image: background,
                        fit: pw.BoxFit.cover,
                      ),
                    )
                  : null,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Header
                  _buildPdfHeader(certificate, logo, fontBold),
                  pw.SizedBox(height: 40),
                  
                  // Certificate Title
                  pw.Text(
                    'CERTIFICATE',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 36,
                      color: PdfColors.blue900,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  
                  // Certificate Type
                  pw.Text(
                    certificate.typeDisplayName,
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 18,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  
                  // Certificate content
                  pw.Text(
                    'This is to certify that',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 16,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  
                  // Recipient name
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blue900, width: 2),
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Text(
                      certificate.recipientName,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 28,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  
                  // Description
                  pw.Container(
                    width: 400,
                    child: pw.Text(
                      certificate.description,
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 14,
                        color: PdfColors.grey700,
                        lineSpacing: 5,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  
                  pw.Spacer(),
                  
                  // Footer with signature and QR code
                  _buildPdfFooter(certificate, signature, qrCodeData, fontRegular, fontBold),
                ],
              ),
            );
          },
        ),
      );

      return await pdf.save();
    } catch (e) {
      _logger.e('Error generating PDF: $e');
      rethrow;
    }
  }

  pw.Widget _buildPdfHeader(CertificateModel certificate, pw.ImageProvider? logo, pw.Font fontBold) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Container(
                width: 80,
                height: 80,
                child: pw.Image(logo),
              ),
            pw.SizedBox(height: 10),
            pw.Text(
              certificate.organizationName,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 16,
                color: PdfColors.blue900,
              ),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Certificate ID',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              certificate.verificationId,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 14,
                color: PdfColors.grey800,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Issued: ${_formatDate(certificate.issuedAt)}',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfFooter(
    CertificateModel certificate,
    pw.ImageProvider? signature,
    String qrCodeData,
    pw.Font fontRegular,
    pw.Font fontBold,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        // Signature section
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (signature != null) ...[
              pw.Container(
                width: 150,
                height: 60,
                child: pw.Image(signature),
              ),
              pw.SizedBox(height: 5),
            ],
            pw.Container(
              width: 200,
              height: 1,
              color: PdfColors.grey400,
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Authorized Signature',
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 12,
                color: PdfColors.grey600,
              ),
            ),
            pw.Text(
              certificate.organizationName,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 14,
                color: PdfColors.grey800,
              ),
            ),
          ],
        ),
        
        // QR Code section
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrCodeData,
              width: 80,
              height: 80,
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Verify Certificate',
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _generateQRCodeData(CertificateModel certificate) {
    // Generate QR code data with verification URL
    return 'https://verify.certificate.com/${certificate.verificationId}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Save PDF to file
  Future<File> savePdfToFile(Uint8List pdfBytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName.pdf');
      await file.writeAsBytes(pdfBytes);
      return file;
    } catch (e) {
      _logger.e('Error saving PDF to file: $e');
      rethrow;
    }
  }

  // Print PDF
  Future<void> printPdf(Uint8List pdfBytes) async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      _logger.e('Error printing PDF: $e');
      rethrow;
    }
  }

  // Share PDF
  Future<void> sharePdf(Uint8List pdfBytes, String fileName) async {
    try {
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: '$fileName.pdf',
      );
    } catch (e) {
      _logger.e('Error sharing PDF: $e');
      rethrow;
    }
  }

  // Generate certificate with template
  Future<Uint8List> generateFromTemplate({
    required CertificateModel certificate,
    required Map<String, dynamic> templateData,
  }) async {
    try {
      // This would integrate with template system
      return await generateCertificatePdf(certificate: certificate);
    } catch (e) {
      _logger.e('Error generating PDF from template: $e');
      rethrow;
    }
  }
} 