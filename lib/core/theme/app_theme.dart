import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts';

/// Enhanced Material Design 3 theme with Android-specific customizations
class AppTheme {
  // Enhanced color palette for cannabis cultivation theme
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFF4CAF50);
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color accentGreen = Color(0xFF81C784);
  static const Color mintGreen = Color(0xFFA5D6A7);

  static const Color leafYellow = Color(0xFFF57F17);
  static const Color leafOrange = Color(0xFFFF8F00);
  static const Color leafBrown = Color(0xFF5D4037);
  static const Color amberAccent = Color(0xFFFFB300);

  static const Color purpleAccent = Color(0xFF9C27B0);
  static const Color deepPurple = Color(0xFF6A1B9A);
  static const Color lavender = Color(0xFFE1BEE7);

  static const Color surfaceWhite = Color(0xFFFAFAFA);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundDark = Color(0xFF121212);

  static const Color errorRed = Color(0xFFD32F2F);
  static const Color warningOrange = Color(0xFFE65100);
  static const Color successGreen = Color(0xFF388E3C);
  static const Color infoBlue = Color(0xFF1976D2);

  // Material Design 3 semantic colors
  static const Color surfaceVariantLight = Color(0xFFF3F4F6);
  static const Color surfaceTintLight = Color(0xFF2E7D32);
  static const Color outlineLight = Color(0xFFD4D4D8);
  static const Color outlineVariantLight = Color(0xFFE4E4E7);

  static const Color surfaceVariantDark = Color(0xFF1F1F1F);
  static const Color surfaceTintDark = Color(0xFF4CAF50);
  static const Color outlineDark = Color(0xFF52525B);
  static const Color outlineVariantDark = Color(0xFF27272A);

  // Enhanced Light Theme with Material Design 3
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Material Design 3 color scheme
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        onPrimary: Colors.white,
        primaryContainer: lightGreen,
        onPrimaryContainer: darkGreen,
        secondary: leafYellow,
        onSecondary: Colors.white,
        secondaryContainer: amberAccent,
        onSecondaryContainer: leafBrown,
        tertiary: purpleAccent,
        onTertiary: Colors.white,
        tertiaryContainer: lavender,
        onTertiaryContainer: deepPurple,
        surface: surfaceWhite,
        onSurface: Colors.black87,
        surfaceVariant: surfaceVariantLight,
        onSurfaceVariant: Colors.black54,
        background: backgroundLight,
        onBackground: Colors.black87,
        error: errorRed,
        onError: Colors.white,
        outline: outlineLight,
        outlineVariant: outlineVariantLight,
        surfaceTint: surfaceTintLight,
        scrim: Colors.black38,
        inverseSurface: Color(0xFF313033),
        onInverseSurface: Color(0xFFF8F4F4),
        inversePrimary: Color(0xFF4CAF50),
      ),

      // Text theme with Google Fonts
      textTheme: GoogleFonts.robotoTextTheme().copyWith(
        displayLarge: GoogleFonts.roboto(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        displayMedium: GoogleFonts.roboto(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        headlineLarge: GoogleFonts.roboto(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        headlineMedium: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        titleLarge: GoogleFonts.roboto(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        titleMedium: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: Colors.black87,
        ),
        bodyMedium: GoogleFonts.roboto(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: Colors.black87,
        ),
        labelLarge: GoogleFonts.roboto(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),

      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: 24,
        ),
      ),

      // Card theme
      cardTheme: CardTheme(
        color: cardWhite,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: primaryGreen, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Floating action button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceWhite,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorRed, width: 1),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: const TextStyle(color: Colors.grey),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey.shade200,
        selectedColor: primaryGreen.withOpacity(0.2),
        disabledColor: Colors.grey.shade100,
        labelStyle: GoogleFonts.roboto(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: GoogleFonts.roboto(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: primaryGreen,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryGreen,
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryGreen;
          }
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryGreen.withOpacity(0.5);
          }
          return Colors.grey.shade300;
        }),
      ),

      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryGreen;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // Radio theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryGreen;
          }
          return Colors.grey.shade600;
        }),
      ),

      // Slider theme
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryGreen,
        inactiveTrackColor: primaryGreen.withOpacity(0.3),
        thumbColor: primaryGreen,
        overlayColor: primaryGreen.withOpacity(0.1),
        valueIndicatorColor: primaryGreen,
        valueIndicatorTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Enhanced Dark Theme with Material Design 3
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Material Design 3 dark color scheme
      colorScheme: const ColorScheme.dark(
        primary: lightGreen,
        onPrimary: Colors.black,
        primaryContainer: darkGreen,
        onPrimaryContainer: mintGreen,
        secondary: amberAccent,
        onSecondary: Colors.black,
        secondaryContainer: leafYellow,
        onSecondaryContainer: leafBrown,
        tertiary: lavender,
        onTertiary: deepPurple,
        tertiaryContainer: purpleAccent,
        onTertiaryContainer: Colors.white,
        surface: surfaceVariantDark,
        onSurface: Colors.white,
        surfaceVariant: Color(0xFF2A2A2A),
        onSurfaceVariant: Colors.white70,
        background: backgroundDark,
        onBackground: Colors.white,
        error: errorRed,
        onError: Colors.white,
        outline: outlineDark,
        outlineVariant: outlineVariantDark,
        surfaceTint: surfaceTintDark,
        scrim: Colors.black54,
        inverseSurface: surfaceWhite,
        onInverseSurface: Colors.black,
        inversePrimary: primaryGreen,
      ),

      // Text theme for dark mode
      textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.roboto(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        displayMedium: GoogleFonts.roboto(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        headlineLarge: GoogleFonts.roboto(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.roboto(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        titleMedium: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: Colors.white70,
        ),
        bodyMedium: GoogleFonts.roboto(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: Colors.white70,
        ),
      ),

      // App bar theme for dark mode
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: 24,
        ),
      ),

      // Card theme for dark mode
      cardTheme: CardTheme(
        color: const Color(0xFF2A2A2A),
        elevation: 2,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Bottom navigation bar theme for dark mode
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        selectedItemColor: lightGreen,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
      ),

      // Input decoration theme for dark mode
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 1),
        ),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: const TextStyle(color: Colors.grey),
      ),
    );
  }

  /// Android-specific theme extensions
  static ThemeData get androidLightTheme {
    return lightTheme.copyWith(
      // Android-specific customizations
      extensions: [
        _AndroidThemeExtension(
          statusBarColor: primaryGreen,
          navigationBarColor: primaryGreen,
          lightStatusBar: true,
          lightNavigationBar: true,
          systemNavBarDividerColor: Colors.transparent,
        ),
      ],
    );
  }

  static ThemeData get androidDarkTheme {
    return darkTheme.copyWith(
      // Android dark theme customizations
      extensions: [
        _AndroidThemeExtension(
          statusBarColor: Colors.transparent,
          navigationBarColor: Colors.transparent,
          lightStatusBar: false,
          lightNavigationBar: false,
          systemNavBarDividerColor: Colors.black12,
        ),
      ],
    );
  }

  /// Custom color schemes for different cultivation stages
  static ThemeData get germinationTheme => _createStageTheme(
        primary: const Color(0xFF66BB6A), // Light green for germination
        secondary: const Color(0xFF42A5F5), // Blue for water
        accent: const Color(0xFF29B6F6), // Light blue
      );

  static ThemeData get vegetativeTheme => _createStageTheme(
        primary: const Color(0xFF4CAF50), // Green for vegetative growth
        secondary: const Color(0xFF66BB6A), // Light green
        accent: const Color(0xFF8BC34A), // Lime green
      );

  static ThemeData get floweringTheme => _createStageTheme(
        primary: const Color(0xFF9C27B0), // Purple for flowering
        secondary: const Color(0xFFBA68C8), // Light purple
        accent: const Color(0xFFFFB300), // Amber for buds
      );

  static ThemeData get harvestingTheme => _createStageTheme(
        primary: const Color(0xFFFF6F00), // Orange for harvest
        secondary: const Color(0xFFF4511E), // Deep orange
        accent: const Color(0xFFFFB300), // Amber
      );

  static ThemeData _createStageTheme({
    required Color primary,
    required Color secondary,
    required Color accent,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        tertiary: accent,
        brightness: Brightness.light,
      ),
    );
  }

  /// Component-specific themes
  static ElevatedButtonThemeData get androidElevatedButtonTheme {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 2,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static CardThemeData get androidCardTheme {
    return CardThemeData(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.all(8),
    );
  }

  static AppBarThemeData get androidAppBarTheme {
    return const AppBarThemeData(
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    );
  }
}

