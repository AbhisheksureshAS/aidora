import 'package:flutter/material.dart';

class AppTheme {
  // Aidora Premium Brand Colors
  static const Color primaryBlack = Color(0xFF080012); // Deep rich purplish-black background
  static const Color secondaryBlack = Color(0xFF10051A); // Slightly lighter background
  static const Color cardDark = Color(0xFF1B0C2B); // Soft purple tint card color
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAFA5C0); // Light grey with purple tint
  static const Color emergencyRed = Color(0xFFFF3B30);
  static const Color accentWhite = Color(0xFFFFFFFF);
  
  // Primary Aidora Purple
  static const Color primaryPurple = Color(0xFF5F259F);
  static const Color lightPurple = Color(0xFF7A36C4);
  static const Color veryLightPurple = Color(0xFF2E194D); // Used for chips/tags
  static const Color accentPurple = Color(0xFFA168F2);
  static const Color darkPurple = Color(0xFF381561);
  
  // Status Colors
  static const Color statusPending = Color(0xFF8E8E93);
  static const Color statusAccepted = Color(0xFF007AFF);
  static const Color statusCompleted = Color(0xFF34C759);
  
  // Theme colors aliases
  static const Color darkSurfaceColor = primaryBlack;
  static const Color darkCardColor = cardDark;
  
  static const Color errorColor = emergencyRed;
  static const Color successColor = statusCompleted;
  static const Color warningColor = Color(0xFFF39C12);

  // Legacy compatibility getters (mapped to the main dark theme)
  static Color get surfaceColor => darkSurfaceColor;
  static Color get cardColor => darkCardColor;

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryPurple,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primaryPurple,
      secondary: accentPurple,
      surface: primaryBlack,
      error: emergencyRed,
      onPrimary: accentWhite,
      onSecondary: accentWhite,
      onSurface: textPrimary,
      onError: textPrimary,
      outline: textSecondary.withValues(alpha: 0.2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: primaryBlack,
      canvasColor: primaryBlack,
      dividerColor: textSecondary.withValues(alpha: 0.1),
      
      appBarTheme: AppBarTheme(
        backgroundColor: primaryBlack,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        surfaceTintColor: Colors.transparent,
      ),
      
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryPurple,
        foregroundColor: accentWhite,
        elevation: 6,
      ),
      
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        shadowColor: primaryPurple.withValues(alpha: 0.1),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: accentWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentPurple,
          side: const BorderSide(color: primaryPurple),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondaryBlack,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: textSecondary.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: textSecondary.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accentPurple, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: emergencyRed, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: emergencyRed, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
      ),
      
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: secondaryBlack,
        selectedItemColor: accentPurple,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: cardDark,
        selectedColor: primaryPurple,
        side: BorderSide(color: primaryPurple.withValues(alpha: 0.3)),
        labelStyle: const TextStyle(color: textPrimary),
        secondaryLabelStyle: const TextStyle(color: accentWhite),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primaryPurple;
            }
            return secondaryBlack;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return accentWhite;
            }
            return textSecondary;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: textSecondary.withValues(alpha: 0.2)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
    );
  }

  // Unified Light Theme fallback - maps to Dark Theme since user explicitly asked NOT to 
  // convert app to full black/white minimal style. It's a unified Premium App Theme now.
  static ThemeData get lightTheme => darkTheme;

  static BoxDecoration get darkCardDecoration {
    return BoxDecoration(
      color: cardDark,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: primaryPurple.withValues(alpha: 0.2)),
      boxShadow: [
        BoxShadow(
          color: primaryPurple.withValues(alpha: 0.05),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // Emergency card decoration with red + purple mix glow
  static BoxDecoration get emergencyCardDecoration {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF8B1A2A), primaryPurple],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: emergencyRed.withValues(alpha: 0.3)),
      boxShadow: [
        BoxShadow(
          color: emergencyRed.withValues(alpha: 0.2),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // Main action card decoration (soft purple tint)
  static BoxDecoration get mainActionCardDecoration {
    return BoxDecoration(
      color: secondaryBlack,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: primaryPurple.withValues(alpha: 0.3)),
      boxShadow: [
        BoxShadow(
          color: primaryPurple.withValues(alpha: 0.1),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration get categoryCardDecoration {
    return BoxDecoration(
      color: cardDark,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: primaryPurple.withValues(alpha: 0.15)),
    );
  }

  static BoxDecoration get primaryButtonDecoration {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [primaryPurple, lightPurple],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: primaryPurple.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration get cardDecoration => darkCardDecoration;
  static BoxDecoration get lightCardDecoration => darkCardDecoration;
}
