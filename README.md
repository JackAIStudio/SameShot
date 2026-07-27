# SameShot

<p align="center">
  <img src="Resources/logo.png" alt="SameShot logo" width="120" />
</p>

让观众看到的，就是你正在录的。

SameShot 是一个面向视频录制（尤其教学 / 讲解）的 macOS 画中画布局助手。  
它帮你把人物预览直接放进屏幕画面里，在录制过程中实时发现遮挡、立刻调整位置，让录制者看到的画面与观众最终看到的画面保持一致，并减少双轨录制和后期拼接。直播场景同样适用。

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black.svg)
![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)

## 为什么需要它

常见做法是：

1. 主画面录一份
2. 摄像头画面另录一份
3. 后期再拼画中画

这样更灵活，但录的时候你往往不知道最终会不会挡住关键内容；问题要到剪辑阶段才暴露。

SameShot 走的是另一条路：

1. 在屏幕上放好人物画中画
2. 直接录这一整屏
3. 录制中发现遮挡，立刻挪开
4. 观众看到的，就是你录制时看到的

## 功能

- 摄像头实时预览
- 单一摄像头画质列表，自动模式优先使用摄像头提供的最低分辨率与接近 30 fps 的帧率
- 动态展示摄像头提供的全部原生分辨率，按画面从小到大排列并标注横屏、方形或竖屏比例
- 帧率由应用自动匹配，优先选择最接近 30 fps 的可用帧率
- 原始画面比例、16:9、4:3、1:1 与自由调整等画中画比例
- 填满裁切或完整显示摄像头画面
- 直接拖动和缩放画中画
- 一键恢复画中画默认大小，并可从菜单栏重置位置
- 状态栏图标入口
- 常驻控制面板
- 视频圆角与镜像设置
- 预览窗口隐藏与快速恢复
- 窗口状态自动保存

## 系统要求

- macOS 13.0 或更高版本
- 摄像头
- Xcode 26 或更高版本（推荐用于界面调试）
- Swift 6.2 工具链 / Xcode Command Line Tools（仅使用命令行构建时）

## 权限说明

- **摄像头权限**：用于本地实时预览
- 如果曾拒绝授权，可在悬浮窗中点击“打开摄像头权限设置”重新授权
- 摄像头画面与界面设置只保存在本机，不会上传
- 设置通过 `UserDefaults` 本地持久化

## 安装

### 方式一：下载 DMG（推荐）

1. 打开 [Releases](https://github.com/JackAIStudio/SameShot/releases) 下载最新的 `SameShot-x.y.z.dmg`
2. 打开 DMG，把 `SameShot.app` 拖到 `Applications`
3. 正式分发版已通过 Developer ID 签名与 Apple 公证，通常可直接打开

### 方式二：从源码构建

```bash
git clone https://github.com/JackAIStudio/SameShot.git
cd SameShot
swift build
./build-app.sh
open dist/SameShot.app
```

## 使用方式

1. 启动后会出现悬浮窗和 SameShot 品牌状态栏图标
2. 授权摄像头访问后，悬浮窗会显示摄像头实时预览
3. 开始录屏或直播，把主内容与画中画一起录进同一画面
4. 发现遮挡时，立刻拖动或缩放悬浮窗
5. 需要时可通过控制面板调整摄像头画质、画中画比例、圆角和镜像

## 默认设置

- 摄像头画质：自动优先选择最低分辨率与接近 30 fps 的帧率；手动选项按分辨率从小到大展示，并在控制面板显示实际输入
- 画中画大小：默认宽度 320，可直接拖动窗口边缘调整
- 画中画比例：保持原始画面比例，避免用户手动判断画面比例
- 显示方式：铺满窗口；仅当窗口与摄像头比例不一致时才会裁切
- 外观：圆角 18，默认开启镜像

## 项目结构

```text
SameShot/
├── Sources/SameShot/   # 应用源码
├── Resources/          # App Icon / Logo / 状态栏图标
├── Config/             # Xcode App 的 Bundle 身份与权限配置
├── SameShot.xcodeproj/ # 原生 macOS App 工程与共享 Scheme
├── Package.swift       # Swift Package 定义
├── build-app.sh        # 打包 .app / DMG，并安装到 /Applications
├── LICENSE
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
└── CHANGELOG.md
```

## 开发

界面与状态栏功能请通过原生 App 工程调试：

```bash
open SameShot.xcodeproj
```

在 Xcode 中选择共享的 `SameShot App` Scheme 和 `My Mac`，然后按 `⌘R`。该入口运行的是带固定 Bundle ID、App Icon 和程序化品牌状态栏图标的 Debug `.app`，Bartender 等菜单栏管理工具可以稳定识别它。若 Scheme 显示为 `SameShot` 而不是 `SameShot App`，说明当前打开的仍是 Swift Package。

不要通过打开 `Package.swift` 后直接运行可执行文件来调试菜单栏界面；Swift Package 入口只生成裸可执行文件，不具备 macOS App Bundle 身份。

如果使用 Bartender 且图标仍未直接出现在顶部菜单栏，请先在 Bartender 的“菜单栏布局”中刷新项目清单，再检查“隐藏项目”和“始终隐藏”分组。SameShot 不会绕过用户在菜单栏管理工具中设置的显示规则。

命令行编译仍然可用于快速检查源码：

```bash
swift build
```

需要生成签名、公证的分发包时：

```bash
./build-app.sh
open dist/SameShot.app
# 同时会生成 dist/SameShot-0.1.3.dmg，并安装到 /Applications/SameShot.app
```

更完整的协作约定见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 已知限制

- 当前为早期版本（`0.1.3`），功能以实用为主
- 暂无自动化 UI 测试
- 分发包已做 Developer ID 签名与 Apple 公证；如本机策略较严，仍可能需要手动允许一次

## 贡献

欢迎提交 Issue 与 Pull Request。  
请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。

## 安全

如发现安全问题，请参考 [SECURITY.md](SECURITY.md)。

## 许可证

本项目使用 [MIT License](LICENSE)。
