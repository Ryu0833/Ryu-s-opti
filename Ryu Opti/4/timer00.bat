@echo off
setlocal enabledelayedexpansion

REM --- Définir les chemins ---
set "BAT_DIR=%~dp0"
set "EXE_NAME=SetTimerResolution.exe"
set "TARGET_EXE=C:\%EXE_NAME%"
set "STARTUP_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "SHORTCUT=%STARTUP_DIR%\SetTimerResolution.lnk"

echo  1 - Install TimerResolution
echo  2 - Restor 
echo  0 - Exit
echo ================================
set /p choice="Select number: "

if "%choice%"=="1" goto install
if "%choice%"=="2" goto restore
if "%choice%"=="0" goto exit1 


:install
cls
echo  1 - 1ms(most stable recommended)
echo  2 - 0.5070ms(best perfermance mchi stable w ta9der dirlk problems sama fkahtrk kidirha) 
echo ================================
set /p choice="Select number: "

if "%choice%"=="1" goto 1
if "%choice%"=="2" goto 0.5

:1

reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v "GlobalTimerResolutionRequests" /t REG_DWORD /d "1" /f
goto exit0

:0.5

reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v "GlobalTimerResolutionRequests" /t REG_DWORD /d "1" /f

REM --- Vérifier si l'exécutable existe ---
if not exist "%BAT_DIR%%EXE_NAME%" (
    echo [ERREUR] %EXE_NAME% introuvable dans %BAT_DIR%
    pause
    exit /b
)

REM --- Copier vers C:\ ---
REM echo [INFO] Copie de %EXE_NAME% vers C:\
copy /Y "%BAT_DIR%%EXE_NAME%" "%TARGET_EXE%" >nul
if errorlevel 1 (
    echo [ERREUR] Impossible de copier %EXE_NAME% vers C:\
    pause
    exit /b
)
REM --- Créer le raccourci ---
REM echo [INFO] Création du raccourci dans le démarrage automatique...
powershell -NoProfile -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%SHORTCUT%'); $s.TargetPath = '%TARGET_EXE%'; $s.Arguments = '--resolution 5070 --no-console'; $s.WorkingDirectory = 'C:\'; $s.WindowStyle = 1; $s.Save()"
goto exit0

:restore

REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /f >nul 2>&1

REM 1. Tuer le processus si en cours
tasklist /FI "IMAGENAME eq %EXE_NAME%" | find /I "%EXE_NAME%" >nul
if not errorlevel 1 (
     REM echo [INFO] Processus %EXE_NAME% détecté, arrêt en cours...
    taskkill /F /IM "%EXE_NAME%" >nul
) else (
     echo [INFO] Aucun processus %EXE_NAME% trouvé.
)

REM 2. Supprimer l’exécutable
if exist "%TARGET_EXE%" (
    del /F /Q "%TARGET_EXE%"
     REM echo [OK] Fichier %TARGET_EXE% supprimé.
) else (
     echo [INFO] Fichier %TARGET_EXE% introuvable.
)

REM 3. Supprimer le raccourci
if exist "%SHORTCUT%" (
    del /F /Q "%SHORTCUT%"
    REM echo [OK] Raccourci supprimé.
) else (
     echo [INFO] Aucun raccourci trouvé.
)

echo [OK] Restauration terminée.
pause
goto exit1

:exit0
cls
echo IDA MAKHDAMLKCH BIEN DIR RESTOR
echo Press any key to close.
pause >nul

start https://discord.gg/gQjfXSECrj
start https://www.twitch.tv/ryu0833
start https://www.tiktok.com/@ryu_val_
start https://www.tiktok.com/@ryutech0

start cmd /k "echo Adrob tala 3la TikTok w matnssach follow & pause & exit"

exit

:exit1
cls
start https://discord.gg/gQjfXSECrj
start https://www.twitch.tv/ryu0833
start https://www.tiktok.com/@ryu_val_
start https://www.tiktok.com/@ryutech0

start cmd /k "echo Adrob tala 3la TikTok w matnssach follow & pause & exit"

exit

