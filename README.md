# StreamSafeArea

macOS 本地悬浮提示工具，用来在共享屏幕时标记直播右下角人物画中画可能遮挡的区域，也支持直接显示摄像头实时预览。

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black.svg)
![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)

## 功能

- 线框模式 / 视频模式
- 动态列出当前摄像头实际可用分辨率（含最高支持帧率）
- 点击穿透开关
- 锁定位置与尺寸开关
- 锁定视频比例开关
- hover 悬浮快捷按钮：控制 / 锁定 / 比例
- 可拖动、缩放、吸附右下角
- 可把悬浮窗移动到鼠标所在屏幕
- 顶部状态栏图标 `SSA`
- 控制面板为常驻浮动工具窗
- 预览窗口隐藏与悬浮恢复按钮
- 悬浮窗状态自动防抖保存

## 系统要求

- macOS 13.0 或更高版本
- 支持摄像头预览的 Mac（可选，仅视频模式需要）
- Swift 6.2 工具链 / Xcode Command Line Tools

## 权限说明

- **摄像头权限**：仅在使用视频模式时需要，用于本地实时预览
- 摄像头画面与界面设置仅保存在本机，不会上传到远程服务器
- 设置通过 `UserDefaults` 本地持久化

## 快速开始

```bash
# 克隆仓库
git clone https://github.com/JackAIStudio/StreamSafeArea.git
cd StreamSafeArea

# 调试构建
swift build

# 打包成 macOS App
./build-app.sh

# 运行
open dist/StreamSafeArea.app
```

首次使用视频模式时，系统会请求摄像头权限，请在弹窗中允许。

## 使用说明

1. 启动后会出现悬浮窗和状态栏图标 `SSA`
2. 线框模式：用半透明边框标记可能被遮挡的区域
3. 视频模式：在悬浮窗中显示摄像头实时预览
4. 将鼠标移入悬浮窗可显示快捷按钮
5. 可在控制面板中调整分辨率、透明度、锁定、点击穿透等选项
6. 需要共享屏幕时，把悬浮窗放到你想标记的位置即可

## 项目结构

```text
StreamSafeArea/
├── Sources/StreamSafeArea/   # 应用源码
├── Package.swift             # Swift Package 定义
├── build-app.sh              # 打包为 .app 的脚本
├── LICENSE                   # MIT 许可证
├── CONTRIBUTING.md           # 贡献指南
├── CODE_OF_CONDUCT.md        # 行为准则
├── SECURITY.md               # 安全策略
└── CHANGELOG.md              # 更新日志
```

## 开发

```bash
swift build
./build-app.sh
open dist/StreamSafeArea.app
```

更完整的协作约定见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 路线图 / 已知限制

- 当前为早期公开版本（`0.1.0`），功能以实用为主
- 暂无自动化 UI 测试
- 未做 Apple 公证（notarization），从源码自建的 App 可能需要在“隐私与安全性”中手动允许
- 控制面板中仍保留少量开发期状态信息，后续可继续收敛

## 贡献

欢迎提交 Issue 与 Pull Request。  
请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。

## 安全

如发现安全问题，请参考 [SECURITY.md](SECURITY.md)。

## 许可证

本项目使用 [MIT License](LICENSE)。
