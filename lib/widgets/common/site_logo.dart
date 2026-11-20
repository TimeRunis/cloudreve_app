import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/site.dart';
import '../../models/site_config.dart';
import '../../providers/settings_provider.dart';
import '../../providers/site_config_provider.dart';

/// 把站点配置里的 logo 解析成可直接加载的地址。
///
/// - 亮色主题优先 `logo`，暗色主题优先 `logo_light`（服务端字段注释：
///   `logo` 用于浅色模式、`logo_light` 用于深色模式）；
/// - 配置里通常是 `/static/img/logo.svg` 这种相对路径，用站点地址补全；
/// - 未配置时返回 null，由调用方回退到默认图标。
String? resolveSiteLogoUrl(
  Site? site,
  SiteConfig? config, {
  required bool dark,
}) {
  final raw = dark
      ? (config?.logoLight ?? config?.logo)
      : (config?.logo ?? config?.logoLight);
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) return value;
  final base = site?.normalizedBaseUrl ?? '';
  if (base.isEmpty) return null;
  return value.startsWith('/') ? '$base$value' : '$base/$value';
}

/// 站点未配置 logo 时使用的内置 logo 资源（亮色 / 暗色各一套）。
String defaultSiteLogoAsset({required bool dark}) =>
    dark ? 'assets/logo_light.svg' : 'assets/logo.svg';

/// 内置默认 logo：跟随亮 / 暗主题切换 [defaultSiteLogoAsset]。
class DefaultSiteLogo extends StatelessWidget {
  /// 固定高度；宽度按 SVG 比例自适应。
  final double height;

  /// 内置 logo 的 viewBox 比例（1351 × 331），用于加载前占位，避免宽度跳变。
  static const double _aspectRatio = 1351 / 331;

  const DefaultSiteLogo({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SvgPicture.asset(
      defaultSiteLogoAsset(dark: dark),
      width: height * _aspectRatio,
      height: height,
      fit: BoxFit.contain,
    );
  }
}

/// 站点 logo（跟随站点配置和亮 / 暗主题），加载中或失败时显示 [fallback]。
///
/// 支持 SVG（Cloudreve 默认 logo 就是 svg）与常见位图格式。
class SiteLogo extends ConsumerWidget {
  /// 固定高度；宽度按图片比例自适应，并用 [maxWidth] 限制。
  final double height;

  /// 未配置 logo、加载中或加载失败时显示的占位 / 兜底内容。
  final Widget fallback;

  /// 最大宽度，避免超宽 logo 把标题挤掉。
  final double? maxWidth;

  final BoxFit fit;

  const SiteLogo({
    super.key,
    required this.height,
    required this.fallback,
    this.maxWidth,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(siteConfigProvider).valueOrNull;
    final site = ref.watch(currentSiteProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final url = resolveSiteLogoUrl(site, config, dark: dark);

    Widget child;
    if (url == null) {
      child = fallback;
    } else if (_isSvg(url)) {
      child = SvgPicture.network(
        url,
        height: height,
        fit: fit,
        placeholderBuilder: (_) => fallback,
        errorBuilder: (_, __, ___) => fallback,
      );
    } else {
      child = CachedNetworkImage(
        imageUrl: url,
        height: height,
        fit: fit,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      );
    }

    final max = maxWidth;
    if (max == null) return child;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: max, maxHeight: height),
      child: child,
    );
  }

  static bool _isSvg(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.svg');
  }
}
