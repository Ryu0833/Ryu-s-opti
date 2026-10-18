# Ryu Launcher (Offline) - launcheroffline.ps1
#
# Install / first run (Admin PowerShell or Terminal):
#   irm https://raw.githubusercontent.com/Ryu0833/Ryu-s-opti/main/Ryu%20Opti/launcheroffline.ps1 | iex
#
# - Run with irm | iex : downloads the repo to Desktop\Ryu Opti, saves this launcher there,
#                        creates the "Ryu Launcher" Desktop shortcut, then opens the menu.
# - Run from the folder (shortcut): always tries to sync with GitHub first;
#                        if the update fails (no internet) it runs the local copy.

$selfUrl = 'https://raw.githubusercontent.com/Ryu0833/Ryu-s-opti/main/Ryu%20Opti/launcheroffline.ps1'
$repo = 'Ryu0833/Ryu-s-opti'
$isFile = [bool]$PSCommandPath

# Relaunch as Administrator if needed
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if ($isFile) {
        Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    } else {
        Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm '$selfUrl' | iex`"" -Verb RunAs
    }
    exit
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

$desktop = [Environment]::GetFolderPath('Desktop')
if ($isFile) {
    $root = $PSScriptRoot
} else {
    $root = Join-Path $desktop 'Ryu Opti'
    if (!(Test-Path -LiteralPath $root)) { New-Item -ItemType Directory -Path $root | Out-Null }
}

function Sync-Repo {
    $tmp = Join-Path $env:TEMP 'RyuOpti_Sync'
    try {
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        New-Item -ItemType Directory -Path $tmp | Out-Null
        $zip = Join-Path $tmp 'repo.zip'
        $ok = $false
        foreach ($b in 'main','master') {
            try {
                Invoke-WebRequest -UseBasicParsing -TimeoutSec 20 -Uri "https://github.com/$repo/archive/refs/heads/$b.zip" -OutFile $zip -ErrorAction Stop
                $ok = $true
                break
            } catch {}
        }
        if (-not $ok) { return $false }
        Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $tmp 'x') -Force
        $src = Get-ChildItem (Join-Path $tmp 'x') -Directory | Select-Object -First 1
        $inner = Join-Path $src.FullName 'Ryu Opti'
        if (!(Test-Path $inner)) { return $false }
        & robocopy $inner $root /E /NFL /NDL /NJH /NJS /NP | Out-Null
        return ($LASTEXITCODE -lt 8)
    } catch {
        return $false
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# Read the menu ($scripts list + version) straight from the synced launcher.ps1,
# parsed safely (data only, no code from the file is executed).
function Get-Menu {
    $lp = Join-Path $root 'launcher.ps1'
    if (!(Test-Path -LiteralPath $lp)) { return $null }
    try {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($lp, [ref]$null, [ref]$null)
        $assign = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$scripts' }, $true)
        if (-not $assign) { return $null }
        $tables = $assign.Right.FindAll({ param($n) $n -is [System.Management.Automation.Language.HashtableAst] }, $true)
        $list = @()
        foreach ($t in $tables) { $list += ,($t.SafeGetValue()) }
        $ver = ''
        $va = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$version' }, $true)
        if ($va) { $ver = ($va.Right.Extent.Text -replace '"','' -replace "'",'').Trim() }
        return @{ Scripts = $list; Version = $ver }
    } catch { return $null }
}

# Save any helper EXE the menu needs (e.g. SetTimerResolution.exe) so it also works offline
function Save-Exes($list) {
    foreach ($s in $list) {
        if ($s.ExeName -and $s.ExeUrl) {
            $rel = ($s.Folder -replace '^Ryu Opti/?', '') -replace '/', '\'
            $d = if ($rel) { Join-Path $root $rel } else { $root }
            $e = Join-Path $d $s.ExeName
            if ((Test-Path -LiteralPath $d) -and !(Test-Path -LiteralPath $e)) {
                try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 -Uri $s.ExeUrl -OutFile $e -ErrorAction Stop } catch {}
            }
        }
    }
}

# First run through irm | iex: keep a local copy of this launcher + create the shortcut
function Install-Local {
    $self = Join-Path $root 'launcheroffline.ps1'
    if (!(Test-Path -LiteralPath $self)) {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $selfUrl -OutFile $self -ErrorAction Stop
        } catch {
            Write-Host "Could not save the offline launcher: $_" -ForegroundColor Red
            return
        }
    }
    $bat = Join-Path $root 'Ryu Launcher Offline.bat'
    Set-Content -LiteralPath $bat -Value "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0launcheroffline.ps1`"" -Encoding Ascii
    try {
        $sc = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desktop 'Ryu Launcher.lnk'))
        $sc.TargetPath = $bat
        $sc.WorkingDirectory = $root
        $sc.Save()
    } catch {}
    Write-Host "Offline mode installed in: $root" -ForegroundColor Green
    Write-Host "Use the 'Ryu Launcher' shortcut on your Desktop next time." -ForegroundColor Green
    Start-Sleep -Seconds 2
}

