# Aqua Claude Code 一键连接工具

这是给非技术用户使用的 Windows 纯净版小工具：双击打开，输入 AquaCloud Key，刷新模型，选择工作目录，然后在该目录中启动 Claude Code。

## 使用方法

1. 双击 `打开AquaClaudeCode工具.cmd`。
2. 输入 AquaCloud API Key。
3. 点击“刷新模型”。
4. 从“模型下拉选择”里选择模型。
5. 在“Claude Code 工作目录”里选择你的项目目录。
6. 点击“连接 Claude Code”。

默认勾选“关闭窗口时清除 Key（推荐）”。关闭工具后，本地配置文件不会保留 API Key。

## 会保存什么

- Base URL
- 已选择的模型
- 已选择的工作目录
- 只有取消“关闭窗口时清除 Key”时，才会保存 API Key

## 纯净版说明

这个目录只包含启动脚本、双击入口和说明文档。本地配置文件、临时启动脚本、真实 Key 都会被 Git 忽略。
