import 'dart:async';
import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en', 'US'), // English
    Locale('ms', 'MY'), // Bahasa Malaysia
    Locale('zh', 'CN'), // Chinese (Simplified)
  ];

  // Common
  String get appName => _localizedValues[locale.languageCode]!['app_name']!;
  String get loading => _localizedValues[locale.languageCode]!['loading']!;
  String get error => _localizedValues[locale.languageCode]!['error']!;
  String get success => _localizedValues[locale.languageCode]!['success']!;
  String get cancel => _localizedValues[locale.languageCode]!['cancel']!;
  String get confirm => _localizedValues[locale.languageCode]!['confirm']!;
  String get save => _localizedValues[locale.languageCode]!['save']!;
  String get delete => _localizedValues[locale.languageCode]!['delete']!;
  String get edit => _localizedValues[locale.languageCode]!['edit']!;
  String get close => _localizedValues[locale.languageCode]!['close']!;
  String get retry => _localizedValues[locale.languageCode]!['retry']!;

  // Authentication
  String get login => _localizedValues[locale.languageCode]!['login']!;
  String get logout => _localizedValues[locale.languageCode]!['logout']!;
  String get register => _localizedValues[locale.languageCode]!['register']!;
  String get email => _localizedValues[locale.languageCode]!['email']!;
  String get password => _localizedValues[locale.languageCode]!['password']!;
  String get forgotPassword => _localizedValues[locale.languageCode]!['forgot_password']!;
  String get resetPassword => _localizedValues[locale.languageCode]!['reset_password']!;

  // Dashboard
  String get dashboard => _localizedValues[locale.languageCode]!['dashboard']!;
  String get certificates => _localizedValues[locale.languageCode]!['certificates']!;
  String get documents => _localizedValues[locale.languageCode]!['documents']!;
  String get profile => _localizedValues[locale.languageCode]!['profile']!;
  String get settings => _localizedValues[locale.languageCode]!['settings']!;

  // Certificates
  String get createCertificate => _localizedValues[locale.languageCode]!['create_certificate']!;
  String get verifyCertificate => _localizedValues[locale.languageCode]!['verify_certificate']!;
  String get certificateTitle => _localizedValues[locale.languageCode]!['certificate_title']!;
  String get recipientName => _localizedValues[locale.languageCode]!['recipient_name']!;
  String get issueDate => _localizedValues[locale.languageCode]!['issue_date']!;
  String get expiryDate => _localizedValues[locale.languageCode]!['expiry_date']!;

  // Profile
  String get editProfile => _localizedValues[locale.languageCode]!['edit_profile']!;
  String get changePassword => _localizedValues[locale.languageCode]!['change_password']!;
  String get language => _localizedValues[locale.languageCode]!['language']!;
  String get selectLanguage => _localizedValues[locale.languageCode]!['select_language']!;
  String get exportData => _localizedValues[locale.languageCode]!['export_data']!;

  // Support
  String get helpSupport => _localizedValues[locale.languageCode]!['help_support']!;
  String get liveChat => _localizedValues[locale.languageCode]!['live_chat']!;
  String get contactSupport => _localizedValues[locale.languageCode]!['contact_support']!;
  String get startChat => _localizedValues[locale.languageCode]!['start_chat']!;

  // Messages
  String get languageChanged => _localizedValues[locale.languageCode]!['language_changed']!;
  String get dataExported => _localizedValues[locale.languageCode]!['data_exported']!;
  String get chatStarted => _localizedValues[locale.languageCode]!['chat_started']!;

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': 'UPM Digital Certificates',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'close': 'Close',
      'retry': 'Retry',
      'login': 'Login',
      'logout': 'Logout',
      'register': 'Register',
      'email': 'Email',
      'password': 'Password',
      'forgot_password': 'Forgot Password',
      'reset_password': 'Reset Password',
      'dashboard': 'Dashboard',
      'certificates': 'Certificates',
      'documents': 'Documents',
      'profile': 'Profile',
      'settings': 'Settings',
      'create_certificate': 'Create Certificate',
      'verify_certificate': 'Verify Certificate',
      'certificate_title': 'Certificate Title',
      'recipient_name': 'Recipient Name',
      'issue_date': 'Issue Date',
      'expiry_date': 'Expiry Date',
      'edit_profile': 'Edit Profile',
      'change_password': 'Change Password',
      'language': 'Language',
      'select_language': 'Select Language',
      'export_data': 'Export Data',
      'help_support': 'Help & Support',
      'live_chat': 'Live Chat',
      'contact_support': 'Contact Support',
      'start_chat': 'Start Chat',
      'language_changed': 'Language changed successfully',
      'data_exported': 'Data exported successfully',
      'chat_started': 'Chat session started',
    },
    'ms': {
      'app_name': 'Sijil Digital UPM',
      'loading': 'Memuatkan...',
      'error': 'Ralat',
      'success': 'Berjaya',
      'cancel': 'Batal',
      'confirm': 'Sahkan',
      'save': 'Simpan',
      'delete': 'Padam',
      'edit': 'Edit',
      'close': 'Tutup',
      'retry': 'Cuba Lagi',
      'login': 'Log Masuk',
      'logout': 'Log Keluar',
      'register': 'Daftar',
      'email': 'E-mel',
      'password': 'Kata Laluan',
      'forgot_password': 'Lupa Kata Laluan',
      'reset_password': 'Set Semula Kata Laluan',
      'dashboard': 'Papan Pemuka',
      'certificates': 'Sijil',
      'documents': 'Dokumen',
      'profile': 'Profil',
      'settings': 'Tetapan',
      'create_certificate': 'Cipta Sijil',
      'verify_certificate': 'Sahkan Sijil',
      'certificate_title': 'Tajuk Sijil',
      'recipient_name': 'Nama Penerima',
      'issue_date': 'Tarikh Dikeluarkan',
      'expiry_date': 'Tarikh Tamat',
      'edit_profile': 'Edit Profil',
      'change_password': 'Tukar Kata Laluan',
      'language': 'Bahasa',
      'select_language': 'Pilih Bahasa',
      'export_data': 'Eksport Data',
      'help_support': 'Bantuan & Sokongan',
      'live_chat': 'Sembang Langsung',
      'contact_support': 'Hubungi Sokongan',
      'start_chat': 'Mula Sembang',
      'language_changed': 'Bahasa berjaya ditukar',
      'data_exported': 'Data berjaya dieksport',
      'chat_started': 'Sesi sembang dimulakan',
    },
    'zh': {
      'app_name': 'UPM Digital Certificates',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'close': 'Close',
      'retry': 'Retry',
      'login': 'Login',
      'logout': 'Logout',
      'register': 'Register',
      'email': 'Email',
      'password': 'Password',
      'forgot_password': 'Forgot Password',
      'reset_password': 'Reset Password',
      'dashboard': 'Dashboard',
      'certificates': 'Certificates',
      'documents': 'Documents',
      'profile': 'Profile',
      'settings': 'Settings',
      'create_certificate': 'Create Certificate',
      'verify_certificate': 'Verify Certificate',
      'certificate_title': 'Certificate Title',
      'recipient_name': 'Recipient Name',
      'issue_date': 'Issue Date',
      'expiry_date': 'Expiry Date',
      'edit_profile': 'Edit Profile',
      'change_password': 'Change Password',
      'language': 'Language',
      'select_language': 'Select Language',
      'export_data': 'Export Data',
      'help_support': 'Help & Support',
      'live_chat': 'Live Chat',
      'contact_support': 'Contact Support',
      'start_chat': 'Start Chat',
      'language_changed': 'Language changed successfully',
      'data_exported': 'Data exported successfully',
      'chat_started': 'Chat session started',
    },
  };
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ms', 'zh'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
} 