@Echo Off
call :IsAdmin

echo rak baghi dir opti ta3i ?
echo  1 - yes
echo  2 - no 

echo ================================
set /p choice="Select number: "

if "%choice%"=="1" goto opti
if "%choice%"=="2" goto exitmsg

:opti

@powerShell -command "Disable-MMAgent -mc"

reg add "HKEY_CURRENT_USER\Software\Microsoft\GameBar" /v "AutoGameModeEnabled" /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsRunInBackground /t REG_DWORD /d 0 /f
reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows\fssProv" /v "EncryptProtocol" /t REG_DWORD /d "0" /f
reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule" /v "DisableRpcOver" /t REG_DWORD /d "1" /f

ipconfig/release
ipconfig/Renew
ipconfig/flushdns

netsh interface tcp set global autotuninglevel=restricted
netsh interface ipv4 set subinterface "Ethernet" mtu=1492 store=persistent
netsh interface ipv4 set subinterface "WiFi" mtu=1300 store=persistent

netsh int ipv4 set dynamicport udp start=1025 num=64511
netsh int ipv4 set dynamicport tcp start=1025 num=64511

@powershell -command "netsh int tcp set supplemental Template=Internet CongestionProvider=ctcp"
@powershell -command "netsh int tcp set supplemental Template=Datacenter CongestionProvider=ctcp"
@powershell -command "netsh int tcp set supplemental Template=Compat CongestionProvider=ctcp"
@powershell -command "netsh int tcp set supplemental Template=DatacenterCustom CongestionProvider=ctcp"
@powershell -command "netsh int tcp set supplemental Template=InternetCustom CongestionProvider=ctcp"

netsh int tcp set supplemental Template=Internet CongestionProvider=ctcp
netsh int tcp set supplemental Template=Datacenter CongestionProvider=ctcp
netsh int tcp set supplemental Template=Compat CongestionProvider=ctcp
netsh int tcp set supplemental Template=DatacenterCustom CongestionProvider=ctcp
netsh int tcp set supplemental Template=InternetCustom CongestionProvider=ctcp

netsh int tcp set global rsc=enabled 
netsh int tcp set global rss=enabled 
netsh int tcp set global dca=enabled 
netsh int tcp set global timestamps=disabled 
netsh int tcp set global initialRto=2000 
netsh int tcp set global nonsackrttresiliency=disabled 
netsh int tcp set global maxsynretransmissions=2
::@powershell -command "Get-NetAdapter | ForEach-Object { Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName 'Flow Control' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue }"
@powershell -command "Get-NetAdapter | ForEach-Object { Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName 'Green Ethernet' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue }"
@powershell -command "Get-NetAdapter | ForEach-Object { Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName 'Gigabit Lite' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue }"
@powershell -command "Get-NetAdapter | ForEach-Object { Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName 'Jumbo Frame' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue }"
@powershell -command "Get-NetAdapter | ForEach-Object { Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName 'Power Saving Mode' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue }"
@powershell -command "Get-NetAdapter | ForEach-Object { Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName 'Energy-Efficient Ethernet' -DisplayValue 'Disabled' -ErrorAction SilentlyContinue }" 
@powershell -command "Get-NetAdapter | ForEach-Object { Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName 'EEE Max Support Speed' -DisplayValue '10 Mbps Full Duplex' -ErrorAction SilentlyContinue }" 
@powershell -command "Set-NetOffloadGlobalSetting -Chimney 'Disabled'"
@powershell -command "Enable-NetAdapterChecksumOffload -Name *" 
@powershell -command "Disable-NetAdapterRsc -Name * "
@powershell -command "Set-NetOffloadGlobalSetting -PacketCoalescingFilter 'Disabled' "
::@powershell -command "Disable-NetAdapterLso -Name *"
@powershell -command "Set-NetTCPSetting -SettingName 'InternetCustom' -MinRto '300'" 
@powershell -command "Set-NetTCPSetting -SettingName 'InternetCustom' -InitialCongestionWindow '10'" 
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /t REG_DWORD /v DefaultTTL /d 64 /f 
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /t REG_DWORD /v MaxUserPort /d 65534 /f 
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /t REG_DWORD /v TcpTimedWaitDelay /d 30 /f 
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Psched" /t REG_DWORD /v NonBestEffortLimit /d 0 /f 
reg add "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\Tcpip\QoS" /t REG_SZ /v "Do not use NLA" /d 1 /f 
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /t REG_DWORD /v LargeSystemCache /d 0 /f 
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /t REG_DWORD /v Size /d 3 /f 
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Nsi\{eb004a03-9b1a-11d4-9123-0050047759bc}\26" /v "00000000" /t REG_BINARY /d "0000000000000000000000000500000000000000000000000000000000000000ff00000000000000" /f 
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Nsi\{eb004a03-9b1a-11d4-9123-0050047759bc}\26" /v "04000000" /t REG_BINARY /d "0000000000000000000000000500000000000000000000000000000000000000ff00000000000000" /f 
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Nsi\{eb004a03-9b1a-11d4-9123-0050047759bc}\0" /v "0200" /t REG_BINARY /d "0000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000ff000000000000000000000000000000000000000000ff000000000000000000000000000000" /f 
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Nsi\{eb004a03-9b1a-11d4-9123-0050047759bc}\0" /v "1700" /t REG_BINARY /d "0000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000ff000000000000000000000000000000000000000000ff000000000000000000000000000000" /f 
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v "DnsPriority" /t REG_DWORD /d "6" /f 
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v "HostsPriority" /t REG_DWORD /d "5" /f 
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v "LocalPriority" /t REG_DWORD /d "4" /f 
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider" /v "NetbtPriority" /t REG_DWORD /d "7" /f 
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /t REG_DWORD /v IRPStackSize /d 30 /f 

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Psched" /t REG_DWORD /v NonBestEffortLimit /d 0 /f 
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Psched" /t REG_DWORD /v TimerResolution /d 1 /f 

