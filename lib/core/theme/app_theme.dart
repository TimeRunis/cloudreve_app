import 'package:flutter/material.dart';

import '../../models/site_config.dart';
import 'app_colors.dart';

/// 解析 #RRGGBB / #AARRGGBB 十六进制颜色。
Color parseHexColor(String? hex, {Color fallback = const Color(0xFF1976D2)}) {
  if (hex == null) return fallback;
  var h = hex.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

/// 根据站点配置构建亮/暗主题。
class AppTheme {
  static const _defaultPrimary = Color(0xFF1976D2);

  static ThemeData light(SiteConfig? config) => _build(config, Brightness.light);

  static ThemeData dark(SiteConfig? config) => _build(config, Brightness.dark);

  static ThemeData _build(SiteConfig? config, Brightness brightness) {
    final variant = config?.activeVariant;
    final palette =
        brightness == Brightness.light ? variant?.light : variant?.dark;

    final primaryHex = palette?.primary.main;
    final secondaryHex = palette?.secondary.main;
    final seed = parseHexColor(primaryHex, fallback: _defaultPrimary);

    var scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    scheme = scheme.copyWith(
      primary: parseHexColor(primaryHex, fallback: scheme.primary),
      secondary: parseHexColor(secondaryHex, fallback: scheme.secondary),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      extensions: [
        brightness == Brightness.light ? AppColors.light : AppColors.dark,
      ],
    );
  }
}

/// 将存储的字符串转成 ThemeMode。
ThemeMode themeModeFromString(String mode) {
  switch (mode) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}
