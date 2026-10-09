@echo Off
setlocal EnableExtensions EnableDelayedExpansion

echo Basic Optimization for Windows.
pause


goto main

:main
cls
echo rak baghi dir :

echo  1 - Scan System File(ta9der tawl)
echo  2 - Microsoft Edge Remove/Restor
echo  3 - Brave Browser Debloat (ida 3andk)
echo  4 - Disable Windows Defender (9ader matkhdmch)
echo  5 - Old Right-Click Menu (Only Windows 11)
echo  0 - exit 

echo ================================
set /p choice="Select number: "

if "%choice%"=="0" goto exitmsg1
if "%choice%"=="1" goto scanf
if "%choice%"=="2" goto edge
if "%choice%"=="3" goto brave
if "%choice%"=="4" goto deff
if "%choice%"=="5" goto rc

:deff

cls
echo  1 - Disable Windows Defender
echo  2 - Restor Windows Defender
echo  0 - Main


echo ================================
set /p choice="Select number: "

if "%choice%"=="1" goto dff0
if "%choice%"=="2" goto dff1
if "%choice%"=="0" goto main


:dff0
cls
echo Disable Windows Defender....
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiVirus" /t REG_DWORD /d 1 /f

goto main

:dff1
cls
echo Restor Windows Defender....
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /f
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiVirus" /f

goto main

:edge
cls
echo  1 - Microsoft Edge Remove
echo  2 - Microsoft Edge Restor
echo  0 - Main


echo ================================
set /p choice="Select number: "

if "%choice%"=="1" goto edg0
if "%choice%"=="2" goto edg1
if "%choice%"=="0" goto main

:edg1
cls
@echo off
echo Remove Microsoft Edge...
winget install Microsoft.Edge --source winget
echo.
echo Installation complete.
pause

goto main

:edg0
cls
setlocal

echo Looking for Microsoft Edge installer...
set "edge_setup="

:: Search for the setup.exe in the Edge Application folder
for /f "delims=" %%I in ('dir /b /s /a-d "%ProgramFiles(x86)%\Microsoft\Edge\Application\setup.exe" 2^>nul') do (
    set "edge_setup=%%I"
)

:: Check if the installer was found
if not defined edge_setup (
    echo Microsoft Edge is not installed.
    pause
    exit /b
)

:: Create the dummy folder and file to unlock the uninstaller
if not exist "%SystemRoot%\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe" (
    mkdir "%SystemRoot%\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
)
type nul > "%SystemRoot%\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\MicrosoftEdge.exe"

:: Run the uninstaller silently
echo Uninstalling Microsoft Edge...
"%edge_setup%" --uninstall --system-level --force-uninstall --delete-profile

echo Microsoft Edge was removed.
pause

goto main

:rc

reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /f /ve
taskkill /f /im explorer.exe
start explorer.exe

goto main


:brave
cls
echo  Debloat Brave...
reg add "HKLM\SOFTWARE\Policies\BraveSoftware\Brave" /v "BraveRewardsDisabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\BraveSoftware\Brave" /v "BraveWalletDisabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\BraveSoftware\Brave" /v "BraveVPNDisabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\BraveSoftware\Brave" /v "BraveAIChatEnabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\BraveSoftware\Brave" /v "BraveStatsPingEnabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\BraveSoftware\Brave" /v "BraveNewsDisabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\BraveSoftware\Brave" /v "BraveTalkDisabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\BraveSoftware\Brave" /v "TorDisabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\BraveSoftware\Brave" /v "BraveP3AEnabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\BraveSoftware\Brave" /v "UrlKeyedAnonymizedDataCollectionEnabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\BraveSoftware\Brave" /v "SafeBrowsingExtendedReportingEnabled" /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\BraveSoftware\Brave" /v "MetricsReportingEnabled" /t REG_DWORD /d 0 /f

goto main

:scanf
cls
echo  Scan System File(This may take a while).... 
DISM.exe /Online /Cleanup-image /Restorehealth
sfc /scannow
goto main


:exitmsg
endlocal
cls
echo IDA MAKHDAMLKCH BIEN DIR RESTOR
echo Adrob tala 3la TikTok w matnssach follow
pause 
start https://linktr.ee/Ryu0833

exit


:exitmsg1
endlocal
cls
echo Adrob tala 3la TikTok w matnssach follow
pause
start https://linktr.ee/Ryu0833


exit
