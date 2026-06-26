# Aqua Claude Code 一键连接工具

这是给非技术用户使用的 Windows 小工具：双击打开，输入 AquaCloud Key，刷新模型，从下拉框选择模型，然后连接 Claude Code。

## 使用方法

1. 双击 `打开AquaClaudeCode工具.cmd`。
2. 输入 AquaCloud API Key。
3. 点击“刷新模型”。
4. 从“模型下拉选择”里选择模型。
5. 点击“连接 Claude Code”。

默认勾选“关闭窗口时清除 Key（推荐）”。关闭工具后，本地配置文件不会保留 API Key。

## 上传 GitHub 前注意

请只上传外层的 `github-release` 目录，不要上传你的个人工作目录。

不要上传：

- `aqua-claude-config.json`
- 任何真实 API Key
- 私人安装资料或笔记

如果真实 Key 曾经提交到 GitHub，请立刻去 AquaCloud 后台重置 Key，并重新创建干净仓库。

