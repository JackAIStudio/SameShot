# StreamSafeArea 协作说明

本文件用于本仓库的本地 AI / 协作者约定。对外部贡献者，请优先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 语言要求

- 与用户的回复使用简体中文。
- 如果需要给出 Plan，使用简体中文。
- Git commit 信息使用简体中文或约定式英文均可，保持清晰可读。

## 打包与安装约定

- 当代码改动完成并且已经构建成功后，如果用户明确表示“需要打包 App”或表达同等意思，默认执行打包安装流程，不再额外询问是否替换应用程序目录中的现有 App。
- 默认打包命令为：`./build-app.sh`
- 默认安装目标为：`/Applications/StreamSafeArea.app`
- 默认行为是用新打包出的 `dist/StreamSafeArea.app` 覆盖同步 `/Applications/StreamSafeArea.app`
- 除非用户明确指定其他安装位置，否则 `/Applications/StreamSafeArea.app` 视为最终交付版本

## 打包完成后的反馈

- 需要明确告知用户是否打包成功。
- 需要明确告知最终 App 路径是 `/Applications/StreamSafeArea.app`。

## 开源协作注意

- 不要把本机绝对路径、个人邮箱或其他私密信息写进公开文档。
- 不要提交 `.build`、`dist`、调试截图或本地密钥文件。
- 对外文档以 README / CONTRIBUTING / SECURITY / LICENSE 为准。
