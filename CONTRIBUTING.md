# 贡献指南

感谢你关注 StreamSafeArea。下面是参与开发前建议先了解的约定。

## 开发环境

- macOS 13 或更高版本
- Xcode Command Line Tools
- Swift 6.2 工具链（与 `Package.swift` 中声明一致）

## 本地运行

```bash
# 调试构建
swift build

# 打包成 .app
./build-app.sh

# 启动
open dist/StreamSafeArea.app
```

## 建议的开发流程

1. Fork 本仓库，并基于 `main` 创建功能分支
2. 保持改动聚焦，一次 PR 尽量只解决一个问题
3. 本地验证构建与基本交互
4. 提交清晰的 commit 信息
5. 发起 Pull Request，说明动机、改动点和验证方式

## Commit 约定

推荐使用简洁、可读的中文或英文 commit 信息，例如：

- `feat: 增加吸附到屏幕边缘`
- `fix: 修复摄像头分辨率切换后画面拉伸`
- `docs: 补充权限说明`
- `chore: 更新打包脚本`

## 代码风格

- 优先保持与现有文件一致的结构与命名
- 新增 UI 逻辑时尽量复用现有控制器，避免重复状态源
- 涉及窗口位置、摄像头会话、设置持久化的改动，请特别说明回归风险
- 不要提交构建产物、调试截图、本机路径或私密信息

## Pull Request 检查清单

- [ ] 本地 `swift build` 通过
- [ ] 如修改打包流程，已验证 `./build-app.sh`
- [ ] 说明测试场景（线框模式 / 视频模式 / 多屏幕等）
- [ ] 文档如有需要已同步更新

## 问题反馈

提 Issue 时请尽量包含：

- macOS 版本
- 摄像头型号（如相关）
- 复现步骤
- 期望行为与实际行为
- 相关截图或日志

## 行为准则

参与本项目即表示你同意遵守 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)。
