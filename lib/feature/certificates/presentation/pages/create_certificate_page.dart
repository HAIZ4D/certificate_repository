import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/certificate_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/certificate_providers.dart';
import '../../../auth/presentation/widgets/custom_text_field.dart';

// Signature-related enums and classes
enum SignatureType {
  digital,
  visual,
  qrCode,
  watermark,
}

class SignatureInfo {
  final String id;
  final String signerId;
  final String signerName;
  final String? signerPosition;
  final SignatureType type;
  final String data;
  final DateTime signedAt;

  const SignatureInfo({
    required this.id,
    required this.signerId,
    required this.signerName,
    this.signerPosition,
    required this.type,
    required this.data,
    required this.signedAt,
  });
}

class CreateCertificatePage extends ConsumerStatefulWidget {
  final String? certificateId; // For edit mode
  
  const CreateCertificatePage({super.key, this.certificateId});

  @override
  ConsumerState<CreateCertificatePage> createState() => _CreateCertificatePageState();
}

class _CreateCertificatePageState extends ConsumerState<CreateCertificatePage> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentStep = 0;

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientEmailController = TextEditingController();
  final _templateIdController = TextEditingController();
  final _customFieldControllers = <String, TextEditingController>{};

  // Form data
  CertificateType _selectedType = CertificateType.academic;
  DateTime? _expiryDate;
  bool _isPublic = false;
  final List<String> _tags = [];
  final Map<String, dynamic> _customData = {};
  final List<SignatureInfo> _signatures = [];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _recipientNameController.dispose();
    _recipientEmailController.dispose();
    _templateIdController.dispose();
    for (final controller in _customFieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value;
    final creationState = ref.watch(certificateCreationProvider);

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Check if user has permission to create certificates
    if (currentUser.role != UserRole.systemAdmin && 
        currentUser.role != UserRole.certificateAuthority) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Create Certificate'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock,
                size: 80,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: AppTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'You do not have permission to create certificates.',
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(widget.certificateId != null ? 'Edit Certificate' : 'Create Certificate'),
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Progress indicator
              _buildProgressIndicator(),
              // Form content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _currentStep = index;
                    });
                  },
                  children: [
                    _buildBasicInfoStep(),
                    _buildRecipientInfoStep(),
                    _buildCertificateDetailsStep(),
                    _buildReviewStep(),
                  ],
                ),
              ),
              // Navigation buttons
              _buildNavigationButtons(),
            ],
          ),
          // Loading overlay
          if (creationState.isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      color: AppTheme.primaryColor,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          final isCompleted = index < _currentStep;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.white30,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            Icons.check,
                            color: AppTheme.primaryColor,
                            size: 20,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive 
                                  ? AppTheme.primaryColor 
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStepTitle(index),
                  style: AppTheme.bodySmall.copyWith(
                    color: isActive ? Colors.white : Colors.white60,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _getStepTitle(int index) {
    switch (index) {
      case 0:
        return 'Basic Info';
      case 1:
        return 'Recipient';
      case 2:
        return 'Details';
      case 3:
        return 'Review';
      default:
        return '';
    }
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FadeInUp(
        duration: const Duration(milliseconds: 600),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Certificate Information',
                    style: AppTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  
                  // Certificate Name
                  CustomTextField(
                    controller: _nameController,
                    label: 'Certificate Name',
                    hintText: 'Enter certificate name',
                    prefixIcon: Icons.card_membership,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter certificate name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Certificate Type
                  Text(
                    'Certificate Type',
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<CertificateType>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: CertificateType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Icon(
                                _getCertificateTypeIcon(type),
                                size: 20,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Text(type.displayName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Description
                  CustomTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    hintText: 'Enter certificate description',
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter certificate description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  // Template ID (optional)
                  CustomTextField(
                    controller: _templateIdController,
                    label: 'Template ID (Optional)',
                    hintText: 'Enter template ID if using a template',
                    prefixIcon: Icons.dashboard_customize,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FadeInUp(
        duration: const Duration(milliseconds: 600),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recipient Information',
                  style: AppTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                
                // Recipient Name
                CustomTextField(
                  controller: _recipientNameController,
                  label: 'Recipient Name',
                  hintText: 'Enter recipient\'s full name',
                  prefixIcon: Icons.person,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter recipient name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Recipient Email
                CustomTextField(
                  controller: _recipientEmailController,
                  label: 'Recipient Email',
                  hintText: 'Enter recipient\'s email address',
                  prefixIcon: Icons.email,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter recipient email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                
                // Additional recipient fields based on certificate type
                if (_selectedType == CertificateType.academic) ...[
                  Text(
                    'Academic Information',
                    style: AppTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildCustomField('Student ID', 'studentId', Icons.badge),
                  const SizedBox(height: 16),
                  _buildCustomField('Course', 'course', Icons.school),
                  const SizedBox(height: 16),
                  _buildCustomField('Grade', 'grade', Icons.grade),
                ] else if (_selectedType == CertificateType.professional) ...[
                  Text(
                    'Professional Information',
                    style: AppTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildCustomField('Job Title', 'jobTitle', Icons.work),
                  const SizedBox(height: 16),
                  _buildCustomField('Department', 'department', Icons.business),
                ] else if (_selectedType == CertificateType.completion) ...[
                  Text(
                    'Completion Information',
                    style: AppTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildCustomField('Training Course', 'trainingCourse', Icons.library_books),
                  const SizedBox(height: 16),
                  _buildCustomField('Duration', 'duration', Icons.timer),
                  const SizedBox(height: 16),
                  _buildCustomField('Score', 'score', Icons.assessment),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCertificateDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FadeInUp(
        duration: const Duration(milliseconds: 600),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Certificate Details',
                  style: AppTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                
                // Expiry Date
                ListTile(
                  leading: const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                  title: const Text('Expiry Date'),
                  subtitle: Text(
                    _expiryDate != null
                        ? DateFormat('dd MMM yyyy').format(_expiryDate!)
                        : 'No expiry date',
                  ),
                  trailing: TextButton(
                    onPressed: _selectExpiryDate,
                    child: Text(_expiryDate != null ? 'Change' : 'Set'),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                
                // Public Certificate
                SwitchListTile(
                  title: const Text('Public Certificate'),
                  subtitle: const Text('Make this certificate publicly viewable'),
                  value: _isPublic,
                  onChanged: (value) {
                    setState(() {
                      _isPublic = value;
                    });
                  },
                  secondary: const Icon(Icons.public, color: AppTheme.primaryColor),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                
                // Tags
                ListTile(
                  leading: const Icon(Icons.label, color: AppTheme.primaryColor),
                  title: const Text('Tags'),
                  subtitle: _tags.isEmpty
                      ? const Text('No tags added')
                      : Wrap(
                          spacing: 8,
                          children: _tags.map((tag) {
                            return Chip(
                              label: Text(tag),
                              onDeleted: () {
                                setState(() {
                                  _tags.remove(tag);
                                });
                              },
                            );
                          }).toList(),
                        ),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addTag,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                
                // Signatures
                ListTile(
                  leading: const Icon(Icons.draw, color: AppTheme.primaryColor),
                  title: const Text('Signatures'),
                  subtitle: Text('${_signatures.length} signature(s) configured'),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addSignature,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                
                // Display configured signatures
                if (_signatures.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ...(_signatures.map((sig) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        _getSignatureIcon(sig.type),
                        color: AppTheme.primaryColor,
                      ),
                      title: Text(sig.signerName),
                      subtitle: Text(sig.type.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _signatures.remove(sig);
                          });
                        },
                      ),
                    ),
                  ))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    final currentUser = ref.watch(currentUserProvider).value!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: FadeInUp(
        duration: const Duration(milliseconds: 600),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Certificate',
                      style: AppTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    
                    // Certificate Preview
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Icon(
                                _getCertificateTypeIcon(_selectedType),
                                size: 32,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _nameController.text,
                                      style: AppTheme.titleLarge,
                                    ),
                                    Text(
                                      _selectedType.displayName,
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          
                          // Description
                          Text(
                            'Description',
                            style: AppTheme.titleSmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(_descriptionController.text),
                          const SizedBox(height: 16),
                          
                          // Recipient
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Recipient',
                                      style: AppTheme.titleSmall.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(_recipientNameController.text),
                                    Text(
                                      _recipientEmailController.text,
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Issuer',
                                      style: AppTheme.titleSmall.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(currentUser.displayName),
                                    Text(
                                      currentUser.profile['organizationName'] ?? currentUser.email,
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Additional Info
                          if (_expiryDate != null) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.event,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Expires on ${DateFormat('dd MMM yyyy').format(_expiryDate!)}',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (_isPublic) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.public,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Public Certificate',
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (_tags.isNotEmpty) ...[
                            Wrap(
                              spacing: 8,
                              children: _tags.map((tag) {
                                return Chip(
                                  label: Text(
                                    tag,
                                    style: AppTheme.bodySmall,
                                  ),
                                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Custom Data Summary
                    if (_customData.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Additional Fields',
                        style: AppTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ..._customData.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Text(
                                '${_formatFieldName(entry.key)}:',
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(entry.value.toString()),
                            ],
                          ),
                        );
                      }),
                    ],
                    
                    // Signatures Summary
                    if (_signatures.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Signatures',
                        style: AppTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ..._signatures.map((sig) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                _getSignatureIcon(sig.type),
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text('${sig.signerName} (${sig.type.name})'),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Warning message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.warningColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.warningColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please review all information carefully. Once created, certificates cannot be edited.',
                      style: AppTheme.bodyMedium,
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

  Widget _buildNavigationButtons() {
    final isLastStep = _currentStep == 3;
    final isFirstStep = _currentStep == 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!isFirstStep)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Previous'),
              ),
            ),
          if (!isFirstStep) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: isLastStep ? _createCertificate : _nextStep,
              child: Text(isLastStep ? 'Create Certificate' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomField(String label, String key, IconData icon) {
    _customFieldControllers[key] ??= TextEditingController();
    
    return CustomTextField(
      controller: _customFieldControllers[key]!,
      label: label,
      hintText: 'Enter $label',
      prefixIcon: icon,
      onChanged: (value) {
        _customData[key] = value;
      },
    );
  }

  void _nextStep() {
    if (_currentStep == 0 && !_validateBasicInfo()) return;
    if (_currentStep == 1 && !_validateRecipientInfo()) return;
    
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousStep() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool _validateBasicInfo() {
    return _formKey.currentState?.validate() ?? false;
  }

  bool _validateRecipientInfo() {
    if (_recipientNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter recipient name')),
      );
      return false;
    }
    if (_recipientEmailController.text.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
            .hasMatch(_recipientEmailController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return false;
    }
    return true;
  }

  Future<void> _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _addTag() async {
    final controller = TextEditingController();
    final tag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter tag',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    
    if (tag != null && tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
      });
    }
  }

  Future<void> _addSignature() async {
    final result = await showDialog<SignatureInfo>(
      context: context,
      builder: (context) => _AddSignatureDialog(),
    );
    
    if (result != null) {
      setState(() {
        _signatures.add(result);
      });
    }
  }

  Future<void> _createCertificate() async {
    final currentUser = ref.read(currentUserProvider).value!;
    
    try {
      await ref.read(certificateCreationProvider.notifier).createCertificate(
        templateId: _templateIdController.text.isEmpty ? '' : _templateIdController.text,
        issuerId: currentUser.id,
        recipientId: '', // This should be looked up from recipient email
        recipientEmail: _recipientEmailController.text,
        recipientName: _recipientNameController.text,
        organizationId: currentUser.organizationId ?? '',
        organizationName: currentUser.profile['organizationName'] ?? 'UPM',
        title: _nameController.text,
        description: _descriptionController.text,
        type: _selectedType,
        completedAt: null,
        expiresAt: _expiryDate,
        metadata: _customData,
        tags: _tags,
        notes: null,
        requiresApproval: false,
        approvalSteps: [],
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificate created successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        context.go('/certificates');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating certificate: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  IconData _getCertificateTypeIcon(CertificateType type) {
    switch (type) {
      case CertificateType.academic:
        return Icons.school;
      case CertificateType.professional:
        return Icons.work;
      case CertificateType.completion:
        return Icons.library_books;
      case CertificateType.achievement:
        return Icons.emoji_events;
      case CertificateType.participation:
        return Icons.people;
      case CertificateType.recognition:
        return Icons.card_membership;
      case CertificateType.custom:
        return Icons.description;
    }
  }

  IconData _getSignatureIcon(SignatureType type) {
    switch (type) {
      case SignatureType.digital:
        return Icons.vpn_key;
      case SignatureType.visual:
        return Icons.draw;
      case SignatureType.qrCode:
        return Icons.qr_code;
      case SignatureType.watermark:
        return Icons.water_drop;
    }
  }

  String _formatFieldName(String fieldName) {
    return fieldName
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ')
        .trim();
  }
}

// Dialog for adding signatures
class _AddSignatureDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddSignatureDialog> createState() => _AddSignatureDialogState();
}

class _AddSignatureDialogState extends ConsumerState<_AddSignatureDialog> {
  final _signerNameController = TextEditingController();
  final _signerPositionController = TextEditingController();
  SignatureType _selectedType = SignatureType.digital;

  @override
  void dispose() {
    _signerNameController.dispose();
    _signerPositionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value!;
    
    return AlertDialog(
      title: const Text('Add Signature'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _signerNameController,
              decoration: const InputDecoration(
                labelText: 'Signer Name',
                hintText: 'Enter signer\'s name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _signerPositionController,
              decoration: const InputDecoration(
                labelText: 'Position',
                hintText: 'Enter signer\'s position',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SignatureType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Signature Type',
              ),
              items: SignatureType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_signerNameController.text.isNotEmpty) {
              const uuid = Uuid();
              Navigator.pop(
                context,
                SignatureInfo(
                  id: uuid.v4(),
                  signerId: currentUser.id,
                  signerName: _signerNameController.text,
                  signerPosition: _signerPositionController.text.isEmpty ? null : _signerPositionController.text,
                  type: _selectedType,
                  data: '',
                  signedAt: DateTime.now(),
                ),
              );
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
} 
