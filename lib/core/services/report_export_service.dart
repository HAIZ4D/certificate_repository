import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

class ReportExportService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Logger _logger = Logger();

  static const String _reportsStoragePath = 'reports/exports';

  /// Export report as PDF
  Future<String> exportReportAsPDF({
    required Map<String, dynamic> reportData,
    required String reportTitle,
    String? description,
  }) async {
    try {
      _logger.i('Generating PDF report: $reportTitle');

      final pdf = pw.Document(
        title: reportTitle,
        author: 'UPM Digital Certificate System',
        subject: 'System Report',
        creator: 'Report Export Service',
      );

      // Add pages to PDF
      pdf.addPage(await _buildReportCoverPage(reportTitle, description, reportData));
      pdf.addPage(await _buildReportSummaryPage(reportData));
      
      // Add detailed pages for each section
      if (reportData['users'] != null) {
        pdf.addPage(await _buildUsersReportPage(reportData['users']));
      }
      
      if (reportData['certificates'] != null) {
        pdf.addPage(await _buildCertificatesReportPage(reportData['certificates']));
      }
      
      if (reportData['documents'] != null) {
        pdf.addPage(await _buildDocumentsReportPage(reportData['documents']));
      }
      
      if (reportData['activity'] != null) {
        pdf.addPage(await _buildActivityReportPage(reportData['activity']));
      }

      final pdfBytes = await pdf.save();
      
      // Upload to Firebase Storage
      final fileName = 'report_${_sanitizeFileName(reportTitle)}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final downloadUrl = await _uploadToStorage(pdfBytes, fileName, 'application/pdf');
      
      // Save locally for download
      if (!kIsWeb) {
        final localPath = await _saveToLocal(pdfBytes, fileName);
        _logger.i('PDF report saved locally: $localPath');
      }

      _logger.i('PDF report exported successfully: $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      _logger.e('Error exporting PDF report: $e');
      rethrow;
    }
  }

  /// Export report as Excel
  Future<String> exportReportAsExcel({
    required Map<String, dynamic> reportData,
    required String reportTitle,
  }) async {
    try {
      _logger.i('Generating Excel report: $reportTitle');

      final excel = Excel.createExcel();
      
      // Remove default sheet and create custom sheets
      excel.delete('Sheet1');
      
      // Summary sheet
      final summarySheet = excel['Summary'];
      _buildExcelSummarySheet(summarySheet, reportData, reportTitle);
      
      // Users sheet
      if (reportData['users'] != null) {
        final usersSheet = excel['Users'];
        _buildExcelUsersSheet(usersSheet, reportData['users']);
      }
      
      // Certificates sheet
      if (reportData['certificates'] != null) {
        final certificatesSheet = excel['Certificates'];
        _buildExcelCertificatesSheet(certificatesSheet, reportData['certificates']);
      }
      
      // Documents sheet
      if (reportData['documents'] != null) {
        final documentsSheet = excel['Documents'];
        _buildExcelDocumentsSheet(documentsSheet, reportData['documents']);
      }
      
      // Activity sheet
      if (reportData['activity'] != null) {
        final activitySheet = excel['Activity'];
        _buildExcelActivitySheet(activitySheet, reportData['activity']);
      }

      final excelBytes = excel.save()!;
      
      // Upload to Firebase Storage
      final fileName = 'report_${_sanitizeFileName(reportTitle)}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final downloadUrl = await _uploadToStorage(Uint8List.fromList(excelBytes), fileName, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      
      // Save locally for download
      if (!kIsWeb) {
        final localPath = await _saveToLocal(Uint8List.fromList(excelBytes), fileName);
        _logger.i('Excel report saved locally: $localPath');
      }

      _logger.i('Excel report exported successfully: $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      _logger.e('Error exporting Excel report: $e');
      rethrow;
    }
  }

  /// Export report as CSV
  Future<String> exportReportAsCSV({
    required Map<String, dynamic> reportData,
    required String reportTitle,
  }) async {
    try {
      _logger.i('Generating CSV report: $reportTitle');

      final csvData = <List<String>>[];
      
      // Add header
      csvData.add(['Report', reportTitle]);
      csvData.add(['Generated At', DateTime.now().toIso8601String()]);
      csvData.add([]);
      
      // Add summary data
      csvData.add(['SUMMARY']);
      csvData.add(['Metric', 'Value']);
      
      if (reportData['users'] != null) {
        final users = reportData['users'] as Map<String, dynamic>;
        csvData.add(['Total Users', users['totalUsers'].toString()]);
      }
      
      if (reportData['certificates'] != null) {
        final certificates = reportData['certificates'] as Map<String, dynamic>;
        csvData.add(['Total Certificates', certificates['totalCertificates'].toString()]);
        csvData.add(['Issued Certificates', certificates['issuedCount'].toString()]);
      }
      
      if (reportData['documents'] != null) {
        final documents = reportData['documents'] as Map<String, dynamic>;
        csvData.add(['Total Documents', documents['totalDocuments'].toString()]);
      }
      
      csvData.add([]);
      
      // Add detailed data sections
      if (reportData['users'] != null) {
        _addUsersDataToCSV(csvData, reportData['users']);
      }
      
      if (reportData['certificates'] != null) {
        _addCertificatesDataToCSV(csvData, reportData['certificates']);
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      final csvBytes = Uint8List.fromList(csvString.codeUnits);
      
      // Upload to Firebase Storage
      final fileName = 'report_${_sanitizeFileName(reportTitle)}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final downloadUrl = await _uploadToStorage(csvBytes, fileName, 'text/csv');
      
      // Save locally for download
      if (!kIsWeb) {
        final localPath = await _saveToLocal(csvBytes, fileName);
        _logger.i('CSV report saved locally: $localPath');
      }

      _logger.i('CSV report exported successfully: $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      _logger.e('Error exporting CSV report: $e');
      rethrow;
    }
  }

  /// Build PDF cover page
  Future<pw.Page> _buildReportCoverPage(
    String title, 
    String? description, 
    Map<String, dynamic> reportData
  ) async {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Spacer(),
            
            // Title
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1976D2'),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            
            pw.SizedBox(height: 30),
            
            // Description
            if (description != null) ...[
              pw.Text(
                description,
                style: pw.TextStyle(
                  fontSize: 16,
                  color: PdfColor.fromHex('#666666'),
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 30),
            ],
            
            // Report info
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('#CCCCCC')),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'UNIVERSITI PUTRA MALAYSIA',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1976D2'),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Digital Certificate System Report',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColor.fromHex('#666666'),
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Generated on: ${DateFormat('MMMM dd, yyyy at HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColor.fromHex('#666666'),
                    ),
                  ),
                ],
              ),
            ),
            
            pw.Spacer(),
            
            // Footer
            pw.Text(
              'Confidential - For Internal Use Only',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColor.fromHex('#999999'),
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build PDF summary page
  Future<pw.Page> _buildReportSummaryPage(Map<String, dynamic> reportData) async {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Text(
              'EXECUTIVE SUMMARY',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1976D2'),
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Summary cards
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildSummaryCard(
                    'Users',
                    reportData['users']?['totalUsers']?.toString() ?? '0',
                    PdfColor.fromHex('#4CAF50'),
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: _buildSummaryCard(
                    'Certificates',
                    reportData['certificates']?['totalCertificates']?.toString() ?? '0',
                    PdfColor.fromHex('#2196F3'),
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 20),
            
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildSummaryCard(
                    'Documents',
                    reportData['documents']?['totalDocuments']?.toString() ?? '0',
                    PdfColor.fromHex('#FF9800'),
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: _buildSummaryCard(
                    'Activities',
                    reportData['activity']?['totalActivities']?.toString() ?? '0',
                    PdfColor.fromHex('#9C27B0'),
                  ),
                ),
              ],
            ),
            
            pw.SizedBox(height: 30),
            
            // Key insights
            pw.Text(
              'KEY INSIGHTS',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1976D2'),
              ),
            ),
            
            pw.SizedBox(height: 15),
            
            _buildInsightsList(reportData),
          ],
        );
      },
    );
  }

  /// Build summary card for PDF
  pw.Widget _buildSummaryCard(String title, String value, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#E3F2FD'),
        border: pw.Border.all(color: color),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Build insights list for PDF
  pw.Widget _buildInsightsList(Map<String, dynamic> reportData) {
    final insights = <String>[];
    
    if (reportData['certificates'] != null) {
      final certs = reportData['certificates'] as Map<String, dynamic>;
      final issuedCount = certs['issuedCount'] ?? 0;
      final totalCount = certs['totalCertificates'] ?? 0;
      if (totalCount > 0) {
        final percentage = ((issuedCount / totalCount) * 100).round();
        insights.add('$percentage% of certificates have been issued');
      }
    }
    
    if (reportData['activity'] != null) {
      final activity = reportData['activity'] as Map<String, dynamic>;
      final averagePerDay = activity['averageActivitiesPerDay'] ?? 0;
      insights.add('Average $averagePerDay activities per day');
    }
    
    if (reportData['users'] != null) {
      final users = reportData['users'] as Map<String, dynamic>;
      final roleDistribution = users['roleDistribution'] as Map<String, dynamic>? ?? {};
      final caCount = roleDistribution['certificateAuthority'] ?? 0;
      insights.add('$caCount Certificate Authorities registered');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: insights.map((insight) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('• ', style: pw.TextStyle(
              fontSize: 14,
              color: PdfColor.fromHex('#1976D2'),
            )),
            pw.Expanded(
              child: pw.Text(
                insight,
                style: pw.TextStyle(
                  fontSize: 14,
                  color: PdfColor.fromHex('#333333'),
                ),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  /// Build users report page
  Future<pw.Page> _buildUsersReportPage(Map<String, dynamic> usersData) async {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'USER STATISTICS',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1976D2'),
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Role distribution table
            pw.Text(
              'Role Distribution',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            
            pw.SizedBox(height: 10),
            
            _buildDataTable(
              ['Role', 'Count'],
              (usersData['roleDistribution'] as Map<String, dynamic>? ?? {})
                  .entries
                  .map((e) => [e.key, e.value.toString()])
                  .toList(),
            ),
          ],
        );
      },
    );
  }

  /// Build certificates report page
  Future<pw.Page> _buildCertificatesReportPage(Map<String, dynamic> certificatesData) async {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'CERTIFICATE STATISTICS',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1976D2'),
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Status distribution
            pw.Text(
              'Status Distribution',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            
            pw.SizedBox(height: 10),
            
            _buildDataTable(
              ['Status', 'Count'],
              (certificatesData['statusDistribution'] as Map<String, dynamic>? ?? {})
                  .entries
                  .map((e) => [e.key, e.value.toString()])
                  .toList(),
            ),
          ],
        );
      },
    );
  }

  /// Build documents report page
  Future<pw.Page> _buildDocumentsReportPage(Map<String, dynamic> documentsData) async {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'DOCUMENT STATISTICS',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1976D2'),
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Document stats
            _buildDataTable(
              ['Metric', 'Value'],
              [
                ['Total Documents', documentsData['totalDocuments'].toString()],
                ['Pending Review', documentsData['pendingCount'].toString()],
                ['Approved', documentsData['approvedCount'].toString()],
                ['Rejected', documentsData['rejectedCount'].toString()],
              ],
            ),
          ],
        );
      },
    );
  }

  /// Build activity report page
  Future<pw.Page> _buildActivityReportPage(Map<String, dynamic> activityData) async {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'ACTIVITY STATISTICS',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1976D2'),
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Activity distribution
            pw.Text(
              'Action Distribution',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            
            pw.SizedBox(height: 10),
            
            _buildDataTable(
              ['Action', 'Count'],
              (activityData['actionDistribution'] as Map<String, dynamic>? ?? {})
                  .entries
                  .map((e) => [e.key, e.value.toString()])
                  .toList(),
            ),
          ],
        );
      },
    );
  }

  /// Build data table for PDF
  pw.Widget _buildDataTable(List<String> headers, List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromHex('#CCCCCC')),
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F5F5F5'),
          ),
          children: headers.map((header) => pw.Container(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              header,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
              ),
            ),
          )).toList(),
        ),
        // Data rows
        ...rows.map((row) => pw.TableRow(
          children: row.map((cell) => pw.Container(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              cell,
              style: const pw.TextStyle(fontSize: 11),
            ),
          )).toList(),
        )),
      ],
    );
  }

  /// Build Excel summary sheet
  void _buildExcelSummarySheet(Sheet sheet, Map<String, dynamic> reportData, String title) {
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(title);
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue('Generated: ${DateTime.now()}');
    
    int row = 4;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('Summary');
    row++;
    
    if (reportData['users'] != null) {
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('Total Users');
      sheet.cell(CellIndex.indexByString('B$row')).value = reportData['users']['totalUsers'];
      row++;
    }
    
    if (reportData['certificates'] != null) {
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('Total Certificates');
      sheet.cell(CellIndex.indexByString('B$row')).value = reportData['certificates']['totalCertificates'];
      row++;
    }
  }

  /// Build Excel users sheet
  void _buildExcelUsersSheet(Sheet sheet, Map<String, dynamic> usersData) {
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Role');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Count');
    
    int row = 2;
    final roleDistribution = usersData['roleDistribution'] as Map<String, dynamic>? ?? {};
    for (final entry in roleDistribution.entries) {
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(entry.key);
      sheet.cell(CellIndex.indexByString('B$row')).value = IntCellValue(entry.value);
      row++;
    }
  }

  /// Build Excel certificates sheet
  void _buildExcelCertificatesSheet(Sheet sheet, Map<String, dynamic> certificatesData) {
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Status');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Count');
    
    int row = 2;
    final statusDistribution = certificatesData['statusDistribution'] as Map<String, dynamic>? ?? {};
    for (final entry in statusDistribution.entries) {
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(entry.key);
      sheet.cell(CellIndex.indexByString('B$row')).value = IntCellValue(entry.value);
      row++;
    }
  }

  /// Build Excel documents sheet
  void _buildExcelDocumentsSheet(Sheet sheet, Map<String, dynamic> documentsData) {
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Metric');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Value');
    
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue('Total Documents');
    sheet.cell(CellIndex.indexByString('B2')).value = IntCellValue(documentsData['totalDocuments'] ?? 0);
    
    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('Pending Count');
    sheet.cell(CellIndex.indexByString('B3')).value = IntCellValue(documentsData['pendingCount'] ?? 0);
  }

  /// Build Excel activity sheet
  void _buildExcelActivitySheet(Sheet sheet, Map<String, dynamic> activityData) {
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Action');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Count');
    
    int row = 2;
    final actionDistribution = activityData['actionDistribution'] as Map<String, dynamic>? ?? {};
    for (final entry in actionDistribution.entries) {
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(entry.key);
      sheet.cell(CellIndex.indexByString('B$row')).value = IntCellValue(entry.value);
      row++;
    }
  }

  /// Add users data to CSV
  void _addUsersDataToCSV(List<List<String>> csvData, Map<String, dynamic> usersData) {
    csvData.add(['USERS DETAIL']);
    csvData.add(['Role', 'Count']);
    
    final roleDistribution = usersData['roleDistribution'] as Map<String, dynamic>? ?? {};
    for (final entry in roleDistribution.entries) {
      csvData.add([entry.key, entry.value.toString()]);
    }
    csvData.add([]);
  }

  /// Add certificates data to CSV
  void _addCertificatesDataToCSV(List<List<String>> csvData, Map<String, dynamic> certificatesData) {
    csvData.add(['CERTIFICATES DETAIL']);
    csvData.add(['Status', 'Count']);
    
    final statusDistribution = certificatesData['statusDistribution'] as Map<String, dynamic>? ?? {};
    for (final entry in statusDistribution.entries) {
      csvData.add([entry.key, entry.value.toString()]);
    }
    csvData.add([]);
  }

  /// Upload file to Firebase Storage
  Future<String> _uploadToStorage(Uint8List bytes, String fileName, String contentType) async {
    try {
      final storageRef = _storage.ref().child('$_reportsStoragePath/$fileName');
      
      final uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'generatedAt': DateTime.now().toIso8601String(),
            'fileSize': bytes.length.toString(),
            'reportType': 'system_report',
          },
        ),
      );

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      _logger.e('Error uploading to storage: $e');
      rethrow;
    }
  }

  /// Save file locally
  Future<String> _saveToLocal(Uint8List bytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      _logger.e('Error saving file locally: $e');
      rethrow;
    }
  }

  /// Share exported file
  Future<void> shareExportedFile(String filePath, String fileName) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Report: $fileName',
        );
      } else {
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    } catch (e) {
      _logger.e('Error sharing file: $e');
      rethrow;
    }
  }

  /// Sanitize filename for safe storage
  String _sanitizeFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'[^\w\-_\.]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase();
  }

  /// Get report export history
  Future<List<Map<String, dynamic>>> getExportHistory({int limit = 20}) async {
    try {
      final listResult = await _storage.ref().child(_reportsStoragePath).list(
        ListOptions(maxResults: limit),
      );
      
      final exports = <Map<String, dynamic>>[];
      
      for (final item in listResult.items) {
        try {
          final metadata = await item.getMetadata();
          final downloadUrl = await item.getDownloadURL();
          
          exports.add({
            'fileName': item.name,
            'downloadUrl': downloadUrl,
            'generatedAt': metadata.customMetadata?['generatedAt'],
            'fileSize': metadata.size,
            'contentType': metadata.contentType,
          });
        } catch (e) {
          _logger.w('Error getting metadata for ${item.name}: $e');
        }
      }
      
      // Sort by generation time (newest first)
      exports.sort((a, b) {
        final aTime = DateTime.tryParse(a['generatedAt'] ?? '') ?? DateTime(1970);
        final bTime = DateTime.tryParse(b['generatedAt'] ?? '') ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      
      return exports;
    } catch (e) {
      _logger.e('Error getting export history: $e');
      return [];
    }
  }

  /// Delete exported report
  Future<void> deleteExportedReport(String fileName) async {
    try {
      await _storage.ref().child('$_reportsStoragePath/$fileName').delete();
      _logger.i('Exported report deleted: $fileName');
    } catch (e) {
      _logger.e('Error deleting exported report: $e');
      rethrow;
    }
  }

  /// Export CSV data
  Future<Map<String, dynamic>> exportCSV({
    required List<List<String>> data,
    required String filename,
    required List<String> headers,
  }) async {
    try {
      // Create CSV content
      final csvContent = const ListToCsvConverter().convert([headers, ...data]);
      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      
      // Upload to storage
      final downloadUrl = await _uploadToStorage(bytes, filename, 'text/csv');
      
      return {
        'success': true,
        'filename': filename,
        'size': '${data.length} records',
        'downloadUrl': downloadUrl,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Save text file
  Future<Map<String, dynamic>> saveTextFile({
    required String content,
    required String filename,
  }) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(content));
      final downloadUrl = await _uploadToStorage(bytes, filename, 'text/plain');
      
      return {
        'success': true,
        'filename': filename,
        'size': '${content.length} characters',
        'path': downloadUrl,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
} 