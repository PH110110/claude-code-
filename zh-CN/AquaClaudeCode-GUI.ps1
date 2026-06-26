Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $AppDir "aqua-claude-config.json"

function Read-Config {
    if (Test-Path -LiteralPath $ConfigPath) {
        try {
            return Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            return $null
        }
    }
    return $null
}

function Save-Config($BaseUrl, $ApiKey, $Model, $ClearKeyOnClose = $true) {
    $keyToSave = ""
    if (-not $ClearKeyOnClose) {
        $keyToSave = $ApiKey
    }
    $data = [ordered]@{
        baseUrl = $BaseUrl
        apiKey = $keyToSave
        model = $Model
        clearKeyOnClose = [bool]$ClearKeyOnClose
        updatedAt = (Get-Date).ToString("s")
    }
    $data | ConvertTo-Json | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
}

function Normalize-BaseUrl($Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return "https://apibeta.aquacloud.io/v1"
    }
    return $Value.Trim().TrimEnd("/")
}

function Get-ModelId($Item) {
    if ($null -eq $Item) { return $null }
    if ($Item -is [string]) { return $Item }
    foreach ($name in @("id", "model", "name", "platform_model_id", "platformModelId")) {
        if ($Item.PSObject.Properties.Name -contains $name) {
            $value = [string]$Item.$name
            if (-not [string]::IsNullOrWhiteSpace($value)) { return $value }
        }
    }
    return [string]$Item
}

function Set-Status($Text, $ColorName = "DimGray") {
    $statusLabel.Text = $Text
    $statusLabel.ForeColor = [System.Drawing.Color]::$ColorName
}

function Add-Log($Text) {
    $time = Get-Date -Format "HH:mm:ss"
    $logBox.AppendText("[$time] $Text`r`n")
    $logBox.SelectionStart = $logBox.TextLength
    $logBox.ScrollToCaret()
}

function Refresh-Models {
    $baseUrl = Normalize-BaseUrl $baseUrlBox.Text
    $apiKey = $keyBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        [System.Windows.Forms.MessageBox]::Show("请先输入 AquaCloud API Key。", "缺少 Key", "OK", "Warning") | Out-Null
        return
    }

    $refreshButton.Enabled = $false
    $modelBox.Items.Clear()
    Set-Status "正在拉取模型..." "DarkOrange"
    Add-Log "请求 $baseUrl/models"

    try {
        $headers = @{
            Authorization = "Bearer $apiKey"
            Accept = "application/json"
        }
        $response = Invoke-RestMethod -Method Get -Uri "$baseUrl/models" -Headers $headers -TimeoutSec 45
        $items = @()
        if ($response.data) {
            $items = @($response.data)
        } elseif ($response.models) {
            $items = @($response.models)
        } elseif ($response -is [array]) {
            $items = @($response)
        }

        $ids = New-Object System.Collections.Generic.List[string]
        foreach ($item in $items) {
            $id = Get-ModelId $item
            if (-not [string]::IsNullOrWhiteSpace($id) -and -not $ids.Contains($id)) {
                [void]$ids.Add($id)
            }
        }

        if ($ids.Count -eq 0) {
            Set-Status "没有读到模型，请手动填写" "DarkOrange"
            Add-Log "请求成功，但返回里没解析出模型 ID。"
            return
        }

        foreach ($id in $ids) {
            [void]$modelBox.Items.Add($id)
        }

        if ($modelBox.Items.Count -gt 0) {
            $saved = $modelBox.Tag
            if (-not [string]::IsNullOrWhiteSpace($saved) -and $modelBox.Items.Contains($saved)) {
                $modelBox.SelectedItem = $saved
            } else {
                $modelBox.SelectedIndex = 0
            }
        }

        Save-Config $baseUrl $apiKey ([string]$modelBox.SelectedItem) $clearKeyCheckBox.Checked
        Set-Status "已拉取 $($ids.Count) 个模型" "SeaGreen"
        Add-Log "已拉取 $($ids.Count) 个模型。"
    } catch {
        Set-Status "拉取失败，可看日志" "Firebrick"
        Add-Log "拉取失败：$($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("拉取模型失败：$($_.Exception.Message)`r`n`r`n这版不是浏览器跨域问题了，通常是 Key、网络、接口路径或权限问题。", "刷新模型失败", "OK", "Error") | Out-Null
    } finally {
        $refreshButton.Enabled = $true
    }
}

