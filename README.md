# Aqua Claude Code Launcher

中文 / English bilingual clean release for connecting AquaCloud models to Claude Code on Windows.

## 下载 / Download

- 中文版：进入 `zh-CN/`，双击 `打开AquaClaudeCode工具.cmd`
- English: open `en/`, then double-click `Open-AquaClaudeCode.cmd`

## 功能 / Features

- 输入 AquaCloud API Key
- 拉取并选择可用模型
- 自主选择 Claude Code 启动后的工作目录
- 一键启动 Claude Code
- 默认关闭窗口时清除 API Key

## Requirements

- Windows
- PowerShell 5+
- Claude Code installed and available as `claude` in PATH
- AquaCloud API key

## Clean Release Notes

This repository intentionally contains only the launcher, command files, README files, and ignore rules.

Local user files are ignored and should not be committed:

- `aqua-claude-config.json`
- `aqua-claude-launch-*.tmp.ps1`
- Any real API key, key file, or private note
