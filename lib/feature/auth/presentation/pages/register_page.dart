import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/validation_service.dart';
import '../../providers/auth_providers.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/social_login_button.dart';

/// RegisterPage
///
/// Multi-step wizard for creating a new account with role selection, field
/// validation, Google sign-up and email/password flow. Handles pending status
/// states for CA/Admin roles.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  late PageController _pageController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  
  int _currentStep = 0;
  UserType? _selectedUserType;
  bool _acceptTerms = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleGoogleSignUp() async {
    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    } catch (e) {
      
      if (mounted) {
        String errorMessage = 'Google sign up failed: ';
        final errorString = e.toString().toLowerCase();
        
        if (errorString.contains('sign_in_canceled')) {
          errorMessage += 'Sign in was canceled.';
        } else if (errorString.contains('network_error')) {
          errorMessage += 'Network error. Please check your internet connection.';
        } else if (errorString.contains('sign_in_failed')) {
          errorMessage += 'Sign in failed. Please try again.';
        } else {
          errorMessage += e.toString();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  bool _validateFieldsManually() {
    // Manually validate each field
    if (_emailController.text.trim().isEmpty) {
      return false;
    }
    
    final emailValidation = ValidationService.validateEmail(_emailController.text.trim());
    if (emailValidation != null) {
      return false;
    }
    
    if (_displayNameController.text.trim().isEmpty || _displayNameController.text.trim().length < 2) {
      return false;
    }
    
    if (_passwordController.text.isEmpty || _passwordController.text.length < AppConfig.passwordMinLength) {
      return false;
    }
    
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(_passwordController.text)) {
      return false;
    }
    
    if (_confirmPasswordController.text != _passwordController.text) {
      return false;
    }
    
    return true;
  }

  void _handleEmailSignUp() async {

    if (!(_formKey.currentState?.validate() ?? false)) {
      // If Form validation fails, try manual validation
      if (!_validateFieldsManually()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all required fields correctly'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        return;
      }
    }
    
    if (_selectedUserType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your user type'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    
    // Validate email according to user type
    if (_selectedUserType == UserType.ca || _selectedUserType == UserType.admin) {
      final upmEmailValidation = ValidationService.validateUpmEmail(_emailController.text.trim());
      if (upmEmailValidation != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(upmEmailValidation),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    }
    
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the terms and conditions'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    try {
      await ref.read(authNotifierProvider.notifier).signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _displayNameController.text.trim(),
        userType: _selectedUserType!,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        String successMessage;
        if (_selectedUserType == UserType.ca) {
          successMessage = 'CA account created successfully! Please wait for admin approval.';
        } else if (_selectedUserType == UserType.admin) {
          successMessage = 'Admin account created successfully! Please wait for approval.';
        } else {
          successMessage = 'Account created successfully! Welcome to UPM Digital Certificates.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        String errorMessage = 'Registration failed: ';
        final errorString = e.toString().toLowerCase();
        
        if (errorString.contains('email-already-in-use')) {
          errorMessage += 'An account with this email already exists.';
        } else if (errorString.contains('weak-password')) {
          errorMessage += 'Password is too weak. Please use a stronger password.';
        } else if (errorString.contains('invalid-email')) {
          errorMessage += 'Invalid email format.';
        } else if (errorString.contains('network-request-failed')) {
          errorMessage += 'Network error. Please check your internet connection.';
        } else if (errorString.contains('upm email')) {
          errorMessage += 'Please use your UPM email address (@upm.edu.my).';
        } else {
          errorMessage += e.toString();
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      if (_currentStep == 0) {
        if (_formKey.currentState?.validate() ?? false) {
          setState(() {
            _currentStep++;
          });
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please fill in all required fields correctly'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      } else if (_currentStep == 1) {
        if (_selectedUserType == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select your user type to continue'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          return;
        }
        
        setState(() {
          _currentStep++;
        });
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        ref.read(authNotifierProvider.notifier).clearError();
      }
      
      if (next.isAuthenticated) {
        final currentUserState = ref.read(currentUserProvider);
        currentUserState.when(
          data: (user) {
            if (user != null) {
              final defaultRoute = user.getDefaultRoute();
              
              if (user.userType == UserType.ca && user.status == UserStatus.pending) {
                context.go('/ca/pending');
              } else if (user.userType == UserType.admin && user.status == UserStatus.pending) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Your admin account is pending approval. Please wait for confirmation.'),
                    backgroundColor: AppTheme.warningColor,
                    duration: Duration(seconds: 5),
                  ),
                );
                context.go('/login');
              } else {
                context.go(defaultRoute);
              }
            } else {
              context.go('/login');
            }
          },
          loading: () {
            // Give user data loading more time, retry if not loaded successfully within 5 seconds
            Future.delayed(const Duration(seconds: 5), () {
              if (!mounted) return;
              
              final userState = ref.read(currentUserProvider);
              if (userState.hasValue && userState.value != null) {
                final user = userState.value!;
                final defaultRoute = user.getDefaultRoute();
                
                if (user.userType == UserType.ca && user.status == UserStatus.pending) {
                  context.go('/ca/pending');
                } else if (user.userType == UserType.admin && user.status == UserStatus.pending) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your admin account is pending approval. Please wait for confirmation.'),
                      backgroundColor: AppTheme.warningColor,
                      duration: Duration(seconds: 5),
                    ),
                  );
                  context.go('/login');
                } else {
                  context.go(defaultRoute);
                }
              } else if (userState.hasError) {
                // If user data loading fails, show error message and return to login page
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to load user data. Please try logging in again.'),
                    backgroundColor: AppTheme.errorColor,
                    duration: Duration(seconds: 5),
                  ),
                );
                context.go('/login');
              } else {
                // Still loading, may have issues, force reload
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Loading user data is taking longer than expected. Please try logging in again.'),
                    backgroundColor: AppTheme.warningColor,
                    duration: Duration(seconds: 5),
                  ),
                );
                context.go('/login');
              }
            });
          },
          error: (error, stack) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading user data: ${error.toString()}'),
                backgroundColor: AppTheme.errorColor,
                duration: const Duration(seconds: 5),
              ),
            );
            context.go('/login');
          },
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildProgressIndicator(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStep1(),
                    _buildStep2(),
                    _buildStep3(),
                  ],
                ),
              ),
              _buildNavigationButtons(authState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(
                  right: i < 2 ? AppTheme.spacingS : 0,
                ),
                decoration: BoxDecoration(
                  color: i <= _currentStep 
                      ? AppTheme.primaryColor 
                      : AppTheme.dividerColor,
                  borderRadius: AppTheme.smallRadius,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    final authState = ref.watch(authNotifierProvider);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spacingL),
          
          FadeInDown(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    borderRadius: AppTheme.extraLargeRadius,
                    gradient: AppTheme.primaryGradient,
                  ),
                  child: const Icon(
                    Icons.person_add_rounded,
                    size: 40,
                    color: AppTheme.textOnPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingL),
                Text(
                  'Create Account',
                  style: AppTheme.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  'Join the secure certificate repository',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          FadeInLeft(
            delay: const Duration(milliseconds: 200),
            child: GoogleSignInButton(
              onPressed: authState.isLoading ? null : _handleGoogleSignUp,
              isLoading: authState.isLoading,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
                  child: Text(
                    'OR',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          FadeInRight(
            delay: const Duration(milliseconds: 600),
            child: CustomTextField(
              controller: _emailController,
              label: 'Email Address',
              hintText: 'Enter your UPM email',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (value) {
                try {
                  // In the first step, only perform basic email format validation
                  // More strict validation will be performed according to user type during final registration
                  return ValidationService.validateEmail(value);
                } catch (e) {
                  return 'Email validation error';
                }
              },
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          FadeInLeft(
            delay: const Duration(milliseconds: 800),
            child: CustomTextField(
              controller: _displayNameController,
              label: 'Full Name',
              hintText: 'Enter your full name',
              prefixIcon: Icons.person_outline,
              validator: (value) {
                try {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  if (value.length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                } catch (e) {
                  return 'Name validation error';
                }
              },
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          FadeInRight(
            delay: const Duration(milliseconds: 1000),
            child: CustomTextField(
              controller: _passwordController,
              label: 'Password',
              hintText: 'Create a strong password',
              obscureText: !_isPasswordVisible,
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible 
                      ? Icons.visibility_off_outlined 
                      : Icons.visibility_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
              validator: (value) {
                try {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < AppConfig.passwordMinLength) {
                    return 'Password must be at least ${AppConfig.passwordMinLength} characters';
                  }
                  if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
                    return 'Password must contain uppercase, lowercase, and number';
                  }
                  return null;
                } catch (e) {
                  return 'Password validation error';
                }
              },
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingM),
          
          FadeInLeft(
            delay: const Duration(milliseconds: 1200),
            child: CustomTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              hintText: 'Confirm your password',
              obscureText: !_isConfirmPasswordVisible,
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _isConfirmPasswordVisible 
                      ? Icons.visibility_off_outlined 
                      : Icons.visibility_outlined,
                ),
                onPressed: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
              ),
              validator: (value) {
                try {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                } catch (e) {
                  return 'Password confirmation validation error';
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spacingL),
          
          FadeInDown(
            child: Column(
              children: [
                Text(
                  'Select Your Role',
                  style: AppTheme.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  'Choose the role that best describes your position',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          ...UserType.values.map((type) {
            final index = UserType.values.indexOf(type);
            return FadeInUp(
              delay: Duration(milliseconds: 200 * index),
              child: _buildRoleCard(type),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRoleCard(UserType type) {
    final isSelected = _selectedUserType == type;
    final typeInfo = _getTypeInfo(type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedUserType = type;
            });
          },
          borderRadius: AppTheme.mediumRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(AppTheme.spacingL),
            decoration: BoxDecoration(
              borderRadius: AppTheme.mediumRadius,
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
                width: isSelected ? 2 : 1,
              ),
              color: isSelected 
                  ? AppTheme.primaryColor.withValues(alpha: 0.05)
                  : AppTheme.backgroundLight,
              boxShadow: isSelected ? AppTheme.cardShadow : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.primaryColor
                        : AppTheme.dividerColor,
                    borderRadius: AppTheme.mediumRadius,
                  ),
                  child: Icon(
                    typeInfo['icon'],
                    color: isSelected 
                        ? AppTheme.textOnPrimary
                        : AppTheme.textSecondary,
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: AppTheme.spacingM),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeInfo['title'],
                        style: AppTheme.titleMedium.copyWith(
                          color: isSelected 
                              ? AppTheme.primaryColor
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        typeInfo['description'],
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (isSelected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: AppTheme.textOnPrimary,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spacingL),
          
          FadeInDown(
            child: Column(
              children: [
                Text(
                  'Terms & Conditions',
                  style: AppTheme.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  'Please review and accept our terms',
                  style: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: Container(
              height: 300,
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.dividerColor),
                borderRadius: AppTheme.mediumRadius,
                color: AppTheme.surfaceColor,
              ),
              child: const SingleChildScrollView(
                child: Text(
                  '''Terms and Conditions for Digital Certificate Repository

1. ACCEPTANCE OF TERMS
By registering and using this application, you agree to be bound by these Terms and Conditions.

2. USER RESPONSIBILITIES
- Provide accurate and truthful information
- Maintain the confidentiality of your account credentials
- Use the service only for legitimate purposes
- Comply with all applicable laws and regulations

3. CERTIFICATE AUTHENTICITY
- Users are responsible for the accuracy of certificate information
- Certificate Authorities must verify all information before issuance
- False or misleading information may result in account suspension

4. DATA PRIVACY
- We collect and process personal data in accordance with our Privacy Policy
- Your data is protected using industry-standard security measures
- You have the right to access, modify, or delete your personal information

5. INTELLECTUAL PROPERTY
- The application and its content are protected by copyright laws
- Users retain ownership of their uploaded content
- Unauthorized use or distribution is prohibited

6. SERVICE AVAILABILITY
- We strive to maintain 99.9% uptime
- Scheduled maintenance will be announced in advance
- We are not liable for service interruptions beyond our control

7. LIMITATION OF LIABILITY
- The service is provided "as is" without warranties
- We are not liable for any indirect or consequential damages
- Our liability is limited to the amount paid for the service

8. MODIFICATIONS
- These terms may be updated from time to time
- Users will be notified of significant changes
- Continued use constitutes acceptance of modified terms

By clicking "I Accept", you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.''',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: Row(
              children: [
                Checkbox(
                  value: _acceptTerms,
                  onChanged: (value) {
                    setState(() {
                      _acceptTerms = value ?? false;
                    });
                  },
                  activeColor: AppTheme.primaryColor,
                ),
                Expanded(
                  child: Text(
                    'I accept the Terms and Conditions and Privacy Policy',
                    style: AppTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(AuthState authState) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: authState.isLoading ? null : _previousStep,
                child: const Text('Previous'),
              ),
            ),
          
          if (_currentStep > 0) const SizedBox(width: AppTheme.spacingM),
          
          Expanded(
            flex: _currentStep == 0 ? 1 : 2,
            child: ElevatedButton(
              onPressed: authState.isLoading ? null : () {
                if (_currentStep < 2) {
                  _nextStep();
                } else {
                  _handleEmailSignUp();
                }
              },
              child: authState.isLoading && _currentStep == 2
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.textOnPrimary,
                        ),
                      ),
                    )
                  : Text(_currentStep < 2 ? 'Next' : 'Create Account'),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getTypeInfo(UserType type) {
    switch (type) {
      case UserType.ca:
        return {
          'title': 'Certificate Authority',
          'description': 'Issue and manage digital certificates',
          'icon': Icons.verified_user_outlined,
        };
      case UserType.admin:
        return {
          'title': 'Administrator',
          'description': 'Full system management access',
          'icon': Icons.admin_panel_settings_outlined,
        };
      case UserType.user:
        return {
          'title': 'User',
          'description': 'General system access - view and manage your certificates',
          'icon': Icons.account_circle_outlined,
        };
    }
  }
} 
