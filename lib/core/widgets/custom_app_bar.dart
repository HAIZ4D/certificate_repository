import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final bool centerTitle;
  final TextStyle? titleStyle;
  final double? elevation;
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.centerTitle = true,
    this.titleStyle,
    this.elevation,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: titleStyle ?? AppTheme.titleLarge.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      centerTitle: centerTitle,
      backgroundColor: backgroundColor ?? AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: elevation ?? 0,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      bottom: bottom,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
  );
} 