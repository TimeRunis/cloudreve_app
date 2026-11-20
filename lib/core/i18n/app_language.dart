import 'package:flutter/widgets.dart';

/// 应用界面语言（设置页可切换）。
enum AppLanguage {
  /// 跟随系统：系统是中文就用中文，其余语言统一回退英文。
  system('system', '跟随系统', null),
  zh('zh', '简体中文', Locale('zh')),
  en('en', 'English', Locale('en'));

  const AppLanguage(this.value, this.label, this.locale);

  /// 持久化用的字符串值。
  final String value;

  /// 语言自身的名称（设置项里显示）。
  final String label;

  /// 传给 MaterialApp 的 locale；[system] 为 null。
  final Locale? locale;

  static AppLanguage fromValue(String? value) {
    for (final language in AppLanguage.values) {
      if (language.value == value) return language;
    }
    return AppLanguage.system;
  }
}
