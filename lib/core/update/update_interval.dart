/// 自动检查更新的频率（设置页可切换）。
enum UpdateCheckInterval {
  /// 每次启动都检查。
  launch('launch', '每次启动'),

  /// 每天最多检查一次。
  daily('daily', '每天'),

  /// 每 7 天检查一次。
  weekly('weekly', '每 7 天'),

  /// 每 30 天检查一次。
  monthly('monthly', '每 30 天');

  const UpdateCheckInterval(this.value, this.label);

  /// 持久化用的字符串值。
  final String value;

  /// 设置页展示的文案。
  final String label;

  /// 两次检查之间的最小间隔；[launch] 没有固定间隔（按启动次数判断）。
  Duration? get minGap => switch (this) {
        UpdateCheckInterval.launch => null,
        UpdateCheckInterval.daily => const Duration(days: 1),
        UpdateCheckInterval.weekly => const Duration(days: 7),
        UpdateCheckInterval.monthly => const Duration(days: 30),
      };

  /// 解析持久化的值，未知值回退为 [launch]。
  static UpdateCheckInterval fromValue(String? value) {
    for (final interval in UpdateCheckInterval.values) {
      if (interval.value == value) return interval;
    }
    return UpdateCheckInterval.launch;
  }
}
