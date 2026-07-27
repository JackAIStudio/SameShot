# SameShot

<p align="center">
  <img src="Resources/logo.png" alt="SameShot logo" width="120" />
</p>

你看到的布局，就是观众看到的画面。

SameShot 是一款用于**屏幕录制**和**电脑直播**的 macOS 摄像头画中画工具。
它把摄像头画面悬浮在桌面上，让你在录制或直播过程中随时调整人物的位置和大小，及时避开重要内容。

SameShot 本身不负责录屏或推流，需要配合现有的录制或直播软件使用。

## 适用场景

- **屏幕录制**：录制前直接排好人物画中画，录制过程中所见即所得
- **电脑直播**：实时移动或调整人物画面，避免遮挡直播内容

## 功能

- 始终置顶的摄像头画中画
- 直接拖动、缩放和快速隐藏
- 原始比例、16:9、4:3、1:1 与自由比例
- 完整显示或铺满裁切
- 摄像头画质自动匹配，以及镜像、圆角和状态保存

## 安装

1. 前往 [Releases](https://github.com/JackAIStudio/SameShot/releases) 下载最新的 `SameShot-x.y.z.dmg`
2. 打开 DMG，将 `SameShot.app` 拖入“应用程序”
3. 启动 SameShot，并允许摄像头访问

正式发布版本已通过 Developer ID 签名与 Apple 公证。

## 系统要求

- Apple Silicon Mac
- macOS 13.0 或更高版本
- 可用的摄像头

## 使用方式

1. 启动 SameShot 并授权摄像头访问
2. 将画中画拖到合适位置，并调整大小或显示比例
3. 在录制或直播软件中采集当前屏幕，开始录制或直播

摄像头画面仅在本机实时处理，不会由 SameShot 录制或上传；界面设置保存在本机。

## 当前限制

- 当前版本不提供摄像头切换：优先使用内置前置摄像头，没有内置摄像头时使用系统默认摄像头

## 开发

开发环境需要 Xcode 26 或更高版本，以及 Swift 6.2 或更高版本。

```bash
git clone https://github.com/JackAIStudio/SameShot.git
cd SameShot
open SameShot.xcodeproj
```

在 Xcode 中选择 `SameShot App` Scheme 和 `My Mac` 后运行。命令行构建仅用于检查源码：

```bash
swift test
```

贡献指南见 [CONTRIBUTING.md](CONTRIBUTING.md)，版本变更见 [CHANGELOG.md](CHANGELOG.md)。

## 许可证

[MIT License](LICENSE)
