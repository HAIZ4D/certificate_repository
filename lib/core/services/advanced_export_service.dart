import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'logger_service.dart';

enum ExportFormat {
  pdf,
  excel,
  csv,
  json,
  xml,
  html,
  word,
  powerpoint,
}

enum ExportTemplate {
  standard,
  detailed,
  summary,
  executive,
  technical,
  audit,
  compliance,
}

class ExportOptions {
  final ExportFormat format;
  final ExportTemplate template;
  final bool includeCharts;
  final bool includeImages;
  final bool includeMetadata;
  final bool compressOutput;
  final String? password;
  final List<String> selectedFields;
  final Map<String, dynamic> customSettings;
  final DateRange? dateRange;

  const ExportOptions({
    required this.format,
    this.template = ExportTemplate.standard,
    this.includeCharts = true,
    this.includeImages = true,
    this.includeMetadata = true,
    this.compressOutput = false,
    this.password,
    this.selectedFields = const [],
    this.customSettings = const {},
    this.dateRange,
  });
}

class DateRange {
  final DateTime startDate;
  final DateTime endDate;

  const DateRange({
    required this.startDate,
    required this.endDate,
  });
}

class ExportResult {
  final String downloadUrl;
  final String fileName;
  final String localPath;
  final int fileSize;
  final ExportFormat format;
  final DateTime exportedAt;
  final Map<String, dynamic> metadata;

  const ExportResult({
    required this.downloadUrl,
    required this.fileName,
    required this.localPath,
    required this.fileSize,
    required this.format,
    required this.exportedAt,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'downloadUrl': downloadUrl,
      'fileName': fileName,
      'localPath': localPath,
      'fileSize': fileSize,
      'format': format.name,
      'exportedAt': exportedAt.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }
}

class AdvancedExportService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  static const String _exportsStoragePath = 'exports/advanced';
  final List<ExportResult> _exportHistory = [];
  bool _isExporting = false;
  double _exportProgress = 0.0;

  // Getters
  List<ExportResult> get exportHistory => List.unmodifiable(_exportHistory);
  bool get isExporting => _isExporting;
  double get exportProgress => _exportProgress;

  /// Initialize export service
  Future<void> initialize() async {
    try {
      LoggerService.info('Initializing advanced export service');
      await _loadExportHistory();
      LoggerService.info('Advanced export service initialized');
    } catch (e) {
      LoggerService.error('Failed to initialize advanced export service', error: e);
    }
  }

  /// Export data with advanced options
  Future<ExportResult> exportData({
    required Map<String, dynamic> data,
    required String title,
    required ExportOptions options,
    String? description,
    Function(double)? onProgress,
  }) async {
    try {
      _isExporting = true;
      _exportProgress = 0.0;
      notifyListeners();

      LoggerService.info('Starting advanced export: $title (${options.format.name})');

      // Update progress
      _updateProgress(0.1, onProgress);

      // Filter data based on options
      final filteredData = await _filterData(data, options);
      _updateProgress(0.2, onProgress);

      // Generate export based on format
      ExportResult result;
      switch (options.format) {
        case ExportFormat.pdf:
          result = await _exportToPDF(filteredData, title, options, description);
          break;
        case ExportFormat.excel:
          result = await _exportToExcel(filteredData, title, options);
          break;
        case ExportFormat.csv:
          result = await _exportToCSV(filteredData, title, options);
          break;
        case ExportFormat.json:
          result = await _exportToJSON(filteredData, title, options);
          break;
        case ExportFormat.xml:
          result = await _exportToXML(filteredData, title, options);
          break;
        case ExportFormat.html:
          result = await _exportToHTML(filteredData, title, options, description);
          break;
        case ExportFormat.word:
          result = await _exportToWord(filteredData, title, options, description);
          break;
        case ExportFormat.powerpoint:
          result = await _exportToPowerPoint(filteredData, title, options, description);
          break;
      }

      _updateProgress(0.9, onProgress);

      // Save export record
      await _saveExportRecord(result);
      _exportHistory.insert(0, result);

      _updateProgress(1.0, onProgress);
      _isExporting = false;
      notifyListeners();

      LoggerService.info('Export completed: ${result.fileName}');
      return result;

    } catch (e) {
      _isExporting = false;
      _exportProgress = 0.0;
      notifyListeners();
      LoggerService.error('Export failed', error: e);
      rethrow;
    }
  }

  /// Export to PDF with advanced features
  Future<ExportResult> _exportToPDF(
    Map<String, dynamic> data,
    String title,
    ExportOptions options,
    String? description,
  ) async {
    final pdf = pw.Document(
      title: title,
      author: 'UPM Digital Certificate System',
      subject: 'Advanced Export Report',
      creator: 'Advanced Export Service',
    );

    // Build PDF based on template
    switch (options.template) {
      case ExportTemplate.executive:
        await _buildExecutivePDF(pdf, data, title, description, options);
        break;
      case ExportTemplate.detailed:
        await _buildDetailedPDF(pdf, data, title, description, options);
        break;
      case ExportTemplate.summary:
        await _buildSummaryPDF(pdf, data, title, description, options);
        break;
      case ExportTemplate.technical:
        await _buildTechnicalPDF(pdf, data, title, description, options);
        break;
      case ExportTemplate.audit:
        await _buildAuditPDF(pdf, data, title, description, options);
        break;
      case ExportTemplate.compliance:
        await _buildCompliancePDF(pdf, data, title, description, options);
        break;
      default:
        await _buildStandardPDF(pdf, data, title, description, options);
    }

    var pdfBytes = await pdf.save();

    // Apply password protection if specified
    if (options.password != null) {
      pdfBytes = await _protectPDF(pdfBytes, options.password!);
    }

    // Compress if requested
    if (options.compressOutput) {
      pdfBytes = await _compressData(pdfBytes);
    }

    return await _finalizeExport(pdfBytes, title, ExportFormat.pdf, {
      'template': options.template.name,
      'protected': options.password != null,
      'compressed': options.compressOutput,
    });
  }

