import 'package:cloudreve_view/models/site.dart';
import 'package:cloudreve_view/models/user.dart';
import 'package:cloudreve_view/widgets/common/user_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const site = Site(
    id: 's1',
    name: '测试站点',
    baseUrl: 'https://demo.cloudreve.org/',
  );

  User user({String? avatar}) => User(
        id: 'u1',
        email: 'user@example.com',
        nickname: 'Alice',
        status: 'active',
        createdAt: '',
        avatar: avatar,
      );

  group('userAvatarUrl', () {
    test('上传头像与 Gravatar 都走 /user/avatar/{id}', () {
      expect(
        userAvatarUrl(site, user(avatar: 'file')),
        'https://demo.cloudreve.org/api/v4/user/avatar/u1',
      );
      expect(
        userAvatarUrl(site, user(avatar: 'gravatar')),
        'https://demo.cloudreve.org/api/v4/user/avatar/u1',
      );
    });

    test('没有头像、没有用户或没有站点时返回 null', () {
      expect(userAvatarUrl(site, user()), isNull);
      expect(userAvatarUrl(site, user(avatar: '')), isNull);
      expect(userAvatarUrl(site, null), isNull);
      expect(userAvatarUrl(null, user(avatar: 'file')), isNull);
    });
  });
}