/// Android-specific theme extension
@immutable
class _AndroidThemeExtension extends ThemeExtension<_AndroidThemeExtension> {
  const _AndroidThemeExtension({
    required this.statusBarColor,
    required this.navigationBarColor,
    required this.lightStatusBar,
    required this.lightNavigationBar,
    required this.systemNavBarDividerColor,
  });

  final Color statusBarColor;
  final Color navigationBarColor;
  final bool lightStatusBar;
  final bool lightNavigationBar;
  final Color systemNavBarDividerColor;

  @override
  _AndroidThemeExtension copyWith({
    Color? statusBarColor,
    Color? navigationBarColor,
    bool? lightStatusBar,
    bool? lightNavigationBar,
    Color? systemNavBarDividerColor,
  }) {
    return _AndroidThemeExtension(
      statusBarColor: statusBarColor ?? this.statusBarColor,
      navigationBarColor: navigationBarColor ?? this.navigationBarColor,
      lightStatusBar: lightStatusBar ?? this.lightStatusBar,
      lightNavigationBar: lightNavigationBar ?? this.lightNavigationBar,
      systemNavBarDividerColor: systemNavBarDividerColor ?? this.systemNavBarDividerColor,
    );
  }

  @override
  _AndroidThemeExtension lerp(ThemeExtension<_AndroidThemeExtension>? other, double t) {
    if (other is! _AndroidThemeExtension) {
      return this;
    }

    return _AndroidThemeExtension(
      statusBarColor: Color.lerp(statusBarColor, other.statusBarColor, t)!,
      navigationBarColor: Color.lerp(navigationBarColor, other.navigationBarColor, t)!,
      lightStatusBar: t < 0.5 ? lightStatusBar : other.lightStatusBar,
      lightNavigationBar: t < 0.5 ? lightNavigationBar : other.lightNavigationBar,
      systemNavBarDividerColor: Color.lerp(systemNavBarDividerColor, other.systemNavBarDividerColor, t)!,
    );
  }
}

