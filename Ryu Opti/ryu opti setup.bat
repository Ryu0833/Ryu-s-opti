@echo off
setlocal EnableExtensions
title Ryu Opti - Download and Offline Setup

echo =========================================
echo   Ryu Opti - Download + Offline Launcher
echo =========================================
echo.

rem ---- Locate the real Desktop (works with OneDrive-redirected desktops) ----
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%D"
set "TARGET=%DESKTOP%\Ryu Opti"
set "WORK=%TEMP%\RyuOpti_Setup"
set "ZIP=%WORK%\repo.zip"

if exist "%WORK%" rmdir /s /q "%WORK%"
mkdir "%WORK%"

rem ---- 1. Download the repository as a zip (tries main, then master) ----
echo [1/5] Downloading repository from GitHub...
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $ProgressPreference='SilentlyContinue'; foreach($b in 'main','master'){ try{ Invoke-WebRequest -UseBasicParsing -Uri ('https://github.com/Ryu0833/Ryu-s-opti/archive/refs/heads/'+$b+'.zip') -OutFile '%ZIP%'; exit 0 }catch{} }; exit 1"
if errorlevel 1 goto fail_download

rem ---- 2. Extract ----
echo [2/5] Extracting...
powershell -NoProfile -Command "Expand-Archive -LiteralPath '%ZIP%' -DestinationPath '%WORK%\x' -Force"
if errorlevel 1 goto fail_extract

set "ROOT="
for /d %%R in ("%WORK%\x\*") do set "ROOT=%%R"
if not defined ROOT goto fail_extract
if not exist "%ROOT%\Ryu Opti" goto fail_extract

rem ---- 3. Copy "Ryu Opti" folder to the Desktop ----
echo [3/5] Copying to "%TARGET%"...
robocopy "%ROOT%\Ryu Opti" "%TARGET%" /E /NFL /NDL /NJH /NJS /NP >nul
if %errorlevel% geq 8 goto fail_copy

rem ---- 4. Download SetTimerResolution.exe so the Timer script works offline ----
echo [4/5] Downloading SetTimerResolution.exe for offline use...
if not exist "%TARGET%\Advanced Tweaks\1" mkdir "%TARGET%\Advanced Tweaks\1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $ProgressPreference='SilentlyContinue'; try{ Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/valleyofdoom/TimerResolution/releases/download/SetTimerResolution-v1.0.0/SetTimerResolution.exe' -OutFile '%TARGET%\Advanced Tweaks\1\SetTimerResolution.exe' }catch{ exit 1 }"
if errorlevel 1 echo     [!] Could not download SetTimerResolution.exe - the launcher will retry it when you are online.

rem ---- 5. Create the self-updating offline launcher + Desktop shortcut ----
echo [5/5] Creating offline launcher...
if exist "%TARGET%\Ryu Launcher Offline.bat" del /f /q "%TARGET%\Ryu Launcher Offline.bat" >nul 2>&1
if exist "%TARGET%\Ryu Launcher Offline.ps1" del /f /q "%TARGET%\Ryu Launcher Offline.ps1" >nul 2>&1
powershell -NoProfile -Command "Get-Content -LiteralPath '%~f0' | Where-Object { $_.StartsWith('::P::') } | ForEach-Object { $_.Substring(5) } | Set-Content -LiteralPath '%TARGET%\launcheroffline.ps1' -Encoding Ascii"
if errorlevel 1 goto fail_launcher
powershell -NoProfile -Command "Get-Content -LiteralPath '%~f0' | Where-Object { $_.StartsWith('::W::') } | ForEach-Object { $_.Substring(5) } | Set-Content -LiteralPath '%TARGET%\Ryu Launcher Offline.bat' -Encoding Ascii"
if errorlevel 1 goto fail_launcher

powershell -NoProfile -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%DESKTOP%\Ryu Launcher.lnk'); $s.TargetPath='%TARGET%\Ryu Launcher Offline.bat'; $s.WorkingDirectory='%TARGET%'; $s.IconLocation='shell32.dll,21'; $s.Save()"

