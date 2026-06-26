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
        [System.Windows.Forms.MessageBox]::Show("Please enter your AquaCloud API Key first.", "Missing Key", "OK", "Warning") | Out-Null
        return
    }

    $refreshButton.Enabled = $false
    $modelBox.Items.Clear()
    Set-Status "Fetching models..." "DarkOrange"
    Add-Log "Requesting $baseUrl/models"

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
            Set-Status "No models found. Enter one manually." "DarkOrange"
            Add-Log "Request succeeded, but no model ID was found in the response."
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
        Set-Status "Fetched $($ids.Count) models" "SeaGreen"
        Add-Log "Fetched $($ids.Count) models。"
    } catch {
        Set-Status "Fetch failed. Check the log." "Firebrick"
        Add-Log "Fetch failed: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show("Model fetch failed: $($_.Exception.Message)`r`n`r`nThis is not a browser CORS issue. It is usually caused by the key, network, endpoint path, or account permissions.", "Model refresh failed", "OK", "Error") | Out-Null
    } finally {
        $refreshButton.Enabled = $true
    }
}

function Start-Claude {
    $baseUrl = Normalize-BaseUrl $baseUrlBox.Text
    $apiKey = $keyBox.Text.Trim()
    $model = [string]$modelBox.Text

    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter your AquaCloud API Key first.", "Missing Key", "OK", "Warning") | Out-Null
        return
    }
    if ([string]::IsNullOrWhiteSpace($model)) {
        [System.Windows.Forms.MessageBox]::Show("Refresh and select a model first. If the list is empty, type the model ID directly into the model box.", "Missing Model", "OK", "Warning") | Out-Null
        return
    }

    Save-Config $baseUrl $apiKey $model $clearKeyCheckBox.Checked

    $claudeCmd = Get-Command "claude" -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        [System.Windows.Forms.MessageBox]::Show("The claude command was not found. Install Claude Code first, or make sure claude is in PATH.", "Claude Code Not Found", "OK", "Error") | Out-Null
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
Read-Host 'Claude Code has exited. Press Enter to close this window.'
"@
    $tempPath = Join-Path $env:TEMP "aqua-claude-launch.ps1"
    Set-Content -LiteralPath $tempPath -Value $launchScript -Encoding UTF8

    Add-Log "Starting Claude Code with model: $model"
    Start-Process -FilePath "powershell.exe" -ArgumentList @("-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$tempPath`"")
}

function Save-Only {
    $model = [string]$modelBox.Text
    Save-Config (Normalize-BaseUrl $baseUrlBox.Text) $keyBox.Text.Trim() $model $clearKeyCheckBox.Checked
    Set-Status "Saved" "SeaGreen"
    if ($clearKeyCheckBox.Checked) {
        Add-Log "配置Saved，但 Key 不会写入本地文件。"
    } else {
        Add-Log "配置Saved到 $ConfigPath"
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Aqua Claude Code One-Click Launcher"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(760, 560)
$form.MinimumSize = New-Object System.Drawing.Size(720, 520)
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 10)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Aqua Claude Code One-Click Launcher"
$title.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 16, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(24, 20)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Enter your key, fetch models, choose one, then launch Claude Code."
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
$showKeyButton.Text = "Show"
$showKeyButton.Location = New-Object System.Drawing.Point(590, 199)
$showKeyButton.Size = New-Object System.Drawing.Size(60, 32)
$showKeyButton.Add_Click({
    $keyBox.UseSystemPasswordChar = -not $keyBox.UseSystemPasswordChar
    $showKeyButton.Text = if ($keyBox.UseSystemPasswordChar) { "Show" } else { "Hide" }
})
$form.Controls.Add($showKeyButton)

$saveButton = New-Object System.Windows.Forms.Button
$saveButton.Text = "Save"
$saveButton.Location = New-Object System.Drawing.Point(658, 199)
$saveButton.Size = New-Object System.Drawing.Size(60, 32)
$saveButton.Add_Click({ Save-Only })
$form.Controls.Add($saveButton)

$modelLabel = New-Object System.Windows.Forms.Label
$modelLabel.Text = "Model selection"
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
$refreshButton.Text = "Fetch Models"
$refreshButton.Location = New-Object System.Drawing.Point(590, 277)
$refreshButton.Size = New-Object System.Drawing.Size(128, 34)
$refreshButton.Add_Click({ Refresh-Models })
$form.Controls.Add($refreshButton)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "Launch Claude Code"
$startButton.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
$startButton.Location = New-Object System.Drawing.Point(28, 334)
$startButton.Size = New-Object System.Drawing.Size(690, 46)
$startButton.Add_Click({ Start-Claude })
$form.Controls.Add($startButton)

$clearKeyCheckBox = New-Object System.Windows.Forms.CheckBox
$clearKeyCheckBox.Text = "Clear key when closing (recommended)"
$clearKeyCheckBox.Checked = $true
$clearKeyCheckBox.Location = New-Object System.Drawing.Point(28, 388)
$clearKeyCheckBox.Size = New-Object System.Drawing.Size(260, 28)
$form.Controls.Add($clearKeyCheckBox)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Waiting for settings"
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
    Add-Log "Loaded local settings."
}

$form.Add_FormClosing({
    if ($clearKeyCheckBox.Checked) {
        Save-Config (Normalize-BaseUrl $baseUrlBox.Text) "" ([string]$modelBox.Text) $true
        $keyBox.Text = ""
    }
})

Add-Log "Ready."
[void]$form.ShowDialog()



