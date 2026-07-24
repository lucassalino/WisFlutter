import 'package:flutter/material.dart';

/// Brand Kit WIS — degradê Azul Marinho → Azul Petróleo, tema escuro forçado.
abstract final class WisColors {
  static const navy = Color(0xFF0D3B66);
  static const petrol = Color(0xFF0F5C6E);
  static const iconAccent = Color(0xFF1B7A8C);
  static const indigoAccent = Color(0xFFA5B4FC);
  static const greenAccent = Color(0xFF6EE7B7);

  static const background = Color(0xFF0A1420);
  static const surface = Color(0xFF101E30);
  static const surfaceVariant = Color(0xFF16273B);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, petrol],
  );
}

class WisTheme {
  const WisTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final colorScheme = base.colorScheme.copyWith(
      primary: WisColors.indigoAccent,
      secondary: WisColors.greenAccent,
      surface: WisColors.surface,
      error: const Color(0xFFF87171),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: WisColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: WisColors.background,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: WisColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WisColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: WisColors.indigoAccent,
          foregroundColor: WisColors.navy,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: WisColors.indigoAccent),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: WisColors.surface,
        selectedItemColor: WisColors.indigoAccent,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
