/// 时间格式化与排序比较（列表按「最新在前」排列时使用）。
library;

/// `2026/08/15 02:08`；[value] 为空时返回空串。
String formatDateTime(DateTime? value) {
  if (value == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}/${two(value.month)}/${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

/// 倒序比较：新的在前，没有时间的排在最后（供 [List.sort] 使用）。
int compareNewestFirst(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}
