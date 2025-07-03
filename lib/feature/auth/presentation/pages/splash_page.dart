import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/models/user_model.dart';
import '../../../auth/providers/auth_providers.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  bool _animationsComplete = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );
    
    _textAnimation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    );
    
    _startAnimations();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _logoController.forward();
    }
    
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      _textController.forward();
    }
    
    // Mark animations as complete after total duration
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) {
      setState(() {
        _animationsComplete = true;
      });
    }
  }

  void _navigateByUserRole(UserModel user) {
    if (!mounted || _hasNavigated) return;
    
    setState(() {
      _hasNavigated = true;
    });
    
    try {
      // Use new getDefaultRoute method for navigation
      final defaultRoute = user.getDefaultRoute();
      
      // Special handling for CA pending status
      if (user.userType == UserType.ca && user.status == UserStatus.pending) {
        context.go('/ca/pending');
        return;
      }
      
      // Special handling for Admin pending status
      if (user.userType == UserType.admin && user.status == UserStatus.pending) {
        context.go('/login');
        return;
      }
      
      // Check user status
      if (user.status != UserStatus.active) {
        // Return inactive users to login page
        context.go('/login');
        return;
      }
      
      // Navigate according to user type
      context.go(defaultRoute);
      
    } catch (e) {
      // Fallback to login if navigation fails
      context.go('/login');
    }
  }

  void _navigateToLogin() {
    if (!mounted || _hasNavigated) return;
    
    setState(() {
      _hasNavigated = true;
    });
    
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes only in build method
    ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (previous, next) {
      if (!mounted || !_animationsComplete || _hasNavigated) return;
      
      // Get auto-login preference
      ref.read(authServiceProvider).shouldAutoLogin().then((shouldAutoLogin) {
        if (!mounted || _hasNavigated) return;
        
        next.when(
          data: (user) {
            if (user != null) {
              // User is logged in, navigate by role regardless of remember me setting
              _navigateByUserRole(user);
            } else {
              // User is not logged in
              _navigateToLogin();
            }
          },
          loading: () {
            // Do nothing while loading, keep showing splash
          },
          error: (error, stack) {
            // Always go to login on error
            _navigateToLogin();
          },
        );
      }).catchError((error) {
        // If shouldAutoLogin fails, go to login
        if (mounted && !_hasNavigated) {
          _navigateToLogin();
        }
      });
    });

    // Handle initial state if not loading when animations complete
    if (_animationsComplete && !_hasNavigated) {
      final currentUserState = ref.read(currentUserProvider);
      if (!currentUserState.isLoading) {
        // Delay slightly to avoid calling during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _hasNavigated) return;
          
          ref.read(authServiceProvider).shouldAutoLogin().then((shouldAutoLogin) {
            if (!mounted || _hasNavigated) return;
            
            currentUserState.when(
              data: (user) {
                if (user != null && shouldAutoLogin) {
                  _navigateByUserRole(user);
                } else if (user != null && !shouldAutoLogin) {
                  ref.read(authServiceProvider).signOut().then((_) {
                    if (mounted && !_hasNavigated) {
                      _navigateToLogin();
                    }
                  }).catchError((error) {
                    if (mounted && !_hasNavigated) {
                      _navigateToLogin();
                    }
                  });
                } else {
                  _navigateToLogin();
                }
              },
              loading: () {
                // Wait for loading to complete
              },
              error: (error, stack) {
                _navigateToLogin();
              },
            );
          }).catchError((error) {
            if (mounted && !_hasNavigated) {
              _navigateToLogin();
            }
          });
        });
      }
    }
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                          MediaQuery.of(context).padding.top - 
                          MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                children: [
                  // Top spacer
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  
                  // Logo section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated logo
                        ScaleTransition(
                          scale: _logoAnimation,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: AppTheme.extraLargeRadius,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  offset: const Offset(0, 8),
                                  blurRadius: 24,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.security_rounded,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: AppTheme.spacingXL),
                        
                        // App name with animation
                        FadeTransition(
                          opacity: _textAnimation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.5),
                              end: Offset.zero,
                            ).animate(_textAnimation),
                            child: Column(
                              children: [
                                Text(
                                  AppConfig.appName,
                                  style: AppTheme.headlineMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                
                                const SizedBox(height: AppTheme.spacingS),
                                
                                Text(
                                  AppConfig.appDescription,
                                  style: AppTheme.bodyLarge.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                  
                  // Loading section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Loading animation
                        FadeInUp(
                          delay: const Duration(milliseconds: 2000),
                          child: Container(
                            width: 60,
                            height: 60,
                            padding: const EdgeInsets.all(AppTheme.spacingM),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: AppTheme.spacingL),
                        
                        // Loading text
                        FadeInUp(
                          delay: const Duration(milliseconds: 2200),
                          child: Text(
                            'Initializing secure connection...',
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  
                  // Bottom section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // University branding
                        FadeInUp(
                          delay: const Duration(milliseconds: 2500),
                          child: Column(
                            children: [
                              Text(
                                'Powered by',
                                style: AppTheme.bodySmall.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacingXS),
                              Text(
                                'Universiti Putra Malaysia',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: AppTheme.spacingL),
                        
                        // Version info
                        FadeInUp(
                          delay: const Duration(milliseconds: 2700),
                          child: Text(
                            'Version ${AppConfig.appVersion}',
                            style: AppTheme.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: AppTheme.spacingL),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 
