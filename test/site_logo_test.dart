import 'package:cloudreve_view/models/site.dart';
import 'package:cloudreve_view/models/site_config.dart';
import 'package:cloudreve_view/widgets/common/site_logo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const site = Site(
    id: 's1',
    name: '测试站点',
    baseUrl: 'https://demo.cloudreve.org/',
  );

  SiteConfig config({String? logo, String? logoLight}) =>
      SiteConfig(title: '测试', logo: logo, logoLight: logoLight);

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
