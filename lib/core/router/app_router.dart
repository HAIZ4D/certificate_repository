import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Core models and services
import '../../features/client/presentation/pages/client_dashboard_page.dart';
import '../models/user_model.dart';
import '../services/logger_service.dart';

// Auth
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/admin_setup_page.dart';

// Dashboard
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/dashboard/presentation/pages/main_dashboard.dart';

// Certificates
import '../../features/certificates/presentation/pages/certificate_list_page.dart';
import '../../features/certificates/presentation/pages/certificate_detail_page.dart';
import '../../features/certificates/presentation/pages/create_certificate_page.dart';
import '../../features/certificates/presentation/pages/verify_certificate_page.dart';
import '../../features/certificates/presentation/pages/public_certificate_viewer_page.dart';
import '../../features/certificates/presentation/pages/certificate_templates_page.dart';

// Documents
import '../../features/documents/presentation/pages/document_list_page.dart';
import '../../features/documents/presentation/pages/document_detail_page.dart';
import '../../features/documents/presentation/pages/document_upload_page.dart';

// Profile
import '../../features/profile/presentation/pages/profile_page.dart';

// Notifications
import '../../features/notifications/presentation/pages/notifications_page.dart';

// Help
import '../../features/help/presentation/pages/help_page.dart';

// CA Pages
import '../../features/ca/presentation/pages/ca_dashboard.dart';
import '../../features/ca/presentation/pages/ca_certificate_creation_page.dart';
import '../../features/ca/presentation/pages/ca_pending_approval_page.dart';
import '../../features/ca/presentation/pages/ca_document_review_page.dart';

// Admin Pages
import '../../features/admin/presentation/pages/admin_dashboard.dart';
import '../../features/admin/presentation/pages/ca_approval_page.dart';
import '../../features/admin/presentation/pages/user_management_page.dart';
import '../../features/admin/presentation/pages/admin_settings_page.dart';
import '../../features/admin/presentation/pages/admin_analytics_page.dart';
import '../../features/admin/presentation/pages/admin_backup_page.dart';

// Auth providers for route guards
import '../../features/auth/providers/auth_providers.dart';