bcdedit /deletevalue disabledynamictick 
::bcdedit /set useplatformclock false
bcdedit /deletevalue useplatformclock
bcdedit /deletevalue useplatformtick
bcdedit /deletevalue tscsyncpolicy

@powershell -command "Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'SvcHostSplitThresholdInKB' -Value ((Get-CimInstance -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1KB) -Type DWord -Force"

sc config "WSearch" start= disabled
sc stop "WSearch"

sc config "TapiSrv" start= disabled
sc stop "TapiSrv"

sc config "DPS" start= disabled
sc stop "DPS"

sc config "SysMain" start= disabled
sc stop "SysMain"

sc config "Spooler" start= disabled
sc stop "Spooler"

sc config "RmSvc" start= disabled

reg add "HKLM\SYSTEM\CurrentControlSet\Services\RasMan" /v "Start" /t REG_DWORD /d "4" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\luafv" /v "Start" /t REG_DWORD /d "4" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\midisrv" /v "Start" /t REG_DWORD /d "4" /f

reg add "HKLM\SYSTEM\CurrentControlSet\Services\MMCSS" /v "Start" /t REG_DWORD /d "2" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\bam" /v "Start" /t REG_DWORD /d "1" /f

Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "NetworkThrottlingIndex" /t REG_DWORD /d "4294967295" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "SystemResponsiveness" /t REG_DWORD /d "10" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Priority" /t REG_DWORD /d "6" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Window Manager" /v "Priority" /t REG_DWORD /d "5" /f

Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\Dwm" /v "OverlayMinFPS" /t REG_DWORD /d "0" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v "NtfsDisableLastAccessUpdate" /t REG_DWORD /d "0" /f
::Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "EnableVirtualizationBasedSecurity" /t REG_DWORD /d "0" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "DisablePagingExecutive" /t REG_DWORD /d "1" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "PagingFiles" /t REG_SZ /d "C:\pagefile.sys 16 8192" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "ExistingPageFile" /t REG_SZ /d "C:\pagefile.sys" /f
reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\pci\Parameters" /v "ASPMOptOut" /t REG_DWORD /d "0" /f
reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Processor" /v "AllowPepPerfStates" /t REG_DWORD /d "0" /f

Reg.exe add "HKLM\System\CurrentControlSet\Control\Session Manager\kernel" /v "PriorityControl" /t REG_DWORD /d "50" /f
Reg.exe add "HKLM\System\CurrentControlSet\Control\Session Manager\kernel" /v "DisableOverlappedExecution" /t REG_DWORD /d "0" /f
Reg.exe add "HKLM\System\CurrentControlSet\Control\Session Manager\kernel" /v "TimeIncrement" /t REG_DWORD /d "15" /f
Reg.exe add "HKLM\System\CurrentControlSet\Control\Session Manager\kernel" /v "QuantumLength" /t REG_DWORD /d "20" /f

