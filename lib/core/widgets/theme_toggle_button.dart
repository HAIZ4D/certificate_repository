import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

class ThemeToggleButton extends ConsumerWidget {
  final double? size;
  final Color? iconColor;
  final bool showLabel;
  final String? tooltip;

  const ThemeToggleButton({
    super.key,
    this.size,
    this.iconColor,
    this.showLabel = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeModeNotifier = ref.read(themeModeProvider.notifier);

    final icon = _getThemeIcon(themeMode);
    final label = _getThemeLabel(themeMode);

    if (showLabel) {
      return FadeIn(
        child: OutlinedButton.icon(
          onPressed: () => _showThemeBottomSheet(context, themeMode, themeModeNotifier),
          icon: Icon(icon, size: size ?? 20),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: iconColor ?? Theme.of(context).iconTheme.color,
          ),
        ),
      );
    }

    return ZoomIn(
      child: IconButton(
        onPressed: () => _showThemeBottomSheet(context, themeMode, themeModeNotifier),
        icon: Icon(icon, size: size ?? 24),
        color: iconColor ?? Theme.of(context).iconTheme.color,
        tooltip: tooltip ?? 'Change theme',
      ),
    );
  }

  IconData _getThemeIcon(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  String _getThemeLabel(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'Auto';
    }
  }

  void _showThemeBottomSheet(
    BuildContext context,
    ThemeMode currentTheme,
    ThemeModeNotifier themeModeNotifier,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ThemeSelectionBottomSheet(
        currentTheme: currentTheme,
        themeModeNotifier: themeModeNotifier,
      ),
    );
  }
}

class ThemeSelectionBottomSheet extends StatelessWidget {
  final ThemeMode currentTheme;
  final ThemeModeNotifier themeModeNotifier;

  const ThemeSelectionBottomSheet({
    super.key,
    required this.currentTheme,
    required this.themeModeNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Text(
            'Choose Appearance',
            style: AppTheme.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your preferred theme mode',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          
          // Theme options
          _buildThemeOption(
            context,
            'System Default',
            'Automatically adjust based on your device settings',
            Icons.brightness_auto_outlined,
            ThemeMode.system,
          ),
          _buildThemeOption(
            context,
            'Light Mode',
            'Always use the light theme',
            Icons.light_mode_outlined,
            ThemeMode.light,
          ),
          _buildThemeOption(
            context,
            'Dark Mode',
            'Always use the dark theme',
            Icons.dark_mode_outlined,
            ThemeMode.dark,
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    ThemeMode themeMode,
  ) {
    final isSelected = currentTheme == themeMode;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppTheme.primaryColor
              : Colors.grey.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : Colors.transparent,
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.grey[600],
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppTheme.primaryColor : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTheme.bodySmall.copyWith(
            color: Colors.grey[600],
          ),
        ),
        trailing: isSelected
            ? const Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
              )
            : null,
        onTap: () async {
          themeModeNotifier.setThemeMode(themeMode);
          if (context.mounted) {
            Navigator.of(context).pop();
            
            // Show confirmation
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(
                      icon,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text('Theme changed to $title'),
                  ],
                ),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

// Quick theme toggle that cycles through modes
class QuickThemeToggle extends ConsumerWidget {
  const QuickThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final themeModeNotifier = ref.read(themeModeProvider.notifier);

    return IconButton(
      onPressed: () => _cycleTheme(ref, themeModeNotifier),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Icon(
          _getThemeIcon(themeMode),
          key: ValueKey(themeMode),
        ),
      ),
      tooltip: 'Toggle theme',
    );
  }

  IconData _getThemeIcon(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  void _cycleTheme(WidgetRef ref, ThemeModeNotifier themeModeNotifier) {
    final currentTheme = ref.read(themeModeProvider);
    ThemeMode nextTheme;

    switch (currentTheme) {
      case ThemeMode.light:
        nextTheme = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        nextTheme = ThemeMode.system;
        break;
      case ThemeMode.system:
        nextTheme = ThemeMode.light;
        break;
    }

    themeModeNotifier.setThemeMode(nextTheme);
  }
} 
