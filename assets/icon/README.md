# 应用图标源文件

这里只存**设计源文件与母版**，不参与 App 打包（未在 `pubspec.yaml` 的 `assets` 中声明）。

| 文件 | 说明 |
|---|---|
| `../cloudreve.svg` | 原始矢量图（viewBox 0 0 1835 1835） |
| `cloudreve_1024.png` | 由 SVG 渲染的 1024×1024 母版（透明角），重新导出图标时以它为基准 |
| `preview.png` | 192px 传统图标 / 180px iOS / 192px maskable 预览 |
| `preview_small.png` | 48 / 180 / 32 / 128 小尺寸观感预览（3× 放大） |

已经生成到各平台的位置（无需再重复生成）：

- Android：`android/app/src/main/res/mipmap-*/ic_launcher.png`、`ic_launcher_foreground.png`、
  `mipmap-anydpi-v26/ic_launcher.xml`、`values/ic_launcher_background.xml`（背景色 `#CBE9F7`）
- iOS：`ios/Runner/Assets.xcassets/AppIcon.appiconset/`（铺 `#CBE9F7` 底、无 alpha）
- macOS：`macos/Runner/Assets.xcassets/AppIcon.appiconset/`（圆角方块，透明外围）
- Windows：`windows/runner/resources/app_icon.ico`（16–256 多尺寸）
- Web：`web/favicon.png`、`web/icons/Icon-192.png`、`Icon-512.png`、`Icon-maskable-192/512.png`

如需调整图标，改 `cloudreve.svg` 后用 Chromium 内核渲染成 1024 PNG（ImageMagick 对 clipPath 渲染不准），
再按各平台尺寸等比缩放即可。
