/// 主题模式（system / light / dark）对应的中文名。
///
/// 侧边栏、设置页、主题悬浮窗共用，避免各处再写一份 switch。
String themeModeLabel(String mode) {
  switch (mode) {
    case 'light':
      return '亮色';
    case 'dark':
      return '暗色';
    default:
      return '跟随系统';
  }
}