Clear-Host
Write-Host "Checking GitHub for updates..." -ForegroundColor Cyan
$synced = Sync-Repo
if ($synced) {
    $status = 'Synced with GitHub (latest version)'
    $statusColor = 'Green'
} else {
    $status = 'Update unavailable (offline?) - using local copy'
    $statusColor = 'Yellow'
}
if (-not $isFile) { Install-Local }
if ($synced) {
    $first = Get-Menu
    if ($first) { Save-Exes $first.Scripts }
}

while ($true) {
    $cfg = Get-Menu
    Clear-Host
    if ($null -eq $cfg -or $cfg.Scripts.Count -eq 0) {
        Write-Host "Could not read launcher.ps1 from: $root" -ForegroundColor Red
        Write-Host "Connect to the internet and start the launcher again so it can download the files."
        [void](Read-Host "Press Enter to exit")
        break
    }
    $scripts = $cfg.Scripts

    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "     Launcher Ryu Tweaks $($cfg.Version) (Offline)" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host $status -ForegroundColor $statusColor
    Write-Host ""
    for ($i = 0; $i -lt $scripts.Count; $i++) {
        Write-Host "$($i + 1). $($scripts[$i].Name)"
    }
    Write-Host "0. Exit" -ForegroundColor Yellow
    Write-Host "--------------------------------" -ForegroundColor Cyan

    $choice = Read-Host "Select a number script to run "
    if ($choice -eq '0') { Clear-Host; break }

    $n = 0
    if (-not [int]::TryParse($choice, [ref]$n) -or $n -lt 1 -or $n -gt $scripts.Count) {
        Write-Host "Invalid selection. Please enter a number from the list." -ForegroundColor Red
        Start-Sleep -Seconds 1
        continue
    }

    $sel = $scripts[$n - 1]
    try {
        # Repo folder "Ryu Opti/1" maps to <this folder>\1
        $rel = ($sel.Folder -replace '^Ryu Opti/?', '') -replace '/', '\'
        $dir = if ($rel) { Join-Path $root $rel } else { $root }
        $file = Join-Path $dir $sel.FileName

        if (!(Test-Path -LiteralPath $file)) {
            $stem = [IO.Path]::GetFileNameWithoutExtension($sel.FileName).Trim()
            $ext = [IO.Path]::GetExtension($sel.FileName)
            $alt = Get-ChildItem -LiteralPath $dir -Filter "$stem*$ext" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($alt) { $file = $alt.FullName }
        }
        if (!(Test-Path -LiteralPath $file)) { throw "Script file not found: $file (connect to the internet once to sync)" }

        Write-Host "`nExecuting $($sel.Name) as Admin..." -ForegroundColor Cyan

        if ($sel.Type -eq 'RepoScriptps1') {
            Start-Process -FilePath 'PowerShell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$file`"" -WorkingDirectory $dir -Wait
        }
        else {
            if ($sel.Type -eq 'RepoWithExe') {
                $exe = Join-Path $dir $sel.ExeName
                if (!(Test-Path -LiteralPath $exe)) {
                    Write-Host "Downloading $($sel.ExeName) (only needed once)..." -ForegroundColor Cyan
                    try {
                        Invoke-WebRequest -UseBasicParsing -Uri $sel.ExeUrl -OutFile $exe -ErrorAction Stop
                    } catch {
                        throw "$($sel.ExeName) is missing. Connect to the internet once so it can be saved for offline use."
                    }
                }
            }
            Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$file`"" -WorkingDirectory $dir -Wait
        }
    } catch {
        Write-Host "Error executing script: $_" -ForegroundColor Red
    }

    Write-Host "`nPress Enter to return to the menu..."
    [void](Read-Host)
}