/// Extension methods for accessing Android theme
extension AndroidTheme on ThemeData {
  _AndroidThemeExtension? get android {
    return extension<_AndroidThemeExtension>();
  }
}

/// Adaptive icon theme configuration for Android
class AdaptiveIconTheme {
  static const Color backgroundColor = Color(0xFF2E7D32);
  static const Color foregroundColor = Colors.white;
  static const Color monochromeColor = Colors.white;

  /// Material Design 3 color system for adaptive icons
  static const Map<String, Color> colorResources = {
    'ic_launcher_background': backgroundColor,
    'ic_launcher_foreground': foregroundColor,
    'ic_launcher_monochrome': monochromeColor,
  };

  /// Create adaptive icon configuration
  static Map<String, dynamic> createAdaptiveIconConfig({
    Color? background,
    Color? foreground,
    Color? monochrome,
  }) {
    return {
      'background': background ?? backgroundColor,
      'foreground': foreground ?? foregroundColor,
      'monochrome': monochrome ?? monochromeColor,
    };
  }
}

/// Android splash screen theme configuration
class SplashScreenTheme {
  static const Color backgroundColor = Color(0xFF2E7D32);
  static const Color splashColor = Color(0xFF4CAF50);
  static const Color textColor = Colors.white;

  static Duration get animationDuration => const Duration(milliseconds: 800);

