# Aqua Claude Code One-Click Launcher

This is a simple Windows launcher for non-technical users. Double-click it, enter an AquaCloud API key, fetch models, select a model from the dropdown, and launch Claude Code.

## How To Use

1. Double-click `Open-AquaClaudeCode.cmd`.
2. Enter your AquaCloud API key.
3. Click `Fetch Models`.
4. Pick a model from the dropdown.
5. Click `Launch Claude Code`.

The `Clear key when closing` option is enabled by default. When the window closes, the local config file will not keep the API key.

## Before Publishing

Publish only the clean `github-release` folder.

Do not publish:

- `aqua-claude-config.json`
- Any real API key
- Private setup notes

If a real key was ever pushed to GitHub, revoke it in AquaCloud immediately and create a clean repository.