// Create aliases for the missing classes
typedef CACreateCertificatePage = CACertificateCreationPage;
typedef DashboardHomePage = DashboardPage;

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),

      // Authentication Routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      
      // System Initialization Routes
      GoRoute(
        path: '/admin-setup',
        builder: (context, state) => const AdminSetupPage(),
      ),

      // CA Pending Route (Outside shell for special layout)
      GoRoute(
        path: '/ca/pending',
        builder: (context, state) => const CAPendingApprovalPage(),
      ),

      // Main Dashboard with Shell Navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainDashboard(child: child),
        routes: [
          // Dashboard Home
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardHomePage(),
          ),

          // ⬇ Add this here
          GoRoute(
            path: '/client-dashboard',
            builder: (context, state) => const ClientDashboardPage(),
          ),

          // Certificates
          GoRoute(
            path: '/certificates',
            builder: (context, state) => const CertificateListPage(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreateCertificatePage(),
              ),
              GoRoute(
                path: 'templates',
                builder: (context, state) => const CertificateTemplatesPage(),
              ),
              GoRoute(
                path: 'pending',
                builder: (context, state) => const CertificateListPage(),
              ),
              GoRoute(
                path: 'issued',
                builder: (context, state) => const CertificateListPage(),
              ),
              GoRoute(
                path: 'downloads',
                builder: (context, state) => const CertificateListPage(),
              ),
              GoRoute(
                path: 'share',
                builder: (context, state) => const CertificateListPage(),
              ),
              GoRoute(
                path: 'request',
                builder: (context, state) => const CreateCertificatePage(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => CertificateDetailPage(
                  certificateId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => CreateCertificatePage(
                      certificateId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),



          // Documents
          GoRoute(
            path: '/documents',
            builder: (context, state) => const DocumentListPage(),
            routes: [
              GoRoute(
                path: 'upload',
                builder: (context, state) => const DocumentUploadPage(),
              ),
              GoRoute(
                path: 'share',
                builder: (context, state) => const DocumentListPage(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => DocumentDetailPage(
                  documentId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'view/:id',
                builder: (context, state) => DocumentDetailPage(
                  documentId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),

          // Profile
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),

          // Admin Routes
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminDashboard(),
            routes: [
              GoRoute(
                path: 'dashboard',
                builder: (context, state) => const AdminDashboard(),
              ),
              GoRoute(
                path: 'users',
                builder: (context, state) => const UserManagementPage(),
              ),
              GoRoute(
                path: 'ca-approvals',
                builder: (context, state) => const CAApprovalPage(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const AdminSettingsPage(),
              ),
              GoRoute(
                path: 'analytics',
                builder: (context, state) => const AdminAnalyticsPage(),
              ),
              GoRoute(
                path: 'backup',
                builder: (context, state) => const AdminBackupPage(),
              ),
            ],
          ),

          // Certificate Authority (CA) Routes
          GoRoute(
            path: '/ca',
            builder: (context, state) => const CADashboard(),
            routes: [
              GoRoute(
                path: 'dashboard',
                builder: (context, state) => const CADashboard(),
              ),
              GoRoute(
                path: 'create-certificate',
                builder: (context, state) => const CACreateCertificatePage(),
              ),
              GoRoute(
                path: 'document-review',
                builder: (context, state) => const CADocumentReviewPage(),
              ),
              GoRoute(
                path: 'pending',
                builder: (context, state) => const CAPendingApprovalPage(),
              ),
            ],
          ),

          // Verification Routes
          GoRoute(
            path: '/verify',
            builder: (context, state) => const VerifyCertificatePage(),
            routes: [
              GoRoute(
                path: 'scanner',
                builder: (context, state) => const VerifyCertificatePage(),
              ),
            ],
          ),

          // Public Routes
          GoRoute(
            path: '/public',
            builder: (context, state) => const VerifyCertificatePage(),
          ),

          // Help Route
          GoRoute(
            path: '/help',
            builder: (context, state) => const HelpPage(),
          ),

          // Notifications Route
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsPage(),
          ),
        ],
      ),

      // Outside the ShellRoute
      GoRoute(
        path: '/verify/:token',
        builder: (context, state) => PublicCertificateViewerPage(
          token: state.pathParameters['token']!,
        ),
      ),


      // Public Viewer (No authentication required)
      GoRoute(
        path: '/view/:token',
        builder: (context, state) => PublicCertificateViewerPage(
          token: state.pathParameters['token']!,
        ),
      ),

      // Error Page
      GoRoute(
        path: '/error',
        builder: (context, state) => ErrorPage(
          error: state.extra as String?,
        ),
      ),
    ],

// Redirect logic for authentication and authorization
    redirect: (context, state) {
      final uriPath = state.uri.path;
      final isOnPublicViewer =
          uriPath.startsWith('/view/') || uriPath.startsWith('/verify/');

      final isOnError = state.uri.path == '/error';

      // Always allow public and error routes
      if (isOnPublicViewer || isOnError) return null;

      // Access providers safely using ProviderScope.containerOf
      late final AsyncValue authState;
      late final AsyncValue currentUserState;
      try {
        final container = ProviderScope.containerOf(context, listen: false);
        authState = container.read(authStateProvider);
        currentUserState = container.read(currentUserProvider);
      } catch (e) {
        // If context is not ready (e.g. during hot reload), skip redirect
        return null;
      }

      final isAuthenticated =
          authState.hasValue && authState.value != null && !authState.hasError;
      final isOnSplash = state.uri.path == '/splash';
      final isOnAuth =
          state.uri.path == '/login' || state.uri.path == '/register';
      final isOnAdminSetup = state.uri.path == '/admin-setup';

      if (isOnAdminSetup && isAuthenticated) {
        return '/dashboard';
      }

      if ((authState.isLoading || currentUserState.isLoading) &&
          !isOnSplash &&
          !isOnAuth) {
        return '/splash';
      }

      if (authState.hasError ||
          (authState.hasValue && authState.value == null)) {
        return isOnAuth || isOnSplash ? null : '/login';
      }

      if (!isAuthenticated && !isOnAuth && !isOnSplash) {
        return '/login';
      }

      if (isAuthenticated && (isOnAuth || isOnSplash)) {
        final user = currentUserState.valueOrNull;
        return user?.getDefaultRoute() ?? '/dashboard';
      }

      // Permission control SINI
      final user = currentUserState.valueOrNull;
      if (isAuthenticated && user != null) {
        final currentPath = state.uri.path;

        if (!user.canAccessPath(currentPath)) {
          LoggerService.warning(
              'Access denied for user ${user.email} to path $currentPath');
          return user.getDefaultRoute();
        }

        if (user.userType == UserType.ca && user.status == UserStatus.pending) {
          if (currentPath != '/ca/pending') return '/ca/pending';
        }

        if (user.userType == UserType.admin &&
            user.status == UserStatus.pending) {
          return isOnAuth ? null : '/login';
        }

        if (user.status != UserStatus.active &&
            user.status != UserStatus.pending) {
          return isOnAuth ? null : '/login';
        }

        if (currentPath.startsWith('/admin') &&
            user.userType != UserType.admin) {
          return user.getDefaultRoute();
        }

        if (currentPath.startsWith('/ca') &&
            user.userType != UserType.ca &&
            user.userType != UserType.admin) {
          return user.getDefaultRoute();
        }
      }

      return null;
    },

    errorBuilder: (context, state) => ErrorPage(
      error: state.error?.toString(),
    ),
  );
}

class ErrorPage extends StatelessWidget {
  final String? error;

  const ErrorPage({super.key, this.error});

  @override
  Widget build(BuildContext context) {
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
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
