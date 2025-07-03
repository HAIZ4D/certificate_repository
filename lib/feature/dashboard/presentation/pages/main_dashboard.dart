import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/providers/auth_providers.dart';

class MainDashboard extends ConsumerStatefulWidget {
  final Widget child;

  const MainDashboard({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard> {
  int _selectedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update selectedIndex on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser != null) {
        final navigationItems = _getNavigationItems(currentUser);
        _updateSelectedIndex(navigationItems);
      }
    });
  }

  // Add method to update selectedIndex based on current route
  void _updateSelectedIndex(List<NavigationItem> navigationItems) {
    final currentLocation = GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;

    for (int i = 0; i < navigationItems.length; i++) {
      if (currentLocation.startsWith(navigationItems[i].route)) {
        if (_selectedIndex != i) {
          setState(() {
            _selectedIndex = i;
          });
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      data: (user) {
        if (user == null) {
          // User not authenticated, redirect to login page
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.go('/login');
            }
          });
          // Show loading indicator during redirection
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final navigationItems = _getNavigationItems(user);

        // Update selected index to match current route
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateSelectedIndex(navigationItems);
        });

        return Scaffold(
          body: widget.child,
          bottomNavigationBar: _buildBottomNavigationBar(navigationItems),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) {
        // Also redirect to login page when error occurs
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/login');
          }
        });
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar(List<NavigationItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, -2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingS,
            vertical: AppTheme.spacingXS,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = _selectedIndex == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                    context.go(item.route);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacingS,
                      horizontal: AppTheme.spacingXS,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: AppTheme.mediumRadius,
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(AppTheme.spacingXS),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.transparent,
                            borderRadius: AppTheme.smallRadius,
                          ),
                          child: Icon(
                            item.icon,
                            size: 24,
                            color: isSelected
                                ? AppTheme.textOnPrimary
                                : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          item.label,
                          style: AppTheme.bodySmall.copyWith(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<NavigationItem> _getNavigationItems(UserModel user) {
    final baseItems = <NavigationItem>[
      const NavigationItem(
        icon: Icons.dashboard_outlined,
        label: 'Dashboard',
        route: '/dashboard',
      ),
      const NavigationItem(
        icon: Icons.description_outlined,
        label: 'Certificates',
        route: '/certificates',
      ),
    ];

    // Add user type specific navigation items
    switch (user.userType) {
      case UserType.admin:
        return [
          ...baseItems,
          const NavigationItem(
            icon: Icons.folder_outlined,
            label: 'Documents',
            route: '/documents',
          ),
          const NavigationItem(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Admin',
            route: '/admin',
          ),
          const NavigationItem(
            icon: Icons.person_outlined,
            label: 'Profile',
            route: '/profile',
          ),
        ];

      case UserType.ca:
        return [
          ...baseItems,
          const NavigationItem(
            icon: Icons.verified_user_outlined,
            label: 'CA Panel',
            route: '/ca',
          ),
          const NavigationItem(
            icon: Icons.person_outlined,
            label: 'Profile',
            route: '/profile',
          ),
        ];

      case UserType.user:
        return [
          ...baseItems,
          const NavigationItem(
            icon: Icons.folder_outlined,
            label: 'Documents',
            route: '/documents',
          ),
          const NavigationItem(
            icon: Icons.person_outlined,
            label: 'Profile',
            route: '/profile',
          ),
        ];
    }
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final String route;

  const NavigationItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
