import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/models/certificate_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/providers/auth_providers.dart';

// Certificate Templates Provider
final certificateTemplatesProvider = StreamProvider<List<CertificateTemplate>>((ref) {
  return FirebaseFirestore.instance
      .collection('certificate_templates')
      .where('isActive', isEqualTo: true)
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => CertificateTemplate.fromFirestore(doc))
          .toList());
});

class CertificateTemplatesPage extends ConsumerStatefulWidget {
  const CertificateTemplatesPage({super.key});

  @override
  ConsumerState<CertificateTemplatesPage> createState() => _CertificateTemplatesPageState();
}

class _CertificateTemplatesPageState extends ConsumerState<CertificateTemplatesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  CertificateType? _selectedType;
  bool _showActiveOnly = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(certificateTemplatesProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Access denied')),
      );
    }

    // Check permissions
    final canManageTemplates = currentUser.isAdmin || currentUser.userType == UserType.ca;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: CustomAppBar(
        title: 'Certificate Templates',
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          if (canManageTemplates)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showCreateTemplateDialog,
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchQuery.isNotEmpty || _selectedType != null || !_showActiveOnly)
            _buildActiveFilters(),
          Expanded(
            child: templatesAsync.when(
              data: (templates) => _buildTemplatesList(templates, canManageTemplates),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(error.toString()),
            ),
          ),
        ],
      ),
      floatingActionButton: canManageTemplates
          ? FloatingActionButton(
              onPressed: _showCreateTemplateDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildActiveFilters() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      color: AppTheme.surfaceColor,
      child: Wrap(
        spacing: AppTheme.spacingS,
        children: [
          if (_searchQuery.isNotEmpty)
            _buildFilterChip(
              'Search: $_searchQuery',
              () => setState(() {
                _searchQuery = '';
                _searchController.clear();
              }),
            ),
          if (_selectedType != null)
            _buildFilterChip(
              'Type: ${_selectedType!.displayName}',
              () => setState(() => _selectedType = null),
            ),
          if (!_showActiveOnly)
            _buildFilterChip(
              'Including Inactive',
              () => setState(() => _showActiveOnly = true),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Chip(
      label: Text(label),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 16),
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
    );
  }

  Widget _buildTemplatesList(List<CertificateTemplate> templates, bool canManage) {
    final filteredTemplates = _filterTemplates(templates);

    if (filteredTemplates.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(certificateTemplatesProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        itemCount: filteredTemplates.length,
        itemBuilder: (context, index) {
          return FadeInUp(
            delay: Duration(milliseconds: index * 100),
            child: _buildTemplateCard(filteredTemplates[index], canManage),
          );
        },
      ),
    );
  }

  Widget _buildTemplateCard(CertificateTemplate template, bool canManage) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: InkWell(
        onTap: () => _showTemplateDetails(template),
        borderRadius: AppTheme.mediumRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: AppTheme.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (template.description.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.spacingXS),
                          Text(
                            template.description,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      color: template.isActive
                          ? AppTheme.successColor.withValues(alpha: 0.1)
                          : AppTheme.warningColor.withValues(alpha: 0.1),
                      borderRadius: AppTheme.smallRadius,
                    ),
                    child: Text(
                      template.isActive ? 'Active' : 'Inactive',
                      style: AppTheme.bodySmall.copyWith(
                        color: template.isActive
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  _buildTemplateInfo(
                    Icons.category,
                    template.type.displayName,
                  ),
                  const SizedBox(width: AppTheme.spacingL),
                  _buildTemplateInfo(
                    Icons.settings,
                    '${template.fields.length} Fields',
                  ),
                  const Spacer(),
                  if (canManage) ...[
                    IconButton(
                      onPressed: () => _showEditTemplateDialog(template),
                      icon: const Icon(Icons.edit, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    IconButton(
                      onPressed: () => _showDeleteConfirmation(template),
                      icon: const Icon(Icons.delete, size: 20, color: AppTheme.errorColor),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: AppTheme.spacingXS),
        Text(
          text,
          style: AppTheme.bodySmall.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 96,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'No templates found',
              style: AppTheme.titleLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'Create your first certificate template to get started.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            ElevatedButton.icon(
              onPressed: _showCreateTemplateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Template'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 96,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'Error loading templates',
              style: AppTheme.titleLarge.copyWith(
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacingL),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(certificateTemplatesProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  List<CertificateTemplate> _filterTemplates(List<CertificateTemplate> templates) {
    return templates.where((template) {
      // Active filter
      if (_showActiveOnly && !template.isActive) return false;

      // Type filter
      if (_selectedType != null && template.type != _selectedType) return false;

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!template.name.toLowerCase().contains(query) &&
            !template.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Templates'),
        content: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: const InputDecoration(
            hintText: 'Enter search term...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Filter Templates'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Template Type:'),
              DropdownButton<CertificateType?>(
                value: _selectedType,
                isExpanded: true,
                onChanged: (value) => setState(() => _selectedType = value),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Types')),
                  ...CertificateType.values.map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Show Active Only'),
                value: _showActiveOnly,
                onChanged: (value) => setState(() => _showActiveOnly = value ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTemplateDetails(CertificateTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(template.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Type: ${template.type.displayName}'),
              const SizedBox(height: 8),
              Text('Status: ${template.isActive ? 'Active' : 'Inactive'}'),
              const SizedBox(height: 8),
              Text('Fields: ${template.fields.length}'),
              const SizedBox(height: 8),
              if (template.description.isNotEmpty)
                Text('Description: ${template.description}'),
              const SizedBox(height: 16),
              const Text('Template Fields:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...template.fields.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text('• ${entry.key}: ${entry.value}'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCreateTemplateDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    CertificateType selectedType = CertificateType.academic;
    bool isActive = true;
    final Map<String, String> fields = {};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Template'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Template Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<CertificateType>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Template Type',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => selectedType = value!),
                    items: CertificateType.values.map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      ),
                    ).toList(),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (value) => setState(() => isActive = value ?? true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                try {
                  await FirebaseFirestore.instance.collection('certificate_templates').add({
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'type': selectedType.name,
                    'isActive': isActive,
                    'fields': fields,
                    'template': {},
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Template created successfully'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                    ref.invalidate(certificateTemplatesProvider);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create template: $e'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTemplateDialog(CertificateTemplate template) {
    final nameController = TextEditingController(text: template.name);
    final descriptionController = TextEditingController(text: template.description);
    CertificateType selectedType = template.type;
    bool isActive = template.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Template'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Template Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<CertificateType>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Template Type',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => selectedType = value!),
                    items: CertificateType.values.map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      ),
                    ).toList(),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (value) => setState(() => isActive = value ?? true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                try {
                  await FirebaseFirestore.instance
                      .collection('certificate_templates')
                      .doc(template.id)
                      .update({
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'type': selectedType.name,
                    'isActive': isActive,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Template updated successfully'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                    ref.invalidate(certificateTemplatesProvider);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update template: $e'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(CertificateTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('certificate_templates')
                    .doc(template.id)
                    .delete();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Template deleted successfully'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                  ref.invalidate(certificateTemplatesProvider);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete template: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
} 