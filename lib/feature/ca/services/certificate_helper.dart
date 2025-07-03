import 'dart:io';
import 'dart:convert';
import 'package:pdf/widgets.dart' as pw;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

// ignore_for_file: prefer_const_constructors

class CertificateHelper {
  /// Generate the certificate PDF
  static Future<File> generatePdf({
    required String title,
    required String recipientName,
    required String description,
    required DateTime issuedAt,
    required Map<String, dynamic> customFields,
    required String signature,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Center(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('This is awarded to',
                  style: pw.TextStyle(fontSize: 18)),
              pw.Text(
                recipientName,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(description, textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 20),
              pw.Text(
                'Issued on: ${issuedAt.toLocal().toString().split(" ")[0]}',
              ),
              if (customFields.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                ...customFields.entries.map(
                  (e) => pw.Text('${e.key}: ${e.value ?? "-"}'),
                ),
              ],
              pw.SizedBox(height: 30),
              pw.Text(
                'Digital Signature:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(signature, style: pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/certificate_$timestamp.pdf');

    await file.writeAsBytes(await pdf.save());
    return file;
  }

  /// Upload the PDF to Firebase Storage and return the download URL
  static Future<String> uploadPdfToFirebase(
    File file,
    String certificateId,
  ) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(
            'certificates/$certificateId.pdf',
          );
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      // Error handling - consider using proper logging in production
      rethrow;
    }
  }

  /// Update the Firestore document with the PDF URL
  static Future<void> updateCertificateUrlInFirestore(
    String certificateId,
    String downloadUrl,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('certificates')
          .doc(certificateId)
          .update({'pdfUrl': downloadUrl});
    } catch (e) {
      // Error handling - consider using proper logging in production
      rethrow;
    }
  }

  /// Generate SHA256 digital signature from data
  static String generateSignature(Map<String, dynamic> data) {
    final sortedMap = Map.fromEntries(
      data.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final jsonData = jsonEncode(sortedMap);
    final bytes = utf8.encode(jsonData);
    return sha256.convert(bytes).toString();
  }

  /// Update Firestore certificate document with signature metadata
  static Future<void> updateCertificateWithSignature(
    String certificateId,
    Map<String, dynamic> signatureData,
    String signedBy,
  ) async {
    try {
      final signature = generateSignature(signatureData);
      await FirebaseFirestore.instance
          .collection('certificates')
          .doc(certificateId)
          .update({
        'signature': signature,
        'signedAt': FieldValue.serverTimestamp(),
        'signedBy': signedBy,
        'isSigned': true,
      });
    } catch (e) {
      // Error handling - consider using proper logging in production
      rethrow;
    }
  }

  /// Optional: Verify a hash with the expected data
  static bool verifyHash(Map<String, dynamic> data, String givenHash) {
    final calculated = generateSignature(data);
    return calculated == givenHash;
  }
}
