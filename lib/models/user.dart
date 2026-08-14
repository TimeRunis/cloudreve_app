/// 用户组信息。
class UserGroup {
  final String id;
  final String name;
  final String? permission;
  final int? directLinkBatchSize;
  final int? trashRetention;

  const UserGroup({
    required this.id,
    required this.name,
    this.permission,
    this.directLinkBatchSize,
    this.trashRetention,
  });

  factory UserGroup.fromJson(Map<String, dynamic> json) => UserGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        permission: json['permission'] as String?,
        directLinkBatchSize: json['direct_link_batch_size'] as int?,
        trashRetention: json['trash_retention'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (permission != null) 'permission': permission,
        if (directLinkBatchSize != null) 'direct_link_batch_size': directLinkBatchSize,
        if (trashRetention != null) 'trash_retention': trashRetention,
      };
}

/// 用户信息（来自登录响应或 /user/me）。
class User {
  final String id;
  final String email;
  final String nickname;
  final String status;
  final String createdAt;
  final String? avatar;
  final UserGroup? group;

  const User({
    required this.id,
    required this.email,
    required this.nickname,
    required this.status,
    required this.createdAt,
    this.avatar,
    this.group,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        nickname: json['nickname'] as String? ?? '',
        status: json['status'] as String? ?? 'active',
        createdAt: json['created_at'] as String? ?? '',
        avatar: json['avatar'] as String?,
        group: json['group'] == null
            ? null
            : UserGroup.fromJson(json['group'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nickname': nickname,
        'status': status,
        'created_at': createdAt,
        'avatar': avatar,
        if (group != null) 'group': group!.toJson(),
      };
}

/// 登录 / 刷新返回的令牌对。
class TokenPair {
  final String accessToken;
  final String refreshToken;
  final String? accessExpires;
  final String? refreshExpires;

  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    this.accessExpires,
    this.refreshExpires,
  });

  factory TokenPair.fromJson(Map<String, dynamic> json) => TokenPair(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        accessExpires: json['access_expires'] as String?,
        refreshExpires: json['refresh_expires'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'access_expires': accessExpires,
        'refresh_expires': refreshExpires,
      };
}

/// 登录成功后的完整结果。
class LoginResult {
  final User user;
  final TokenPair token;

  const LoginResult({required this.user, required this.token});

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
        user: User.fromJson(json['user'] as Map<String, dynamic>),
        token: TokenPair.fromJson(json['token'] as Map<String, dynamic>),
      );
}

/// 存储容量（GET /user/capacity）。
class Capacity {
  final int total;
  final int used;
  final int storagePackTotal;

  const Capacity({
    required this.total,
    required this.used,
    required this.storagePackTotal,
  });

  factory Capacity.fromJson(Map<String, dynamic> json) => Capacity(
        total: (json['total'] as num?)?.toInt() ?? 0,
        used: (json['used'] as num?)?.toInt() ?? 0,
        storagePackTotal: (json['storage_pack_total'] as num?)?.toInt() ?? 0,
      );
}