::Reg.exe add "HKLM\System\CurrentControlSet\Control\Session Manager\kernel" /v "ThreadDpcEnable" /t REG_DWORD /d "0" /f
::Reg.exe add "HKLM\System\CurrentControlSet\Control\Session Manager\kernel" /v "SplitLargeCaches" /t REG_DWORD /d "1" /f
::REG DELETE "HKLM\System\CurrentControlSet\Control\Session Manager\kernel" /v SplitLargeCaches /f >nul 2>&1

Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyTolerancePerfOverride" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyToleranceScreenOffIR" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "ExitLatencyCheckEnabled" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "Latency" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyToleranceDefault" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "LatencyToleranceFSVP" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "RtlCapabilityCheckLatency" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v "ExitLatency" /t REG_DWORD /d "1" /f

Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\TaggedEnergy" /v "DisableTaggedEnergyLogging" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\TaggedEnergy" /v "TelemetryMaxApplication" /t REG_DWORD /d "0" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\TaggedEnergy" /v "TelemetryMaxTagPerApplication" /t REG_DWORD /d "0" /f

Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\I/O System" /v "CountOperations" /t REG_DWORD /d "0" /f


Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultD3TransitionLatencyActivelyUsed" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultD3TransitionLatencyIdleLongTime" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultD3TransitionLatencyIdleMonitorOff" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultD3TransitionLatencyIdleNoContext" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultD3TransitionLatencyIdleShortTime" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultD3TransitionLatencyIdleVeryLongTime" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultLatencyToleranceIdle0" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultLatencyToleranceIdle0MonitorOff" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultLatencyToleranceIdle1" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultLatencyToleranceIdle1MonitorOff" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "Latency" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "MaxIAverageGraphicsLatencyInOneBucket" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "MiracastPerfTrackGraphicsLatency" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "MonitorLatencyTolerance" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "MonitorRefreshLatencyTolerance" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "TransitionLatency" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultLatencyToleranceMemory" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultLatencyToleranceNoContext" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultLatencyToleranceNoContextMonitorOff" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultLatencyToleranceOther" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultLatencyToleranceTimerPeriod" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultMemoryRefreshLatencyToleranceActivelyUsed" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultMemoryRefreshLatencyToleranceMonitorOff" /t REG_DWORD /d "1" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power" /v "DefaultMemoryRefreshLatencyToleranceNoContext" /t REG_DWORD /d "1" /f



Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v "Win32PrioritySeparation" /t REG_DWORD /d "38" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\VALORANT-Win64-Shipping.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "3" /f
::Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\VALORANT.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "6" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\RainbowSix.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\AoE3DE_s.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\cs2.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\League of Legends.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\GTA5.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\cod.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\sp24-cod.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\bf6.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\FortniteClient-Win64-Shipping.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\discord.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "5" /f
::Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v "CpuPriorityClass" /t REG_DWORD /d "4" /f
::Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "3" /f
::Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "3" /f

Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\VALORANT-Win64-Shipping.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\RainbowSix.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\AoE3DE_s.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\cs2.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\League of Legends.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\GTA5.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\sp24-cod.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\bf6.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "3" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\FortniteClient-Win64-Shipping.exe\PerfOptions" /v "IoPriority" /t REG_DWORD /d "3" /f

Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\VALORANT-Win64-Shipping.exe\PerfOptions" /v "PagePriority" /t REG_DWORD /d "5" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\RainbowSix.exe\PerfOptions" /v "PagePriority" /t REG_DWORD /d "5" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\AoE3DE_s.exe\PerfOptions" /v "PagePriority" /t REG_DWORD /d "5" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\cs2.exe\PerfOptions" /v "PagePriority" /t REG_DWORD /d "5" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\League of Legends.exe\PerfOptions" /v "PagePriority" /t REG_DWORD /d "5" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\GTA5.exe\PerfOptions" /v "PagePriority" /t REG_DWORD /d "5" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\sp24-cod.exe\PerfOptions" /v "PagePriority" /t REG_DWORD /d "5" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\bf6.exe\PerfOptions" /v "PagePriority" /t REG_DWORD /d "5" /f
Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\FortniteClient-Win64-Shipping.exe\PerfOptions" /v "PagePriority" /t REG_DWORD /d "5" /f


Reg.exe add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v "AppCaptureEnabled" /t REG_DWORD /d "0" /f
Reg.exe add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d "0" /f
Reg.exe add "HKLM\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\GameDVR" /v "AllowgameDVR" /t REG_DWORD /d "0" /f

Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v "KeyboardDataQueueSize" /t REG_DWORD /d "100" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v "MouseDataQueueSize" /t REG_DWORD /d "100" /f
Reg.exe add "HKCU\Control Panel\Mouse" /v "MouseSpeed" /t REG_SZ /d "0" /f 
Reg.exe add "HKCU\Control Panel\Mouse" /v "MouseThreshold1" /t REG_SZ /d "0" /f 
Reg.exe add "HKCU\Control Panel\Mouse" /v "MouseThreshold2" /t REG_SZ /d "0" /f 

