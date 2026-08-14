import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/site.dart';
import '../../models/user.dart';

/// 本地存储：非敏感配置用 shared_preferences，令牌用 flutter_secure_storage。
class AppStorage {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _kSites = 'sites';
  static const _kCurrentSiteId = 'current_site_id';
  static const _kThemeMode = 'theme_mode';

  AppStorage(this._prefs, this._secure);

  static Future<AppStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage();
    return AppStorage(prefs, secure);
  }

  // ---------- 主题 ----------
  String getThemeMode() => _prefs.getString(_kThemeMode) ?? 'system';

  Future<void> setThemeMode(String mode) => _prefs.setString(_kThemeMode, mode);

  // ---------- 站点列表 ----------
  List<Site> getSites() {
    final raw = _prefs.getString(_kSites);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return Site.decodeList(raw);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveSites(List<Site> sites) =>
      _prefs.setString(_kSites, Site.encodeList(sites));

  // ---------- 当前站点 ----------
  String? getCurrentSiteId() => _prefs.getString(_kCurrentSiteId);

  Future<void> setCurrentSiteId(String? id) =>
      id == null ? _prefs.remove(_kCurrentSiteId) : _prefs.setString(_kCurrentSiteId, id);

  // ---------- 令牌（安全存储） ----------
  String _tokenKey(String siteId) => 'site.$siteId.token';
  String _userKey(String siteId) => 'site.$siteId.user';

  Future<void> saveToken(String siteId, TokenPair token) =>
      _secure.write(key: _tokenKey(siteId), value: jsonEncode(token.toJson()));

  Future<TokenPair?> getToken(String siteId) async {
    final raw = await _secure.read(key: _tokenKey(siteId));
    if (raw == null) return null;
    try {
      return TokenPair.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearToken(String siteId) async {
    await _secure.delete(key: _tokenKey(siteId));
    await _secure.delete(key: _userKey(siteId));
  }

  Future<void> saveUser(String siteId, User user) =>
      _secure.write(key: _userKey(siteId), value: jsonEncode(user.toJson()));

  Future<User?> getUser(String siteId) async {
    final raw = await _secure.read(key: _userKey(siteId));
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
