import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/certificate_model.dart';
import '../../providers/certificate_providers.dart';

class CertificateFilterDialog extends ConsumerStatefulWidget {
  const CertificateFilterDialog({super.key});

  @override
  ConsumerState<CertificateFilterDialog> createState() => _CertificateFilterDialogState();
}

class _CertificateFilterDialogState extends ConsumerState<CertificateFilterDialog> {
  late CertificateFilter _tempFilter;
  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    final currentFilter = ref.read(certificateFilterProvider);
    _tempFilter = currentFilter;
    _startDate = currentFilter.startDate;
    _endDate = currentFilter.endDate;
    _selectedTags = List.from(currentFilter.tags ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      content: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        decoration: BoxDecoration(
          color: AppTheme.backgroundLight,
          borderRadius: AppTheme.largeRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              offset: const Offset(0, 8),
              blurRadius: 24,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusFilter(),
                    const SizedBox(height: AppTheme.spacingL),
                    _buildTypeFilter(),
                    const SizedBox(height: AppTheme.spacingL),
                    _buildDateRangeFilter(),
                    const SizedBox(height: AppTheme.spacingL),
                    _buildTagsFilter(),
                    const SizedBox(height: AppTheme.spacingL),
                    _buildVerificationFilter(),
                    const SizedBox(height: AppTheme.spacingL),
                    _buildExpirationFilter(),
                    const SizedBox(height: AppTheme.spacingL),
                    _buildOtherSettings(),
                  ],
                ),
              ),
            ),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusL),
        ),
      ),
      child: Row(
        children: [
          FadeInLeft(
            child: const Icon(
              Icons.filter_list,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: FadeInLeft(
              delay: const Duration(milliseconds: 100),
              child: Text(
                'Filter Certificates',
                style: AppTheme.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          FadeInRight(
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: _buildFilterSection(
        title: 'Status',
        icon: Icons.label_outline,
        child: Wrap(
          spacing: AppTheme.spacingS,
          runSpacing: AppTheme.spacingS,
          children: [
            _buildFilterChip(
              label: 'All',
              isSelected: _tempFilter.statuses == null,
              onSelected: (selected) {
                setState(() {
                  _tempFilter = CertificateFilter(
                    statuses: selected ? null : _tempFilter.statuses,
                    types: _tempFilter.types,
                    startDate: _tempFilter.startDate,
                    endDate: _tempFilter.endDate,
                    searchTerm: _tempFilter.searchTerm,
                    tags: _tempFilter.tags,
                    isExpired: _tempFilter.isExpired,
                    isVerified: _tempFilter.isVerified,
                  );
                });
              },
            ),
            ...CertificateStatus.values.map((status) => _buildFilterChip(
              label: _getStatusDisplayName(status),
              isSelected: _tempFilter.statuses?.contains(status) ?? false,
              onSelected: (selected) {
                setState(() {
                  final currentStatuses = List<CertificateStatus>.from(_tempFilter.statuses ?? []);
                  if (selected) {
                    currentStatuses.add(status);
                  } else {
                    currentStatuses.remove(status);
                  }
                  _tempFilter = CertificateFilter(
                    statuses: currentStatuses.isEmpty ? null : currentStatuses,
                    types: _tempFilter.types,
                    startDate: _tempFilter.startDate,
                    endDate: _tempFilter.endDate,
                    searchTerm: _tempFilter.searchTerm,
                    tags: _tempFilter.tags,
                    isExpired: _tempFilter.isExpired,
                    isVerified: _tempFilter.isVerified,
                  );
                });
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeFilter() {
    return FadeInUp(
      delay: const Duration(milliseconds: 300),
      child: _buildFilterSection(
        title: 'Certificate Type',
        icon: Icons.category,
        child: Wrap(
          spacing: AppTheme.spacingS,
          runSpacing: AppTheme.spacingS,
          children: [
            _buildFilterChip(
              label: 'All',
              isSelected: _tempFilter.types == null,
              onSelected: (selected) {
                setState(() {
                  _tempFilter = CertificateFilter(
                    statuses: _tempFilter.statuses,
                    types: selected ? null : _tempFilter.types,
                    startDate: _tempFilter.startDate,
                    endDate: _tempFilter.endDate,
                    searchTerm: _tempFilter.searchTerm,
                    tags: _tempFilter.tags,
                    isExpired: _tempFilter.isExpired,
                    isVerified: _tempFilter.isVerified,
                  );
                });
              },
            ),
            ...CertificateType.values.map((type) => _buildFilterChip(
              label: _getTypeDisplayName(type),
              isSelected: _tempFilter.types?.contains(type) ?? false,
              onSelected: (selected) {
                setState(() {
                  final currentTypes = List<CertificateType>.from(_tempFilter.types ?? []);
                  if (selected) {
                    currentTypes.add(type);
                  } else {
                    currentTypes.remove(type);
                  }
                  _tempFilter = CertificateFilter(
                    statuses: _tempFilter.statuses,
                    types: currentTypes.isEmpty ? null : currentTypes,
                    startDate: _tempFilter.startDate,
                    endDate: _tempFilter.endDate,
                    searchTerm: _tempFilter.searchTerm,
                    tags: _tempFilter.tags,
                    isExpired: _tempFilter.isExpired,
                    isVerified: _tempFilter.isVerified,
                  );
                });
              },
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeFilter() {
    return FadeInUp(
      delay: const Duration(milliseconds: 400),
      child: _buildFilterSection(
        title: 'Date Range',
        icon: Icons.date_range,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: 'Start Date',
                    date: _startDate,
                    onTap: () => _selectStartDate(),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingM),
                Expanded(
                  child: _buildDateField(
                    label: 'End Date',
                    date: _endDate,
                    onTap: () => _selectEndDate(),
                  ),
                ),
              ],
            ),
            if (_startDate != null || _endDate != null) ...[
              const SizedBox(height: AppTheme.spacingS),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                      _tempFilter = CertificateFilter(
                        statuses: _tempFilter.statuses,
                        types: _tempFilter.types,
                        startDate: null,
                        endDate: null,
                        searchTerm: _tempFilter.searchTerm,
                        tags: _tempFilter.tags,
                        isExpired: _tempFilter.isExpired,
                        isVerified: _tempFilter.isVerified,
                      );
                    });
                  },
                  child: const Text('Clear Dates'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTagsFilter() {
    return FadeInUp(
      delay: const Duration(milliseconds: 500),
      child: _buildFilterSection(
        title: 'Tags',
        icon: Icons.local_offer,
        child: Consumer(
          builder: (context, ref, child) {
            final availableTagsAsync = ref.watch(availableTagsProvider);
            return availableTagsAsync.when(
              data: (availableTags) {
                if (availableTags.isEmpty) {
                  return Text(
                    'No tags available',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  );
                }

                return Wrap(
                  spacing: AppTheme.spacingS,
                  runSpacing: AppTheme.spacingS,
                  children: availableTags.map((tag) => _buildFilterChip(
                    label: tag,
                    isSelected: _selectedTags.contains(tag),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                        _tempFilter = CertificateFilter(
                          statuses: _tempFilter.statuses,
                          types: _tempFilter.types,
                          startDate: _tempFilter.startDate,
                          endDate: _tempFilter.endDate,
                          searchTerm: _tempFilter.searchTerm,
                          tags: _selectedTags.isEmpty ? null : _selectedTags,
                          isExpired: _tempFilter.isExpired,
                          isVerified: _tempFilter.isVerified,
                        );
                      });
                    },
                  )).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text(
                'Failed to load tags',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.errorColor,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVerificationFilter() {
    return FadeInUp(
      delay: const Duration(milliseconds: 600),
      child: _buildFilterSection(
        title: 'Verification Status',
        icon: Icons.verified,
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text('Only Verified'),
              value: _tempFilter.isVerified == true,
              onChanged: (value) {
                setState(() {
                  _tempFilter = _tempFilter.copyWith(
                    isVerified: value == true ? true : null,
                  );
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpirationFilter() {
    return FadeInUp(
      delay: const Duration(milliseconds: 700),
      child: _buildFilterSection(
        title: 'Expiration Status',
        icon: Icons.schedule,
        child: Column(
          children: [
            CheckboxListTile(
              title: const Text('Only Active'),
              value: _tempFilter.isExpired == false,
              onChanged: (value) {
                setState(() {
                  _tempFilter = _tempFilter.copyWith(
                    isExpired: value == true ? false : null,
                  );
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherSettings() {
    return FadeInUp(
      delay: const Duration(milliseconds: 800),
      child: _buildFilterSection(
        title: 'Other Settings',
        icon: Icons.settings,
        child: const Column(
          children: [
            // Add other settings widgets here
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              title,
              style: AppTheme.titleSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingM),
        child,
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
      checkmarkColor: AppTheme.primaryColor,
      backgroundColor: AppTheme.backgroundLight,
      side: BorderSide(
        color: isSelected 
            ? AppTheme.primaryColor 
            : AppTheme.dividerColor.withValues(alpha: 0.5),
      ),
      labelStyle: AppTheme.bodySmall.copyWith(
        color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.smallRadius,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppTheme.dividerColor.withValues(alpha: 0.5),
          ),
          borderRadius: AppTheme.smallRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: AppTheme.spacingXS),
                Flexible(
                  child: Text(
                    date != null 
                        ? '${date.day}/${date.month}/${date.year}'
                        : 'Select date',
                    style: AppTheme.bodyMedium.copyWith(
                      color: date != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.radiusL),
        ),
        border: Border(
          top: BorderSide(
            color: AppTheme.dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: FadeInLeft(
              delay: const Duration(milliseconds: 800),
              child: OutlinedButton(
                onPressed: _clearAllFilters,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                ),
                child: const Text('Clear All'),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: FadeInRight(
              delay: const Duration(milliseconds: 800),
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                ),
                child: const Text('Apply Filters'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _startDate = date;
        _tempFilter = CertificateFilter(
          statuses: _tempFilter.statuses,
          types: _tempFilter.types,
          startDate: date,
          endDate: _tempFilter.endDate,
          searchTerm: _tempFilter.searchTerm,
          tags: _tempFilter.tags,
          isExpired: _tempFilter.isExpired,
          isVerified: _tempFilter.isVerified,
        );
      });
    }
  }

  void _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _endDate = date;
        _tempFilter = CertificateFilter(
          statuses: _tempFilter.statuses,
          types: _tempFilter.types,
          startDate: _tempFilter.startDate,
          endDate: date,
          searchTerm: _tempFilter.searchTerm,
          tags: _tempFilter.tags,
          isExpired: _tempFilter.isExpired,
          isVerified: _tempFilter.isVerified,
        );
      });
    }
  }

  void _clearAllFilters() {
    setState(() {
      _tempFilter = const CertificateFilter();
      _startDate = null;
      _endDate = null;
      _selectedTags.clear();
    });
  }

  void _applyFilters() {
    ref.read(certificateFilterProvider.notifier).updateFilter(_tempFilter);
    Navigator.of(context).pop();
  }

  String _getStatusDisplayName(CertificateStatus status) {
    switch (status) {
      case CertificateStatus.draft:
        return 'Draft';
      case CertificateStatus.pending:
        return 'Pending';
      case CertificateStatus.approved:
        return 'Approved';
      case CertificateStatus.issued:
        return 'Issued';
      case CertificateStatus.revoked:
        return 'Revoked';
      case CertificateStatus.expired:
        return 'Expired';
      default:
        return 'Unknown';
    }
  }

  String _getTypeDisplayName(CertificateType type) {
    switch (type) {
      case CertificateType.academic:
        return 'Academic';
      case CertificateType.professional:
        return 'Professional';
      case CertificateType.achievement:
        return 'Achievement';
      case CertificateType.completion:
        return 'Completion';
      case CertificateType.participation:
        return 'Participation';
      case CertificateType.recognition:
        return 'Recognition';
      case CertificateType.custom:
        return 'Custom';
    }
  }
} 