for /f "tokens=*" %%i in ('@powershell -command "Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1 -ExpandProperty Name"') do set NIC=%%i

netsh interface ipv4 set dnsservers name="%NIC%" static 8.8.8.8 primary
netsh interface ipv4 add dnsservers name="%NIC%" 8.8.4.4 index=2

@powershell -command "Get-NetAdapterRss -Name '%NIC%' | Format-List"

@powershell -command "Set-NetAdapterRss -Name '%NIC%' -NumberOfReceiveQueues 2"

reg add "HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v "RssBaseCpu" /t REG_DWORD /d "2" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "RssBaseCpu" /t REG_DWORD /d "2" /f
::reg add "HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v "MaxRssProcessors" /t REG_DWORD /d "2" /f
::reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "MaxRssProcessors" /t REG_DWORD /d "2" /f

setlocal EnableExtensions EnableDelayedExpansion

FOR /F "tokens=*" %%D IN ('reg query "HKLM\SYSTEM\CurrentControlSet\Enum\USB"') DO (
    FOR /F "tokens=*" %%I IN ('reg query "%%D" 2^>NUL') DO (

        REG ADD "%%I\Device Parameters" /F /V "EnhancedPowerManagementEnabled" /T REG_DWORD /D 0 >NUL 2>&1
        REG ADD "%%I\Device Parameters" /F /V "AllowIdleIrpInD3"              /T REG_DWORD /D 0 >NUL 2>&1
        REG ADD "%%I\Device Parameters" /F /V "SelectiveSuspendOn"           /T REG_DWORD /D 0 >NUL 2>&1
        REG ADD "%%I\Device Parameters" /F /V "DeviceSelectiveSuspended"     /T REG_DWORD /D 0 >NUL 2>&1
        REG ADD "%%I\Device Parameters" /F /V "SelectiveSuspendEnabled"     /T REG_DWORD /D 0 >NUL 2>&1
        REG ADD "%%I\Device Parameters" /F /V "IdleInWorkingState"           /T REG_DWORD /D 0 >NUL 2>&1

        echo USB power management disabled for %%I
    )
)

endlocal

setlocal

set KEY=HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}

for /f "tokens=*" %%K in ('reg query "%KEY%"') do (

    reg query "%%K" /v PnPCapabilities >nul 2>&1
    if not errorlevel 1 (
        echo power management disabled for : %%K
        reg add "%%K" /v PnPCapabilities /t REG_DWORD /d 0x18 /f
    )

)


::remove old tweak
::REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v ThreadPriority /f >nul 2>&1
::REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v ThreadPriority /f >nul 2>&1
::REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters" /v ThreadPriority /f >nul 2>&1
::REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DXGKrnl\Parameters" /v ThreadPriority /f >nul 2>&1
::REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\USBHUB3\Parameters" /v ThreadPriority /f >nul 2>&1
::REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\USBXHCI\Parameters" /v ThreadPriority /f >nul 2>&1
::REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\igdkmd64\Parameters" /v ThreadPriority /f >nul 2>&1
::REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\AMDKMDAG\Parameters" /v ThreadPriority /f >nul 2>&1
::REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\amdkmdap\Parameters" /v ThreadPriority /f >nul 2>&1
::REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v ThreadPriority /f >nul 2>&1
::REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v ThreadPriority /f >nul 2>&1
::reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe" /f
::reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe" /f

::DISM.exe /Online /Cleanup-image /Restorehealth
::sfc /scannow

::goto exitmsg

:: Mouse Priority Boost
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\mouhid\Parameters" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul

REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul


:: Keyboard Priority Boost
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\kbdhid\Parameters" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul

:: DirectX Kernel Priority Boost
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DXGKrnl\Parameters" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\dxgmms2\Parameters" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul

:: USB Controller Priority Boost
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\USBHUB3\Parameters" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\USBXHCI\Parameters" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul
::REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Wdf01000\Parameters" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul


::REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\USBHUB3\Parameters\Wdf" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul
::REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\USBXHCI\Parameters\Wdf" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul

goto next1

cls

echo  1 - 4 cores cpu(mli7a ida rak 7ab tna9ss 3la cpu ta3k)
echo  2 - 6-8 core cpu
echo  0 - Next

echo.
set /p s=Choose an option: 


if "%s%"=="1" goto 2core
if "%s%"=="2" goto 4core
if "%s%"=="0" goto exitmsg

echo Invalid choice, exiting...
pause

