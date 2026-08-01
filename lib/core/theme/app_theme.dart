import 'package:flutter/material.dart';

/// Brand Kit WIS — fundo preto absoluto com cartões em "vidro fosco",
/// espelhando o tema `.dark` + `auth-glass`/`dash-glass-card`/`events-dark-card`
/// do PWA (ver ServiceFlow/src/app/globals.css).
abstract final class WisColors {
  static const navy = Color(0xFF0D3B66);
  static const petrol = Color(0xFF0F5C6E);
  static const iconAccent = Color(0xFF1B7A8C);
  static const indigoAccent = Color(0xFFA5B4FC);
  static const greenAccent = Color(0xFF6EE7B7);

  static const background = Color(0xFF000000);
  static const card = Color(0xFF16161A);
  static const cardBorder = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const inputFill = Color(0x0DFFFFFF); // rgba(255,255,255,0.05)
  static const inputBorder = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)
  static const inputBorderFocus = Color(0x40FFFFFF); // rgba(255,255,255,0.25)
  static const divider = Color(0x11FFFFFF); // rgba(255,255,255,0.07)
  static const destructive = Color(0xFFF87171);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, petrol],
  );

  /// Spotlight radial usado em auth-bg / dash-purple-bg.
  static const spotlight = RadialGradient(
    center: Alignment(0.5, -1.1),
    radius: 1.0,
    colors: [Color(0x1AD2D2EB), Colors.transparent],
    stops: [0.0, 0.7],
  );
}

class WisTheme {
  const WisTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final colorScheme = base.colorScheme.copyWith(
      primary: WisColors.indigoAccent,
      secondary: WisColors.greenAccent,
      surface: WisColors.card,
      error: WisColors.destructive,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: WisColors.background,
      dividerColor: WisColors.divider,
      appBarTheme: const AppBarTheme(
        backgroundColor: WisColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: WisColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          side: const BorderSide(color: WisColors.cardBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WisColors.inputFill,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.28)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: WisColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: WisColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: WisColors.inputBorderFocus),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: WisColors.destructive),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.75),
          backgroundColor: WisColors.inputFill,
          side: const BorderSide(color: WisColors.inputBorder),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Colors.white70),
      ),
      iconTheme: IconThemeData(color: Colors.white.withValues(alpha: 0.6)),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: WisColors.background,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white.withValues(alpha: 0.4),
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: WisColors.inputFill,
        side: const BorderSide(color: WisColors.inputBorder),
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: WisColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: WisColors.cardBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: WisColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        iconColor: Colors.white70,
        collapsedIconColor: Colors.white54,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: WisColors.card,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: WisColors.cardBorder),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
