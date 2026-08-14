import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/site.dart';
import '../models/user.dart';
import 'settings_provider.dart';
import 'storage_provider.dart';

/// 当前站点的认证状态。
class AuthState {
  final TokenPair? token;
  final User? user;
  final bool loading;

  const AuthState({this.token, this.user, this.loading = false});

  bool get isLoggedIn => token != null;

  AuthState copyWith({TokenPair? token, User? user, bool? loading}) =>
      AuthState(
        token: token ?? this.token,
        user: user ?? this.user,
        loading: loading ?? this.loading,
      );
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final site = ref.watch(currentSiteProvider);
    if (site == null) return const AuthState();
    _load(site);
    return const AuthState(loading: true);
  }

  Future<void> _load(Site site) async {
    final storage = ref.read(storageProvider);
    final token = await storage.getToken(site.id);
    final user = await storage.getUser(site.id);
    // 站点已切换时丢弃过期结果。
    final current = ref.read(currentSiteProvider);
    if (current?.id == site.id) {
      state = AuthState(token: token, user: user);
    }
  }

  /// 登录成功后保存令牌与用户。
  Future<void> signIn(Site site, TokenPair token, User user) async {
    state = AuthState(token: token, user: user);
    await ref.read(storageProvider).saveToken(site.id, token);
    await ref.read(storageProvider).saveUser(site.id, user);
  }

  Future<void> updateToken(Site site, TokenPair token) async {
    state = state.copyWith(token: token);
    await ref.read(storageProvider).saveToken(site.id, token);
  }

  Future<void> signOut(Site site) async {
    state = const AuthState();
    await ref.read(storageProvider).clearToken(site.id);
  }
}
