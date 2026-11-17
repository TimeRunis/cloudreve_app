/// Cloudreve 文件 URI 的显示转换。
library;

/// 把 Cloudreve 文件 URI 转成可读路径，如
/// `cloudreve://my/%E9%97%A8%E7%A5%A8/a%402x.png` → `/门票/a@2x.png`。
///
/// 服务端返回的 `path` / `sys:restore_uri` 都是百分号编码的；`pathSegments`
/// 已经完成解码，所以直接拼接即可 —— 不要再 `decodeComponent` 一次，
/// 否则文件名里本身含 `%` 时会抛 `Illegal percent encoding`。
String readableCloudrevePath(String uri) {
  if (uri.isEmpty) return '';
  try {
    final segments = Uri.parse(uri).pathSegments.where((s) => s.isNotEmpty);
    return segments.isEmpty ? '/' : '/${segments.join('/')}';
  } catch (_) {
    // 非法转义（极少数脏数据）时原样返回，至少不崩。
    return uri;
  }
}

/// 取 URI 末尾的文件名（已解码）；解析不出来时返回空串。
String readableUriName(String uri) {
  if (uri.isEmpty) return '';
  try {
    final segments =
        Uri.parse(uri).pathSegments.where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? '' : segments.last;
  } catch (_) {
    return '';
  }
}
