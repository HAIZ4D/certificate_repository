import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_theme.dart';

class SocialLoginButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String icon;
  final String text;
  final String? subtitle;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double? elevation;

  const SocialLoginButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.text,
    this.subtitle,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.elevation,
  });

  @override
  State<SocialLoginButton> createState() => _SocialLoginButtonState();
}

class _SocialLoginButtonState extends State<SocialLoginButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
  }

  void _handleTapCancel() {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: widget.onPressed != null ? _handleTapDown : null,
            onTapUp: widget.onPressed != null ? _handleTapUp : null,
            onTapCancel: widget.onPressed != null ? _handleTapCancel : null,
            onTap: widget.isLoading ? null : widget.onPressed,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.spacingM,
                horizontal: AppTheme.spacingL,
              ),
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? AppTheme.backgroundLight,
                borderRadius: AppTheme.mediumRadius,
                border: Border.all(
                  color: widget.borderColor ?? AppTheme.dividerColor,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                  if (_isPressed)
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                ],
              ),
              child: widget.isLoading
                  ? _buildLoadingContent()
                  : _buildContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return Row(
      children: [
        // Icon
        Flexible(
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              borderRadius: AppTheme.smallRadius,
            ),
            child: widget.icon.endsWith('.svg')
                ? SvgPicture.asset(
                    widget.icon,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  )
                : Image.asset(
                    widget.icon,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
          ),
        ),
        
        const SizedBox(width: AppTheme.spacingM),
        
        // Text content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.text,
                style: AppTheme.bodyLarge.copyWith(
                  color: widget.textColor ?? AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.subtitle!,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Arrow icon
        Flexible(
          child: Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: widget.textColor ?? AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.textColor ?? AppTheme.primaryColor,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Text(
          'Signing you in...',
          style: AppTheme.bodyLarge.copyWith(
            color: widget.textColor ?? AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Google Sign-In Button
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SocialLoginButton(
      onPressed: onPressed,
      isLoading: isLoading,
      icon: 'assets/icons/google.svg',
      text: 'Continue with Google',
      subtitle: 'Use your UPM email address',
    );
  }
}

// Custom Social Button with Icon
class CustomSocialButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String text;
  final String? subtitle;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final bool isLoading;

  const CustomSocialButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.text,
    this.subtitle,
    this.iconColor,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: AppTheme.mediumRadius,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppTheme.spacingM,
              horizontal: AppTheme.spacingL,
            ),
            decoration: BoxDecoration(
              color: backgroundColor ?? AppTheme.backgroundLight,
              borderRadius: AppTheme.mediumRadius,
              border: Border.all(
                color: borderColor ?? AppTheme.dividerColor,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            textColor ?? AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingM),
                      Text(
                        'Please wait...',
                        style: AppTheme.bodyLarge.copyWith(
                          color: textColor ?? AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        icon,
                        size: 24,
                        color: iconColor ?? AppTheme.primaryColor,
                      ),
                      
                      const SizedBox(width: AppTheme.spacingM),
                      
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              text,
                              style: AppTheme.bodyLarge.copyWith(
                                color: textColor ?? AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: textColor ?? AppTheme.textSecondary,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// Apple Sign-In Button (for future use)
class AppleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const AppleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomSocialButton(
      onPressed: onPressed,
      isLoading: isLoading,
      icon: Icons.apple,
      text: 'Continue with Apple',
      subtitle: 'Sign in with your Apple ID',
      iconColor: Colors.black,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      borderColor: Colors.black,
    );
  }
}

// Microsoft Sign-In Button (for future use)
class MicrosoftSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const MicrosoftSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomSocialButton(
      onPressed: onPressed,
      isLoading: isLoading,
      icon: Icons.business,
      text: 'Continue with Microsoft',
      subtitle: 'Use your Microsoft account',
      iconColor: const Color(0xFF0078D4),
    );
  }
} 
