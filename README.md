# Aqua Claude Code Launcher

A tiny Windows launcher that lets non-technical users connect AquaCloud models to Claude Code.

The user flow is intentionally simple:

1. Double-click the launcher.
2. Enter an AquaCloud API key.
3. Fetch models.
4. Pick a model from the dropdown.
5. Launch Claude Code.

By default, the API key is cleared when the window closes and is not written to the local config file.

## Folders

- `zh-CN/` - Chinese version.
- `en/` - English version for overseas campaigns.

## Before Publishing To GitHub

Only publish this `github-release` folder.

Do not publish files from your personal working folder, especially:

- `aqua-claude-config.json`
- Any file containing a real API key
- Personal notes or private setup documents

If a real key was ever committed, revoke it immediately in AquaCloud and rewrite the Git history or create a fresh repository.

## Upload With Git

```powershell
cd D:\模型链接工具\github-release
git init
git add .
git commit -m "Initial release"
git branch -M main
git remote add origin https://github.com/YOUR_NAME/YOUR_REPO.git
git push -u origin main
```

## Requirements

- Windows
- PowerShell 5+
- Claude Code installed and available as `claude` in PATH
- AquaCloud API key

## Security Behavior

- The key is held in memory while the window is open.
- The key is passed to the launched Claude Code PowerShell session through environment variables.
- The temporary launch script deletes itself immediately after setting environment variables.
- With the default checkbox enabled, closing the launcher clears the saved key.