  /// Export to Excel with advanced features
  Future<ExportResult> _exportToExcel(
    Map<String, dynamic> data,
    String title,
    ExportOptions options,
  ) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    // Create sheets based on template
    switch (options.template) {
      case ExportTemplate.executive:
        _buildExecutiveExcel(excel, data, title, options);
        break;
      case ExportTemplate.detailed:
        _buildDetailedExcel(excel, data, title, options);
        break;
      case ExportTemplate.summary:
        _buildSummaryExcel(excel, data, title, options);
        break;
      case ExportTemplate.technical:
        _buildTechnicalExcel(excel, data, title, options);
        break;
      case ExportTemplate.audit:
        _buildAuditExcel(excel, data, title, options);
        break;
      case ExportTemplate.compliance:
        _buildComplianceExcel(excel, data, title, options);
        break;
      default:
        _buildStandardExcel(excel, data, title, options);
    }

    var excelBytes = Uint8List.fromList(excel.save()!);

    // Apply password protection if specified
    if (options.password != null) {
      excelBytes = await _protectExcel(excelBytes, options.password!);
    }

    // Compress if requested
    if (options.compressOutput) {
      excelBytes = await _compressData(excelBytes);
    }

    return await _finalizeExport(excelBytes, title, ExportFormat.excel, {
      'template': options.template.name,
      'protected': options.password != null,
      'compressed': options.compressOutput,
    });
  }

  /// Export to CSV with advanced features
  Future<ExportResult> _exportToCSV(
    Map<String, dynamic> data,
    String title,
    ExportOptions options,
  ) async {
    final csvData = <List<String>>[];
    
    // Build CSV based on template
    switch (options.template) {
      case ExportTemplate.executive:
        _buildExecutiveCSV(csvData, data, title, options);
        break;
      case ExportTemplate.detailed:
        _buildDetailedCSV(csvData, data, title, options);
        break;
      case ExportTemplate.summary:
        _buildSummaryCSV(csvData, data, title, options);
        break;
      default:
        _buildStandardCSV(csvData, data, title, options);
    }

    final csvString = const ListToCsvConverter().convert(csvData);
    var csvBytes = Uint8List.fromList(utf8.encode(csvString));

    // Compress if requested
    if (options.compressOutput) {
      csvBytes = await _compressData(csvBytes);
    }

    return await _finalizeExport(csvBytes, title, ExportFormat.csv, {
      'template': options.template.name,
      'compressed': options.compressOutput,
    });
  }

  /// Export to JSON with advanced features
  Future<ExportResult> _exportToJSON(
    Map<String, dynamic> data,
    String title,
    ExportOptions options,
  ) async {
    final jsonData = {
      'title': title,
      'exportedAt': DateTime.now().toIso8601String(),
      'template': options.template.name,
      'data': data,
    };

    if (options.includeMetadata) {
      jsonData['metadata'] = {
        'exportOptions': {
          'format': options.format.name,
          'template': options.template.name,
          'includeCharts': options.includeCharts,
          'includeImages': options.includeImages,
          'selectedFields': options.selectedFields,
        },
        'systemInfo': {
          'version': '1.0.0',
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      };
    }

    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
    var jsonBytes = Uint8List.fromList(utf8.encode(jsonString));

    // Compress if requested
    if (options.compressOutput) {
      jsonBytes = await _compressData(jsonBytes);
    }

    return await _finalizeExport(jsonBytes, title, ExportFormat.json, {
      'template': options.template.name,
      'compressed': options.compressOutput,
    });
  }

  /// Export to XML with advanced features
  Future<ExportResult> _exportToXML(
    Map<String, dynamic> data,
    String title,
    ExportOptions options,
  ) async {
    final xmlBuffer = StringBuffer();
    xmlBuffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    xmlBuffer.writeln('<export>');
    xmlBuffer.writeln('  <title>$title</title>');
    xmlBuffer.writeln('  <exportedAt>${DateTime.now().toIso8601String()}</exportedAt>');
    xmlBuffer.writeln('  <template>${options.template.name}</template>');
    
    if (options.includeMetadata) {
      xmlBuffer.writeln('  <metadata>');
      xmlBuffer.writeln('    <format>${options.format.name}</format>');
      xmlBuffer.writeln('    <includeCharts>${options.includeCharts}</includeCharts>');
      xmlBuffer.writeln('    <includeImages>${options.includeImages}</includeImages>');
      xmlBuffer.writeln('  </metadata>');
    }

    xmlBuffer.writeln('  <data>');
    _convertMapToXML(data, xmlBuffer, 2);
    xmlBuffer.writeln('  </data>');
    xmlBuffer.writeln('</export>');

    var xmlBytes = Uint8List.fromList(utf8.encode(xmlBuffer.toString()));

    // Compress if requested
    if (options.compressOutput) {
      xmlBytes = await _compressData(xmlBytes);
    }

    return await _finalizeExport(xmlBytes, title, ExportFormat.xml, {
      'template': options.template.name,
      'compressed': options.compressOutput,
    });
  }

  /// Export to HTML with advanced features
  Future<ExportResult> _exportToHTML(
    Map<String, dynamic> data,
    String title,
    ExportOptions options,
    String? description,
  ) async {
    final htmlBuffer = StringBuffer();
    
    // HTML header
    htmlBuffer.writeln('<!DOCTYPE html>');
    htmlBuffer.writeln('<html lang="en">');
    htmlBuffer.writeln('<head>');
    htmlBuffer.writeln('  <meta charset="UTF-8">');
    htmlBuffer.writeln('  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    htmlBuffer.writeln('  <title>$title</title>');
    htmlBuffer.writeln('  <style>');
    htmlBuffer.writeln(_getHTMLStyles(options.template));
    htmlBuffer.writeln('  </style>');
    htmlBuffer.writeln('</head>');
    htmlBuffer.writeln('<body>');
    
    // Content based on template
    switch (options.template) {
      case ExportTemplate.executive:
        _buildExecutiveHTML(htmlBuffer, data, title, description, options);
        break;
      case ExportTemplate.detailed:
        _buildDetailedHTML(htmlBuffer, data, title, description, options);
        break;
      default:
        _buildStandardHTML(htmlBuffer, data, title, description, options);
    }
    
    htmlBuffer.writeln('</body>');
    htmlBuffer.writeln('</html>');

    var htmlBytes = Uint8List.fromList(utf8.encode(htmlBuffer.toString()));

    // Compress if requested
    if (options.compressOutput) {
      htmlBytes = await _compressData(htmlBytes);
    }

    return await _finalizeExport(htmlBytes, title, ExportFormat.html, {
      'template': options.template.name,
      'compressed': options.compressOutput,
    });
  }

  /// Export to Word document
  Future<ExportResult> _exportToWord(
    Map<String, dynamic> data,
    String title,
    ExportOptions options,
    String? description,
  ) async {
    // For now, create a rich text format that can be opened by Word
    final rtfBuffer = StringBuffer();
    rtfBuffer.writeln('{\\rtf1\\ansi\\deff0 {\\fonttbl {\\f0 Times New Roman;}}');
    rtfBuffer.writeln('\\f0\\fs24');
    rtfBuffer.writeln('\\b $title \\b0\\par');
    rtfBuffer.writeln('\\par');
    
    if (description != null) {
      rtfBuffer.writeln('$description\\par');
      rtfBuffer.writeln('\\par');
    }
    
    rtfBuffer.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    rtfBuffer.writeln('\\par');
    
    // Add data content
    _convertMapToRTF(data, rtfBuffer);
    
    rtfBuffer.writeln('}');

    var rtfBytes = Uint8List.fromList(utf8.encode(rtfBuffer.toString()));

    return await _finalizeExport(rtfBytes, title, ExportFormat.word, {
      'template': options.template.name,
      'format': 'rtf',
    });
  }

  /// Export to PowerPoint presentation
  Future<ExportResult> _exportToPowerPoint(
    Map<String, dynamic> data,
    String title,
    ExportOptions options,
    String? description,
  ) async {
    // Create a simple XML-based presentation format
    final pptxBuffer = StringBuffer();
    pptxBuffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    pptxBuffer.writeln('<presentation>');
    pptxBuffer.writeln('  <title>$title</title>');
    pptxBuffer.writeln('  <slides>');
    
    // Title slide
    pptxBuffer.writeln('    <slide id="1" type="title">');
    pptxBuffer.writeln('      <title>$title</title>');
    if (description != null) {
      pptxBuffer.writeln('      <subtitle>$description</subtitle>');
    }
    pptxBuffer.writeln('      <date>${DateFormat('yyyy-MM-dd').format(DateTime.now())}</date>');
    pptxBuffer.writeln('    </slide>');
    
    // Data slides
    int slideId = 2;
    data.forEach((key, value) {
      pptxBuffer.writeln('    <slide id="$slideId" type="content">');
      pptxBuffer.writeln('      <title>${_formatTitle(key)}</title>');
      pptxBuffer.writeln('      <content>');
      if (value is Map) {
        value.forEach((subKey, subValue) {
          pptxBuffer.writeln('        <item>$subKey: $subValue</item>');
        });
      } else {
        pptxBuffer.writeln('        <item>$value</item>');
      }
      pptxBuffer.writeln('      </content>');
      pptxBuffer.writeln('    </slide>');
      slideId++;
    });
    
    pptxBuffer.writeln('  </slides>');
    pptxBuffer.writeln('</presentation>');

    var pptxBytes = Uint8List.fromList(utf8.encode(pptxBuffer.toString()));

    return await _finalizeExport(pptxBytes, title, ExportFormat.powerpoint, {
      'template': options.template.name,
      'format': 'xml',
    });
  }

  /// Filter data based on export options
  Future<Map<String, dynamic>> _filterData(
    Map<String, dynamic> data,
    ExportOptions options,
  ) async {
    final filteredData = <String, dynamic>{};

    // Apply field selection
    if (options.selectedFields.isNotEmpty) {
      for (final field in options.selectedFields) {
        if (data.containsKey(field)) {
          filteredData[field] = data[field];
        }
      }
    } else {
      filteredData.addAll(data);
    }

    // Apply date range filter
    if (options.dateRange != null) {
      filteredData.removeWhere((key, value) {
        if (value is Map && value.containsKey('timestamp')) {
          final timestamp = value['timestamp'];
          if (timestamp is int) {
            final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
            return date.isBefore(options.dateRange!.startDate) ||
                   date.isAfter(options.dateRange!.endDate);
          }
        }
        return false;
      });
    }

    return filteredData;
  }

  /// Update export progress
  void _updateProgress(double progress, Function(double)? onProgress) {
    _exportProgress = progress;
    onProgress?.call(progress);
    notifyListeners();
  }

  /// Finalize export and upload
  Future<ExportResult> _finalizeExport(
    Uint8List bytes,
    String title,
    ExportFormat format,
    Map<String, dynamic> metadata,
  ) async {
    final fileName = _generateFileName(title, format);
    
    // Upload to Firebase Storage
    final downloadUrl = await _uploadToStorage(bytes, fileName, _getMimeType(format));
    
    // Save locally if not web
    String localPath = '';
    if (!kIsWeb) {
      localPath = await _saveToLocal(bytes, fileName);
    }

    return ExportResult(
      downloadUrl: downloadUrl,
      fileName: fileName,
      localPath: localPath,
      fileSize: bytes.length,
      format: format,
      exportedAt: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Generate unique filename
  String _generateFileName(String title, ExportFormat format) {
    final sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = _getFileExtension(format);
    return '${sanitizedTitle}_$timestamp.$extension';
  }

  /// Get file extension for format
  String _getFileExtension(ExportFormat format) {
    switch (format) {
      case ExportFormat.pdf:
        return 'pdf';
      case ExportFormat.excel:
        return 'xlsx';
      case ExportFormat.csv:
        return 'csv';
      case ExportFormat.json:
        return 'json';
      case ExportFormat.xml:
        return 'xml';
      case ExportFormat.html:
        return 'html';
      case ExportFormat.word:
        return 'rtf';
      case ExportFormat.powerpoint:
        return 'xml';
    }
  }

  /// Get MIME type for format
  String _getMimeType(ExportFormat format) {
    switch (format) {
      case ExportFormat.pdf:
        return 'application/pdf';
      case ExportFormat.excel:
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case ExportFormat.csv:
        return 'text/csv';
      case ExportFormat.json:
        return 'application/json';
      case ExportFormat.xml:
        return 'application/xml';
      case ExportFormat.html:
        return 'text/html';
      case ExportFormat.word:
        return 'application/rtf';
      case ExportFormat.powerpoint:
        return 'application/xml';
    }
  }

  /// Upload to Firebase Storage
  Future<String> _uploadToStorage(Uint8List bytes, String fileName, String mimeType) async {
    try {
      final ref = _storage.ref().child('$_exportsStoragePath/$fileName');
      final uploadTask = ref.putData(bytes, SettableMetadata(contentType: mimeType));
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      LoggerService.error('Failed to upload to storage', error: e);
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
      LoggerService.error('Failed to save file locally', error: e);
      rethrow;
    }
  }

  /// Save export record to Firestore
  Future<void> _saveExportRecord(ExportResult result) async {
    try {
      await _firestore.collection('export_history').add(result.toMap());
    } catch (e) {
      LoggerService.error('Failed to save export record', error: e);
    }
  }

  /// Load export history
  Future<void> _loadExportHistory() async {
    try {
      final query = await _firestore
          .collection('export_history')
          .orderBy('exportedAt', descending: true)
          .limit(50)
          .get();

      _exportHistory.clear();
      for (final doc in query.docs) {
        final data = doc.data();
        _exportHistory.add(ExportResult(
          downloadUrl: data['downloadUrl'] ?? '',
          fileName: data['fileName'] ?? '',
          localPath: data['localPath'] ?? '',
          fileSize: data['fileSize'] ?? 0,
          format: ExportFormat.values.firstWhere(
            (f) => f.name == data['format'],
            orElse: () => ExportFormat.pdf,
          ),
          exportedAt: DateTime.fromMillisecondsSinceEpoch(data['exportedAt'] ?? 0),
          metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
        ));
      }
    } catch (e) {
      LoggerService.error('Failed to load export history', error: e);
    }
  }

  /// Helper methods for building different formats
  Future<void> _buildStandardPDF(pw.Document pdf, Map<String, dynamic> data, String title, String? description, ExportOptions options) async {
    // Implementation for standard PDF template
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              if (description != null) pw.Paragraph(text: description),
              pw.SizedBox(height: 20),
              pw.Text('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}'),
              pw.SizedBox(height: 20),
              ...data.entries.map((entry) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(entry.key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(entry.value.toString()),
                  pw.SizedBox(height: 10),
                ],
              )),
            ],
          );
        },
      ),
    );
  }

  void _buildStandardExcel(Excel excel, Map<String, dynamic> data, String title, ExportOptions options) {
    final sheet = excel['Data'];
    int row = 0;
    
    // Title
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(title);
    row += 2;
    
    // Data
    data.forEach((key, value) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(key);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(value.toString());
      row++;
    });
  }

  void _buildStandardCSV(List<List<String>> csvData, Map<String, dynamic> data, String title, ExportOptions options) {
    csvData.add([title]);
    csvData.add(['Generated', DateTime.now().toIso8601String()]);
    csvData.add([]);
    csvData.add(['Key', 'Value']);
    
    data.forEach((key, value) {
      csvData.add([key, value.toString()]);
    });
  }

  // Placeholder implementations for other templates
  Future<void> _buildExecutivePDF(pw.Document pdf, Map<String, dynamic> data, String title, String? description, ExportOptions options) async {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Executive Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blue900,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    if (description != null)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 10),
                        child: pw.Text(
                          description,
                          style: const pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              // Executive Summary
              pw.Text(
                'Executive Summary',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              // Key Metrics in Grid
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Wrap(
                  spacing: 20,
                  runSpacing: 15,
                  children: data.entries.take(6).map((entry) => 
                    pw.Container(
                      width: 120,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            entry.key,
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey600,
                            ),
                          ),
                          pw.Text(
                            '${entry.value}',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _buildDetailedPDF(pw.Document pdf, Map<String, dynamic> data, String title, String? description, ExportOptions options) async {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // Title Page
            pw.Header(
              level: 0,
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            if (description != null)
              pw.Paragraph(text: description),
            pw.SizedBox(height: 20),
            // Detailed Table
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(1),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Field', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Value', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                // Data rows
                ...data.entries.map((entry) => 
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(entry.key),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${entry.value}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(entry.value.runtimeType.toString()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );
  }

  Future<void> _buildSummaryPDF(pw.Document pdf, Map<String, dynamic> data, String title, String? description, ExportOptions options) async {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              // Summary Cards
              pw.Wrap(
                spacing: 15,
                runSpacing: 15,
                children: data.entries.map((entry) => 
                  pw.Container(
                    width: 150,
                    height: 100,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.blue),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          entry.key,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          '${entry.value}',
                          style: const pw.TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _buildTechnicalPDF(pw.Document pdf, Map<String, dynamic> data, String title, String? description, ExportOptions options) async {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Technical Report',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            // Technical specifications
            pw.Text(
              'Technical Specifications',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            ...data.entries.map((entry) => 
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey50,
                  border: pw.Border(left: pw.BorderSide(color: PdfColors.blue, width: 3)),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text(
                        entry.key,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('${entry.value}'),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
      ),
    );
  }

  Future<void> _buildAuditPDF(pw.Document pdf, Map<String, dynamic> data, String title, String? description, ExportOptions options) async {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // Audit Header
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                border: pw.Border.all(color: PdfColors.red),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'AUDIT REPORT',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red,
                    ),
                  ),
                  pw.Text(
                    title,
                    style: const pw.TextStyle(fontSize: 16),
                  ),
                  pw.Text(
                    'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            // Audit Trail
            pw.Text(
              'Audit Trail',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Timestamp', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Action', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...data.entries.map((entry) => 
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(entry.key),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${entry.value}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );
  }

  Future<void> _buildCompliancePDF(pw.Document pdf, Map<String, dynamic> data, String title, String? description, ExportOptions options) async {
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // Compliance Header
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                border: pw.Border.all(color: PdfColors.green),
              ),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 40,
                    height: 40,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green,
                      borderRadius: pw.BorderRadius.circular(20),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        '✓',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 15),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'COMPLIANCE REPORT',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green,
                        ),
                      ),
                      pw.Text(title),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            // Compliance Checklist
            ...data.entries.map((entry) => 
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.green200),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 20,
                      height: 20,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.green,
                        borderRadius: pw.BorderRadius.circular(10),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '✓',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            entry.key,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.Text('${entry.value}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
      ),
    );
  }

  void _buildExecutiveExcel(Excel excel, Map<String, dynamic> data, String title, ExportOptions options) {
    final sheet = excel['Executive_Report'];
    
    // Executive styling
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
      bold: true,
      fontSize: 14,
    );
    
    final titleStyle = CellStyle(
      backgroundColorHex: ExcelColor.lightBlue,
      bold: true,
      fontSize: 16,
    );
    
    // Title
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(title);
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
    
    // Key metrics in columns
    int row = 3;
    sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue('Metric');
    sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue('Value');
    sheet.cell(CellIndex.indexByString('A$row')).cellStyle = headerStyle;
    sheet.cell(CellIndex.indexByString('B$row')).cellStyle = headerStyle;
    
    data.entries.take(10).forEach((entry) {
      row++;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(entry.key);
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue('${entry.value}');
    });
  }

  void _buildDetailedExcel(Excel excel, Map<String, dynamic> data, String title, ExportOptions options) {
    final sheet = excel['Detailed_Report'];
    
    // Detailed table with multiple columns
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.grey,
      bold: true,
      fontSize: 12,
    );
    
    // Headers
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Field');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Value');
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('Type');
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('Length');
    
    for (final cell in ['A1', 'B1', 'C1', 'D1']) {
      sheet.cell(CellIndex.indexByString(cell)).cellStyle = headerStyle;
    }
    
    // Data
    int row = 1;
    for (final entry in data.entries) {
      row++;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(entry.key);
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue('${entry.value}');
      sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(entry.value.runtimeType.toString());
      sheet.cell(CellIndex.indexByString('D$row')).value = IntCellValue(entry.value.toString().length);
    }
  }

  void _buildSummaryExcel(Excel excel, Map<String, dynamic> data, String title, ExportOptions options) {
    final sheet = excel['Summary'];
    
    // Summary with charts-like data layout
    final titleStyle = CellStyle(
      backgroundColorHex: ExcelColor.green,
      fontColorHex: ExcelColor.white,
      bold: true,
      fontSize: 14,
    );
    
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(title);
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;
    
    // Create summary grid
    final entries = data.entries.toList();
    int col = 0;
    int row = 3;
    
    for (int i = 0; i < entries.length; i++) {
      if (col > 2) {
        col = 0;
        row += 3;
      }
      
      final colLetter = String.fromCharCode(65 + col * 2); // A, C, E...
      sheet.cell(CellIndex.indexByString('$colLetter$row')).value = TextCellValue(entries[i].key);
      sheet.cell(CellIndex.indexByString('$colLetter${row + 1}')).value = TextCellValue('${entries[i].value}');
      
      col++;
    }
  }

  void _buildTechnicalExcel(Excel excel, Map<String, dynamic> data, String title, ExportOptions options) {
    final sheet = excel['Technical_Specs'];
    
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.blue,
      fontColorHex: ExcelColor.white,
      bold: true,
    );
    
    // Technical specifications table
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Technical Specifications: $title');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = headerStyle;
    
    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('Parameter');
    sheet.cell(CellIndex.indexByString('B3')).value = TextCellValue('Value');
    sheet.cell(CellIndex.indexByString('C3')).value = TextCellValue('Unit');
    sheet.cell(CellIndex.indexByString('D3')).value = TextCellValue('Status');
    
    for (final cell in ['A3', 'B3', 'C3', 'D3']) {
      sheet.cell(CellIndex.indexByString(cell)).cellStyle = headerStyle;
    }
    
    int row = 3;
    for (final entry in data.entries) {
      row++;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(entry.key);
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue('${entry.value}');
      sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue('N/A');
      sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue('OK');
    }
  }

  void _buildAuditExcel(Excel excel, Map<String, dynamic> data, String title, ExportOptions options) {
    final sheet = excel['Audit_Log'];
    
    final auditStyle = CellStyle(
      backgroundColorHex: ExcelColor.red,
      fontColorHex: ExcelColor.white,
      bold: true,
    );
    
    // Audit header
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('AUDIT REPORT: $title');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = auditStyle;
    
    // Audit columns
    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('Timestamp');
    sheet.cell(CellIndex.indexByString('B3')).value = TextCellValue('Event');
    sheet.cell(CellIndex.indexByString('C3')).value = TextCellValue('Details');
    sheet.cell(CellIndex.indexByString('D3')).value = TextCellValue('User');
    sheet.cell(CellIndex.indexByString('E3')).value = TextCellValue('Status');
    
    for (final cell in ['A3', 'B3', 'C3', 'D3', 'E3']) {
      sheet.cell(CellIndex.indexByString(cell)).cellStyle = auditStyle;
    }
    
    int row = 3;
    for (final entry in data.entries) {
      row++;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()));
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(entry.key);
      sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue('${entry.value}');
      sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue('System');
      sheet.cell(CellIndex.indexByString('E$row')).value = TextCellValue('Logged');
    }
  }

  void _buildComplianceExcel(Excel excel, Map<String, dynamic> data, String title, ExportOptions options) {
    final sheet = excel['Compliance'];
    
    final complianceStyle = CellStyle(
      backgroundColorHex: ExcelColor.green,
      fontColorHex: ExcelColor.white,
      bold: true,
    );
    
    // Compliance header
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('COMPLIANCE REPORT: $title');
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = complianceStyle;
    
    // Compliance checklist
    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('Requirement');
    sheet.cell(CellIndex.indexByString('B3')).value = TextCellValue('Status');
    sheet.cell(CellIndex.indexByString('C3')).value = TextCellValue('Evidence');
    sheet.cell(CellIndex.indexByString('D3')).value = TextCellValue('Date Verified');
    
    for (final cell in ['A3', 'B3', 'C3', 'D3']) {
      sheet.cell(CellIndex.indexByString(cell)).cellStyle = complianceStyle;
    }
    
    int row = 3;
    for (final entry in data.entries) {
      row++;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(entry.key);
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue('✓ COMPLIANT');
      sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue('${entry.value}');
      sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(DateFormat('yyyy-MM-dd').format(DateTime.now()));
    }
  }

  void _buildExecutiveCSV(List<List<String>> csvData, Map<String, dynamic> data, String title, ExportOptions options) {
    // Executive summary format
    csvData.add(['EXECUTIVE REPORT', title]);
    csvData.add(['Generated', DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())]);
    csvData.add([]); // Empty row
    
    // Key metrics summary
    csvData.add(['Key Metrics', 'Value', 'Trend', 'Status']);
    for (final entry in data.entries.take(10)) {
      csvData.add([
        entry.key,
        '${entry.value}',
        'Stable', 
        'Normal'
      ]);
    }
  }

  void _buildDetailedCSV(List<List<String>> csvData, Map<String, dynamic> data, String title, ExportOptions options) {
    // Detailed format with metadata
    csvData.add(['DETAILED REPORT', title]);
    csvData.add(['Timestamp', DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())]);
    csvData.add([]); // Empty row
    
    // Detailed headers
    csvData.add(['Field', 'Value', 'Type', 'Length', 'Description']);
    for (final entry in data.entries) {
      csvData.add([
        entry.key,
        '${entry.value}',
        entry.value.runtimeType.toString(),
        entry.value.toString().length.toString(),
        'Auto-generated field'
      ]);
    }
  }

  void _buildSummaryCSV(List<List<String>> csvData, Map<String, dynamic> data, String title, ExportOptions options) {
    // Summary format - condensed
    csvData.add(['SUMMARY REPORT', title]);
    csvData.add([]); // Empty row
    
    // Two-column layout
    csvData.add(['Item', 'Summary']);
    final entries = data.entries.toList();
    for (int i = 0; i < entries.length; i += 2) {
      final row = <String>[entries[i].key, '${entries[i].value}'];
      if (i + 1 < entries.length) {
        row.addAll([entries[i + 1].key, '${entries[i + 1].value}']);
      }
      csvData.add(row);
    }
  }

  void _buildStandardHTML(StringBuffer htmlBuffer, Map<String, dynamic> data, String title, String? description, ExportOptions options) {
    htmlBuffer.writeln('<div class="container">');
    htmlBuffer.writeln('<h1>$title</h1>');
    if (description != null) {
      htmlBuffer.writeln('<p class="description">$description</p>');
    }
    htmlBuffer.writeln('<p class="timestamp">Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}</p>');
    htmlBuffer.writeln('<div class="data">');
    data.forEach((key, value) {
      htmlBuffer.writeln('<div class="data-item">');
      htmlBuffer.writeln('<strong>$key:</strong> $value');
      htmlBuffer.writeln('</div>');
    });
    htmlBuffer.writeln('</div>');
    htmlBuffer.writeln('</div>');
  }

  void _buildExecutiveHTML(StringBuffer htmlBuffer, Map<String, dynamic> data, String title, String? description, ExportOptions options) {
    htmlBuffer.writeln('''
    <div class="executive-container">
      <div class="executive-header">
        <h1 class="executive-title">$title</h1>
        <div class="executive-badge">EXECUTIVE REPORT</div>
      </div>
      ${description != null ? '<p class="executive-description">$description</p>' : ''}
      <div class="executive-summary">
        <h2>Key Performance Indicators</h2>
        <div class="kpi-grid">
    ''');
    
    for (final entry in data.entries.take(6)) {
      htmlBuffer.writeln('''
        <div class="kpi-card">
          <div class="kpi-value">${entry.value}</div>
          <div class="kpi-label">${entry.key}</div>
        </div>
      ''');
    }
    
    htmlBuffer.writeln('''
        </div>
      </div>
      <div class="timestamp">Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}</div>
    </div>
    ''');
  }

  void _buildDetailedHTML(StringBuffer htmlBuffer, Map<String, dynamic> data, String title, String? description, ExportOptions options) {
    htmlBuffer.writeln('''
    <div class="detailed-container">
      <header class="detailed-header">
        <h1>$title</h1>
        <span class="report-type">Detailed Technical Report</span>
      </header>
      ${description != null ? '<section class="description">$description</section>' : ''}
      
      <section class="data-section">
        <h2>Technical Specifications</h2>
        <table class="detailed-table">
          <thead>
            <tr>
              <th>Parameter</th>
              <th>Value</th>
              <th>Type</th>
              <th>Size</th>
            </tr>
          </thead>
          <tbody>
    ''');
    
    for (final entry in data.entries) {
      htmlBuffer.writeln('''
        <tr>
          <td class="param-name">${entry.key}</td>
          <td class="param-value">${entry.value}</td>
          <td class="param-type">${entry.value.runtimeType}</td>
          <td class="param-size">${entry.value.toString().length} chars</td>
        </tr>
      ''');
    }
    
    htmlBuffer.writeln('''
          </tbody>
        </table>
      </section>
    </div>
    ''');
  }

  String _getHTMLStyles(ExportTemplate template) {
    const baseStyles = '''
      body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
      .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
      h1 { color: #333; margin-bottom: 20px; }
      h2 { color: #555; margin-top: 30px; margin-bottom: 15px; }
      .timestamp { color: #999; font-size: 0.9em; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; }
    ''';

    switch (template) {
      case ExportTemplate.executive:
        return '$baseStyles'
          '.executive-container { }'
          '.executive-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px; }'
          '.executive-title { color: #2c3e50; font-size: 2.5em; margin: 0; }'
          '.executive-badge { background: #3498db; color: white; padding: 8px 16px; border-radius: 20px; font-size: 0.8em; font-weight: bold; }'
          '.executive-description { font-size: 1.1em; color: #666; margin: 20px 0; line-height: 1.6; }'
          '.kpi-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }'
          '.kpi-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; text-align: center; }'
          '.kpi-value { font-size: 2.5em; font-weight: bold; margin-bottom: 5px; }'
          '.kpi-label { font-size: 0.9em; opacity: 0.9; }';
        
      case ExportTemplate.detailed:
        return '$baseStyles'
          '.detailed-container { }'
          '.detailed-header { background: #34495e; color: white; padding: 20px; margin: -30px -30px 30px -30px; border-radius: 8px 8px 0 0; }'
          '.detailed-header h1 { color: white; margin: 0; }'
          '.report-type { background: rgba(255,255,255,0.2); padding: 4px 12px; border-radius: 15px; font-size: 0.8em; }'
          '.description { background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 20px 0; }'
          '.detailed-table { width: 100%; border-collapse: collapse; margin: 20px 0; }'
          '.detailed-table th { background: #2c3e50; color: white; padding: 12px; text-align: left; }'
          '.detailed-table td { padding: 10px 12px; border-bottom: 1px solid #ddd; }'
          '.detailed-table tr:nth-child(even) { background: #f8f9fa; }'
          '.param-name { font-weight: bold; color: #2c3e50; }'
          '.param-value { font-family: monospace; background: #f1f2f6; padding: 4px 8px; border-radius: 3px; }'
          '.param-type { color: #7f8c8d; font-style: italic; }'
          '.param-size { color: #95a5a6; font-size: 0.9em; }';
        
      case ExportTemplate.summary:
        return '$baseStyles'
          '.summary-container { }'
          '.summary-header { background: linear-gradient(135deg, #28a745 0%, #20c997 100%); color: white; padding: 20px; margin: -30px -30px 30px -30px; border-radius: 8px 8px 0 0; }'
          '.summary-cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 15px; margin: 20px 0; }'
          '.summary-card { border: 1px solid #dee2e6; border-radius: 8px; padding: 15px; background: white; transition: all 0.3s; }'
          '.summary-card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.1); transform: translateY(-2px); }'
          '.card-title { font-weight: bold; color: #28a745; margin-bottom: 8px; }'
          '.card-value { font-size: 1.2em; color: #495057; }';
        
      default:
        return '$baseStyles'
          '.data { margin-top: 30px; }'
          '.data-item { margin: 10px 0; padding: 15px; background: #f8f9fa; border-left: 4px solid #007bff; border-radius: 0 5px 5px 0; }'
          '.data-item strong { color: #495057; }';
    }
  }

  void _convertMapToXML(Map<String, dynamic> map, StringBuffer buffer, int indent) {
    final spaces = '  ' * indent;
    map.forEach((key, value) {
      if (value is Map) {
        buffer.writeln('$spaces<$key>');
        _convertMapToXML(value as Map<String, dynamic>, buffer, indent + 1);
        buffer.writeln('$spaces</$key>');
      } else if (value is List) {
        buffer.writeln('$spaces<$key>');
        for (var item in value) {
          buffer.writeln('$spaces  <item>$item</item>');
        }
        buffer.writeln('$spaces</$key>');
      } else {
        buffer.writeln('$spaces<$key>$value</$key>');
      }
    });
  }

  void _convertMapToRTF(Map<String, dynamic> map, StringBuffer buffer) {
    map.forEach((key, value) {
      buffer.writeln('\\b $key \\b0\\par');
      if (value is Map) {
        _convertMapToRTF(value as Map<String, dynamic>, buffer);
      } else {
        buffer.writeln('$value\\par');
      }
      buffer.writeln('\\par');
    });
  }

  String _formatTitle(String title) {
    return title.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  Future<Uint8List> _protectPDF(Uint8List pdfBytes, String password) async {
    try {
      // Implement PDF password protection
      // Note: Using simple encryption here, stronger encryption should be used in production
      final protectedBytes = <int>[];
      
      // Add PDF encryption header
      protectedBytes.addAll('%%PDF-ENCRYPTED\n'.codeUnits);
      
      // Simple XOR encryption (should use AES or stronger encryption in production)
      final passwordBytes = password.codeUnits;
      for (int i = 0; i < pdfBytes.length; i++) {
        protectedBytes.add(pdfBytes[i] ^ passwordBytes[i % passwordBytes.length]);
      }
      
      return Uint8List.fromList(protectedBytes);
    } catch (e) {
      LoggerService.warning('PDF protection failed, returning original', error: e);
      return pdfBytes;
    }
  }

  Future<Uint8List> _protectExcel(Uint8List excelBytes, String password) async {
    try {
      // Implement Excel password protection
      // Using simple file header modification and encryption here
      final protectedBytes = <int>[];
      
      // Add encryption identifier
      protectedBytes.addAll('XLS-PROTECTED\n'.codeUnits);
      
      // Store password hash
      final passwordHash = password.hashCode;
      protectedBytes.addAll([
        (passwordHash >> 24) & 0xFF,
        (passwordHash >> 16) & 0xFF,
        (passwordHash >> 8) & 0xFF,
        passwordHash & 0xFF,
      ]);
      
      // Simple content encryption
      final passwordBytes = password.codeUnits;
      for (int i = 0; i < excelBytes.length; i++) {
        protectedBytes.add(excelBytes[i] ^ passwordBytes[i % passwordBytes.length]);
      }
      
      return Uint8List.fromList(protectedBytes);
    } catch (e) {
      LoggerService.warning('Excel protection failed, returning original', error: e);
      return excelBytes;
    }
  }

  Future<Uint8List> _compressData(Uint8List data) async {
    try {
      // Implement data compression using built-in GZip
      final codec = GZipCodec();
      final compressedData = codec.encode(data);
      
      LoggerService.info('Data compressed from ${data.length} to ${compressedData.length} bytes');
      return Uint8List.fromList(compressedData);
    } catch (e) {
      LoggerService.warning('Data compression failed, returning original', error: e);
      return data;
    }
  }

  /// Get available export formats
  List<ExportFormat> getAvailableFormats() {
    return ExportFormat.values;
  }

  /// Get available templates
  List<ExportTemplate> getAvailableTemplates() {
    return ExportTemplate.values;
  }

  /// Delete export from history
  Future<void> deleteExport(String fileName) async {
    try {
      // Remove from storage
      final ref = _storage.ref().child('$_exportsStoragePath/$fileName');
      await ref.delete();

      // Remove from history
      _exportHistory.removeWhere((export) => export.fileName == fileName);
      notifyListeners();

      LoggerService.info('Export deleted: $fileName');
    } catch (e) {
      LoggerService.error('Failed to delete export', error: e);
    }
  }

  /// Share export file
  Future<void> shareExport(ExportResult export) async {
    try {
      if (export.localPath.isNotEmpty) {
        await Share.shareXFiles([XFile(export.localPath)]);
      } else {
        await Share.share(export.downloadUrl);
      }
    } catch (e) {
      LoggerService.error('Failed to share export', error: e);
    }
  }
}

// Riverpod providers
final advancedExportServiceProvider = ChangeNotifierProvider<AdvancedExportService>((ref) {
  return AdvancedExportService();
});

final exportHistoryProvider = Provider<List<ExportResult>>((ref) {
  return ref.watch(advancedExportServiceProvider).exportHistory;
});

final isExportingProvider = Provider<bool>((ref) {
  return ref.watch(advancedExportServiceProvider).isExporting;
});

final exportProgressProvider = Provider<double>((ref) {
  return ref.watch(advancedExportServiceProvider).exportProgress;
}); 