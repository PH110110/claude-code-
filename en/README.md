# Aqua Claude Code One-Click Launcher

This is a clean Windows launcher for non-technical users. Double-click it, enter an AquaCloud API key, fetch models, choose a working directory, and launch Claude Code in that folder.

## Download

[Download latest English version](https://github.com/PH110110/claude-code-/releases/latest/download/AquaClaudeCode-en.zip)

## How To Use

1. Download and unzip the latest English package.
2. Double-click `Open-AquaClaudeCode.cmd`.
3. Enter your AquaCloud API key.
4. Click `Fetch Models`.
5. Pick a model from the dropdown.
6. Choose the `Claude Code working directory`.
7. Click `Launch Claude Code`.

The `Clear key when closing` option is enabled by default. When the window closes, the local config file will not keep the API key.

## What Gets Saved

- Base URL
- Selected model
- Selected working directory
- API key only when you disable `Clear key when closing`

## Clean Release

This folder contains only the launcher script, the command file, and this README. Local config and temporary launch files are ignored by Git.
