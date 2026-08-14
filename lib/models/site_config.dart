import 'dart:convert';

/// 一个主题色（Material 三色：main/light/dark）。
class ThemeColor {
  final String main;
  final String? light;
  final String? dark;

  const ThemeColor({required this.main, this.light, this.dark});

  factory ThemeColor.fromJson(Map<String, dynamic> json) => ThemeColor(
        main: json['main'] as String? ?? '#1976d2',
        light: json['light'] as String?,
        dark: json['dark'] as String?,
      );
}

/// 一套色板（primary + secondary）。
class ThemePalette {
  final ThemeColor primary;
  final ThemeColor secondary;

  const ThemePalette({required this.primary, required this.secondary});

  factory ThemePalette.fromJson(Map<String, dynamic> json) {
    final palette = json['palette'] as Map<String, dynamic>? ?? {};
    return ThemePalette(
      primary: ThemeColor.fromJson(
          palette['primary'] as Map<String, dynamic>? ?? {}),
      secondary: ThemeColor.fromJson(
          palette['secondary'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// 一个主题变体（含亮色 / 暗色两套色板）。
class ThemeVariant {
  final ThemePalette light;
  final ThemePalette dark;

  const ThemeVariant({required this.light, required this.dark});

  factory ThemeVariant.fromJson(Map<String, dynamic> json) => ThemeVariant(
        light: ThemePalette.fromJson(json['light'] as Map<String, dynamic>? ?? {}),
        dark: ThemePalette.fromJson(json['dark'] as Map<String, dynamic>? ?? {}),
      );
}

/// 站点基础配置（来自 GET /site/config/basic）。
class SiteConfig {
  final String title;
  final String? defaultTheme;
  final Map<String, ThemeVariant> themes;
  final String? captchaType;
  final String? captchaReCaptchaKey;
  final String? logo;
  final String? logoLight;
  final bool appPromotion;

  const SiteConfig({
    required this.title,
    this.defaultTheme,
    this.themes = const {},
    this.captchaType,
    this.captchaReCaptchaKey,
    this.logo,
    this.logoLight,
    this.appPromotion = false,
  });

  /// 当前启用的主题变体；找不到时回退到第一个。
  ThemeVariant? get activeVariant {
    if (defaultTheme != null && themes.containsKey(defaultTheme)) {
      return themes[defaultTheme];
    }
    if (themes.isNotEmpty) return themes.values.first;
    return null;
  }

  factory SiteConfig.fromJson(Map<String, dynamic> json) {
    final themesStr = json['themes'] as String?;
    final Map<String, ThemeVariant> themes = {};
    if (themesStr != null && themesStr.isNotEmpty) {
      try {
        final raw = jsonDecode(themesStr) as Map<String, dynamic>;
        raw.forEach((key, value) {
          themes[key] =
              ThemeVariant.fromJson(value as Map<String, dynamic>? ?? {});
        });
      } catch (_) {
        // 主题字段解析失败时忽略，使用默认配色。
      }
    }
    return SiteConfig(
      title: json['title'] as String? ?? 'Cloudreve',
      defaultTheme: json['default_theme'] as String?,
      themes: themes,
      captchaType: json['captcha_type'] as String?,
      captchaReCaptchaKey: json['captcha_ReCaptchaKey'] as String?,
      logo: json['logo'] as String?,
      logoLight: json['logo_light'] as String?,
      appPromotion: json['app_promotion'] as bool? ?? false,
    );
  }
}

/// 登录页配置（来自 GET /site/config/login）。
class LoginConfig {
  final bool captchaEnabled;
  final String? tosUrl;
  final String? privacyPolicyUrl;

  const LoginConfig({
    this.captchaEnabled = false,
    this.tosUrl,
    this.privacyPolicyUrl,
  });

  factory LoginConfig.fromJson(Map<String, dynamic> json) => LoginConfig(
        captchaEnabled: json['login_captcha'] as bool? ?? false,
        tosUrl: json['tos_url'] as String?,
        privacyPolicyUrl: json['privacy_policy_url'] as String?,
      );
}
