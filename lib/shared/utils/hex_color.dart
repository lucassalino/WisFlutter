import 'package:flutter/material.dart';

/// Converte um hex `#rrggbb` (opcionalmente sem `#`) numa [Color].
/// Devolve [fallback] se `hex` for nulo ou inválido.
Color hexToColor(String? hex, {Color fallback = const Color(0xFFA5B4FC)}) {
  if (hex == null || hex.isEmpty) return fallback;
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return Color(cleaned.length == 6 ? 0xFF000000 | value : value);
}