function Start-Claude {
    $baseUrl = Normalize-BaseUrl $baseUrlBox.Text
    $apiKey = $keyBox.Text.Trim()
    $model = [string]$modelBox.Text

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        [System.Windows.Forms.MessageBox]::Show("请先输入 AquaCloud API Key。", "缺少 Key", "OK", "Warning") | Out-Null
        return
    }
    if ([string]::IsNullOrWhiteSpace($model)) {
        [System.Windows.Forms.MessageBox]::Show("请先刷新并选择模型。如果列表为空，可以直接在模型框里手动输入模型 ID。", "缺少模型", "OK", "Warning") | Out-Null
        return
    }

    Save-Config $baseUrl $apiKey $model $clearKeyCheckBox.Checked

    $claudeCmd = Get-Command "claude" -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        [System.Windows.Forms.MessageBox]::Show("没有找到 claude 命令。请先安装 Claude Code，或确认 claude 已加入 PATH。", "找不到 Claude Code", "OK", "Error") | Out-Null
        return
    }

    $launchScript = @"
`$env:ANTHROPIC_BASE_URL = '$($baseUrl.Replace("'", "''"))'
`$env:ANTHROPIC_AUTH_TOKEN = '$($apiKey.Replace("'", "''"))'
`$env:ANTHROPIC_MODEL = '$($model.Replace("'", "''"))'
`$env:NO_PROXY = '127.0.0.1,localhost'
Remove-Item -LiteralPath `$PSCommandPath -Force -ErrorAction SilentlyContinue
Write-Host 'AquaCloud -> Claude Code'
Write-Host ('Base URL: ' + `$env:ANTHROPIC_BASE_URL)
Write-Host ('Model: ' + `$env:ANTHROPIC_MODEL)
claude
Read-Host 'Claude Code 已退出，按回车关闭窗口'
"@
    $tempPath = Join-Path $env:TEMP "aqua-claude-launch.ps1"
    Set-Content -LiteralPath $tempPath -Value $launchScript -Encoding UTF8

    Add-Log "启动 Claude Code，模型：$model"
    Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$tempPath`"")
}

