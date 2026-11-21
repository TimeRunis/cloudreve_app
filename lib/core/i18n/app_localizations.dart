import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 当前界面语言的全局实例。
///
/// 由 [CloudreveApp] 在每次构建时写入，供没有 `BuildContext` 的代码
/// （下载 / 上传通知、后台任务等）取文案；界面内仍推荐用
/// `AppLocalizations.of(context)` 以跟随语言切换自动重建。
AppLocalizations appL10n = const AppLocalizations(Locale('zh'));

/// 无 `BuildContext` 时的文案快捷方式。
String tr(String zh, {Map<String, Object?>? args}) => appL10n.t(zh, args: args);

/// 应用文案的多语言入口。
///
/// 以中文文案作为 key：中文界面直接返回 key，英文界面查 [_en] 表；
/// 还没翻译的文案自动回退到中文，方便分批把界面迁移过来。
class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  bool get isZh => locale.languageCode == 'zh';

  /// 取当前语言文案；[args] 用于替换文案里的 `{name}` 占位符。
  String t(String zh, {Map<String, Object?>? args}) {
    var text = isZh ? zh : (_en[zh] ?? zh);
    if (args != null && args.isNotEmpty) {
      args.forEach((key, value) {
        text = text.replaceAll('{$key}', '${value ?? ''}');
      });
    }
    return text;
  }

  static AppLocalizations of(BuildContext context) {
    final instance =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    // 单独测试组件（没有挂载 delegate）时按中文兜底，避免空断言。
    return instance ?? const AppLocalizations(Locale('zh'));
  }

  static const List<Locale> supportedLocales = [Locale('zh'), Locale('en')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// 系统语言解析：中文用中文，其它语言统一回退英文。
  static Locale resolveLocale(Locale? systemLocale) {
    return systemLocale?.languageCode == 'zh'
        ? const Locale('zh')
        : const Locale('en');
  }

  /// 英文文案表（key 为中文原文）。
  static const Map<String, String> _en = {
    // 通用
    '返回': 'Back',
    '取消': 'Cancel',
    '打开': 'Open',
    '关闭': 'Close',
    '设置': 'Settings',
    '菜单': 'Menu',
    '上传': 'Upload',
    '下载': 'Downloads',
    '搜索': 'Search',
    '添加': 'Add',
    '取消选择': 'Clear selection',
    '更多操作': 'More',
    '功能暂未实现': 'Not available yet',
    '读取中…': 'Loading…',
    '再按一次返回键退出软件': 'Press back again to exit',
    // 主题 / 语言
    '外观': 'Appearance',
    '主题': 'Theme',
    '跟随系统': 'System',
    '亮色': 'Light',
    '暗色': 'Dark',
    '主题（{mode}）': 'Theme ({mode})',
    '语言': 'Language',
    '当前：{label}': 'Current: {label}',
    // 站点
    '站点': 'Sites',
    '管理站点': 'Manage sites',
    '添加、切换、编辑或删除站点': 'Add, switch, edit or remove sites',
    '还没有配置任何站点': 'No sites configured',
    '添加站点': 'Add site',
    // 下载设置
    '下载设置': 'Download settings',
    '多线程下载、下载线程数': 'Multi-thread download, thread count',
    '多线程下载': 'Multi-thread download',
    '使用 HTTP Range 分片并行下载，适合大文件':
        'Parallel downloads with HTTP Range, best for large files',
    '下载线程数': 'Threads',
    '仅对大于 1MB 的文件生效；服务器不支持时自动降级单线程':
        'Only for files larger than 1 MB; falls back to single thread if unsupported',
    '开启后可为每个文件分配多个线程并行下载': 'Allocate multiple threads per file when enabled',
    // 日志
    '日志': 'Logs',
    '导出日志': 'Export logs',
    '保存到本地文件，便于反馈问题': 'Save to a local file for bug reports',
    '导出失败：{error}': 'Export failed: {error}',
    '日志已导出': 'Logs exported',
    '可直接打开，或复制路径后自行处理':
        'Open it directly, or copy the path and handle it yourself',
    '复制路径': 'Copy path',
    '日志路径已复制': 'Log path copied',
    '打开文件': 'Open file',
    // 更新
    '更新': 'Updates',
    '检查更新': 'Check for updates',
    '检查 GitHub 上是否有新版本': 'Check GitHub for a new version',
    '上次检查：{time}': 'Last checked: {time}',
    '正在检查新版本…': 'Checking for updates…',
    '已是最新版本': 'Up to date',
    '发现新版本 {version}': 'New version {version} available',
    '检查失败，点击重试': 'Check failed, tap to retry',
    '自动检查更新': 'Auto check',
    '每次启动': 'Every launch',
    '每天': 'Daily',
    '每 7 天': 'Every 7 days',
    '每 30 天': 'Every 30 days',
    // 关于
    '关于': 'About',
    '关于 Cloudreve': 'About Cloudreve',
    '版本、开源仓库与致谢': 'Version, source repository and credits',
    '信息': 'Information',
    '版本': 'Version',
    '开源仓库': 'Source repository',
    '复制仓库地址': 'Copy repository URL',
    '仓库地址已复制': 'Repository URL copied',
    '链接已复制': 'Link copied',
    '问题反馈': 'Feedback',
    '在 GitHub Issues 提交问题或建议': 'Report issues or suggestions on GitHub Issues',
    '致谢': 'Credits',
    '本项目基于 Flutter 构建，并使用了以下开源项目：\n'
            'flutter_riverpod（状态管理）、dio（网络）、logger（日志）、'
            'cached_network_image、video_player、video_thumbnail、'
            'file_picker、gal、package_info_plus、url_launcher 等。\n'
            '感谢 Cloudreve 及其社区提供的服务端与交互参考。':
        'Built with Flutter and the following open-source projects:\n'
            'flutter_riverpod (state management), dio (networking), '
            'logger (logging), cached_network_image, video_player, '
            'video_thumbnail, file_picker, gal, package_info_plus, '
            'url_launcher, and more.\n'
            'Thanks to Cloudreve and its community for the server and '
            'interaction reference.',
    '免责声明': 'Disclaimer',
    '本应用是 Cloudreve 的第三方客户端，非 Cloudreve 官方产品，'
            '与 Cloudreve 官方团队无关。\n'
            '账号、文件等数据均保存在你自行配置的 Cloudreve 站点上，'
            '本应用不上传、不收集任何内容。':
        'This app is a third-party Cloudreve client, not an official '
            'Cloudreve product, and is not affiliated with the Cloudreve team.\n'
            'Accounts and files are stored on the Cloudreve site you configure '
            'yourself. This app does not upload or collect any content.',
    'Cloudreve v4 的第三方 Flutter 客户端':
        'A third-party Flutter client for Cloudreve v4',
    // 登录
    '登录': 'Sign in',
    '邮箱': 'Email',
    '密码': 'Password',
    '验证码': 'Captcha',
    '点击刷新': 'Tap to refresh',
    '切换 / 管理站点': 'Switch / manage sites',
    '请输入邮箱和密码': 'Enter email and password',
    '请输入验证码': 'Enter the captcha',
    '验证码加载失败：{error}': 'Failed to load captcha: {error}',
    '该账号需要两步验证，暂不支持': 'Two-factor authentication is not supported yet',
    '登录失败': 'Sign-in failed',
    '登录失败：{error}': 'Sign-in failed: {error}',
    // 分享链接确认
    '打开分享链接': 'Open share link',
    '检测到来自「{owner}」的分享链接，是否打开？': 'Found a share link from “{owner}”. Open it?',
    // 侧边栏
    '我的文件': 'My Files',
    '图片': 'Images',
    '视频': 'Videos',
    '音乐': 'Music',
    '文档': 'Documents',
    '与我共享': 'Shared with me',
    '回收站': 'Trash',
    '我的分享': 'My shares',
    '下载任务': 'Downloads',
    '存储空间': 'Storage',

    // 文件 / 文件夹 / 操作
    '文件': 'Files',
    '文件夹': 'Folders',
    '大小': 'Size',
    '类型': 'Type',
    '状态': 'Status',
    '时间': 'Time',
    '创建时间': 'Created',
    '路径': 'Path',
    '路径已复制': 'Path copied',
    '原位置': 'Original location',
    '原位置已复制': 'Original location copied',
    '保存路径': 'Save location',
    '布局': 'Layout',
    '网格': 'Grid',
    '列表': 'List',
    '缩略图': 'Thumbnails',
    '分页大小': 'Page size',
    '切换视图': 'Switch view',
    '排序': 'Sort',
    '更多': 'More',
    '分享': 'Share',
    '重命名': 'Rename',
    '复制': 'Copy',
    '获取直链': 'Direct link',
    '标签': 'Tags',
    '整理': 'Organize',
    '详细信息': 'Details',
    '删除': 'Delete',
    '全选': 'Select all',
    '反选': 'Invert',
    '选择': 'Select',
    '刷新': 'Refresh',
    '查看': 'View',
    '查看详情': 'View details',
    '大小排序': 'Sort by size',
    '最小': 'Smallest',
    '最大': 'Largest',
    '最早修改': 'Oldest modified',
    '最新修改': 'Newest modified',
    '最早上传': 'Oldest uploaded',
    '最新上传': 'Newest uploaded',
    '此目录为空': 'This folder is empty',
    '加载文件列表失败': 'Failed to load file list',
    '文件不存在，可能已被移动或删除': 'File not found. It may have been moved or deleted.',
    '无法打开文件': 'Unable to open file',
    '获取下载链接失败': 'Failed to get download link',
    '获取图片地址失败': 'Failed to get image URL',
    '获取视频播放链接失败': 'Failed to get video URL',
    '加入下载队列失败': 'Failed to add to downloads',
    '已加入下载队列：{count} 个任务': 'Added {count} task(s) to downloads',
    '已加入下载队列，可在下载页查看进度':
        'Added to downloads. Check progress on the Downloads page.',
    '文件夹打包下载暂不支持': 'Folder archive download is not supported yet',
    '文件夹打包下载暂不支持，将只下载选中的文件':
        'Folder archive download is not supported; only selected files will be downloaded',
    '已彻底删除': 'Permanently deleted',
    '已移入回收站': 'Moved to trash',
    '删除失败，请重试': 'Delete failed, please try again',
    '没有可删除的选中文件': 'No selected files to delete',
    '确认删除': 'Confirm delete',
    '确定删除': 'Delete',
    '删除记录': 'Delete record',
    '删除任务和文件': 'Delete task and files',
    '仅删除下载记录，已下载的文件会保留。':
        'Only the record will be removed; downloaded files are kept.',
    '将删除任务、已下载的文件与临时文件，此操作不可恢复。':
        'The task, downloaded files and temp files will be deleted. This cannot be undone.',
    '将删除排队任务及其临时文件，此操作不可恢复。':
        'The queued task and its temp files will be deleted. This cannot be undone.',
    '将停止下载并删除已下载的文件与临时文件，此操作不可恢复。':
        'Download will stop and downloaded files and temp files will be deleted. This cannot be undone.',
    '移入回收站': 'Move to trash',
    '彻底删除': 'Delete permanently',
    '确定取消': 'Cancel',
    '选择删除方式：': 'Choose how to delete:',
    '可恢复（取决于站点回收站设置）': 'Recoverable (depends on the site trash settings)',
    '跳过回收站，不可恢复': 'Skip trash; cannot be undone',
    '保留物理文件': 'Keep physical file',
    '解除引用并保留底层文件，需用户组高级删除权限':
        'Unlink and keep the underlying file; requires advanced delete permission',
    '文件夹打包下载': 'Folder archive download',

    // 下载 / 上传
    '下载中': 'Downloading',
    '下载失败': 'Download failed',
    '已完成': 'Completed',
    '已暂停': 'Paused',
    '排队中': 'Queued',
    '暂停': 'Pause',
    '继续': 'Resume',
    '重试': 'Retry',
    '清空已完成': 'Clear completed',
    '清除已完成任务': 'Clear completed tasks',
    '隐藏已完成任务': 'Hide completed tasks',
    '重试所有失败任务': 'Retry all failed tasks',
    '全部开始': 'Start all',
    '全部暂停': 'Pause all',
    '总速度': 'Total speed',
    '总进度 {percent}%': 'Overall {percent}%',
    '失败原因：{error}': 'Reason: {error}',
    '服务器返回空响应': 'Empty response from server',
    '分片下载失败': 'Segment download failed',
    '下载异常：{error}': 'Download error: {error}',
    '下载不完整（{done}/{total}）': 'Incomplete download ({done}/{total})',
    '分片 {index} 下载不完整': 'Segment {index} is incomplete',
    '下载完成 · {size}': 'Downloaded · {size}',
    '下载失败 · {error}': 'Download failed · {error}',
    '正在下载 {count} 个任务': 'Downloading {count} task(s)',
    '{count} 个任务排队中': '{count} task(s) queued',
    '{count} 个任务等待开始': '{count} task(s) waiting to start',
    '上传中': 'Uploading',
    '上传失败': 'Upload failed',
    '上传失败详情': 'Upload failure details',
    '上传文件': 'Upload files',
    '上传队列': 'Upload queue',
    '暂无上传任务': 'No upload tasks',
    '取消上传': 'Cancel upload',
    '取消任务': 'Cancel task',
    '上传失败：{error}': 'Upload failed: {error}',
    '正在上传 {count} 个任务': 'Uploading {count} task(s)',
    '排队中 · {done} / {total}': 'Queued · {done} / {total}',
    '已暂停 · {done} / {total}': 'Paused · {done} / {total}',
    '已完成 · {size}': 'Completed · {size}',
    '自动重试第 {count} 次': 'Automatic retry #{count}',

    // 分享
    '分享内容': 'Shared content',
    '分享失效或链接不存在': 'This share has expired or does not exist',
    '分享根目录': 'Share root',
    '该分享已加密': 'This share is password protected',
    '该分享链接已失效': 'This share link has expired',
    '此分享没有可显示的内容': 'Nothing to show in this share',
    '进入分享': 'Open share',
    '复制链接到剪切板': 'Copy link',
    '还没有分享链接': 'No share links yet',
    '删除分享': 'Delete share',
    '已删除': 'Deleted',
    '当前没有可用站点': 'No site available',
    '无法打开分享链接，请检查链接或网络':
        'Unable to open the share link. Check the link or network.',
    '无法打开该分享': 'Unable to open this share',
    '分享链接格式无法识别': 'Unrecognized share link format',
    '保存分享为快捷方式': 'Save share shortcut',
    '已保存到「我的文件」': 'Saved to “My Files”',
    '保存失败：{error}': 'Save failed: {error}',
    '请先登录后再保存分享': 'Sign in to save this share',
    '只能保存当前站点的分享': 'Only shares from the current site can be saved',
    '一次只能分享一个文件或文件夹': 'Only one file or folder can be shared at a time',
    '请先选择要分享的文件或文件夹': 'Select a file or folder to share first',
    '确定删除分享「{name}」吗？': 'Delete share “{name}”?',
    '加载失败：{error}': 'Failed to load: {error}',
    '确定删除站点「{name}」及其本地登录状态吗？':
        'Delete site “{name}” and its local sign-in state?',
    '创建分享': 'Create share',
    '访问密码': 'Access password',
    '无密码': 'No password',
    '随机密码': 'Random password',
    '自定义密码': 'Custom password',
    '重新生成': 'Regenerate',
    '请输入自定义密码': 'Enter a custom password',
    '密码只能包含字母和数字': 'Password can only contain letters and digits',
    '创建分享失败，服务器未返回链接': 'Failed to create share: the server returned no link',
    '创建分享失败，请重试': 'Failed to create share, please try again',
    '允许查看分享设置': 'Show share view settings',
    '勾选后，其他用户访问此共享文件夹时可以看到你保存在服务器的视图设置 (布局、排序等)。':
        'When enabled, other users can see the view settings (layout, sorting, etc.) you saved on the server when visiting this shared folder.',
    '展示 README 文件': 'Show README file',
    '勾选后，会自动为访问者展示目录下的 README.md (区分大小写) 文件。':
        'When enabled, README.md (case-sensitive) in the folder is shown to visitors.',
    '超时自动过期': 'Auto-expire',
    '开启后，分享链接将在指定时间后自动失效':
        'When enabled, the share link expires after the selected time',
    '过期时间': 'Expiration',
    '1 小时': '1 hour',
    '1 天': '1 day',
    '3 天': '3 days',
    '7 天': '7 days',
    '30 天': '30 days',
    '创建中…': 'Creating…',
    '分享创建成功': 'Share created',
    '复制链接': 'Copy link',
    '在链接中包含密码': 'Include password in link',
    '取消勾选后，访问者需要另行输入密码':
        'When unchecked, visitors must enter the password separately',
    '完成': 'Done',
    '密码校验失败，请重试': 'Wrong password, please try again',
    '密码错误，请重试': 'Incorrect password, please try again',
    '请输入访问密码': 'Enter the access password',
    '解锁': 'Unlock',

    // 回收站 / 站点 / 错误
    '回收站是空的': 'Trash is empty',
    '恢复': 'Restore',
    '恢复文件': 'Restore file',
    '恢复失败，请重试': 'Restore failed, please try again',
    '已恢复': 'Restored',
    '复制原位置': 'Copy original location',
    '原位置：{path}': 'Original location: {path}',
    '确定将「{name}」恢复到原位置吗？': 'Restore “{name}” to its original location?',
    '确定彻底删除「{name}」吗？此操作不可恢复。':
        'Permanently delete “{name}”? This cannot be undone.',
    '删除站点': 'Delete site',
    '编辑站点': 'Edit site',
    '站点名称': 'Site name',
    '站点地址': 'Site URL',
    '例如：我的网盘': 'e.g. My Cloud',
    '请输入站点名称': 'Enter a site name',
    '请输入合法的站点地址（以 http(s):// 开头）':
        'Enter a valid site URL (starting with http(s)://)',
    '保存': 'Save',
    '跳过 HTTPS 证书校验': 'Skip HTTPS certificate verification',
    '站点使用自签名证书或证书链不完整时开启':
        'Enable when the site uses a self-signed or incomplete certificate chain',
    '证书校验失败，请到「站点」设置里开启该站点的「跳过 HTTPS 证书校验」':
        'Certificate verification failed. Enable “Skip HTTPS certificate verification” for this site in Sites settings.',
    '返回上一级': 'Back to parent',
    '网络异常': 'Network error',
    '网络错误': 'Network error',
    '网络连接失败': 'Connection failed',
    '请求失败': 'Request failed',
    '请求超时': 'Request timed out',
    '未配置站点': 'No site configured',
    '服务器错误 ({code})': 'Server error ({code})',
    '错误信息已复制': 'Error copied',

    // 图片 / 视频
    '图片内容为空': 'Image is empty',
    '无法加载图片': 'Failed to load image',
    '已保存到相册': 'Saved to Photos',
    '视频加载失败': 'Failed to load video',
    '当前视频编码格式可能不受支持，或文件已损坏。':
        'The video codec may be unsupported, or the file is corrupted.',
    '倍速': 'Speed',
    '倍速播放': 'Playback speed',
    '全屏': 'Full screen',
    '退出全屏': 'Exit full screen',
    '播放': 'Play',
    '锁定画面': 'Lock controls',
    '亮度 {percent}%': 'Brightness {percent}%',
    '音量 {percent}%': 'Volume {percent}%',

    // 更新
    '发现新版本': 'New version available',
    '新版本已下载': 'New version downloaded',
    '更新内容': "What's new",
    '当前': 'Current',
    '最新': 'Latest',
    '正式版本': 'Stable release',
    '预发布版本': 'Pre-release',
    '立即更新': 'Update now',
    '立即安装': 'Install now',
    '稍后': 'Later',
    '以后再说': 'Later',
    '打开发布页': 'Open release page',
    '安装包下载完成，是否立即安装？': 'Download complete. Install now?',
    'Cloudreve {version} 安装包下载完成，是否立即安装？':
        'Cloudreve {version} has been downloaded. Install now?',
    '该版本没有提供更新说明。': 'No release notes for this version.',
    '没有找到可直接下载的安装包，请在发布页手动下载。':
        'No downloadable package found. Download manually from the release page.',
    '无法开始下载，请在发布页手动下载':
        'Unable to start download. Download manually from the release page.',
    '无法启动安装器，请在下载页打开安装包':
        'Unable to launch installer. Open the package on the Downloads page.',
    '发布页地址已复制到剪贴板': 'Release page URL copied',
    '当前已是最新版本': "You're up to date",
    '未获取到发布信息': 'No release information found',
    '检查更新失败：{error}': 'Update check failed: {error}',
    '安装包已下载': 'Package downloaded',

    // 杂项
    '未选择可上传的文件': 'No files selected for upload',
    '功能暂未实现：{action}': 'Not available yet: {action}',
    '固定到侧边栏功能暂未实现': 'Pin to sidebar is not available yet',
    '未找到与“{keyword}”相关的文件': 'No files matching “{keyword}”',
    '选中文件后点「下载」即可加入队列':
        'Select files and tap “Download” to add them to the queue',
    '下载完成后会显示在这里，可在此直接打开文件':
        'Completed downloads appear here and can be opened directly',
    '失败的任务可在这里重试或删除': 'Failed tasks can be retried or deleted here',
    '暂无下载中的任务': 'No active downloads',
    '没有已完成的下载': 'No completed downloads',
    '没有下载失败的任务': 'No failed downloads',
    '将删除全部已完成的下载记录，已下载的文件会保留。':
        'All completed download records will be removed; downloaded files are kept.',
    '确定清空': 'Clear',
    '（暂无日志）\n': '(No logs)\n',
    '已失效': 'Expired',
    '开启': 'On',
    '搜索文件...': 'Search files…',
    '校验中…': 'Verifying…',
    '添加文件': 'Add files',
    '线程': 'Threads',
    '覆盖已有文件': 'Overwrite existing files',
    '退出登录': 'Sign out',
    '删除 {count} 项': 'Delete {count} item(s)',
    '加入下载队列失败：{error}': 'Failed to add to downloads: {error}',
    '本地文件不存在：{path}': 'Local file not found: {path}',
    '创建上传会话失败': 'Failed to create upload session',
    '没有适配的上传策略：{type}': 'No suitable upload strategy: {type}',
    '本地文件可能已改变，请重新添加文件后再上传':
        'The local file may have changed. Add it again before uploading.',
    ' · {count} 个排队中': ' · {count} queued',
    '未知错误': 'Unknown error',
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'zh' || locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
