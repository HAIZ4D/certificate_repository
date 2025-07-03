import 'dart:typed_data';
// ignore_for_file: prefer_const_constructors
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

class CertificateGeneratorService {
  Future<Uint8List> generateCertificatePDF({
    required String recipientName,
    required String title,
    required String issuedDate,
    required String organization,
    required String signatureImagePath,
  }) async {
    final pdf = pw.Document();

    final signatureImage = pw.MemoryImage(
      await rootBundle
          .load(signatureImagePath)
          .then((data) => data.buffer.asUint8List()),
    );

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.Center(
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text('Certificate of Achievement',
                        style: pw.TextStyle(fontSize: 28)),
                    pw.SizedBox(height: 20),
                    pw.Text(recipientName,
                        style: pw.TextStyle(fontSize: 22)),
                    pw.SizedBox(height: 10),
                    pw.Text('Awarded by $organization'),
                    pw.SizedBox(height: 10),
                    pw.Text('Issued on $issuedDate'),
                  ],
                ),
              ),
              pw.Positioned(
                bottom: 30,
                right: 50,
                child: pw.Image(signatureImage, width: 100),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
