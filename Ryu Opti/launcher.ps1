# Automatically check and relaunch as Administrator if not already elevated
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# GitHub Repository Details
$repoOwner = "Ryu0833"
$repoName  = "Ryu-s-opti"
$branch    = "master"

# Define your 4 options with their respective paths or direct URLs
$scripts = @(
    @{ 
        Name     = "Ryu Power"
        Type     = "RepoScript"
        Folder   = "Ryu Opti/1"
        FileName = "Ryu power.bat" 
    },
    @{ 
        Name     = "Opti"
        Type     = "RepoScript"
        Folder   = "Ryu Opti/2"
        FileName = "opti.bat" 
    },
    @{ 
        Name     = "Shader Cache Cleanup"
        Type     = "RepoScript"
        Folder   = "Ryu Opti/3"
        FileName = "clearshader.bat" 
    },
    @{ 
        Name     = "Timer Resolution Script"
        Type     = "RepoWithExe"
        Folder   = "Ryu Opti/Advanced Tweaks/1"
        FileName = "timer00.bat" 
        ExeUrl   = "https://github.com/valleyofdoom/TimerResolution/releases/download/SetTimerResolution-v1.0.0/SetTimerResolution.exe"
        ExeName  = "SetTimerResolution.exe"
    },
    @{ 
        Name     = "Auto MSI mode"
        Type     = "RepoScript"
        Folder   = "Ryu Opti/Advanced Tweaks/2"
        FileName = "Auto MSI mode .bat" 
    }
)

while ($true) {
    Clear-Host
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "   Launcher Ryu Tweaks          " -ForegroundColor Green
    Write-Host "================================" -ForegroundColor Cyan
    
    for ($i = 0; $i -lt $scripts.Count; $i++) {
        Write-Host "$($i + 1). $($scripts[$i].Name)"
    }
    Write-Host "5. Exit" -ForegroundColor Yellow
    Write-Host "--------------------------------" -ForegroundColor Cyan
    
    $choice = Read-Host "Select a script to run (1-6)"
    
    if ($choice -eq '6') {
        Write-Host "Exiting launcher." -ForegroundColor Green
        break
    }

    $index = [int]$choice - 1
    if ($index -ge 0 -and $index -lt $scripts.Count) {
        $selected = $scripts[$index]
        
        try {
            if ($selected.Type -eq "RepoScript") {
                $pathParts = $selected.Folder -split '/'
                $encodedParts = foreach ($part in $pathParts) { [System.Uri]::EscapeDataString($part) }
                $encodedPath = $encodedParts -join '/'
                
                $url = "https://raw.githubusercontent.com/$repoOwner/$repoName/$branch/$encodedPath/$($selected.FileName)"
                
                Write-Host "`nDownloading and executing $($selected.Name) as Admin..." -ForegroundColor Cyan
                $tempFile = "$env:TEMP\temp_launch_$($index).bat"
                
                Invoke-WebRequest -Uri $url -OutFile $tempFile
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$tempFile`"" -Wait
                
                if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
            }
            elseif ($selected.Type -eq "RepoWithExe") {
                # Create a dedicated temporary working directory so both the script and EXE live together
                $workDir = "$env:TEMP\RyuScript3_Work"
                if (!(Test-Path $workDir)) { New-Item -ItemType Directory -Path $workDir | Out-Null }
                
                # 1. Download the batch script from GitHub repo folder
                $pathParts = $selected.Folder -split '/'
                $encodedParts = foreach ($part in $pathParts) { [System.Uri]::EscapeDataString($part) }
                $encodedPath = $encodedParts -join '/'
                
                $scriptUrl = "https://raw.githubusercontent.com/$repoOwner/$repoName/$branch/$encodedPath/$($selected.FileName)"
                $localScript = "$workDir\$($selected.FileName)"
                
                Write-Host "`nDownloading script from GitHub repository..." -ForegroundColor Cyan
                Invoke-WebRequest -Uri $scriptUrl -OutFile $localScript
                
                # 2. Download the external EXE into the exact same folder
                $localExe = "$workDir\$($selected.ExeName)"
                Write-Host "Downloading SetTimerResolution.exe into the same folder..." -ForegroundColor Cyan
                Invoke-WebRequest -Uri $selected.ExeUrl -OutFile $localExe
                
                # 3. Execute the batch script inside that working directory as Admin so it finds the EXE
                Write-Host "Executing script with required files as Admin..." -ForegroundColor Cyan
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$localScript`"" -WorkingDirectory $workDir -Wait
                
                # 4. Clean up the working directory after execution
                if (Test-Path $workDir) { Remove-Item $workDir -Recurse -Force }
            }
        } catch {
            Write-Host "Error executing script: $_" -ForegroundColor Red
        }
        
        Write-Host "`nPress Enter to return to the menu..."
        [void](Read-Host)
    } else {
        Write-Host "Invalid selection. Please enter a number between 1 and 5." -ForegroundColor Red
        Start-Sleep -Seconds 1
    }
}