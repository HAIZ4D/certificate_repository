import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/certificate_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/providers/auth_providers.dart' as auth_providers;
import '../../providers/certificate_providers.dart';
import '../widgets/certificate_card.dart';
import '../widgets/certificate_filter_dialog.dart';
import '../widgets/certificate_stats_widget.dart';
import '../../../dashboard/services/activity_service.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/config/app_config.dart';

class CertificateListPage extends ConsumerStatefulWidget {
  const CertificateListPage({super.key});

  @override
  ConsumerState<CertificateListPage> createState() => _CertificateListPageState();
}

class _CertificateListPageState extends ConsumerState<CertificateListPage>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  late TabController _tabController;
  bool _isSearching = false;
  String _searchQuery = '';
  final ActivityService _activityService = ActivityService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text != _searchQuery) {
      setState(() {
        _searchQuery = _searchController.text;
      });
      ref.read(certificateFilterProvider.notifier).updateSearchTerm(_searchQuery);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(auth_providers.currentUserProvider).value;
    final canCreate = ref.watch(auth_providers.canCreateCertificatesProvider);
    
        if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
        }
        
        return Scaffold(
          body: NestedScrollView(
            controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildAppBar(user, canCreate),
            _buildStatsSection(),
            _buildTabBar(),
          ];
        },
        body: TabBarView(
          controller: _tabController,
            children: [
            _buildAllCertificatesTab(),
            _buildMyCertificatesTab(),
            if (user.canApproveCertificates) _buildPendingApprovalsTab()
            else _buildSharedCertificatesTab(),
          ],
        ),
      ),
      floatingActionButton: canCreate ? _buildCreateFAB() : null,
    );
  }

  Widget _buildAppBar(UserModel user, bool canCreate) {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FadeInLeft(
                    child: Text(
                      'Certificates',
                      style: AppTheme.headlineLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  FadeInRight(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      _getSubtitleText(user),
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => _showFilterDialog(),
          icon: Stack(
            children: [
              const Icon(Icons.filter_list, color: Colors.white),
              if (_hasActiveFilters())
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.errorColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _toggleSearch(),
          icon: Icon(
            _isSearching ? Icons.close : Icons.search,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
      ],
      bottom: _isSearching ? _buildSearchBar() : null,
    );
  }

  Widget _buildStatsSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
          child: FadeInUp(
          child: const CertificateStatsWidget(),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final user = ref.watch(auth_providers.currentUserProvider).value;
    
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
            controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: AppTheme.titleSmall.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: AppTheme.titleSmall,
          tabs: [
            const Tab(text: 'All'),
            const Tab(text: 'Mine'),
            Tab(text: user?.canApproveCertificates == true ? 'Pending' : 'Shared'),
          ],
        ),
      ),
    );
  }

  Widget _buildAllCertificatesTab() {
    final certificatesAsync = ref.watch(allCertificatesProvider);
    
    return certificatesAsync.when(
      data: (certificates) => _buildCertificatesList(certificates, 'No certificates found'),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorWidget(error.toString()),
    );
  }

  Widget _buildMyCertificatesTab() {
    final currentUser = ref.watch(auth_providers.currentUserProvider).value;
    if (currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final certificatesAsync = ref.watch(userCertificatesProvider(currentUser.id));
    
    return certificatesAsync.when(
      data: (certificates) => _buildCertificatesList(
        certificates, 
        'No certificates found.\nCreate your first certificate!',
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorWidget(error.toString()),
    );
  }

  Widget _buildPendingApprovalsTab() {
    final currentUser = ref.watch(auth_providers.currentUserProvider).value;
    if (currentUser == null || currentUser.organizationId == null) {
      return _buildErrorWidget('No organization assigned');
    }

    final certificatesAsync = ref.watch(pendingCertificatesProvider(currentUser.organizationId!));
    
    return certificatesAsync.when(
      data: (certificates) => _buildCertificatesList(
        certificates, 
        'No pending approvals',
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorWidget(error.toString()),
    );
  }

  Widget _buildSharedCertificatesTab() {
    // For recipients, show certificates shared with them
    final user = ref.watch(auth_providers.currentUserProvider).value;
    if (user == null) return const SizedBox();

    final certificatesAsync = ref.watch(userCertificatesProvider(user.id));
    
    return certificatesAsync.when(
      data: (certificates) => _buildCertificatesList(
        certificates, 
        'No shared certificates',
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorWidget(error.toString()),
    );
  }

  Widget _buildCertificatesList(List<CertificateModel> certificates, String emptyMessage) {
    if (certificates.isEmpty) {
      return _buildEmptyState(emptyMessage);
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh data
        ref.invalidate(allCertificatesProvider);
        ref.invalidate(userCertificatesProvider);
        ref.invalidate(pendingCertificatesProvider);
        ref.invalidate(organizationCertificatesProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        itemCount: certificates.length,
        itemBuilder: (context, index) {
          final certificate = certificates[index];
          return FadeInUp(
            delay: Duration(milliseconds: index * 100),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
              child: CertificateCard(
                certificate: certificate,
                onTap: () => _navigateToCertificateDetail(certificate.id),
                onShare: certificate.canBeShared ? () => _shareCertificate(certificate) : null,
                onDownload: certificate.pdfUrl != null ? () => _downloadCertificate(certificate) : null,
                onEdit: _canEditCertificate(certificate) ? () => _editCertificate(certificate) : null,
                onApprove: _canApproveCertificate(certificate) ? () => _approveCertificate(certificate) : null,
                onRevoke: _canRevokeCertificate(certificate) ? () => _revokeCertificate(certificate) : null,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeInUp(
                child: Icon(
                  Icons.description_outlined,
              size: 80,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Text(
              message,
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
              const SizedBox(height: AppTheme.spacingXL),
          if (ref.watch(auth_providers.canCreateCertificatesProvider))
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: ElevatedButton.icon(
                onPressed: () => context.go('/certificates/create'),
                icon: const Icon(Icons.add),
                label: const Text('Create Certificate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingXL,
                    vertical: AppTheme.spacingM,
                  ),
                ),
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Error loading certificates',
            style: AppTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            error,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(allCertificatesProvider);
              ref.invalidate(userCertificatesProvider);
              ref.invalidate(pendingCertificatesProvider);
              ref.invalidate(organizationCertificatesProvider);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildSearchBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: AppTheme.bodyMedium.copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search certificates...',
            hintStyle: AppTheme.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, color: Colors.white),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                      ref.read(certificateFilterProvider.notifier).updateSearchTerm(null);
                    },
                    icon: const Icon(Icons.clear, color: Colors.white),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildCreateFAB() {
    return FloatingActionButton.extended(
      onPressed: () => context.go('/certificates/create'),
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Create'),
    );
  }

  String _getSubtitleText(UserModel user) {
    if (user.isAdmin) {
      return 'Manage all certificates in your organization';
    } else if (user.isCA) {
      return 'Issue and manage digital certificates';
    } else if (user.isClient) {
      return 'Request and manage certificates for your organization';
    } else {
      return 'View and manage your received certificates';
    }
  }

  bool _hasActiveFilters() {
    final filter = ref.read(certificateFilterProvider);
    return filter.statuses != null ||
           filter.types != null ||
           filter.startDate != null ||
           filter.endDate != null ||
           filter.tags != null ||
           filter.isExpired != null ||
           filter.isVerified != null;
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        ref.read(certificateFilterProvider.notifier).updateSearchTerm(null);
      }
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => const CertificateFilterDialog(),
    );
  }

  void _navigateToCertificateDetail(String certificateId) {
    context.go('/certificates/$certificateId');
  }

  void _shareCertificate(CertificateModel certificate) {
    final shareText = '''
Certificate Details

Title: ${certificate.title}
Recipient: ${certificate.recipientName}
Issued by: ${certificate.organizationName}
Issue Date: ${_formatDate(certificate.issuedAt)}
Status: ${certificate.status.name.toUpperCase()}

Verification ID: ${certificate.verificationId}
Verify at: https://verify.upm.edu.my/${certificate.verificationId}
''';

    Share.share(shareText, subject: 'Certificate: ${certificate.title}');
  }

  void _downloadCertificate(CertificateModel certificate) async {
    try {
      // Show loading snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparing certificate download...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      LoggerService.info('Starting certificate download: ${certificate.id}');

      // Check if certificate has a PDF URL
      if (certificate.pdfUrl != null && certificate.pdfUrl!.isNotEmpty) {
        // Download from existing URL
        await _downloadFromUrl(certificate.pdfUrl!, certificate.title);
      } else {
        // Generate PDF and download
        await _generateAndDownloadPDF(certificate);
      }

      // Log download activity
      await _activityService.logCertificateActivity(
        action: 'certificate_downloaded',
        certificateId: certificate.id,
        details: 'Certificate "${certificate.title}" downloaded',
        metadata: {
          'certificate_title': certificate.title,
          'download_method': certificate.pdfUrl != null ? 'existing_url' : 'generated_pdf',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Certificate "${certificate.title}" downloaded successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }

      LoggerService.info('Certificate download completed: ${certificate.id}');

    } catch (e, stackTrace) {
      LoggerService.error('Failed to download certificate', error: e, stackTrace: stackTrace);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download certificate: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _downloadFromUrl(String url, String filename) async {
    try {
      LoggerService.info('Downloading certificate from Firebase Storage: $url');
      
      // Open the Firebase Storage URL directly for user to download
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        LoggerService.info('Certificate download initiated from URL: $url');
      } else {
        throw Exception('Could not launch download URL');
      }
    } catch (e) {
      LoggerService.error('Failed to download from URL', error: e);
      throw Exception('Failed to download certificate: $e');
    }
  }

  Future<void> _generateAndDownloadPDF(CertificateModel certificate) async {
    try {
      LoggerService.info('Generating PDF for certificate: ${certificate.id}');
      
      // Create PDF document
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'CERTIFICATE OF ${certificate.title.toUpperCase()}',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Issued to: ${certificate.recipientName}', style: const pw.TextStyle(fontSize: 16)),
                pw.Text('Organization: ${certificate.organizationName}', style: const pw.TextStyle(fontSize: 16)),
                pw.Text('Issue Date: ${_formatDate(certificate.issuedAt)}', style: const pw.TextStyle(fontSize: 16)),
                pw.Text('Verification ID: ${certificate.verificationId}', style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 20),
                pw.Text(certificate.description, style: const pw.TextStyle(fontSize: 14)),
                pw.Spacer(),
                pw.Text(
                  'This certificate is digitally signed and verified.', 
                  style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Issued Date:',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '${certificate.issuedAt.day}/${certificate.issuedAt.month}/${certificate.issuedAt.year}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    if (certificate.expiresAt != null) ...[
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Expires:',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        '${certificate.expiresAt!.day}/${certificate.expiresAt!.month}/${certificate.expiresAt!.year}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      );

      // Convert to bytes
      final pdfBytes = await pdf.save();
      
      // Create blob and download in web
      if (kIsWeb) {
        // For web, use url_launcher to open the PDF
        final dataUrl = 'data:application/pdf;base64,${base64Encode(pdfBytes)}';
        await launchUrl(Uri.parse(dataUrl));
      } else {
        // For mobile platforms, save to device storage and show options
        final fileName = '${certificate.title}_${certificate.verificationId}.pdf';
        
        try {
          // Use the printing package to save/share PDF on mobile
          await Printing.sharePdf(
            bytes: pdfBytes,
            filename: fileName,
          );
          
          LoggerService.info('PDF shared successfully on mobile platform');
        } catch (e) {
          LoggerService.error('Failed to share PDF on mobile', error: e);
          
          // Fallback: try to save locally using path_provider
          try {
            final directory = await getApplicationDocumentsDirectory();
            final file = File('${directory.path}/$fileName');
            await file.writeAsBytes(pdfBytes);
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('PDF saved to: ${file.path}'),
                  backgroundColor: AppTheme.successColor,
                  action: SnackBarAction(
                    label: 'Open',
                    onPressed: () async {
                      // Try to open the file
                      try {
                        await launchUrl(Uri.file(file.path));
                      } catch (e) {
                        LoggerService.warning('Could not open PDF file: $e');
                      }
                    },
                  ),
                ),
              );
            }
            
            LoggerService.info('PDF saved locally to: ${file.path}');
          } catch (saveError) {
            LoggerService.error('Failed to save PDF locally', error: saveError);
            throw Exception('Failed to save PDF: $saveError');
          }
        }
      }
      
      LoggerService.info('PDF generated and downloaded for certificate: ${certificate.id}');
      
    } catch (e) {
      LoggerService.error('Failed to generate PDF', error: e);
      throw Exception('Failed to generate certificate PDF: $e');
    }
  }

  void _approveCertificate(CertificateModel certificate) async {
    try {
      final currentUser = ref.read(auth_providers.currentUserProvider).value;
      if (currentUser == null) return;

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Approving certificate...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      LoggerService.info('Approving certificate: ${certificate.id}');

      // Update certificate status in Firebase
      await FirebaseFirestore.instance
          .collection(AppConfig.certificatesCollection)
          .doc(certificate.id)
          .update({
        'status': CertificateStatus.issued.name,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': currentUser.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log approval activity
      await _activityService.logCertificateActivity(
        action: 'certificate_approved',
        certificateId: certificate.id,
        details: 'Certificate "${certificate.title}" approved by ${currentUser.displayName}',
        metadata: {
          'certificate_title': certificate.title,
          'approved_by': currentUser.displayName,
          'approver_id': currentUser.id,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificate approved successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );

        // Refresh the list
        ref.invalidate(allCertificatesProvider);
      }

      LoggerService.info('Certificate approval completed: ${certificate.id}');

    } catch (e, stackTrace) {
      LoggerService.error('Failed to approve certificate', error: e, stackTrace: stackTrace);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve certificate: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _revokeCertificate(CertificateModel certificate) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Certificate'),
        content: Text('Are you sure you want to revoke "${certificate.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                final currentUser = ref.read(auth_providers.currentUserProvider).value;
                if (currentUser == null) return;

                // Show loading
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Revoking certificate...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }

                LoggerService.info('Revoking certificate: ${certificate.id}');

                // Update certificate status in Firebase
                await FirebaseFirestore.instance
                    .collection(AppConfig.certificatesCollection)
                    .doc(certificate.id)
                    .update({
                  'status': CertificateStatus.revoked.name,
                  'revokedAt': FieldValue.serverTimestamp(),
                  'revokedBy': currentUser.id,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                // Log revocation activity
                await _activityService.logCertificateActivity(
                  action: 'certificate_revoked',
                  certificateId: certificate.id,
                  details: 'Certificate "${certificate.title}" revoked by ${currentUser.displayName}',
                  metadata: {
                    'certificate_title': certificate.title,
                    'revoked_by': currentUser.displayName,
                    'revoker_id': currentUser.id,
                  },
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Certificate revoked successfully'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );

                  // Refresh the list
                  ref.invalidate(allCertificatesProvider);
                }

                LoggerService.info('Certificate revocation completed: ${certificate.id}');

              } catch (e, stackTrace) {
                LoggerService.error('Failed to revoke certificate', error: e, stackTrace: stackTrace);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to revoke certificate: ${e.toString()}'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }

  bool _canEditCertificate(CertificateModel certificate) {
    final user = ref.read(auth_providers.currentUserProvider).value;
    if (user == null) return false;
    
    return (user.id == certificate.issuerId || user.isAdmin) &&
           certificate.status == CertificateStatus.draft;
  }

  bool _canApproveCertificate(CertificateModel certificate) {
    final user = ref.read(auth_providers.currentUserProvider).value;
    if (user == null || !user.canApproveCertificates) return false;
    
    return certificate.status == CertificateStatus.pending &&
           certificate.approvalSteps.any((step) => 
               step.approverId == user.id && step.status == 'pending');
  }

  bool _canRevokeCertificate(CertificateModel certificate) {
    final user = ref.read(auth_providers.currentUserProvider).value;
    if (user == null) return false;
    
    return (user.id == certificate.issuerId || user.isAdmin) &&
           certificate.status == CertificateStatus.issued;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _editCertificate(CertificateModel certificate) {
    context.go('/certificates/${certificate.id}/edit');
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _TabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
        color: AppTheme.backgroundLight,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
} 
