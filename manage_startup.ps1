param(
    [ValidateSet("Enable", "Disable", "Toggle", "Status")]
    [string]$Action = "Status"
)

$startupDirectory = [Environment]::GetFolderPath("Startup")
$shortcutPath = Join-Path $startupDirectory "CursorParker.lnk"
$scriptPath = Join-Path $PSScriptRoot "cursor_parker.ps1"
$powerShellPath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

function Enable-CursorParkerStartup {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $powerShellPath
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.WindowStyle = 7
    $shortcut.Description = "Start CursorParker"
    $shortcut.Save()
    Write-Output "CursorParker startup is enabled."
}

function Disable-CursorParkerStartup {
    if (Test-Path -LiteralPath $shortcutPath) {
        Remove-Item -LiteralPath $shortcutPath -Force
    }
    Write-Output "CursorParker startup is disabled."
}

switch ($Action) {
    "Enable" {
        Enable-CursorParkerStartup
    }
    "Disable" {
        Disable-CursorParkerStartup
    }
    "Toggle" {
        if (Test-Path -LiteralPath $shortcutPath) {
            Disable-CursorParkerStartup
        }
        else {
            Enable-CursorParkerStartup
        }
    }
    "Status" {
        if (Test-Path -LiteralPath $shortcutPath) {
            Write-Output "CursorParker startup is enabled."
        }
        else {
            Write-Output "CursorParker startup is disabled."
        }
    }
}
