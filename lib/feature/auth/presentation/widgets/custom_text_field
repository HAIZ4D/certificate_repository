import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function()? onTap;
  final void Function(String)? onSubmitted;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;
  final EdgeInsets? contentPadding;
  final bool autofocus;
  final String? initialValue;

  const CustomTextField({
    super.key,
    this.controller,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onTap,
    this.onSubmitted,
    this.focusNode,
    this.inputFormatters,
    this.contentPadding,
    this.autofocus = false,
    this.initialValue,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _focusAnimation;
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _focusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_handleFocusChange);
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    
    if (_isFocused) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          AnimatedBuilder(
            animation: _focusAnimation,
            builder: (context, child) {
              return Text(
                widget.label!,
                style: AppTheme.bodyMedium.copyWith(
                  color: _hasError
                      ? AppTheme.errorColor
                      : _isFocused
                          ? AppTheme.primaryColor
                          : AppTheme.textSecondary,
                  fontWeight: _isFocused ? FontWeight.w500 : FontWeight.normal,
                ),
              );
            },
          ),
          const SizedBox(height: AppTheme.spacingS),
        ],
        
        AnimatedBuilder(
          animation: _focusAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: AppTheme.mediumRadius,
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: TextFormField(
                controller: widget.controller,
                focusNode: _focusNode,
                initialValue: widget.initialValue,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                obscureText: widget.obscureText,
                enabled: widget.enabled,
                readOnly: widget.readOnly,
                maxLines: widget.maxLines,
                minLines: widget.minLines,
                maxLength: widget.maxLength,
                inputFormatters: widget.inputFormatters,
                autofocus: widget.autofocus,
                onChanged: widget.onChanged,
                onTap: widget.onTap,
                onFieldSubmitted: widget.onSubmitted,
                validator: (value) {
                  final error = widget.validator?.call(value);
                  setState(() {
                    _hasError = error != null;
                  });
                  return error;
                },
                style: AppTheme.bodyLarge.copyWith(
                  color: widget.enabled 
                      ? AppTheme.textPrimary 
                      : AppTheme.textSecondary,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  helperText: widget.helperText,
                  errorText: widget.errorText,
                  prefixIcon: widget.prefixIcon != null
                      ? Icon(
                          widget.prefixIcon,
                          color: _hasError
                              ? AppTheme.errorColor
                              : _isFocused
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary,
                        )
                      : null,
                  suffixIcon: widget.suffixIcon,
                  contentPadding: widget.contentPadding ??
                      const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingM,
                        vertical: AppTheme.spacingM,
                      ),
                  filled: true,
                  fillColor: widget.enabled
                      ? _isFocused
                          ? AppTheme.surfaceColor
                          : AppTheme.surfaceColor.withValues(alpha: 0.5)
                      : AppTheme.surfaceColor.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: AppTheme.mediumRadius,
                    borderSide: BorderSide(
                      color: AppTheme.dividerColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppTheme.mediumRadius,
                    borderSide: BorderSide(
                      color: AppTheme.dividerColor.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: AppTheme.mediumRadius,
                    borderSide: BorderSide(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                  errorBorder: const OutlineInputBorder(
                    borderRadius: AppTheme.mediumRadius,
                    borderSide: BorderSide(
                      color: AppTheme.errorColor,
                      width: 1,
                    ),
                  ),
                  focusedErrorBorder: const OutlineInputBorder(
                    borderRadius: AppTheme.mediumRadius,
                    borderSide: BorderSide(
                      color: AppTheme.errorColor,
                      width: 2,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: AppTheme.mediumRadius,
                    borderSide: BorderSide(
                      color: AppTheme.dividerColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  hintStyle: AppTheme.bodyLarge.copyWith(
                    color: AppTheme.textHint,
                  ),
                  helperStyle: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  errorStyle: AppTheme.bodySmall.copyWith(
                    color: AppTheme.errorColor,
                  ),
                  counterStyle: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// Specialized text fields
class EmailTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  const EmailTextField({
    super.key,
    this.controller,
    this.label = 'Email Address',
    this.hintText = 'Enter your email address',
    this.validator,
    this.onChanged,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      label: label,
      hintText: hintText,
      prefixIcon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: validator ?? _defaultEmailValidator,
      onChanged: onChanged,
      focusNode: focusNode,
      autofocus: autofocus,
    );
  }

  String? _defaultEmailValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email address';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }
}

class PasswordTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final bool autofocus;

  const PasswordTextField({
    super.key,
    this.controller,
    this.label = 'Password',
    this.hintText = 'Enter your password',
    this.validator,
    this.onChanged,
    this.focusNode,
    this.textInputAction = TextInputAction.done,
    this.autofocus = false,
  });

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: widget.controller,
      label: widget.label,
      hintText: widget.hintText,
      prefixIcon: Icons.lock_outline,
      obscureText: !_isPasswordVisible,
      textInputAction: widget.textInputAction,
      validator: widget.validator ?? _defaultPasswordValidator,
      onChanged: widget.onChanged,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
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
    );
  }

  String? _defaultPasswordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
}

class PhoneTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  const PhoneTextField({
    super.key,
    this.controller,
    this.label = 'Phone Number',
    this.hintText = 'Enter your phone number',
    this.validator,
    this.onChanged,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      label: label,
      hintText: hintText,
      prefixIcon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      validator: validator ?? _defaultPhoneValidator,
      onChanged: onChanged,
      focusNode: focusNode,
      autofocus: autofocus,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(15),
      ],
    );
  }

  String? _defaultPhoneValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (value.length < 10) {
      return 'Please enter a valid phone number';
    }
    return null;
  }
} 
