import 'package:flutter/material.dart';

/// 应用级语义颜色，纳入主题系统，随亮/暗主题切换。
///
/// 使用方式：`context.appColors.surface`（需要 import 本文件）。
class AppColors extends ThemeExtension<AppColors> {
  /// 顶部导航/工具栏所在头部区域背景。
  final Color headerBg;

  /// 页面内容区域背景。
  final Color contentBg;

  /// 卡片 / 弹窗等浮层背景。
  final Color surface;

  /// 次级背景（文件夹卡片、缩略图区、输入框灰底等）。
  final Color surfaceMuted;

  /// 分割线 / 卡片边框。
  final Color border;

  /// 工具栏分段按钮、面包屑按钮的边框。
  final Color toolbarBorder;

  /// 主文字。
  final Color textPrimary;

  /// 次级文字 / 图标。
  final Color textSecondary;

  /// 弱文字（辅助说明、下拉箭头等）。
  final Color textMuted;

  /// 更弱的点缀（面包屑分隔箭头等）。
  final Color textFaint;

  const AppColors({
    required this.headerBg,
    required this.contentBg,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.toolbarBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textFaint,
  });

  static const light = AppColors(
    headerBg: Color(0xFFF3F4F6),
    contentBg: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF5F5F5),
    border: Color(0xFFEEEEEE),
    toolbarBorder: Color(0xFFE5E7EB),
    textPrimary: Color(0xFF333333),
    textSecondary: Color(0xFF666666),
    textMuted: Color(0xFF999999),
    textFaint: Color(0xFFB0B0B0),
  );

  static const dark = AppColors(
    headerBg: Color(0xFF1E1E1E),
    contentBg: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    surfaceMuted: Color(0xFF2A2A2A),
    border: Color(0xFF383838),
    toolbarBorder: Color(0xFF383838),
    textPrimary: Color(0xFFE6E6E6),
    textSecondary: Color(0xFFB3B3B3),
    textMuted: Color(0xFF7A7A7A),
    textFaint: Color(0xFF6E6E6E),
  );

  @override
  AppColors copyWith({
    Color? headerBg,
    Color? contentBg,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? toolbarBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textFaint,
  }) {
    return AppColors(
      headerBg: headerBg ?? this.headerBg,
      contentBg: contentBg ?? this.contentBg,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      toolbarBorder: toolbarBorder ?? this.toolbarBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      headerBg: Color.lerp(headerBg, other.headerBg, t)!,
      contentBg: Color.lerp(contentBg, other.contentBg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      toolbarBorder: Color.lerp(toolbarBorder, other.toolbarBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