rmdir /s /q "%WORK%" >nul 2>&1

echo.
echo =========================================
echo  Done!
echo  Folder   : %TARGET%
echo  Launcher : "Ryu Launcher" shortcut on your Desktop
echo             - always checks GitHub for updates on start
echo             - if the update fails (no internet), runs the local copy
echo =========================================
echo.
pause
exit /b 0

:fail_download
echo.
echo [X] Download failed. Check your internet connection and try again.
goto fail_end
:fail_extract
echo.
echo [X] Could not extract the downloaded archive (or "Ryu Opti" folder not found in it).
goto fail_end
:fail_copy
echo.
echo [X] Could not copy files to "%TARGET%".
goto fail_end
:fail_launcher
echo.
echo [X] Could not create the offline launcher.
:fail_end
echo.
pause
exit /b 1

::W::@echo off
::W::powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0launcheroffline.ps1"

::P::# Ryu Launcher (Offline) - launcheroffline.ps1
::P::#
::P::# Install / first run (Admin PowerShell or Terminal):
::P::#   irm https://raw.githubusercontent.com/Ryu0833/Ryu-s-opti/main/Ryu%20Opti/launcheroffline.ps1 | iex
::P::#
::P::# - Run with irm | iex : downloads the repo to Desktop\Ryu Opti, saves this launcher there,
::P::#                        creates the "Ryu Launcher" Desktop shortcut, then opens the menu.
::P::# - Run from the folder (shortcut): always tries to sync with GitHub first;
::P::#                        if the update fails (no internet) it runs the local copy.
::P::
::P::$selfUrl = 'https://raw.githubusercontent.com/Ryu0833/Ryu-s-opti/main/Ryu%20Opti/launcheroffline.ps1'
::P::$repo = 'Ryu0833/Ryu-s-opti'
::P::$isFile = [bool]$PSCommandPath
::P::
::P::# Relaunch as Administrator if needed
::P::if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
::P::    if ($isFile) {
::P::        Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
::P::    } else {
::P::        Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm '$selfUrl' | iex`"" -Verb RunAs
::P::    }
::P::    exit
::P::}
::P::
::P::[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
::P::$ProgressPreference = 'SilentlyContinue'
::P::
::P::$desktop = [Environment]::GetFolderPath('Desktop')
::P::if ($isFile) {
::P::    $root = $PSScriptRoot
::P::} else {
::P::    $root = Join-Path $desktop 'Ryu Opti'
::P::    if (!(Test-Path -LiteralPath $root)) { New-Item -ItemType Directory -Path $root | Out-Null }
::P::}
::P::
::P::function Sync-Repo {
::P::    $tmp = Join-Path $env:TEMP 'RyuOpti_Sync'
::P::    try {
::P::        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
::P::        New-Item -ItemType Directory -Path $tmp | Out-Null
::P::        $zip = Join-Path $tmp 'repo.zip'
::P::        $ok = $false
::P::        foreach ($b in 'main','master') {
::P::            try {
::P::                Invoke-WebRequest -UseBasicParsing -TimeoutSec 20 -Uri "https://github.com/$repo/archive/refs/heads/$b.zip" -OutFile $zip -ErrorAction Stop
::P::                $ok = $true
::P::                break
::P::            } catch {}
::P::        }
::P::        if (-not $ok) { return $false }
::P::        Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $tmp 'x') -Force
::P::        $src = Get-ChildItem (Join-Path $tmp 'x') -Directory | Select-Object -First 1
::P::        $inner = Join-Path $src.FullName 'Ryu Opti'
::P::        if (!(Test-Path $inner)) { return $false }
::P::        & robocopy $inner $root /E /NFL /NDL /NJH /NJS /NP | Out-Null
::P::        return ($LASTEXITCODE -lt 8)
::P::    } catch {
::P::        return $false
::P::    } finally {
::P::        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
::P::    }
::P::}
::P::
::P::# Read the menu ($scripts list + version) straight from the synced launcher.ps1,
::P::# parsed safely (data only, no code from the file is executed).
::P::function Get-Menu {
::P::    $lp = Join-Path $root 'launcher.ps1'
::P::    if (!(Test-Path -LiteralPath $lp)) { return $null }
::P::    try {
::P::        $ast = [System.Management.Automation.Language.Parser]::ParseFile($lp, [ref]$null, [ref]$null)
::P::        $assign = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$scripts' }, $true)
::P::        if (-not $assign) { return $null }
::P::        $tables = $assign.Right.FindAll({ param($n) $n -is [System.Management.Automation.Language.HashtableAst] }, $true)
::P::        $list = @()
::P::        foreach ($t in $tables) { $list += ,($t.SafeGetValue()) }
::P::        $ver = ''
::P::        $va = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$version' }, $true)
::P::        if ($va) { $ver = ($va.Right.Extent.Text -replace '"','' -replace "'",'').Trim() }
::P::        return @{ Scripts = $list; Version = $ver }
::P::    } catch { return $null }
::P::}
::P::
::P::# Save any helper EXE the menu needs (e.g. SetTimerResolution.exe) so it also works offline
::P::function Save-Exes($list) {
::P::    foreach ($s in $list) {
::P::        if ($s.ExeName -and $s.ExeUrl) {
::P::            $rel = ($s.Folder -replace '^Ryu Opti/?', '') -replace '/', '\'
::P::            $d = if ($rel) { Join-Path $root $rel } else { $root }
::P::            $e = Join-Path $d $s.ExeName
::P::            if ((Test-Path -LiteralPath $d) -and !(Test-Path -LiteralPath $e)) {
::P::                try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 30 -Uri $s.ExeUrl -OutFile $e -ErrorAction Stop } catch {}
::P::            }
::P::        }
::P::    }
::P::}
::P::
::P::# First run through irm | iex: keep a local copy of this launcher + create the shortcut
::P::function Install-Local {
::P::    $self = Join-Path $root 'launcheroffline.ps1'
::P::    if (!(Test-Path -LiteralPath $self)) {
::P::        try {
::P::            Invoke-WebRequest -UseBasicParsing -Uri $selfUrl -OutFile $self -ErrorAction Stop
::P::        } catch {
::P::            Write-Host "Could not save the offline launcher: $_" -ForegroundColor Red
::P::            return
::P::        }
::P::    }
::P::    $bat = Join-Path $root 'Ryu Launcher Offline.bat'
::P::    Set-Content -LiteralPath $bat -Value "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0launcheroffline.ps1`"" -Encoding Ascii
::P::    try {
::P::        $sc = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desktop 'Ryu Launcher.lnk'))
::P::        $sc.TargetPath = $bat
::P::        $sc.WorkingDirectory = $root
::P::        $sc.IconLocation = 'shell32.dll,21'
::P::        $sc.Save()
::P::    } catch {}
::P::    Write-Host "Offline mode installed in: $root" -ForegroundColor Green
::P::    Write-Host "Use the 'Ryu Launcher' shortcut on your Desktop next time." -ForegroundColor Green
::P::    Start-Sleep -Seconds 2
::P::}
::P::
::P::Clear-Host
::P::Write-Host "Checking GitHub for updates..." -ForegroundColor Cyan
::P::$synced = Sync-Repo
::P::if ($synced) {
::P::    $status = 'Synced with GitHub (latest version)'
::P::    $statusColor = 'Green'
::P::} else {
::P::    $status = 'Update unavailable (offline?) - using local copy'
::P::    $statusColor = 'Yellow'
::P::}
::P::if (-not $isFile) { Install-Local }
::P::if ($synced) {
::P::    $first = Get-Menu
::P::    if ($first) { Save-Exes $first.Scripts }
::P::}
::P::
::P::while ($true) {
::P::    $cfg = Get-Menu
::P::    Clear-Host
::P::    if ($null -eq $cfg -or $cfg.Scripts.Count -eq 0) {
::P::        Write-Host "Could not read launcher.ps1 from: $root" -ForegroundColor Red
::P::        Write-Host "Connect to the internet and start the launcher again so it can download the files."
::P::        [void](Read-Host "Press Enter to exit")
::P::        break
::P::    }
::P::    $scripts = $cfg.Scripts
::P::
::P::    Write-Host "=========================================" -ForegroundColor Cyan
::P::    Write-Host "     Launcher Ryu Tweaks $($cfg.Version) (Offline)" -ForegroundColor Green
::P::    Write-Host "=========================================" -ForegroundColor Cyan
::P::    Write-Host $status -ForegroundColor $statusColor
::P::    Write-Host ""
::P::    for ($i = 0; $i -lt $scripts.Count; $i++) {
::P::        Write-Host "$($i + 1). $($scripts[$i].Name)"
::P::    }
::P::    Write-Host "0. Exit" -ForegroundColor Yellow
::P::    Write-Host "--------------------------------" -ForegroundColor Cyan
::P::
::P::    $choice = Read-Host "Select a number script to run "
::P::    if ($choice -eq '0') { Clear-Host; break }
::P::
::P::    $n = 0
::P::    if (-not [int]::TryParse($choice, [ref]$n) -or $n -lt 1 -or $n -gt $scripts.Count) {
::P::        Write-Host "Invalid selection. Please enter a number from the list." -ForegroundColor Red
::P::        Start-Sleep -Seconds 1
::P::        continue
::P::    }
::P::
::P::    $sel = $scripts[$n - 1]
::P::    try {
::P::        # Repo folder "Ryu Opti/1" maps to <this folder>\1
::P::        $rel = ($sel.Folder -replace '^Ryu Opti/?', '') -replace '/', '\'
::P::        $dir = if ($rel) { Join-Path $root $rel } else { $root }
::P::        $file = Join-Path $dir $sel.FileName
::P::
::P::        if (!(Test-Path -LiteralPath $file)) {
::P::            $stem = [IO.Path]::GetFileNameWithoutExtension($sel.FileName).Trim()
::P::            $ext = [IO.Path]::GetExtension($sel.FileName)
::P::            $alt = Get-ChildItem -LiteralPath $dir -Filter "$stem*$ext" -ErrorAction SilentlyContinue | Select-Object -First 1
::P::            if ($alt) { $file = $alt.FullName }
::P::        }
::P::        if (!(Test-Path -LiteralPath $file)) { throw "Script file not found: $file (connect to the internet once to sync)" }
::P::
::P::        Write-Host "`nExecuting $($sel.Name) as Admin..." -ForegroundColor Cyan
::P::
::P::        if ($sel.Type -eq 'RepoScriptps1') {
::P::            Start-Process -FilePath 'PowerShell.exe' -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$file`"" -WorkingDirectory $dir -Wait
::P::        }
::P::        else {
::P::            if ($sel.Type -eq 'RepoWithExe') {
::P::                $exe = Join-Path $dir $sel.ExeName
::P::                if (!(Test-Path -LiteralPath $exe)) {
::P::                    Write-Host "Downloading $($sel.ExeName) (only needed once)..." -ForegroundColor Cyan
::P::                    try {
::P::                        Invoke-WebRequest -UseBasicParsing -Uri $sel.ExeUrl -OutFile $exe -ErrorAction Stop
::P::                    } catch {
::P::                        throw "$($sel.ExeName) is missing. Connect to the internet once so it can be saved for offline use."
::P::                    }
::P::                }
::P::            }
::P::            Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$file`"" -WorkingDirectory $dir -Wait
::P::        }
::P::    } catch {
::P::        Write-Host "Error executing script: $_" -ForegroundColor Red
::P::    }
::P::
::P::    Write-Host "`nPress Enter to return to the menu..."
::P::    [void](Read-Host)
::P::}
