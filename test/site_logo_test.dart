import 'package:cloudreve_view/models/site.dart';
import 'package:cloudreve_view/models/site_config.dart';
import 'package:cloudreve_view/widgets/common/site_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const site = Site(
    id: 's1',
    name: '测试站点',
    baseUrl: 'https://demo.cloudreve.org/',
  );

  SiteConfig config({String? logo, String? logoLight}) =>
      SiteConfig(title: '测试', logo: logo, logoLight: logoLight);

  group('defaultSiteLogoAsset', () {
    test('亮色主题使用 logo.svg', () {
      expect(defaultSiteLogoAsset(dark: false), 'assets/logo.svg');
    });

    test('暗色主题使用 logo_light.svg', () {
      expect(defaultSiteLogoAsset(dark: true), 'assets/logo_light.svg');
    });
  });

  group('DefaultSiteLogo', () {
    testWidgets('内置 logo 资源已注册到 asset bundle', (tester) async {
      for (final asset in ['assets/logo.svg', 'assets/logo_light.svg']) {
        final data = await rootBundle.load(asset);
        expect(data.lengthInBytes, greaterThan(0), reason: asset);
      }
    });

    testWidgets('亮色和暗色主题都能渲染，宽度按比例自适应', (tester) async {
      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: Center(child: DefaultSiteLogo(height: 32)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final size = tester.getSize(find.byType(SvgPicture));
        expect(size.height, 32);
        expect(size.width, closeTo(32 * 1351 / 331, 0.5));
      }
    });
  });

  group('resolveSiteLogoUrl', () {
    test('相对路径按站点地址补全', () {
      expect(
        resolveSiteLogoUrl(
          site,
          config(logo: '/static/img/logo.svg'),
          dark: false,
        ),
        'https://demo.cloudreve.org/static/img/logo.svg',
      );
    });

    test('不带前导斜杠的相对路径也能补全', () {
      expect(
        resolveSiteLogoUrl(
          site,
          config(logo: 'static/logo.png'),
          dark: false,
        ),
        'https://demo.cloudreve.org/static/logo.png',
      );
    });

    test('绝对地址原样返回', () {
      const url = 'https://cdn.example.com/logo.png';
      expect(
        resolveSiteLogoUrl(site, config(logo: url), dark: false),
        url,
      );
    });

    test('亮色优先 logo，暗色优先 logo_light', () {
      final c = config(logo: '/light.svg', logoLight: '/dark.svg');
      expect(
        resolveSiteLogoUrl(site, c, dark: false),
        'https://demo.cloudreve.org/light.svg',
      );
      expect(
        resolveSiteLogoUrl(site, c, dark: true),
        'https://demo.cloudreve.org/dark.svg',
      );
    });

    test('暗色缺少 logo_light 时回退 logo', () {
      expect(
        resolveSiteLogoUrl(
          site,
          config(logo: '/light.svg'),
          dark: true,
        ),
        'https://demo.cloudreve.org/light.svg',
      );
    });

    test('未配置 logo 或没有站点地址时返回 null', () {
      expect(resolveSiteLogoUrl(site, config(), dark: false), isNull);
      expect(resolveSiteLogoUrl(null, config(logo: '/a.svg'), dark: false),
          isNull);
      expect(
        resolveSiteLogoUrl(
          site,
          config(logo: '   '),
          dark: false,
        ),
        isNull,
      );
    });
  });
}
