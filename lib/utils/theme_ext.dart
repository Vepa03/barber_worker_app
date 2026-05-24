import 'package:flutter/material.dart';

/// Quick access to theme-aware colors from any BuildContext.
extension ThemeX on BuildContext {
  bool   get isDark    => Theme.of(this).brightness == Brightness.dark;
  Color  get kBg       => Theme.of(this).scaffoldBackgroundColor;
  Color  get kSurface  => Theme.of(this).colorScheme.surface;
  Color  get kText     => Theme.of(this).colorScheme.onSurface;
  Color  get kBorder   => Theme.of(this).dividerColor;
  Color  get kTextSec  => isDark ? const Color(0xFFAEAEB2) : const Color(0xFF8E8E93);
}

// Fixed colors that don't change with theme
const kBlue   = Color(0xFF3875F6);
const kGrey   = Color(0xFF8E8E93);
const kGreen  = Color(0xFF22C55E);
const kAmber  = Color(0xFFF59E0B);
const kRed    = Color(0xFFEF4444);
