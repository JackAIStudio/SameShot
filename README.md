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

- 线框模式 / 视频模式
- 动态列出摄像头可用分辨率（含最高支持帧率）
- 点击穿透
- 锁定位置与尺寸
- 锁定视频比例
- hover 悬浮快捷按钮
- 拖动、缩放、吸附右下角
- 将悬浮窗移动到鼠标所在屏幕
- 状态栏图标入口
- 常驻控制面板
- 预览窗口隐藏与快速恢复
- 窗口状态自动保存

## 系统要求

- macOS 13.0 或更高版本
- 摄像头（仅视频模式需要）
- Swift 6.2 工具链 / Xcode Command Line Tools（从源码构建时）

## 权限说明

- **摄像头权限**：仅视频模式需要，用于本地实时预览
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

1. 启动后会出现悬浮窗和状态栏图标 `SS`
2. 线框模式：先占位，预演画中画可能遮挡的范围
3. 视频模式：直接显示摄像头实时预览
4. 开始录屏或直播，把主内容与画中画一起录进同一画面
5. 发现遮挡时，立刻拖动或缩放悬浮窗
6. 需要时可通过控制面板调整分辨率、透明度、锁定和点击穿透

## 项目结构

```text
SameShot/
├── Sources/SameShot/   # 应用源码
├── Resources/          # App Icon / Logo / 状态栏图标
├── Package.swift       # Swift Package 定义
├── build-app.sh        # 打包 .app / DMG，并安装到 /Applications
├── LICENSE
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
└── CHANGELOG.md
```

## 开发

```bash
swift build
./build-app.sh
open dist/SameShot.app
# 同时会生成 dist/SameShot-0.1.1.dmg，并安装到 /Applications/SameShot.app
```

更完整的协作约定见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 已知限制

- 当前为早期版本（`0.1.1`），功能以实用为主
- 暂无自动化 UI 测试
- 分发包已做 Developer ID 签名与 Apple 公证；如本机策略较严，仍可能需要手动允许一次

## 贡献

欢迎提交 Issue 与 Pull Request。  
请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。

## 安全

如发现安全问题，请参考 [SECURITY.md](SECURITY.md)。

## 许可证

本项目使用 [MIT License](LICENSE)。
