import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/advanced_export_service.dart';
import '../../../core/localization/app_localizations.dart';

class AdvancedExportDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  final String title;
  final String? description;

  const AdvancedExportDialog({
    super.key,
    required this.data,
    required this.title,
    this.description,
  });

  @override
  ConsumerState<AdvancedExportDialog> createState() => _AdvancedExportDialogState();
}

class _AdvancedExportDialogState extends ConsumerState<AdvancedExportDialog> {
  ExportFormat _selectedFormat = ExportFormat.pdf;
  ExportTemplate _selectedTemplate = ExportTemplate.standard;
  bool _includeCharts = true;
  bool _includeImages = true;
  bool _includeMetadata = true;
  bool _compressOutput = false;
  String? _password;
  final List<String> _selectedFields = [];
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isExporting = ref.watch(isExportingProvider);
    final exportProgress = ref.watch(exportProgressProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.file_download, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Text(localizations?.exportData ?? 'Advanced Export'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Export Format Selection
              _buildSectionTitle('Export Format'),
              _buildFormatSelector(),
              const SizedBox(height: 16),

              // Template Selection
              _buildSectionTitle('Template'),
              _buildTemplateSelector(),
              const SizedBox(height: 16),

              // Options
              _buildSectionTitle('Options'),
              _buildOptionsSection(),
              const SizedBox(height: 16),

              // Password Protection
              if (_supportsPasswordProtection())
                _buildPasswordSection(),

              // Field Selection
              _buildSectionTitle('Fields to Include'),
              _buildFieldSelector(),

              // Progress Indicator
              if (isExporting) ...[
                const SizedBox(height: 16),
                _buildProgressIndicator(exportProgress),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isExporting ? null : () => Navigator.of(context).pop(),
          child: Text(localizations?.cancel ?? 'Cancel'),
        ),
        ElevatedButton(
          onPressed: isExporting ? null : _performExport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
          ),
          child: isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(localizations?.exportData ?? 'Export'),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ExportFormat.values.map((format) {
        final isSelected = format == _selectedFormat;
        return FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getFormatIcon(format),
                size: 16,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(_getFormatName(format)),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _selectedFormat = format;
              });
            }
          },
          selectedColor: Colors.blue[600],
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTemplateSelector() {
    return DropdownButtonFormField<ExportTemplate>(
      value: _selectedTemplate,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: ExportTemplate.values.map((template) {
        return DropdownMenuItem(
          value: template,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getTemplateName(template),
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                _getTemplateDescription(template),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (template) {
        if (template != null) {
          setState(() {
            _selectedTemplate = template;
          });
        }
      },
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      children: [
        CheckboxListTile(
          title: const Text('Include Charts'),
          subtitle: const Text('Include visual charts and graphs'),
          value: _includeCharts,
          onChanged: (value) {
            setState(() {
              _includeCharts = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('Include Images'),
          subtitle: const Text('Include images and media files'),
          value: _includeImages,
          onChanged: (value) {
            setState(() {
              _includeImages = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('Include Metadata'),
          subtitle: const Text('Include system and export information'),
          value: _includeMetadata,
          onChanged: (value) {
            setState(() {
              _includeMetadata = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        CheckboxListTile(
          title: const Text('Compress Output'),
          subtitle: const Text('Reduce file size (may affect quality)'),
          value: _compressOutput,
          onChanged: (value) {
            setState(() {
              _compressOutput = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildPasswordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Password Protection'),
        TextField(
          controller: _passwordController,
          decoration: InputDecoration(
            hintText: 'Enter password (optional)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: const Icon(Icons.lock_outline),
          ),
          obscureText: true,
          onChanged: (value) {
            _password = value.isEmpty ? null : value;
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Password protection is available for PDF and Excel formats',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFieldSelector() {
    final availableFields = widget.data.keys.toList();
    
    return Container(
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        itemCount: availableFields.length,
        itemBuilder: (context, index) {
          final field = availableFields[index];
          final isSelected = _selectedFields.contains(field);
          
          return CheckboxListTile(
            title: Text(
              _formatFieldName(field),
              style: const TextStyle(fontSize: 14),
            ),
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedFields.add(field);
                } else {
                  _selectedFields.remove(field);
                }
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          );
        },
      ),
    );
  }

  Widget _buildProgressIndicator(double progress) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
        ),
        const SizedBox(height: 8),
        Text(
          'Exporting... ${(progress * 100).toInt()}%',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<void> _performExport() async {
    try {
      final options = ExportOptions(
        format: _selectedFormat,
        template: _selectedTemplate,
        includeCharts: _includeCharts,
        includeImages: _includeImages,
        includeMetadata: _includeMetadata,
        compressOutput: _compressOutput,
        password: _password,
        selectedFields: _selectedFields,
      );

      final result = await ref.read(advancedExportServiceProvider).exportData(
        data: widget.data,
        title: widget.title,
        options: options,
        description: widget.description,
        onProgress: (progress) {
          // Progress is handled by the provider
        },
      );

      if (mounted) {
        Navigator.of(context).pop(result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export completed: ${result.fileName}'),
            backgroundColor: Colors.green[600],
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () {
                ref.read(advancedExportServiceProvider).shareExport(result);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  bool _supportsPasswordProtection() {
    return _selectedFormat == ExportFormat.pdf || _selectedFormat == ExportFormat.excel;
  }

  IconData _getFormatIcon(ExportFormat format) {
    switch (format) {
      case ExportFormat.pdf:
        return Icons.picture_as_pdf;
      case ExportFormat.excel:
        return Icons.table_chart;
      case ExportFormat.csv:
        return Icons.grid_on;
      case ExportFormat.json:
        return Icons.code;
      case ExportFormat.xml:
        return Icons.code;
      case ExportFormat.html:
        return Icons.web;
      case ExportFormat.word:
        return Icons.description;
      case ExportFormat.powerpoint:
        return Icons.slideshow;
    }
  }

  String _getFormatName(ExportFormat format) {
    switch (format) {
      case ExportFormat.pdf:
        return 'PDF';
      case ExportFormat.excel:
        return 'Excel';
      case ExportFormat.csv:
        return 'CSV';
      case ExportFormat.json:
        return 'JSON';
      case ExportFormat.xml:
        return 'XML';
      case ExportFormat.html:
        return 'HTML';
      case ExportFormat.word:
        return 'Word';
      case ExportFormat.powerpoint:
        return 'PowerPoint';
    }
  }

  String _getTemplateName(ExportTemplate template) {
    switch (template) {
      case ExportTemplate.standard:
        return 'Standard';
      case ExportTemplate.detailed:
        return 'Detailed';
      case ExportTemplate.summary:
        return 'Summary';
      case ExportTemplate.executive:
        return 'Executive';
      case ExportTemplate.technical:
        return 'Technical';
      case ExportTemplate.audit:
        return 'Audit';
      case ExportTemplate.compliance:
        return 'Compliance';
    }
  }

  String _getTemplateDescription(ExportTemplate template) {
    switch (template) {
      case ExportTemplate.standard:
        return 'Basic format with essential information';
      case ExportTemplate.detailed:
        return 'Comprehensive format with all available data';
      case ExportTemplate.summary:
        return 'Condensed format with key metrics only';
      case ExportTemplate.executive:
        return 'High-level overview for executives';
      case ExportTemplate.technical:
        return 'Technical format with detailed specifications';
      case ExportTemplate.audit:
        return 'Audit-ready format with compliance data';
      case ExportTemplate.compliance:
        return 'Regulatory compliance format';
    }
  }

  String _formatFieldName(String field) {
    return field
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
} 