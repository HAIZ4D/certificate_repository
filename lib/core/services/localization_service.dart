import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_localizations.dart';
import 'logger_service.dart';

class LocalizationService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  Locale _currentLocale = const Locale('en', 'US');

  Locale get currentLocale => _currentLocale;

  /// Initialize localization service
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_languageKey);
      
      if (savedLanguage != null) {
        _currentLocale = _getLocaleFromCode(savedLanguage);
        LoggerService.info('Loaded saved language: $savedLanguage');
      } else {
        // Use system locale if supported, otherwise default to English
        final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
        if (_isSupportedLocale(systemLocale)) {
          _currentLocale = systemLocale;
          LoggerService.info('Using system locale: ${systemLocale.languageCode}');
        } else {
          LoggerService.info('System locale not supported, using English');
        }
      }
      
      notifyListeners();
    } catch (e) {
      LoggerService.error('Failed to initialize localization service', error: e);
    }
  }

  /// Change language
  Future<void> changeLanguage(Locale locale) async {
    try {
      if (!_isSupportedLocale(locale)) {
        throw Exception('Unsupported locale: ${locale.languageCode}');
      }

      _currentLocale = locale;
      
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, locale.languageCode);
      
      LoggerService.info('Language changed to: ${locale.languageCode}');
      notifyListeners();
    } catch (e) {
      LoggerService.error('Failed to change language', error: e);
      rethrow;
    }
  }

  /// Get supported languages
  List<LanguageOption> getSupportedLanguages() {
    return [
      const LanguageOption(
        locale: Locale('en', 'US'),
        name: 'English',
        nativeName: 'English',
        flag: '🇺🇸',
        isDefault: true,
      ),
      const LanguageOption(
        locale: Locale('ms', 'MY'),
        name: 'Bahasa Malaysia',
        nativeName: 'Bahasa Malaysia',
        flag: '🇲🇾',
        isDefault: false,
      ),
      const LanguageOption(
        locale: Locale('zh', 'CN'),
        name: 'Chinese (Simplified)',
        nativeName: 'Simplified Chinese',
        flag: '🇨🇳',
        isDefault: false,
      ),
    ];
  }

  /// Get current language option
  LanguageOption getCurrentLanguageOption() {
    return getSupportedLanguages().firstWhere(
      (option) => option.locale.languageCode == _currentLocale.languageCode,
      orElse: () => getSupportedLanguages().first,
    );
  }

  /// Check if locale is supported
  bool _isSupportedLocale(Locale locale) {
    return AppLocalizations.supportedLocales
        .any((supported) => supported.languageCode == locale.languageCode);
  }

  /// Get locale from language code
  Locale _getLocaleFromCode(String languageCode) {
    switch (languageCode) {
      case 'en':
        return const Locale('en', 'US');
      case 'ms':
        return const Locale('ms', 'MY');
      case 'zh':
        return const Locale('zh', 'CN');
      default:
        return const Locale('en', 'US');
    }
  }

  /// Get localized text for common keys
  String getLocalizedText(BuildContext context, String key) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) return key;

    switch (key) {
      case 'app_name':
        return localizations.appName;
      case 'loading':
        return localizations.loading;
      case 'error':
        return localizations.error;
      case 'success':
        return localizations.success;
      case 'cancel':
        return localizations.cancel;
      case 'confirm':
        return localizations.confirm;
      case 'save':
        return localizations.save;
      case 'delete':
        return localizations.delete;
      case 'edit':
        return localizations.edit;
      case 'close':
        return localizations.close;
      case 'retry':
        return localizations.retry;
      default:
        return key;
    }
  }

  /// Format date according to current locale
  String formatDate(DateTime date) {
    switch (_currentLocale.languageCode) {
      case 'ms':
        return '${date.day}/${date.month}/${date.year}';
      case 'zh':
        return '${date.year}/${date.month}/${date.day}';
      default:
        return '${date.month}/${date.day}/${date.year}';
    }
  }

  /// Format time according to current locale
  String formatTime(DateTime time) {
    switch (_currentLocale.languageCode) {
      case 'ms':
      case 'zh':
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      default:
        final hour = time.hour > 12 ? time.hour - 12 : time.hour;
        final period = time.hour >= 12 ? 'PM' : 'AM';
        return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
    }
  }

  /// Get text direction for current locale
  TextDirection getTextDirection() {
    // All supported languages use LTR
    return TextDirection.ltr;
  }

  /// Reset to default language
  Future<void> resetToDefault() async {
    await changeLanguage(const Locale('en', 'US'));
  }
}

class LanguageOption {
  final Locale locale;
  final String name;
  final String nativeName;
  final String flag;
  final bool isDefault;

  const LanguageOption({
    required this.locale,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.isDefault,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LanguageOption && other.locale == locale;
  }

  @override
  int get hashCode => locale.hashCode;
}

// Riverpod providers
final localizationServiceProvider = ChangeNotifierProvider<LocalizationService>((ref) {
  return LocalizationService();
});

final currentLocaleProvider = Provider<Locale>((ref) {
  return ref.watch(localizationServiceProvider).currentLocale;
});

final supportedLanguagesProvider = Provider<List<LanguageOption>>((ref) {
  return ref.read(localizationServiceProvider).getSupportedLanguages();
});

final currentLanguageProvider = Provider<LanguageOption>((ref) {
  return ref.read(localizationServiceProvider).getCurrentLanguageOption();
}); 