function Save-Only {
    $model = [string]$modelBox.Text
    Save-Config (Normalize-BaseUrl $baseUrlBox.Text) $keyBox.Text.Trim() $model $clearKeyCheckBox.Checked
    Set-Status "已保存" "SeaGreen"
    if ($clearKeyCheckBox.Checked) {
        Add-Log "配置已保存，但 Key 不会写入本地文件。"
    } else {
        Add-Log "配置已保存到 $ConfigPath"
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Aqua Claude Code 一键连接工具"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(760, 560)
$form.MinimumSize = New-Object System.Drawing.Size(720, 520)
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Aqua Claude Code 一键连接工具"
$title.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 16, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(24, 20)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "输入 Key，刷新模型，下拉选择，然后启动 Claude Code。"
$subtitle.AutoSize = $true
$subtitle.ForeColor = [System.Drawing.Color]::DimGray
$subtitle.Location = New-Object System.Drawing.Point(26, 58)
$form.Controls.Add($subtitle)

$baseUrlLabel = New-Object System.Windows.Forms.Label
$baseUrlLabel.Text = "Base URL"
$baseUrlLabel.Location = New-Object System.Drawing.Point(28, 100)
$baseUrlLabel.Size = New-Object System.Drawing.Size(160, 24)
$form.Controls.Add($baseUrlLabel)

$baseUrlBox = New-Object System.Windows.Forms.TextBox
$baseUrlBox.Location = New-Object System.Drawing.Point(28, 126)
$baseUrlBox.Size = New-Object System.Drawing.Size(690, 30)
$baseUrlBox.Text = "https://apibeta.aquacloud.io/v1"
$form.Controls.Add($baseUrlBox)

$keyLabel = New-Object System.Windows.Forms.Label
$keyLabel.Text = "AquaCloud API Key"
$keyLabel.Location = New-Object System.Drawing.Point(28, 174)
$keyLabel.Size = New-Object System.Drawing.Size(200, 24)
$form.Controls.Add($keyLabel)

$keyBox = New-Object System.Windows.Forms.TextBox
$keyBox.Location = New-Object System.Drawing.Point(28, 200)
$keyBox.Size = New-Object System.Drawing.Size(548, 30)
$keyBox.UseSystemPasswordChar = $true
$form.Controls.Add($keyBox)

$showKeyButton = New-Object System.Windows.Forms.Button
$showKeyButton.Text = "显示"
$showKeyButton.Location = New-Object System.Drawing.Point(590, 199)
$showKeyButton.Size = New-Object System.Drawing.Size(60, 32)
$showKeyButton.Add_Click({
    $keyBox.UseSystemPasswordChar = -not $keyBox.UseSystemPasswordChar
    $showKeyButton.Text = if ($keyBox.UseSystemPasswordChar) { "显示" } else { "隐藏" }
})
$form.Controls.Add($showKeyButton)

$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Text = "保存"
$saveButton.Location = New-Object System.Drawing.Point(658, 199)
$saveButton.Size = New-Object System.Drawing.Size(60, 32)
$saveButton.Add_Click({ Save-Only })
$form.Controls.Add($saveButton)

$modelLabel = New-Object System.Windows.Forms.Label
$modelLabel.Text = "模型下拉选择"
$modelLabel.Location = New-Object System.Drawing.Point(28, 252)
$modelLabel.Size = New-Object System.Drawing.Size(200, 24)
$form.Controls.Add($modelLabel)

$modelBox = New-Object System.Windows.Forms.ComboBox
$modelBox.Location = New-Object System.Drawing.Point(28, 278)
$modelBox.Size = New-Object System.Drawing.Size(548, 32)
$modelBox.DropDownStyle = "DropDown"
$modelBox.AutoCompleteMode = "SuggestAppend"
$modelBox.AutoCompleteSource = "ListItems"
$form.Controls.Add($modelBox)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = "刷新模型"
$refreshButton.Location = New-Object System.Drawing.Point(590, 277)
$refreshButton.Size = New-Object System.Drawing.Size(128, 34)
$refreshButton.Add_Click({ Refresh-Models })
$form.Controls.Add($refreshButton)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "连接 Claude Code"
$startButton.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
$startButton.Location = New-Object System.Drawing.Point(28, 334)
$startButton.Size = New-Object System.Drawing.Size(690, 46)
$startButton.Add_Click({ Start-Claude })
$form.Controls.Add($startButton)

$clearKeyCheckBox = New-Object System.Windows.Forms.CheckBox
$clearKeyCheckBox.Text = "关闭窗口时清除 Key（推荐）"
$clearKeyCheckBox.Checked = $true
$clearKeyCheckBox.Location = New-Object System.Drawing.Point(28, 388)
$clearKeyCheckBox.Size = New-Object System.Drawing.Size(260, 28)
$form.Controls.Add($clearKeyCheckBox)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "等待配置"
$statusLabel.ForeColor = [System.Drawing.Color]::DimGray
$statusLabel.Location = New-Object System.Drawing.Point(300, 392)
$statusLabel.Size = New-Object System.Drawing.Size(690, 24)
$form.Controls.Add($statusLabel)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(28, 426)
$logBox.Size = New-Object System.Drawing.Size(690, 76)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
$form.Controls.Add($logBox)

$config = Read-Config
if ($config) {
    if ($config.baseUrl) { $baseUrlBox.Text = [string]$config.baseUrl }
    if ($null -ne $config.clearKeyOnClose) {
        $clearKeyCheckBox.Checked = [bool]$config.clearKeyOnClose
    }
    if (-not $clearKeyCheckBox.Checked -and $config.apiKey) {
        $keyBox.Text = [string]$config.apiKey
    }
    if ($config.model) {
        $modelBox.Text = [string]$config.model
        $modelBox.Tag = [string]$config.model
    }
    Add-Log "已读取本地配置。"
}

$form.Add_FormClosing({
    if ($clearKeyCheckBox.Checked) {
        Save-Config (Normalize-BaseUrl $baseUrlBox.Text) "" ([string]$modelBox.Text) $true
        $keyBox.Text = ""
    }
})

Add-Log "准备就绪。"
[void]$form.ShowDialog()