:2core
cls
for /f "tokens=*" %%i in ('@powershell -command "Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1 -ExpandProperty Name"') do set NIC=%%i

@powershell -command "Get-NetAdapterRss -Name '%NIC%' | Format-List"

@powershell -command "Set-NetAdapterRss -Name '%NIC%' -NumberOfReceiveQueues 2"

reg add "HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v "RssBaseCpu" /t REG_DWORD /d "1" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "RssBaseCpu" /t REG_DWORD /d "1" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v "MaxRssProcessors" /t REG_DWORD /d "2" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "MaxRssProcessors" /t REG_DWORD /d "2" /f

goto exitmsg

:4core
cls
for /f "tokens=*" %%i in ('@powershell -command "Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1 -ExpandProperty Name"') do set NIC=%%i

@powershell -command "Get-NetAdapterRss -Name '%NIC%' | Format-List"

@powershell -command "Set-NetAdapterRss -Name '%NIC%' -NumberOfReceiveQueues 4"

reg add "HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v "RssBaseCpu" /t REG_DWORD /d "1" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "RssBaseCpu" /t REG_DWORD /d "1" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v "MaxRssProcessors" /t REG_DWORD /d "4" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "MaxRssProcessors" /t REG_DWORD /d "4" /f

goto exitmsg

:next0
cls
echo nta Streamer ?(y/n)
set /p "choice=> "

if /i "%choice%"=="y" (
    netsh interface tcp set global autotuninglevel=restricted
    Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v "Win32PrioritySeparation" /t REG_DWORD /d "37" /f
    
    reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe" /f
    reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe" /f
    goto next1
) else if /i "%choice%"=="n" (
    goto next1
)

:next1
cls
echo  1 - AMD GPU'S
echo  2 - Nvidia GPU'S
::echo  3 - Intel GPU'S
echo  3 - Restor
echo  0 - Exit

echo.
set /p s=Choose an option: 


if "%s%"=="1" goto amd
if "%s%"=="2" goto nvidia
::if "%s%"=="3" goto intel
if "%s%"=="3" goto restor
if "%s%"=="0" goto exitmsg

echo Invalid choice, exiting...
pause
exit /b

:nvidia
cls
echo Nvidia...
:: Nvidia GPU Driver Priority Boost
 REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul
goto exitmsg

:amd
cls
echo AMD...
:: AMD GPU Driver Priority Boost
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\AMDKMDAG\Parameters" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\amdfendr\Parameters" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul

goto exitmsg

:intel
cls
echo Intel...
:: INTEL GPU Driver Priority Boost
REG ADD "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\igdkmd64\Parameters" /v ThreadPriority /t REG_DWORD /d 0x0000000f /f >nul
goto exitmsg

:restor
cls
echo Restor...
:: Remove Mouse Priority Boost
REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" /v ThreadPriority /f >nul 2>&1
:: Remove Keyboard Priority Boost
REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" /v ThreadPriority /f >nul 2>&1
:: Remove Nvidia GPU Driver Priority Boost
REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters" /v ThreadPriority /f >nul 2>&1
:: Remove DirectX Kernel Priority Boost
REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\DXGKrnl\Parameters" /v ThreadPriority /f >nul 2>&1
:: Remove USB Controller Priority Boost
REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\USBHUB3\Parameters" /v ThreadPriority /f >nul 2>&1
REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\USBXHCI\Parameters" /v ThreadPriority /f >nul 2>&1
REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\igdkmd64\Parameters" /v ThreadPriority /f >nul 2>&1
REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\AMDKMDAG\Parameters" /v ThreadPriority /f >nul 2>&1
REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\amdkmdap\Parameters" /v ThreadPriority /f >nul 2>&1
REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v ThreadPriority /f >nul 2>&1
REG DELETE "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\NDIS\Parameters" /v ThreadPriority /f >nul 2>&1

Reg.exe add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "SystemResponsiveness" /t REG_DWORD /d "20" /f
Reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v "Win32PrioritySeparation" /t REG_DWORD /d "38" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\VALORANT-Win64-Shipping.exe" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\VALORANT.exe" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\RainbowSix.exe" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\AoE3DE_s.exe" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\cs2.exe" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\League of Legends.exe" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\GTA5.exe" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\cod.exe" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\sp24-cod.exe" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\FortniteClient-Win64-Shipping.exe" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe" /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\dwm.exe" /f

bcdedit /deletevalue useplatformtick
bcdedit /deletevalue useplatformclock
bcdedit /deletevalue tscsyncpolicy

goto exitmsg

:exitmsg

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
