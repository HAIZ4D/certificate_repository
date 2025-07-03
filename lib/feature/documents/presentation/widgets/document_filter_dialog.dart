import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class DocumentFilterDialog extends StatefulWidget {
  final String selectedFilter;
  final Function(String) onFilterChanged;

  const DocumentFilterDialog({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  State<DocumentFilterDialog> createState() => _DocumentFilterDialogState();
}

class _DocumentFilterDialogState extends State<DocumentFilterDialog> {
  late String _selectedFilter;

  final List<Map<String, dynamic>> _filterOptions = [
    {
      'value': 'all',
      'label': 'All Documents',
      'icon': Icons.folder_open,
      'color': AppTheme.primaryColor,
    },
    {
      'value': 'academic',
      'label': 'Academic',
      'icon': Icons.school,
      'color': AppTheme.successColor,
    },
    {
      'value': 'identification',
      'label': 'Identification',
      'icon': Icons.badge,
      'color': AppTheme.warningColor,
    },
    {
      'value': 'certificate',
      'label': 'Certificates',
      'icon': Icons.verified,
      'color': AppTheme.infoColor,
    },
    {
      'value': 'pdf',
      'label': 'PDF Documents',
      'icon': Icons.picture_as_pdf,
      'color': Colors.red,
    },
    {
      'value': 'image',
      'label': 'Images',
      'icon': Icons.image,
      'color': Colors.blue,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.selectedFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.filter_list,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  Text(
                    'Filter Documents',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                  ),
                ],
              ),
            ),

            // Filter Options
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Document Type',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  ...(_filterOptions.map((option) => _buildFilterOption(option))),
                ],
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppTheme.dividerColor.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedFilter = 'all';
                        });
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onFilterChanged(_selectedFilter);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(Map<String, dynamic> option) {
    final isSelected = _selectedFilter == option['value'];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = option['value'];
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          decoration: BoxDecoration(
            color: isSelected 
                ? option['color'].withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border.all(
              color: isSelected 
                  ? option['color']
                  : AppTheme.dividerColor.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: option['color'].withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  option['icon'],
                  color: option['color'],
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: Text(
                  option['label'],
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? option['color'] : AppTheme.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: option['color'],
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
} 