  static Widget createSplashScreen({
    String? title,
    String? subtitle,
  }) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo or icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: splashColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.eco,
                  size: 64,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 32),
              if (title != null) ...[
                Text(
                  title,
                  style: GoogleFonts.roboto(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (subtitle != null)
                Text(
                  subtitle,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    color: textColor.withOpacity(0.8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Convenience getters for common theme properties
  static Color get primaryColor => primaryGreen;
  static Color get secondaryColor => leafYellow;
  static Color get accentColor => purpleAccent;
  static Color get backgroundColor => backgroundLight;
  static Color get scaffoldBackgroundColor => backgroundLight;
  static Color get cardColor => cardWhite;
  static Color get textColor => Colors.black87;
  static Color get secondaryTextColor => Colors.black54;
  static Color get dividerColor => Colors.grey.shade300;
  static Color get appBarColor => primaryGreen;
  static Color get errorColor => errorRed;
  static Color get successColor => successGreen;
  static Color get warningColor => warningOrange;
  static Color get infoColor => infoBlue;

  /// Enhanced animation duration constants
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration normalAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
  static const Duration extraSlowAnimation = Duration(milliseconds: 800);

  /// Custom animation curves
  static const Curve easeInOutCurve = Curves.easeInOut;
  static const Curve easeOutCurve = Curves.easeOut;
  static const Curve easeInCurve = Curves.easeIn;
  static const Curve bounceInCurve = Curves.bounceIn;
  static const Curve elasticOutCurve = Curves.elasticOut;

  /// Shadow presets
  static List<BoxShadow> get lightShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 15,
      offset: Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get heavyShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get coloredShadow => [
    BoxShadow(
      color: primaryGreen.withOpacity(0.2),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Gradient presets
  static LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryGreen,
      lightGreen,
    ],
  );

  static LinearGradient get secondaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      leafYellow,
      amberAccent,
    ],
  );

  static LinearGradient get successGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      successGreen,
      lightGreen,
    ],
  );

  static LinearGradient get errorGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      errorRed,
      Colors.red.shade300,
    ],
  );

  static LinearGradient get cardGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      cardWhite,
      backgroundLight,
    ],
  );

  /// Border radius presets
  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(4));
  static const BorderRadius mediumRadius = BorderRadius.all(Radius.circular(8));
  static const BorderRadius largeRadius = BorderRadius.all(Radius.circular(12));
  static const BorderRadius extraLargeRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius roundRadius = BorderRadius.all(Radius.circular(24));

  /// Spacing constants
  static const double spacingXXS = 4.0;
  static const double spacingXS = 8.0;
  static const double spacingS = 12.0;
  static const double spacingM = 16.0;
  static const double spacingL = 20.0;
  static const double spacingXL = 24.0;
  static const double spacingXXL = 32.0;

  /// Typography scale
  static TextStyle get displayStyle => GoogleFonts.roboto(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  static TextStyle get headlineStyle => GoogleFonts.roboto(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
  );

  static TextStyle get titleStyle => GoogleFonts.roboto(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.0,
  );

  static TextStyle get bodyStyle => GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.0,
  );

  static TextStyle get captionStyle => GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.25,
  );

  static TextStyle get labelStyle => GoogleFonts.roboto(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );

  /// Enhanced component styles
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardWhite,
    borderRadius: largeRadius,
    boxShadow: lightShadow,
    border: Border.all(
      color: dividerColor.withOpacity(0.5),
      width: 1,
    ),
  );

  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
    color: cardWhite,
    borderRadius: largeRadius,
    boxShadow: mediumShadow,
    border: Border.all(
      color: dividerColor.withOpacity(0.3),
      width: 1,
    ),
  );

  static BoxDecoration get interactiveCardDecoration => BoxDecoration(
    color: cardWhite,
    borderRadius: largeRadius,
    boxShadow: lightShadow,
    border: Border.all(
      color: primaryGreen.withOpacity(0.3),
      width: 1,
    ),
  );

  /// Button styles
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: primaryGreen,
    foregroundColor: Colors.white,
    elevation: 2,
    shadowColor: primaryGreen.withOpacity(0.3),
    shape: RoundedRectangleBorder(borderRadius: mediumRadius),
    padding: EdgeInsets.symmetric(horizontal: spacingXL, vertical: spacingM),
    textStyle: titleStyle.copyWith(fontWeight: FontWeight.w500),
  );

  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: primaryGreen,
    side: BorderSide(color: primaryGreen, width: 1),
    shape: RoundedRectangleBorder(borderRadius: mediumRadius),
    padding: EdgeInsets.symmetric(horizontal: spacingXL, vertical: spacingM),
    textStyle: titleStyle.copyWith(fontWeight: FontWeight.w500),
  );

  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
    foregroundColor: primaryGreen,
    shape: RoundedRectangleBorder(borderRadius: smallRadius),
    padding: EdgeInsets.symmetric(horizontal: spacingM, vertical: spacingS),
    textStyle: bodyStyle.copyWith(fontWeight: FontWeight.w500),
  );
}