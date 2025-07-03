import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/certificate_model.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/certificate_pdf_service.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/certificate_providers.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/app_config.dart';

class CertificateDetailPage extends ConsumerStatefulWidget {
  final String certificateId;

  const CertificateDetailPage({
    super.key,
    required this.certificateId,
  });

  @override
  ConsumerState<CertificateDetailPage> createState() =>
      _CertificateDetailPageState();
}

class _CertificateDetailPageState extends ConsumerState<CertificateDetailPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final certificateAsync =
    ref.watch(certificateDetailProvider(widget.certificateId));
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      body: certificateAsync.when(
        data: (certificate) {
          if (certificate == null) {
            return _buildNotFoundPage();
          }
          return _buildCertificateDetail(certificate, user);
        },
        loading: () => _buildLoadingPage(),
        error: (error, stack) => _buildErrorPage(error.toString()),
      ),
    );
  }

  Widget _buildCertificateDetail(
      CertificateModel certificate, UserModel? user) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          _buildAppBar(certificate, user),
          _buildCertificateHeader(certificate),
          _buildTabBar(),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(certificate),
          _buildVerificationTab(certificate),
          _buildHistoryTab(certificate),
        ],
      ),
    );
  }

  Widget _buildAppBar(CertificateModel certificate, UserModel? user) {
    final canEdit = user != null &&
        (user.id == certificate.issuerId || user.isAdmin) &&
        certificate.status == CertificateStatus.draft;

    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: _getStatusColor(certificate.status),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getStatusColor(certificate.status),
                _getStatusColor(certificate.status).withValues(alpha: 0.8),
              ],
            ),
          ),
        ),
      ),
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back, color: Colors.white),
      ),
      actions: [
        if (certificate.canBeShared)
          IconButton(
            onPressed: () => _shareCertificate(certificate),
            icon: const Icon(Icons.share, color: Colors.white),
          ),
        if (certificate.pdfUrl != null)
          IconButton(
            onPressed: () => _downloadCertificate(certificate),
            icon: const Icon(Icons.download, color: Colors.white),
          ),
        if (canEdit)
          IconButton(
            onPressed: () => _editCertificate(certificate),
            icon: const Icon(Icons.edit, color: Colors.white),
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) => _handleMenuAction(value, certificate, user),
          itemBuilder: (context) => [
            if (_canApproveCertificate(certificate, user))
              const PopupMenuItem(
                value: 'approve',
                child: ListTile(
                  leading: Icon(Icons.check_circle_outline),
                  title: Text('Approve'),
                ),
              ),
            if (_canRevokeCertificate(certificate, user))
              const PopupMenuItem(
                value: 'revoke',
                child: ListTile(
                  leading: Icon(Icons.block),
                  title: Text('Revoke'),
                ),
              ),
            if (_canDeleteCertificate(certificate, user))
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCertificateHeader(CertificateModel certificate) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        decoration: const BoxDecoration(
          color: AppTheme.backgroundLight,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusL),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInUp(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    decoration: BoxDecoration(
                      color: _getTypeColor(certificate.type)
                          .withValues(alpha: 0.1),
                      borderRadius: AppTheme.mediumRadius,
                    ),
                    child: Icon(
                      _getTypeIcon(certificate.type),
                      color: _getTypeColor(certificate.type),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingL),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          certificate.title,
                          style: AppTheme.headlineMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          certificate.typeDisplayName,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(certificate.status),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingL),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: Text(
                certificate.description,
                style: AppTheme.bodyLarge,
              ),
            ),
            if (certificate.isExpired || certificate.isRevoked) ...[
              const SizedBox(height: AppTheme.spacingM),
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: _buildWarningBanner(certificate),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Verification'),
            Tab(text: 'History'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab(CertificateModel certificate) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(
            title: 'Recipient Information',
            icon: Icons.person_outline,
            children: [
              _buildInfoRow('Name', certificate.recipientName),
              _buildInfoRow('Email', certificate.recipientEmail),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          _buildInfoSection(
            title: 'Certificate Information',
            icon: Icons.description,
            children: [
              _buildInfoRow('Type', certificate.typeDisplayName),
              _buildInfoRow('Status', certificate.statusDisplayName),
              _buildInfoRow('Issued Date', _formatDate(certificate.issuedAt)),
              if (certificate.completedAt != null)
                _buildInfoRow(
                    'Completion Date', _formatDate(certificate.completedAt!)),
              if (certificate.expiresAt != null)
                _buildInfoRow(
                    'Expiry Date', _formatDate(certificate.expiresAt!)),
            ],
          ),
          if (certificate.courseName.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingL),
            _buildInfoSection(
              title: 'Course Details',
              icon: Icons.school,
              children: [
                _buildInfoRow('Course Name', certificate.courseName),
                if (certificate.courseCode.isNotEmpty)
                  _buildInfoRow('Course Code', certificate.courseCode),
                if (certificate.grade.isNotEmpty)
                  _buildInfoRow('Grade', certificate.grade),
                if (certificate.credits != null)
                  _buildInfoRow('Credits', certificate.credits.toString()),
                if (certificate.achievement.isNotEmpty)
                  _buildInfoRow('Achievement', certificate.achievement),
              ],
            ),
          ],
          const SizedBox(height: AppTheme.spacingL),
          _buildInfoSection(
            title: 'Organization',
            icon: Icons.business,
            children: [
              _buildInfoRow('Organization', certificate.organizationName),
              _buildInfoRow('Verification ID', certificate.verificationId),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),



  Widget _buildVerificationTab(CertificateModel certificate) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(
            title: 'QR Code',
            icon: Icons.qr_code,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingL),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppTheme.mediumRadius,
                    border: Border.all(
                      color: AppTheme.dividerColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: QrImageView(
                    data: certificate.qrCode,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              Text(
                'Scan this QR code to verify the certificate authenticity',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          _buildInfoSection(
            title: 'Verification Details',
            icon: Icons.verified,
            children: [
              _buildInfoRow('Verification ID', certificate.verificationId),
              _buildInfoRow(
                  'Digital Signature',
                  certificate.digitalSignature.isNotEmpty
                      ? 'Present'
                      : 'Not Available'),
              _buildInfoRow('Verification Level',
                  certificate.verificationLevel.name.toUpperCase()),
              _buildInfoRow(
                  'Is Verified', certificate.isVerified ? 'Yes' : 'No'),
              _buildInfoRow('Access Count', certificate.accessCount.toString()),
              _buildInfoRow('Verification Count',
                  certificate.verificationCount.toString()),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          _buildInfoSection(
            title: 'Security Information',
            icon: Icons.security,
            children: [
              _buildInfoRow('Created', _formatDateTime(certificate.createdAt)),
              _buildInfoRow(
                  'Last Updated', _formatDateTime(certificate.updatedAt)),
              if (certificate.lastAccessedAt != null)
                _buildInfoRow('Last Accessed',
                    _formatDateTime(certificate.lastAccessedAt!)),
              _buildInfoRow('Version', certificate.version.toString()),
            ],
          ),
        ],
      ),
    );
  }
          // Share Link Button (2B Work)
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                final url =
                    '${AppConfig.verificationBaseUrl}/${certificate.verificationCode}';
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Share link copied to clipboard!')),
                );
              },
              icon: const Icon(Icons.link),
              label: const Text('Copy Secure Share Link'),
            ),
          ),
          if (certificate.tags.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingL),
            _buildTagsSection(certificate.tags),
          ],
          if (certificate.notes != null && certificate.notes!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingL),
            _buildInfoSection(
              title: 'Notes',
              icon: Icons.note,
              children: [
                Text(
                  certificate.notes!,
                  style: AppTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildHistoryTab(CertificateModel certificate) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(
            title: 'Certificate Timeline',
            icon: Icons.timeline,
            children: [
              _buildTimelineItem(
                'Created',
                certificate.createdAt,
                Icons.add_circle_outline,
                AppTheme.primaryColor,
              ),
              if (certificate.status != CertificateStatus.draft)
                _buildTimelineItem(
                  'Issued',
                  certificate.issuedAt,
                  Icons.check_circle_outline,
                  AppTheme.successColor,
                ),
              if (certificate.isRevoked)
                _buildTimelineItem(
                  'Revoked',
                  certificate.updatedAt,
                  Icons.block,
                  AppTheme.errorColor,
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          _buildInfoSection(
            title: 'Statistics',
            icon: Icons.analytics,
            children: [
              _buildInfoRow('Downloads', certificate.downloadCount.toString()),
              _buildInfoRow('Shares', certificate.shareCount.toString()),
              _buildInfoRow(
                  'Verifications', certificate.verificationCount.toString()),
              _buildInfoRow('Total Access', certificate.accessCount.toString()),
            ],
          ),
          if (certificate.shareTokens.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingL),
            _buildInfoSection(
              title: 'Share Tokens',
              icon: Icons.share,
              children: certificate.shareTokens
                  .map((token) => _buildShareTokenItem(token))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        decoration: BoxDecoration(
          color: AppTheme.backgroundLight,
          borderRadius: AppTheme.mediumRadius,
          border: Border.all(
            color: AppTheme.dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  title,
                  style: AppTheme.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection(List<String> tags) {
    return _buildInfoSection(
      title: 'Tags',
      icon: Icons.local_offer,
      children: [
        Wrap(
          spacing: AppTheme.spacingS,
          runSpacing: AppTheme.spacingS,
          children: tags
              .map((tag) => Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingS,
              vertical: AppTheme.spacingXS,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: AppTheme.smallRadius,
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              tag,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
      String title, DateTime date, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingS),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatDateTime(date),
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareTokenItem(ShareToken token) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: token.isValid
            ? AppTheme.successColor.withValues(alpha: 0.1)
            : AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.smallRadius,
        border: Border.all(
          color: token.isValid
              ? AppTheme.successColor.withValues(alpha: 0.3)
              : AppTheme.errorColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                token.isValid ? Icons.check_circle : Icons.error,
                color:
                token.isValid ? AppTheme.successColor : AppTheme.errorColor,
                size: 16,
              ),
              const SizedBox(width: AppTheme.spacingXS),
              Text(
                token.isValid ? 'Active' : 'Expired',
                style: AppTheme.bodySmall.copyWith(
                  color: token.isValid
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${token.currentAccess}/${token.maxAccess}',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Text(
            'Created: ${_formatDateTime(token.createdAt)}',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            'Expires: ${_formatDateTime(token.expiresAt)}',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(CertificateStatus status) {
    final color = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppTheme.smallRadius,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: AppTheme.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildWarningBanner(CertificateModel certificate) {
    String message;
    Color color;
    IconData icon;

    if (certificate.isExpired) {
      message = 'This certificate has expired';
      color = AppTheme.errorColor;
      icon = Icons.error_outline;
    } else if (certificate.isRevoked) {
      message = 'This certificate has been revoked';
      color = AppTheme.errorColor;
      icon = Icons.block;
    } else {
      return const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppTheme.smallRadius,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              message,
              style: AppTheme.bodyMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPage() {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorPage(String error) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'Failed to load certificate',
              style: AppTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              error,
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingL),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificate Not Found'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.description_outlined,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: AppTheme.spacingL),
            Text(
              'Certificate not found',
              style: AppTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.spacingS),
            Text(
              'The certificate you are looking for does not exist or has been removed.',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingL),
            ElevatedButton(
              onPressed: () => context.go('/certificates'),
              child: const Text('View All Certificates'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(CertificateStatus status) {
    switch (status) {
      case CertificateStatus.draft:
        return AppTheme.textSecondary;
      case CertificateStatus.pending:
        return AppTheme.warningColor;
      case CertificateStatus.approved:
        return AppTheme.infoColor;
      case CertificateStatus.issued:
        return AppTheme.successColor;
      case CertificateStatus.revoked:
        return AppTheme.errorColor;
      case CertificateStatus.expired:
        return AppTheme.textSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _getTypeColor(CertificateType type) {
    switch (type) {
      case CertificateType.academic:
        return AppTheme.primaryColor;
      case CertificateType.professional:
        return AppTheme.successColor;
      case CertificateType.achievement:
        return AppTheme.warningColor;
      case CertificateType.completion:
        return AppTheme.infoColor;
      case CertificateType.participation:
        return AppTheme.textSecondary;
      case CertificateType.recognition:
        return Colors.purple;
      case CertificateType.custom:
        return AppTheme.textSecondary;
    }
  }

  IconData _getTypeIcon(CertificateType type) {
    switch (type) {
      case CertificateType.academic:
        return Icons.school_outlined;
      case CertificateType.professional:
        return Icons.work_outline;
      case CertificateType.achievement:
        return Icons.emoji_events_outlined;
      case CertificateType.completion:
        return Icons.task_alt_outlined;
      case CertificateType.participation:
        return Icons.group_outlined;
      case CertificateType.recognition:
        return Icons.star_outline;
      case CertificateType.custom:
        return Icons.description_outlined;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  bool _canApproveCertificate(CertificateModel certificate, UserModel? user) {
    if (user == null || !user.canApproveCertificates) return false;

    return certificate.status == CertificateStatus.pending &&
        certificate.approvalSteps.any(
                (step) => step.approverId == user.id && step.status == 'pending');
  }

  bool _canRevokeCertificate(CertificateModel certificate, UserModel? user) {
    if (user == null) return false;

    return (user.id == certificate.issuerId || user.isAdmin) &&
        certificate.status == CertificateStatus.issued;
  }

  bool _canDeleteCertificate(CertificateModel certificate, UserModel? user) {
    if (user == null) return false;

    return (user.id == certificate.issuerId || user.isAdmin) &&
        certificate.status == CertificateStatus.draft;
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
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Generating certificate PDF...'),
              const SizedBox(height: 8),
              Text(
                'Certificate: ${certificate.title}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      // Use real PDF generation service
      final pdfService = CertificatePdfService();

      // Generate PDF
      final pdfBytes = await pdfService.generateCertificatePdf(certificate);

      // Upload to storage and get download URL
      final downloadUrl =
      await pdfService.uploadPdfToStorage(pdfBytes, certificate);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Download or share the PDF
      if (Platform.isAndroid || Platform.isIOS) {
        // For mobile, use sharing
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'certificate_${certificate.verificationId}.pdf',
        );
      } else {
        // For desktop/web, save locally or open in browser
        final fileName = 'certificate_${certificate.verificationId}.pdf';
        final localPath =
        await pdfService.downloadPdfLocally(pdfBytes, fileName);

        // Try to open the file
        final uri = Uri.file(localPath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Certificate "${certificate.title}" downloaded successfully'),
                ),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View Online',
              textColor: Colors.white,
              onPressed: () async {
                final uri = Uri.parse(downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Failed to download certificate: ${e.toString()}')),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _editCertificate(CertificateModel certificate) {
    context.go('/certificates/${certificate.id}/edit');
  }

  void _handleMenuAction(
      String action, CertificateModel certificate, UserModel? user) {
    switch (action) {
      case 'approve':
        _approveCertificate(certificate, user);
        break;
      case 'revoke':
        _revokeCertificate(certificate, user);
        break;
      case 'delete':
        _deleteCertificate(certificate, user);
        break;
    }
  }

  void _approveCertificate(CertificateModel certificate, UserModel? user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Certificate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to approve this certificate?'),
            const SizedBox(height: 16),
            Text(
              'Certificate: ${certificate.title}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Recipient: ${certificate.recipientName}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                // Show loading
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Approving certificate...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }

                // Actual approval process - simplified version for quick approval
                if (user == null) throw Exception('User not authenticated');

                await ref.read(certificateServiceProvider).updateCertificate(
                  widget.certificateId,
                  {
                    'status': 'approved',
                    'approvedAt': FieldValue.serverTimestamp(),
                    'approvedBy': user.id,
                    'updatedAt': FieldValue.serverTimestamp(),
                  },
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Certificate approved successfully'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );

                  // Refresh the page
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to approve certificate: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _revokeCertificate(CertificateModel certificate, UserModel? user) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Certificate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to revoke this certificate? This action cannot be undone.',
              style: TextStyle(color: AppTheme.errorColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Certificate: ${certificate.title}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Recipient: ${certificate.recipientName}'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for revocation',
                border: OutlineInputBorder(),
                hintText: 'Enter reason...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason for revocation'),
                    backgroundColor: AppTheme.warningColor,
                  ),
                );
                return;
              }

              Navigator.of(context).pop();

              try {
                // Show loading
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Revoking certificate...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }

                // Actual revocation process
                if (user == null) throw Exception('User not authenticated');

                await ref.read(certificateServiceProvider).updateCertificate(
                  certificate.id,
                  {
                    'status': 'revoked',
                    'isRevoked': true,
                    'revocationReason': reasonController.text.trim(),
                    'revokedBy': user.id,
                    'revokedAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  },
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Certificate revoked successfully'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }

                // Navigate back
                if (mounted) {
                  context.go('/certificates');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to revoke certificate: $e'),
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

  void _deleteCertificate(CertificateModel certificate, UserModel? user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Certificate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this certificate? This action cannot be undone.',
              style: TextStyle(color: AppTheme.errorColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Certificate: ${certificate.title}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Status: ${certificate.status.name.toUpperCase()}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              try {
                // Show loading
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Deleting certificate...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }

                // Actual deletion process
                if (user == null) throw Exception('User not authenticated');

                await ref.read(certificateServiceProvider).deleteCertificate(
                  certificate.id,
                  user.id,
                );

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Certificate deleted successfully'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                }

                // Navigate back
                if (mounted) {
                  context.go('/certificates');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete certificate: $e'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
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
