[CmdletBinding(DefaultParameterSetName = 'Launch')]
param(
    [Parameter(Position = 0, ParameterSetName = 'Launch')]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,31}$')]
    [string]$Profile = 'Personal',

    [Parameter(ParameterSetName = 'Launch')]
    [string]$ProfilesRoot = (Join-Path $env:LOCALAPPDATA 'CodexProfiles'),

    [Parameter(ParameterSetName = 'Launch')]
    [switch]$PassThru,

    [Parameter(Mandatory, ParameterSetName = 'Install')]
    [switch]$InstallShortcuts,

    [Parameter(ParameterSetName = 'Install')]
    [string[]]$ShortcutProfiles = @('Work', 'Personal'),

    [Parameter(ParameterSetName = 'Install')]
    [string]$ShortcutProfilesRoot = (Join-Path $env:LOCALAPPDATA 'CodexProfiles'),

    [Parameter(Mandatory, ParameterSetName = 'Status')]
    [switch]$Status
)

$ErrorActionPreference = 'Stop'

function Get-CodexExecutable {
    $package = Get-AppxPackage -Name 'OpenAI.Codex' |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $package) {
        throw 'The OpenAI Codex Windows app is not installed for this user.'
    }

    $executable = Join-Path $package.InstallLocation 'app\ChatGPT.exe'
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
        throw "Codex executable was not found at: $executable"
    }

    return $executable
}

function Get-ProfilePaths([string]$Name, [string]$Root) {
    $profileRoot = Join-Path $Root $Name.ToLowerInvariant()
    [pscustomobject]@{
        Name      = $Name
        Root      = $profileRoot
        CodexHome = Join-Path $profileRoot 'codex-home'
        WebData   = Join-Path $profileRoot 'web-data'
    }
}

function Install-CodexShortcuts {
    param([string[]]$Names, [string]$Root)

    $desktop = [Environment]::GetFolderPath('Desktop')
    $shell = New-Object -ComObject WScript.Shell
    $scriptPath = $PSCommandPath
    $powershell = (Get-Command powershell.exe -ErrorAction Stop).Source
    $icon = Get-CodexExecutable

    foreach ($name in $Names) {
        if ($name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,31}$') {
            throw "Invalid profile name '$name'. Use letters, digits, dot, underscore, or hyphen."
        }

        $linkPath = Join-Path $desktop "Codex - $name.lnk"
        $shortcut = $shell.CreateShortcut($linkPath)
        $shortcut.TargetPath = $powershell
        $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Profile `"$name`" -ProfilesRoot `"$Root`""
        $shortcut.WorkingDirectory = [Environment]::GetFolderPath('UserProfile')
        $shortcut.IconLocation = "$icon,0"
        $shortcut.Description = "Launch isolated Codex profile: $name"
        $shortcut.Save()
        Write-Host "Created $linkPath"
    }
}

if ($PSCmdlet.ParameterSetName -eq 'Install') {
    Install-CodexShortcuts -Names $ShortcutProfiles -Root $ShortcutProfilesRoot
    return
}

if ($PSCmdlet.ParameterSetName -eq 'Status') {
    $exe = Get-CodexExecutable
    Get-CimInstance Win32_Process |
        Where-Object {
            $_.ExecutablePath -eq $exe -and
            $_.CommandLine -match '--user-data-dir=' -and
            $_.CommandLine -notmatch '--type='
        } |
        Select-Object ProcessId, CommandLine
    return
}

$paths = Get-ProfilePaths -Name $Profile -Root $ProfilesRoot
New-Item -ItemType Directory -Force -Path $paths.CodexHome, $paths.WebData | Out-Null

$exe = Get-CodexExecutable
$oldCodexHome = $env:CODEX_HOME
try {
    # Start-Process inherits this environment value. Restore it immediately in
    # the launcher so the caller's PowerShell session is not changed.
    $env:CODEX_HOME = $paths.CodexHome
    $process = Start-Process -FilePath $exe -ArgumentList @(
        "--user-data-dir=$($paths.WebData)"
    ) -PassThru
}
finally {
    if ($null -eq $oldCodexHome) {
        Remove-Item Env:CODEX_HOME -ErrorAction SilentlyContinue
    }
    else {
        $env:CODEX_HOME = $oldCodexHome
    }
}

Write-Host "Launched Codex profile '$Profile' (PID $($process.Id))"
Write-Host "  CODEX_HOME:   $($paths.CodexHome)"
Write-Host "  Web data:     $($paths.WebData)"

if ($PassThru) {
    $process
}
