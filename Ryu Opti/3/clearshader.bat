@echo off
setlocal EnableDelayedExpansion

echo =====================================================
echo           GPU Shader Cache Cleanup
echo =====================================================
echo.
echo Recommended usage:
echo.
echo 1. Run this script in Normal or SAFE MODE before installing
echo    or updating your GPU drivers. SAFE MODE allows Windows
echo    to remove more Shader Caches because GPU drivers are not
echo    actively running or locking the cache files.
echo.
echo 2. If you have already installed your GPU drivers 
echo    and you have stutter, frame pacing issues, glitches,
echo    or occasional instability issues then you can also
echo    run this Shader Cache cleaner to see if it solves
echo    your problems. You should clean Shader Caches
echo    before or right after each GPU driver update.
echo.
echo Run the Cleanup ?
echo  1 - yes
echo  2 - no 

echo ================================
set /p choice="Select number: "

if "%choice%"=="1" goto cl
if "%choice%"=="2" goto exit


:cl
cls
echo.
echo ==========================================
echo        Clearing GPU Shader Caches
echo ==========================================
echo.

:: Windows / DirectX
del /q /s /f "%LOCALAPPDATA%\D3DSCache\*.*" >nul 2>&1
for /d %%p in ("%LOCALAPPDATA%\D3DSCache\*") do rmdir "%%p" /s /q >nul 2>&1
del /q /s /f "%LOCALAPPDATA%\Temp\DXCache\*.*" >nul 2>&1
for /d %%p in ("%LOCALAPPDATA%\Temp\DXCache\*") do rmdir "%%p" /s /q >nul 2>&1
del /q /s /f "%LOCALAPPDATA%\Microsoft\DirectX Shader Cache\*.*" >nul 2>&1
for /d %%p in ("%LOCALAPPDATA%\Microsoft\DirectX Shader Cache\*") do rmdir "%%p" /s /q >nul 2>&1

:: Additional pipeline caches
del /q /s /f "%LOCALAPPDATA%\Temp\D3DCache\*.*" >nul 2>&1
for /d %%p in ("%LOCALAPPDATA%\Temp\D3DCache\*") do rmdir "%%p" /s /q >nul 2>&1
del /q /s /f "%LOCALAPPDATA%\Temp\NVIDIA Corporation\NV_Cache\*.*" >nul 2>&1
for /d %%p in ("%LOCALAPPDATA%\Temp\NVIDIA Corporation\NV_Cache\*") do rmdir "%%p" /s /q >nul 2>&1

:: AMD caches
del /q /s /f "%LOCALAPPDATA%\AMD\DXCache\*.*" >nul 2>&1
for /d %%p in ("%LOCALAPPDATA%\AMD\DXCache\*") do rmdir "%%p" /s /q >nul 2>&1
del /q /s /f "%LOCALAPPDATA%\AMD\GLCache\*.*" >nul 2>&1
for /d %%p in ("%LOCALAPPDATA%\AMD\GLCache\*") do rmdir "%%p" /s /q >nul 2>&1
del /q /s /f "%LOCALAPPDATA%\AMD\VkCache\*.*" >nul 2>&1
for /d %%p in ("%LOCALAPPDATA%\AMD\VkCache\*") do rmdir "%%p" /s /q >nul 2>&1

:: NVIDIA caches
del /q /s /f "%LOCALAPPDATA%\NVIDIA\DXCache\*.*" >nul 2>&1
for /d %%p in ("%LOCALAPPDATA%\NVIDIA\DXCache\*") do rmdir "%%p" /s /q >nul 2>&1
del /q /s /f "%LOCALAPPDATA%\NVIDIA\GLCache\*.*" >nul 2>&1
for /d %%p in ("%LOCALAPPDATA%\NVIDIA\GLCache\*") do rmdir "%%p" /s /q >nul 2>&1
del /q /s /f "%LOCALAPPDATA%\NVIDIA\VkCache\*.*" >nul 2>&1
for /d %%p in ("%LOCALAPPDATA%\NVIDIA\VkCache\*") do rmdir "%%p" /s /q >nul 2>&1
del /q /s /f "%APPDATA%\NVIDIA\ComputeCache\*.*" >nul 2>&1
for /d %%p in ("%APPDATA%\NVIDIA\ComputeCache\*") do rmdir "%%p" /s /q >nul 2>&1

:: Intel cache
del /q /s /f "%LOCALAPPDATA%\Intel\ShaderCache\*.*" >nul 2>&1
for /d %%p in ("%LOCALAPPDATA%\Intel\ShaderCache\*") do rmdir "%%p" /s /q >nul 2>&1


cls
echo.
echo ==========================================
echo Cleanup complete
echo ==========================================
echo.
echo.
echo Adrob tala 3la TikTok w matnssach follow

pause
start https://linktr.ee/Ryu0833
exit /b 0

:exit
cls
echo Adrob tala 3la TikTok w matnssach follow
pause 
start https://linktr.ee/Ryu0833

endlocal
exit /b 0
