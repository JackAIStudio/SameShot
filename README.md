# StreamSafeArea

一个 macOS 本地悬浮提示框小工具，用来在共享屏幕上标记直播时右下角人物画中画（PIP）可能遮挡的区域。

## 当前 MVP 功能

- 桌面悬浮矩形提示框
- 可拖动位置
- 可直接缩放窗口大小
- 可调边框透明度
- 可调填充透明度
- 可调边框粗细
- 可切换点击穿透
- 可一键吸附到当前屏幕右下角
- 自动记住上次位置和尺寸
- 提供简单控制面板

## 运行

### 直接启动

```bash
open /Users/jkw/Documents/OfficalProjects/StreamSafeArea/dist/StreamSafeArea.app
```

### 重新构建

```bash
cd /Users/jkw/Documents/OfficalProjects/StreamSafeArea
./build-app.sh
```

构建结果：

```text
/Users/jkw/Documents/OfficalProjects/StreamSafeArea/dist/StreamSafeArea.app
```

## 使用说明

- 启动后会出现一个橙色低透明度矩形框。
- 直接拖动矩形框可以调整位置。
- 直接拖拽窗口边缘或角落可以调整大小。
- 顶部菜单里可打开“控制面板”。

控制面板支持：

- 修改宽度/高度
- 调整边框透明度
- 调整填充透明度
- 调整边框粗细
- 打开/关闭点击穿透
- 一键吸附右下角
- 隐藏/显示提示框

## 已知限制（MVP）

- 目前默认只做一个矩形框
- 还没有全局快捷键
- 还没有多显示器显式切换 UI
- 还没有锁定宽高比
- 还没有 menubar-only 模式
- 还没有正式签名与发布打包

## 推荐下一步

1. 增加多显示器选择
2. 增加锁定比例（16:9 / 自定义）
3. 增加全局快捷键显示/隐藏
4. 增加预设（直播 / 录课）
5. 优化为菜单栏工具
