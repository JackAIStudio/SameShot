# StreamSafeArea 协作说明

## 语言要求

- 与用户的回复使用简体中文。
- 如果需要给出 Plan，使用简体中文。
- Git commit 信息使用简体中文。

## 打包与安装约定

- 当代码改动完成并且已经构建成功后，如果用户明确表示“需要打包 App”或表达同等意思，默认执行打包安装流程，不再额外询问是否替换应用程序目录中的现有 App。
- 默认打包命令为：`./build-app.sh`
- 默认安装目标为：`/Applications/StreamSafeArea.app`
- 默认行为是用新打包出的 `dist/StreamSafeArea.app` 覆盖同步 `/Applications/StreamSafeArea.app`
- 除非用户明确指定其他安装位置，否则 `/Applications/StreamSafeArea.app` 视为最终交付版本

## 打包完成后的反馈

- 需要明确告知用户是否打包成功。
- 需要明确告知最终 App 路径是 `/Applications/StreamSafeArea.app`。
