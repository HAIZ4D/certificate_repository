import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFF2E7D32); // UPM Green
  static const Color secondaryColor = Color(0xFF1976D2); // Blue
  static const Color accentColor = Color(0xFF1976D2); // Blue
  static const Color backgroundColor = Color(0xFFF8FFFE);
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  
  // Semantic Colors
  static const Color errorColor = Color(0xFFD32F2F);
  static const Color warningColor = Color(0xFFF57C00);
  static const Color successColor = Color(0xFF388E3C);
  static const Color infoColor = Color(0xFF1976D2);
  
  // Text Colors
  static const Color textColor = Color(0xFF1A1A1A);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textSecondaryColor = Color(0xFF757575);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnPrimaryColor = Color(0xFFFFFFFF);
  
  // Additional Colors
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color dividerColor = Color(0xFFBDBDBD);
  static const Color shadowColor = Color(0x1A000000);
  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, Color(0xFF4CAF50)],
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentColor, Color(0xFF42A5F5)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FA)],
  );

  // Shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  // Typography - Text Theme
  static TextTheme get textTheme => GoogleFonts.interTextTheme(
    const TextTheme(
      // Display Text Styles
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: textColor,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textColor,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: textColor,
      ),
      
      // Headline Text Styles
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textColor,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textColor,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textColor,
      ),
      
      // Title Text Styles
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: textColor,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        color: textColor,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textColor,
      ),
      
      // Label Text Styles
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: textColor,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: textColor,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: textColor,
      ),
      
      // Body Text Styles
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: textColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: textColor,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: textColor,
      ),
    ),
  );

  // Spacing Constants
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // Component Themes
  static ElevatedButtonThemeData get elevatedButtonTheme => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: textOnPrimaryColor,
      backgroundColor: primaryColor,
      elevation: 2,
      shadowColor: shadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      textStyle: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: textOnPrimaryColor,
      ),
    ),
  );

  static OutlinedButtonThemeData get outlinedButtonTheme => OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      backgroundColor: Colors.transparent,
      side: const BorderSide(color: primaryColor, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      textStyle: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
    ),
  );

  static TextButtonThemeData get textButtonTheme => TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textStyle: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
    ),
  );

  static InputDecorationTheme get inputDecorationTheme => InputDecorationTheme(
    filled: true,
    fillColor: surfaceColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: errorColor),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: errorColor, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondaryColor),
    labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondaryColor),
    errorStyle: textTheme.bodySmall?.copyWith(color: errorColor),
  );

  static AppBarTheme get appBarTheme => AppBarTheme(
    backgroundColor: primaryColor,
    foregroundColor: textOnPrimaryColor,
    elevation: 2,
    shadowColor: shadowColor,
    centerTitle: true,
    titleTextStyle: textTheme.titleLarge?.copyWith(
      color: textOnPrimaryColor,
      fontWeight: FontWeight.w600,
    ),
    iconTheme: const IconThemeData(
      color: textOnPrimaryColor,
      size: 24,
    ),
  );

  static CardThemeData get cardTheme => CardThemeData(
    color: surfaceColor,
    elevation: 2,
    shadowColor: shadowColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    margin: const EdgeInsets.all(8),
  );

  static ChipThemeData get chipTheme => ChipThemeData(
    backgroundColor: backgroundColor,
    selectedColor: primaryColor.withValues(alpha: 0.2),
    disabledColor: borderColor,
    labelStyle: textTheme.bodySmall,
    secondaryLabelStyle: textTheme.bodySmall?.copyWith(color: textOnPrimaryColor),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
  );

  static FloatingActionButtonThemeData get floatingActionButtonTheme => FloatingActionButtonThemeData(
    backgroundColor: primaryColor,
    foregroundColor: textOnPrimaryColor,
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );

  static TabBarThemeData get tabBarTheme => TabBarThemeData(
    labelColor: primaryColor,
    unselectedLabelColor: textSecondaryColor,
    labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    unselectedLabelStyle: textTheme.titleSmall,
    indicator: const UnderlineTabIndicator(
      borderSide: BorderSide(color: primaryColor, width: 3),
      insets: EdgeInsets.symmetric(horizontal: 16),
    ),
  );

  static BottomNavigationBarThemeData get bottomNavigationBarTheme => BottomNavigationBarThemeData(
    backgroundColor: surfaceColor,
    selectedItemColor: primaryColor,
    unselectedItemColor: textSecondaryColor,
    selectedLabelStyle: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
    unselectedLabelStyle: textTheme.bodySmall,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  );

  static ListTileThemeData get listTileTheme => ListTileThemeData(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    tileColor: surfaceColor,
    textColor: textColor,
    iconColor: textSecondaryColor,
  );

  // Complete Light Theme
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    
    // Color Scheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: accentColor,
      surface: surfaceColor,
      error: errorColor,
      onPrimary: textOnPrimaryColor,
      onSecondary: textOnPrimaryColor,
      onSurface: textColor,
      onError: textOnPrimaryColor,
    ),
    
    // Typography
    textTheme: textTheme,
    
    // Component Themes
    elevatedButtonTheme: elevatedButtonTheme,
    outlinedButtonTheme: outlinedButtonTheme,
    textButtonTheme: textButtonTheme,
    inputDecorationTheme: inputDecorationTheme,
    appBarTheme: appBarTheme,
    cardTheme: cardTheme,
    chipTheme: chipTheme,
    floatingActionButtonTheme: floatingActionButtonTheme,
    tabBarTheme: tabBarTheme,
    bottomNavigationBarTheme: bottomNavigationBarTheme,
    listTileTheme: listTileTheme,
    
    // Additional Properties
    scaffoldBackgroundColor: backgroundColor,
    canvasColor: surfaceColor,
    dividerColor: dividerColor,
    shadowColor: shadowColor,
    
    // Icon Theme
    iconTheme: const IconThemeData(
      color: textColor,
      size: 24,
    ),
    
    // Material Properties
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  // Dark Theme
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    
    // Color Scheme for Dark Mode
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      secondary: accentColor,
      surface: const Color(0xFF1E1E1E),
      error: errorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      onError: Colors.white,
    ),
    
    // Typography for Dark Mode
    textTheme: textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    
    // Dark Component Themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF424242)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF424242)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: TextStyle(color: Colors.grey[400]),
      labelStyle: TextStyle(color: Colors.grey[300]),
    ),
    
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    
    cardTheme: CardThemeData(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF1E1E1E),
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey[400],
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    
    listTileTheme: ListTileThemeData(
      tileColor: const Color(0xFF1E1E1E),
      textColor: Colors.white,
      iconColor: Colors.grey[300],
    ),
    
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF1E1E1E),
      titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    
    // Additional Properties for Dark Mode
    scaffoldBackgroundColor: const Color(0xFF121212),
    canvasColor: const Color(0xFF1E1E1E),
    dividerColor: const Color(0xFF424242),
    shadowColor: Colors.black54,
    
    // Icon Theme for Dark Mode
    iconTheme: const IconThemeData(
      color: Colors.white,
      size: 24,
    ),
    
    // Material Properties
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  // Animation Durations
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration slowAnimation = Duration(milliseconds: 600);
  
  // Border Radius
  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(8));
  static const BorderRadius mediumRadius = BorderRadius.all(Radius.circular(12));
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius extraLargeRadius = BorderRadius.all(Radius.circular(24));
  
  // Radius constants for backward compatibility
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  
  // Spacing
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;
  
  // Elevation
  static const double elevation0 = 0.0;
  static const double elevation1 = 1.0;
  static const double elevation2 = 2.0;
  static const double elevation4 = 4.0;
  static const double elevation8 = 8.0;
  static const double elevation16 = 16.0;

  // Backward compatibility getters for text styles
  static TextStyle get displayLarge => textTheme.displayLarge ?? const TextStyle();
  static TextStyle get displayMedium => textTheme.displayMedium ?? const TextStyle();
  static TextStyle get displaySmall => textTheme.displaySmall ?? const TextStyle();
  static TextStyle get headlineLarge => textTheme.headlineLarge ?? const TextStyle();
  static TextStyle get headlineMedium => textTheme.headlineMedium ?? const TextStyle();
  static TextStyle get headlineSmall => textTheme.headlineSmall ?? const TextStyle();
  static TextStyle get titleLarge => textTheme.titleLarge ?? const TextStyle();
  static TextStyle get titleMedium => textTheme.titleMedium ?? const TextStyle();
  static TextStyle get titleSmall => textTheme.titleSmall ?? const TextStyle();
  static TextStyle get labelLarge => textTheme.labelLarge ?? const TextStyle();
  static TextStyle get labelMedium => textTheme.labelMedium ?? const TextStyle();
  static TextStyle get labelSmall => textTheme.labelSmall ?? const TextStyle();
  static TextStyle get bodyLarge => textTheme.bodyLarge ?? const TextStyle();
  static TextStyle get bodyMedium => textTheme.bodyMedium ?? const TextStyle();
  static TextStyle get bodySmall => textTheme.bodySmall ?? const TextStyle();

  // Additional backward compatibility getters
  static Color get textHint => textSecondaryColor;
} 
