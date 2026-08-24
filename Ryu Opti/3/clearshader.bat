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
echo
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
call :ClearCache "%LOCALAPPDATA%\D3DSCache" "Windows DirectX Shader Cache"
call :ClearCache "%LOCALAPPDATA%\Temp\DXCache" "DX12 Pipeline Cache"
call :ClearCache "%LOCALAPPDATA%\Microsoft\DirectX Shader Cache" "Windows DirectX Alt Cache"

:: Additional pipeline caches
call :ClearCache "%LOCALAPPDATA%\Temp\D3DCache" "Direct3D Pipeline Cache"
call :ClearCache "%LOCALAPPDATA%\Temp\NVIDIA Corporation\NV_Cache" "NVIDIA Pipeline Cache"

:: AMD caches
call :ClearCache "%LOCALAPPDATA%\AMD\DXCache" "AMD DX Cache"
call :ClearCache "%LOCALAPPDATA%\AMD\GLCache" "AMD OpenGL Cache"
call :ClearCache "%LOCALAPPDATA%\AMD\VkCache" "AMD Vulkan Cache"

:: NVIDIA caches
call :ClearCache "%LOCALAPPDATA%\NVIDIA\DXCache" "NVIDIA DX Cache"
call :ClearCache "%LOCALAPPDATA%\NVIDIA\GLCache" "NVIDIA OpenGL Cache"
call :ClearCache "%LOCALAPPDATA%\NVIDIA\VkCache" "NVIDIA Vulkan Cache"
call :ClearCache "%APPDATA%\NVIDIA\ComputeCache" "NVIDIA Compute Cache"

:: Intel cache
call :ClearCache "%LOCALAPPDATA%\Intel\ShaderCache" "Intel Shader Cache"

echo.
echo ==========================================
echo Cleanup complete
echo ==========================================
echo.

pause
goto exit

:exit
cls
echo Adrob tala 3la TikTok w matnssach follow 
start https://linktr.ee/Ryu0833

pause
endlocal
exit /b 0
