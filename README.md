# cloudreve_app

基于 [Cloudreve](https://github.com/cloudreve/Cloudreve) **v4** 的 Flutter 客户端（Android），复刻 Cloudreve v4 Web 端外观与交互。

## 功能

- **登录 / 注销**：邮箱密码登录，自动检测是否需要验证码，令牌使用 `flutter_secure_storage` 安全存储。
- **多站点管理**：手动添加站点地址，可开关「跳过 TLS 证书校验」，随时切换不同 Cloudreve v4 站点。
- **文件浏览**：网格 / 列表 / 画廊三种视图，文件夹与文件分段展示，支持缩略图、排序、分页大小调节。
- **侧边栏**：「我的文件」目录树、与我共享、快速入口（图片/视频/音乐/文档/回收站/分享等）、主题切换、管理站点。
- **多选与文件操作**：单选/全选/反选，选中后顶栏出现「取消」和「更多」，带选中数量角标；文件操作菜单按「单个文件夹 / 单个文件 / 多选」展示不同操作（进入/打开、下载、分享、重命名、复制、获取直链、详细信息、删除等）。
- **图片浏览**：双击图片进入全屏纯黑浏览器，左右滑动切换整个目录的图片，左上角显示「当前/总数」，右上角「关闭 / 详情 / 下载」，下载保存到相册，加载过程有进度。
- **主题切换**：跟随系统 / 亮色 / 暗色，配色取自站点配置的主题色板。
- **返回键**：非根目录返回上一级目录，根目录两次返回退出。

## 技术栈

- Flutter 3.24.2 / Dart >= 3.4.3
- [flutter_riverpod](https://pub.dev/packages/flutter_riverpod)：状态管理
- [dio](https://pub.dev/packages/dio)：网络请求
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)：令牌安全存储
- [shared_preferences](https://pub.dev/packages/shared_preferences)：站点与设置持久化
- [cached_network_image](https://pub.dev/packages/cached_network_image)：图片缓存
- [gal](https://pub.dev/packages/gal)：图片保存到相册

## 运行

```bash
flutter pub get
flutter run
```

需要 Flutter SDK 3.24 及以上版本。

## 接口说明

- Cloudreve v4 API，基础路径：`{站点地址}/api/v4`
- 认证方式：`Authorization: Bearer <access_token>`
- 首次使用请在「添加站点」中填入你的 Cloudreve v4 站点地址（如 `https://v.timerunis.cn`）
