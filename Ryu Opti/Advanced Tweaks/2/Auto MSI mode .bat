<# : batch header
@echo off
setlocal
:: Check for Administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] ERROR: Please right-click this batch file and select "Run as administrator".
    echo.
    pause
    exit /b
)
title PCI Device MSI Mode, Priority and Core Manager (Created by Ryu)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression ([System.IO.File]::ReadAllText('%~f0'))"
exit /b
#>

# Pure PowerShell Code
$Host.UI.RawUI.WindowTitle = "PCI Device MSI Mode, Priority and Core Manager (Created by Ryu)"

# Load Win32 API to detect P-Cores, E-Cores, and SMT Topology
try {
    Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;
    using System.Collections.Generic;

    public class CpuTopology {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool GetLogicalProcessorInformationEx(
            int relationshipType,
            IntPtr buffer,
            ref int returnedLength
        );

        public class CoreInfo {
            public int PhysicalCoreIndex { get; set; }
            public int PrimaryLogicalCore { get; set; }
            public int EfficiencyClass { get; set; }
            public bool IsPCore { get; set; }
            public bool HasSMT { get; set; }
        }

        public static List<CoreInfo> GetCoreDetails() {
            var cores = new List<CoreInfo>();
            int length = 0;
            GetLogicalProcessorInformationEx(0, IntPtr.Zero, ref length); // 0 = RelationProcessorCore
            if (length == 0) return cores;

            IntPtr buffer = Marshal.AllocHGlobal(length);
            try {
                if (GetLogicalProcessorInformationEx(0, buffer, ref length)) {
                    IntPtr ptr = buffer;
                    int offset = 0;
                    int coreIdx = 0;
                    int maxEff = 0;

                    var tempCores = new List<Tuple<int, int, bool, List<int>>>();

                    while (offset < length) {
                        int flags = Marshal.ReadByte(ptr, offset + 4);
                        int effClass = Marshal.ReadByte(ptr, offset + 5);
                        if (effClass > maxEff) { maxEff = effClass; }

                        bool smt = (flags & 1) != 0;
                        int groupCount = Marshal.ReadInt16(ptr, offset + 28);
                        var logCores = new List<int>();

                        int groupOffset = offset + 32;
                        for (int g = 0; g < groupCount; g++) {
                            long mask = Marshal.ReadInt64(ptr, groupOffset);
                            for (int bit = 0; bit < 64; bit++) {
                                if ((mask & (1L << bit)) != 0) {
                                    logCores.Add(bit);
                                }
                            }
                            groupOffset += 16;
                        }

                        tempCores.Add(new Tuple<int, int, bool, List<int>>(coreIdx, effClass, smt, logCores));
                        int structSize = Marshal.ReadInt32(ptr, offset + 0);
                        offset += structSize;
                        coreIdx++;
                    }

                    foreach (var tc in tempCores) {
                        bool isP = (tc.Item2 == maxEff);
                        cores.Add(new CoreInfo {
                            PhysicalCoreIndex = tc.Item1,
                            EfficiencyClass = tc.Item2,
                            IsPCore = isP,
                            HasSMT = tc.Item3,
                            PrimaryLogicalCore = tc.Item4.Count > 0 ? tc.Item4[0] : tc.Item1
                        });
                    }
                }
            } catch {} finally {
                Marshal.FreeHGlobal(buffer);
            }
            return cores;
        }
    }
"@ -ErrorAction SilentlyContinue
} catch {}

# Helper Function: Get System CPU Profile
function Get-CpuProfile {
    $cores = @()
    if ([System.Type]::GetType("CpuTopology")) {
        $cores = [CpuTopology]::GetCoreDetails()
    }

    # Fallback to WMI if Win32 API returns empty
    if ($cores.Count -eq 0) {
        $procs = Get-CimInstance Win32_Processor
        $pCores = ($procs | Measure-Object -Property NumberOfCores -Sum).Sum
        $lCores = ($procs | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
        $smt = $lCores -gt $pCores

        for ($i = 0; $i -lt $pCores; $i++) {
            $log = if ($smt) { $i * 2 } else { $i }
            $cores += [PSCustomObject]@{
                PhysicalCoreIndex  = $i
                PrimaryLogicalCore = $log
                EfficiencyClass    = 0
                IsPCore            = $true
                HasSMT             = $smt
            }
        }
    }

    $totalPhys = $cores.Count
    $totalLog  = ($cores | Measure-Object -Property PrimaryLogicalCore -Maximum).Maximum + 1
    $hasSMT    = ($cores | Where-Object { $_.HasSMT }).Count -gt 0
    $pCores    = $cores | Where-Object { $_.IsPCore }
    $eCores    = $cores | Where-Object { -not $_.IsPCore }
    $isHybrid  = $eCores.Count -gt 0

    return [PSCustomObject]@{
        AllCores     = $cores
        PCores       = $pCores
        ECores       = $eCores
        TotalPhys    = $totalPhys
        HasSMT       = $hasSMT
        IsHybrid     = $isHybrid
    }
}

# Helper Function: Generate 8-byte Binary Mask for AssignmentSetOverride
function Get-AssignmentSetBytes ([int]$coreNum) {
    $bytes = [byte[]]::new(8)
    if ($coreNum -ge 0 -and $coreNum -lt 64) {
        $byteIdx = [math]::Floor($coreNum / 8)
        $bitPos  = $coreNum % 8
        $bytes[$byteIdx] = [byte](1 -shl $bitPos)
    }
    return $bytes
}

# Helper Function: Parse Core Number from AssignmentSetOverride Bytes
function Get-AssignedCoreFromBytes ($bytes) {
    if (-not $bytes) { return "Default" }
    for ($b = 0; $b -lt $bytes.Count; $b++) {
        if ($bytes[$b] -gt 0) {
            for ($bit = 0; $bit -lt 8; $bit++) {
                if (($bytes[$b] -band (1 -shl $bit)) -ne 0) {
                    return "Core " + (($b * 8) + $bit)
                }
            }
        }
    }
    return "Default"
}

# Helper Function: Elevate PCIe Tree Ports Priority to High
function Set-TreeHighPriority ([PSCustomObject]$Device, [string]$Indent = "   ") {
    if ($Device.TreePorts -and $Device.TreePorts.Count -gt 0) {
        foreach ($port in $Device.TreePorts) {
            if (-not (Test-Path $port.RegPrioPath)) { New-Item -Path $port.RegPrioPath -Force | Out-Null }
            Set-ItemProperty -Path $port.RegPrioPath -Name "DevicePriority" -Value 3 -Type DWord -Force
            Write-Host "$Indent-> PCIe Tree Escalation: $($port.Name) -> High Priority" -ForegroundColor DarkCyan
        }
    }
}

function Get-PciDevices {
    $devices = @()
    try {
        $colDevices = Get-CimInstance -ClassName Win32_PnPEntity -Filter "PNPDeviceID LIKE 'PCI%'" -ErrorAction Stop
    } catch {
        $colDevices = Get-WmiObject -Class Win32_PnPEntity -Filter "PNPDeviceID LIKE 'PCI%'"
    }

    # Build dictionary for quick parent lookup
    $devDict = @{}
    foreach ($d in $colDevices) {
        $devDict[$d.PNPDeviceID] = $d
    }

    foreach ($dev in $colDevices) {
        if ($dev.PNPClass -in @('Display', 'Net', 'USB')) {
            $pnpID = $dev.PNPDeviceID
            
            # Detect Driver Type for Network Cards (NDIS vs WDF)
            $driverType = "N/A"
            if ($dev.PNPClass -eq 'Net') {
                $svcName = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpID" -Name "Service" -ErrorAction SilentlyContinue).Service
                $isWdf = $false
                if ($svcName) {
                    $svcReg = "HKLM:\SYSTEM\CurrentControlSet\Services\$svcName"
                    if ((Test-Path "$svcReg\Wdf") -or (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpID\Device Parameters\Wdf")) {
                        $isWdf = $true
                    } else {
                        $svcImagePath = (Get-ItemProperty -Path $svcReg -Name "ImagePath" -ErrorAction SilentlyContinue).ImagePath
                        if ($svcImagePath -like "*wdf*" -or $svcImagePath -like "*netadapter*") {
                            $isWdf = $true
                        }
                    }
                }
                $driverType = if ($isWdf) { "WDF" } else { "NDIS" }
            }

            # Hardware Interrupt Support Check
            $hwMsiSupported = $false
            try {
                if ($dev -is [Microsoft.Management.Infrastructure.CimInstance]) {
                    $devProps = Invoke-CimMethod -InputObject $dev -MethodName GetDeviceProperties -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DeviceProperties
                    $intModes = ($devProps | Where-Object { $_.KeyName -eq 'DEVPKEY_PciDevice_InterruptSupport' }).Data
                    if ($null -ne $intModes -and $intModes -gt 1) { $hwMsiSupported = $true }
                } else {
                    $pnpProp = Get-PnpDeviceProperty -InstanceId $pnpID -KeyName 'DEVPKEY_PciDevice_InterruptSupport' -ErrorAction SilentlyContinue
                    if ($null -ne $pnpProp -and $pnpProp.Data -gt 1) { $hwMsiSupported = $true }
                }
            } catch {}

            # Parse OEM INF File & Check Explicit MSISupported Value
            $infName = "N/A"
            $infMsiValue = $null
            $drvPath = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpID" -Name "Driver" -ErrorAction SilentlyContinue).Driver
            if ($drvPath) {
                $infName = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$drvPath" -Name "InfPath" -ErrorAction SilentlyContinue).InfPath
                if (-not $infName) { $infName = "N/A" }
                else {
                    $infFullPath = Join-Path $env:windir "INF\$infName"
                    if (Test-Path $infFullPath) {
                        try {
                            # Check explicitly for MSISupported = 1
                            $infEnableMatch = Select-String -Path $infFullPath -Pattern '(?i)MessageSignaledInterruptProperties.*?MSISupported.*?0x00010001\s*,\s*1\b' -Quiet -ErrorAction SilentlyContinue
                            # Check explicitly for MSISupported = 0
                            $infDisableMatch = Select-String -Path $infFullPath -Pattern '(?i)MessageSignaledInterruptProperties.*?MSISupported.*?0x00010001\s*,\s*0\b' -Quiet -ErrorAction SilentlyContinue

                            if ($infEnableMatch) {
                                $infMsiValue = 1
                            } elseif ($infDisableMatch) {
                                $infMsiValue = 0
                            }
                        } catch {}
                    }
                }
            }

            # MSI Mode Path
            $msiPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            $msiMode = "Disabled (Line)"
            if (Test-Path $msiPath) {
                $msiVal = (Get-ItemProperty -Path $msiPath -Name "MSISupported" -ErrorAction SilentlyContinue).MSISupported
                if ($msiVal -eq 1) { 
                    if ($hwMsiSupported -or $infMsiValue -eq 1) {
                        $msiMode = "Enabled (MSI)" 
                    } else {
                        $msiMode = "Enabled (UNSAFE)"
                    }
                }
            }

            # Priority & Affinity Path
            $prioPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpID\Device Parameters\Interrupt Management\Affinity Policy"
            $prioMode = "Undefined"
            $coreAssigned = "Default"

            if (Test-Path $prioPath) {
                $prioVal = (Get-ItemProperty -Path $prioPath -Name "DevicePriority" -ErrorAction SilentlyContinue).DevicePriority
                switch ($prioVal) {
                    1 { $prioMode = "Low" }
                    2 { $prioMode = "Normal" }
                    3 { $prioMode = "High" }
                    0 { $prioMode = "Undefined" }
                }

                $devPolicy = (Get-ItemProperty -Path $prioPath -Name "DevicePolicy" -ErrorAction SilentlyContinue).DevicePolicy
                if ($devPolicy -eq 4) {
                    $assignSet = (Get-ItemProperty -Path $prioPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue).AssignmentSetOverride
                    $coreAssigned = Get-AssignedCoreFromBytes -bytes $assignSet
                }
            }

            # Build Device Tree (PCIe Root Ports / Switches)
            $treePorts = @()
            $currId = $pnpID
            $visited = New-Object System.Collections.Generic.HashSet[string]
            
            while ($currId -and $visited.Add($currId)) {
                $parentId = $null
                
                if ($devDict.ContainsKey($currId)) {
                    try { $parentId = $devDict[$currId].Parent } catch {}
                }
                
                if ([string]::IsNullOrWhiteSpace($parentId)) {
                    try {
                        $pProp = Get-PnpDeviceProperty -InstanceId $currId -KeyName 'DEVPKEY_Device_Parent' -ErrorAction SilentlyContinue
                        if ($pProp -and $pProp.Data) { $parentId = $pProp.Data }
                    } catch {}
                }
                
                if ([string]::IsNullOrWhiteSpace($parentId) -or -not $devDict.ContainsKey($parentId)) { break }
                
                $parentDev = $devDict[$parentId]
                $pName = $parentDev.Name
                
                if ($pName -match "(?i)(Root Port|Upstream Switch Port|Downstream Switch Port|AMD.*PCI.*Express)") {
                    $portPrioPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$parentId\Device Parameters\Interrupt Management\Affinity Policy"
                    $exists = $treePorts | Where-Object { $_.PNPID -eq $parentId }
                    if (-not $exists) {
                        $treePorts += [PSCustomObject]@{
                            PNPID = $parentId
                            Name = $pName
                            RegPrioPath = $portPrioPath
                        }
                    }
                }
                $currId = $parentId
            }

            $devices += [PSCustomObject]@{
                PNPID         = $pnpID
                Class         = $dev.PNPClass
                DriverType    = $driverType
                Name          = $dev.Name
                MSIMode       = $msiMode
                Priority      = $prioMode
                Core          = $coreAssigned
                RegMSIPath    = $msiPath
                RegPrioPath   = $prioPath
                HwMsiSupport  = $hwMsiSupported
                InfName       = $infName
                InfMsiValue   = $infMsiValue
                TreePorts     = $treePorts
            }
        }
    }
    return $devices
}

$cpu = Get-CpuProfile

do {
    Clear-Host
    $smtStr = if ($cpu.HasSMT) { "ENABLED" } else { "DISABLED" }
    $archStr = if ($cpu.IsHybrid) { "HYBRID ($($cpu.PCores.Count) P-Cores / $($cpu.ECores.Count) E-Cores)" } else { "STANDARD ($($cpu.PCores.Count) Physical Cores)" }

    Write-Host "=================================================================================================================" -ForegroundColor Cyan
    Write-Host "                                PCI DEVICE MSI MODE, PRIORITY AND CORE MANAGER                                   " -ForegroundColor Cyan
    Write-Host "                                                Created by Ryu                                                   " -ForegroundColor Cyan
    Write-Host "=================================================================================================================" -ForegroundColor Cyan
    Write-Host " CPU Architecture : $archStr" -ForegroundColor Gray
    Write-Host " SMT / HyperThread: $smtStr" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Scanning PCI devices, checking Hardware Capability, and parsing INF definitions..." -ForegroundColor Gray
    
    $devList = Get-PciDevices

    if ($devList.Count -eq 0) {
        Write-Host "No matching PCI devices found." -ForegroundColor Red
        pause
        break
    }

    Clear-Host
    Write-Host "=================================================================================================================" -ForegroundColor Cyan
    Write-Host "                                PCI DEVICE MSI MODE, PRIORITY AND CORE MANAGER                                   " -ForegroundColor Cyan
    Write-Host "                                                Created by Ryu                                                   " -ForegroundColor Cyan
    Write-Host "=================================================================================================================" -ForegroundColor Cyan
    Write-Host " CPU Arch: $archStr | SMT: $smtStr" -ForegroundColor Gray
    Write-Host ""
    Write-Host ("{0,-4} | {1,-12} | {2,-16} | {3,-10} | {4,-10} | {5,-12} | {6}" -f 'ID', 'CLASS', 'MSI MODE', 'PRIORITY', 'CPU CORE', 'INF FILE', 'DEVICE NAME')
    Write-Host ('-' * 115)

    for ($i = 0; $i -lt $devList.Count; $i++) {
        $d = $devList[$i]
        $msiColor = if ($d.MSIMode -eq 'Enabled (MSI)') { 'Green' } elseif ($d.MSIMode -like '*UNSAFE*') { 'Red' } else { 'DarkGray' }
        $coreColor = if ($d.Core -ne 'Default') { 'Yellow' } else { 'DarkGray' }
        $classStr = if ($d.Class -eq 'Net') { "$($d.Class) ($($d.DriverType))" } else { $d.Class }
        
        Write-Host ('[{0,2}] | {1,-12} | ' -f ($i + 1), $classStr) -NoNewline
        Write-Host ('{0,-16}' -f $d.MSIMode) -ForegroundColor $msiColor -NoNewline
        Write-Host (' | {0,-10} | ' -f $d.Priority) -NoNewline
        Write-Host ('{0,-10}' -f $d.Core) -ForegroundColor $coreColor -NoNewline
        Write-Host (' | {0,-12} | {1}' -f $d.InfName, $d.Name)
    }

    Write-Host ""
    Write-Host "-----------------------------------------------------------------------------------------------------------------"
    Write-Host " [A]   AUTO-OPTIMIZE ALL : Dedicated Display Core + Shared Non-Display P-Cores (Excludes Core 0)" -ForegroundColor Green
    Write-Host " [B]   MANUAL SETUP ALL  : Guided step-by-step setup for every device" -ForegroundColor Yellow
    Write-Host " [R]   RESET ALL DEVICES : Revert devices to INF default MSI state, clear priority/core affinity" -ForegroundColor Red
    Write-Host " [1-N] SELECT DEVICE ID  : Edit a single specific device directly" -ForegroundColor White
    Write-Host " [Q]   QUIT SCRIPT" -ForegroundColor Gray
    Write-Host "-----------------------------------------------------------------------------------------------------------------"
    $selection = Read-Host "Enter Choice (A, B, R, Device ID #, or Q)"
    
    if ($selection -eq 'Q' -or $selection -eq 'q') {
        Start-Process "https://linktr.ee/Ryu0833"
        break
    }
    
    # OPTION R: RESET ALL DEVICES
    if ($selection -eq 'R' -or $selection -eq 'r') {
        Clear-Host
        Write-Host "==================================================================================" -ForegroundColor Cyan
        Write-Host "                     RESETTING ALL DEVICES TO DEFAULTS                            " -ForegroundColor Cyan
        Write-Host "==================================================================================" -ForegroundColor Cyan

        foreach ($dev in $devList) {
            Write-Host "Resetting: $($dev.Name)" -ForegroundColor Yellow

            # Update MSI Settings based on INF or default to Disabled (Do NOT delete key)
            if (-not (Test-Path $dev.RegMSIPath)) { New-Item -Path $dev.RegMSIPath -Force | Out-Null }
            
            if ($null -ne $dev.InfMsiValue) {
                Set-ItemProperty -Path $dev.RegMSIPath -Name "MSISupported" -Value $dev.InfMsiValue -Type DWord -Force
                $statusMsg = if ($dev.InfMsiValue -eq 1) { "ENABLED" } else { "DISABLED" }
                Write-Host "   -> MSI Mode updated from INF: $statusMsg" -ForegroundColor Gray
            } else {
                Set-ItemProperty -Path $dev.RegMSIPath -Name "MSISupported" -Value 0 -Type DWord -Force
                Write-Host "   -> MSI Mode DISABLED (Fallback)" -ForegroundColor Gray
            }

            # Clear Priority & Affinity Settings
            if (Test-Path $dev.RegPrioPath) { 
                Remove-ItemProperty -Path $dev.RegPrioPath -Name "DevicePriority" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $dev.RegPrioPath -Name "DevicePolicy" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $dev.RegPrioPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue
                if ((Get-Item $dev.RegPrioPath).PropertyCount -eq 0) {
                    Remove-Item -Path $dev.RegPrioPath -Force -ErrorAction SilentlyContinue
                }
                Write-Host "   -> Core Affinity & Priority Restored to Default" -ForegroundColor Gray
            }

            # Clear PCIe Tree Escalations
            if ($dev.TreePorts -and $dev.TreePorts.Count -gt 0) {
                foreach ($port in $dev.TreePorts) {
                    if (Test-Path $port.RegPrioPath) {
                        Remove-ItemProperty -Path $port.RegPrioPath -Name "DevicePriority" -ErrorAction SilentlyContinue
                        if ((Get-Item $port.RegPrioPath).PropertyCount -eq 0) {
                            Remove-Item -Path $port.RegPrioPath -Force -ErrorAction SilentlyContinue
                        }
                        Write-Host "   -> Reset PCIe Tree: $($port.Name) -> Undefined" -ForegroundColor DarkGray
                    }
                }
            }
            Write-Host ""
        }

        Write-Host "==================================================================================" -ForegroundColor Cyan
        Write-Host "[SUCCESS] All devices and PCIe trees reset to hardware defaults!" -ForegroundColor Green
        Write-Host "RESTART REQUIRED: Reboot Windows or disable/enable devices in Device Manager." -ForegroundColor Yellow
        Write-Host "==================================================================================" -ForegroundColor Cyan
        pause
        continue
    }

    # OPTION A: AUTOMATIC OPTIMIZATION ROUTINE
    if ($selection -eq 'A' -or $selection -eq 'a') {
        Clear-Host
        Write-Host "==================================================================================" -ForegroundColor Cyan
        Write-Host "                         RUNNING AUTO-OPTIMIZATION                                " -ForegroundColor Cyan
        Write-Host "==================================================================================" -ForegroundColor Cyan
        
        $allEligiblePCores = @($cpu.PCores | Where-Object { $_.PhysicalCoreIndex -ne 0 } | Sort-Object PhysicalCoreIndex -Descending)

        if ($allEligiblePCores.Count -eq 0) {
            Write-Host "[!] Error: No eligible Physical P-Cores found (excluding Core 0)." -ForegroundColor Red
            pause
            continue
        }

        $displayDevs = @($devList | Where-Object { $_.Class -eq 'Display' })
        $otherDevs   = @($devList | Where-Object { $_.Class -ne 'Display' })

        $availablePCoreList = [System.Collections.Generic.List[PSObject]]::new()
        foreach ($c in $allEligiblePCores) { $availablePCoreList.Add($c) }

        $displayAssignedCores = @{}
        foreach ($dDev in $displayDevs) {
            if ($availablePCoreList.Count -gt 0) {
                $assignedCore = $availablePCoreList[0]
                $availablePCoreList.RemoveAt(0)
                $displayAssignedCores[$dDev.PNPID] = $assignedCore
            } else {
                $displayAssignedCores[$dDev.PNPID] = $allEligiblePCores[0]
            }
        }

        $nonDisplayCorePool = if ($availablePCoreList.Count -gt 0) { $availablePCoreList } else { $allEligiblePCores }

        Write-Host "Detected SMT State: $smtStr" -ForegroundColor Gray
        Write-Host "Architecture     : $archStr" -ForegroundColor Gray
        Write-Host "All P-Cores (excl. 0): Physical Cores ($($allEligiblePCores.PhysicalCoreIndex -join ', '))" -ForegroundColor Gray
        Write-Host "Display Core Reserved: Physical Core ($(($displayAssignedCores.Values.PhysicalCoreIndex | Select-Object -Unique) -join ', ')) [ISOLATED]" -ForegroundColor Green
        Write-Host "Other Core Pool      : Physical Cores ($($nonDisplayCorePool.PhysicalCoreIndex -join ', '))" -ForegroundColor Yellow
        Write-Host ""

        # Process Display Devices
        foreach ($dev in $displayDevs) {
            $msiStatusStr = "Skipped (No HW/INF Support)"
            if ($null -ne $dev.InfMsiValue) {
                if (-not (Test-Path $dev.RegMSIPath)) { New-Item -Path $dev.RegMSIPath -Force | Out-Null }
                Set-ItemProperty -Path $dev.RegMSIPath -Name "MSISupported" -Value $dev.InfMsiValue -Type DWord -Force
                $msiStatusStr = if ($dev.InfMsiValue -eq 1) { "MSI Enabled (per INF)" } else { "MSI Disabled (per INF)" }
            } elseif ($dev.HwMsiSupport) {
                if (-not (Test-Path $dev.RegMSIPath)) { New-Item -Path $dev.RegMSIPath -Force | Out-Null }
                Set-ItemProperty -Path $dev.RegMSIPath -Name "MSISupported" -Value 1 -Type DWord -Force
                $msiStatusStr = "MSI Enabled (HW Support)"
            }

            if (-not (Test-Path $dev.RegPrioPath)) { New-Item -Path $dev.RegPrioPath -Force | Out-Null }
            Set-ItemProperty -Path $dev.RegPrioPath -Name "DevicePriority" -Value 3 -Type DWord -Force

            $targetCoreObj = $displayAssignedCores[$dev.PNPID]
            $targetPhysIdx = $targetCoreObj.PhysicalCoreIndex
            $targetLogCore = $targetCoreObj.PrimaryLogicalCore

            Set-ItemProperty -Path $dev.RegPrioPath -Name "DevicePolicy" -Value 4 -Type DWord -Force
            $coreBytes = Get-AssignmentSetBytes -coreNum $targetLogCore
            Set-ItemProperty -Path $dev.RegPrioPath -Name "AssignmentSetOverride" -Value $coreBytes -Type Binary -Force

            Write-Host "[GPU-DISPLAY] $($dev.Name)" -ForegroundColor Green
            Write-Host "        -> Mode: $msiStatusStr | Priority: High | Exclusive P-Core $targetPhysIdx (Logical Core $targetLogCore)" -ForegroundColor Green
            Set-TreeHighPriority -Device $dev -Indent "        "
            Write-Host ""
        }

        # Process Other Devices
        $sortedOtherDevs = $otherDevs | Sort-Object {
            if ($_.Class -eq 'USB') { 1 }
            elseif ($_.Class -eq 'Net') { 3 }
            else { 2 }
        }

        $otherPointer = 0
        foreach ($dev in $sortedOtherDevs) {
            $msiStatusStr = "Skipped (No HW/INF Support)"
            if ($null -ne $dev.InfMsiValue) {
                if (-not (Test-Path $dev.RegMSIPath)) { New-Item -Path $dev.RegMSIPath -Force | Out-Null }
                Set-ItemProperty -Path $dev.RegMSIPath -Name "MSISupported" -Value $dev.InfMsiValue -Type DWord -Force
                $msiStatusStr = if ($dev.InfMsiValue -eq 1) { "MSI Enabled (per INF)" } else { "MSI Disabled (per INF)" }
            } elseif ($dev.HwMsiSupport) {
                if (-not (Test-Path $dev.RegMSIPath)) { New-Item -Path $dev.RegMSIPath -Force | Out-Null }
                Set-ItemProperty -Path $dev.RegMSIPath -Name "MSISupported" -Value 1 -Type DWord -Force
                $msiStatusStr = "MSI Enabled (HW Support)"
            }

            if (-not (Test-Path $dev.RegPrioPath)) { New-Item -Path $dev.RegPrioPath -Force | Out-Null }
            Set-ItemProperty -Path $dev.RegPrioPath -Name "DevicePriority" -Value 3 -Type DWord -Force

            if ($dev.Class -eq 'Net' -and $dev.DriverType -eq 'NDIS') {
                Remove-ItemProperty -Path $dev.RegPrioPath -Name "DevicePolicy" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $dev.RegPrioPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue
                Write-Host "[NET-NDIS] $($dev.Name)" -ForegroundColor Cyan
                Write-Host "        -> Mode: $msiStatusStr | Priority: High | Core: Default (NDIS Driver - RSS Preserved)" -ForegroundColor Gray
                Set-TreeHighPriority -Device $dev -Indent "        "
            } else {
                $targetCoreObj = $nonDisplayCorePool[$otherPointer]
                $targetPhysIdx = $targetCoreObj.PhysicalCoreIndex
                $targetLogCore = $targetCoreObj.PrimaryLogicalCore

                Set-ItemProperty -Path $dev.RegPrioPath -Name "DevicePolicy" -Value 4 -Type DWord -Force
                $coreBytes = Get-AssignmentSetBytes -coreNum $targetLogCore
                Set-ItemProperty -Path $dev.RegPrioPath -Name "AssignmentSetOverride" -Value $coreBytes -Type Binary -Force

                $tag = if ($dev.Class -eq 'Net') { "[NET-WDF]" } else { "[DEV]" }
                Write-Host "$tag  $($dev.Name)" -ForegroundColor Yellow
                Write-Host "        -> Mode: $msiStatusStr | Priority: High | Physical P-Core $targetPhysIdx (Logical Core $targetLogCore)" -ForegroundColor Yellow
                Set-TreeHighPriority -Device $dev -Indent "        "

                $otherPointer++
                if ($otherPointer -ge $nonDisplayCorePool.Count) { $otherPointer = 0 }
            }
            Write-Host ""
        }

        Write-Host "==================================================================================" -ForegroundColor Cyan
        Write-Host "[SUCCESS] All devices optimized successfully!" -ForegroundColor Green
        Write-Host "RESTART REQUIRED: Reboot Windows or disable/enable devices in Device Manager." -ForegroundColor Yellow
        Write-Host "==================================================================================" -ForegroundColor Cyan
        pause
        continue
    }

    # OPTION B: MANUAL STEP-BY-STEP GUIDED WIZARD
    if ($selection -eq 'B' -or $selection -eq 'b') {
        Clear-Host
        Write-Host "==================================================================================" -ForegroundColor Cyan
        Write-Host "                  STEP-BY-STEP MANUAL GUIDED SETUP                                " -ForegroundColor Cyan
        Write-Host "==================================================================================" -ForegroundColor Cyan
        Write-Host " You will configure each PCI device one by one." -ForegroundColor Gray
        Write-Host " Press [ENTER] on any choice to keep its current value, or type 'R' to Reset." -ForegroundColor Yellow
        Write-Host ""
        Start-Sleep -Seconds 2

        $currentDevNum = 1
        foreach ($dev in $devList) {
            Clear-Host
            Write-Host "==================================================================================" -ForegroundColor Cyan
            Write-Host " DEVICE ($currentDevNum/$($devList.Count)): $($dev.Name)" -ForegroundColor Yellow
            $classInfo = if ($dev.Class -eq 'Net') { "$($dev.Class) ($($dev.DriverType))" } else { $dev.Class }
            $infStatus = if ($null -ne $dev.InfMsiValue) { "Explicit ($($dev.InfMsiValue))" } else { "Unknown" }
            Write-Host " Class: $classInfo | INF: $($dev.InfName) ($infStatus) | Current MSI: $($dev.MSIMode) | Priority: $($dev.Priority) | Core: $($dev.Core)" -ForegroundColor Gray
            Write-Host "==================================================================================" -ForegroundColor Cyan

            # Reset Option Check
            Write-Host "`n[0/3] Reset Option:" -ForegroundColor White
            Write-Host "   R. Reset Device to System Default (INF-based MSI, Clear Priority, and Core Affinity)"
            Write-Host "   [ENTER] Proceed with configuration"
            $resetChoice = Read-Host "Choice [R or ENTER]"

            if ($resetChoice -eq 'R' -or $resetChoice -eq 'r') {
                if (-not (Test-Path $dev.RegMSIPath)) { New-Item -Path $dev.RegMSIPath -Force | Out-Null }
                if ($null -ne $dev.InfMsiValue) {
                    Set-ItemProperty -Path $dev.RegMSIPath -Name "MSISupported" -Value $dev.InfMsiValue -Type DWord -Force
                    $statusMsg = if ($dev.InfMsiValue -eq 1) { "ENABLED" } else { "DISABLED" }
                    Write-Host "   -> MSI Mode updated from INF: $statusMsg" -ForegroundColor Gray
                } else {
                    Set-ItemProperty -Path $dev.RegMSIPath -Name "MSISupported" -Value 0 -Type DWord -Force
                    Write-Host "   -> MSI Mode DISABLED (Fallback)" -ForegroundColor Gray
                }

                if (Test-Path $dev.RegPrioPath) { 
                    Remove-ItemProperty -Path $dev.RegPrioPath -Name "DevicePriority" -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $dev.RegPrioPath -Name "DevicePolicy" -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $dev.RegPrioPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue
                    if ((Get-Item $dev.RegPrioPath).PropertyCount -eq 0) {
                        Remove-Item -Path $dev.RegPrioPath -Force -ErrorAction SilentlyContinue
                    }
                    Write-Host "   -> Core Affinity & Priority Restored to Default" -ForegroundColor Gray
                }
                Write-Host "   -> Reset device completely to INF/System Defaults" -ForegroundColor Yellow
            } else {
                # 1. MSI Mode
                Write-Host "`n[1/3] MSI Mode Selection:" -ForegroundColor White
                if (-not $dev.HwMsiSupport -and $dev.InfMsiValue -ne 1) {
                    Write-Host "   [!] WARNING: Hardware/INF indicates it only supports legacy Line-Based Interrupts." -ForegroundColor Red
                }
                Write-Host "   1. Enable MSI Mode (MSISupported = 1)"
                Write-Host "   2. Disable MSI Mode (MSISupported = 0)"
                Write-Host "   [ENTER] Keep Current ($($dev.MSIMode))"
                $msiChoice = Read-Host "Choice [1, 2, or ENTER]"

                if ($msiChoice -eq '1') {
                    if (-not (Test-Path $dev.RegMSIPath)) { New-Item -Path $dev.RegMSIPath -Force | Out-Null }
                    Set-ItemProperty -Path $dev.RegMSIPath -Name "MSISupported" -Value 1 -Type DWord -Force
                    Write-Host "   -> Set MSI Mode to ENABLED" -ForegroundColor Green
                } elseif ($msiChoice -eq '2') {
                    if (-not (Test-Path $dev.RegMSIPath)) { New-Item -Path $dev.RegMSIPath -Force | Out-Null }
                    Set-ItemProperty -Path $dev.RegMSIPath -Name "MSISupported" -Value 0 -Type DWord -Force
                    Write-Host "   -> Set MSI Mode to DISABLED" -ForegroundColor Yellow
                } else {
                    Write-Host "   -> Kept current MSI mode" -ForegroundColor Gray
                }

                # 2. Priority Selection
                Write-Host "`n[2/3] Priority Selection:" -ForegroundColor White
                Write-Host "   1. High Priority (3)"
                Write-Host "   2. Normal Priority (2)"
                Write-Host "   3. Low Priority (1)"
                Write-Host "   4. Undefined / Default (0)"
                Write-Host "   [ENTER] Keep Current ($($dev.Priority))"
                $prioChoice = Read-Host "Choice [1-4 or ENTER]"

                if ($prioChoice -in @('1','2','3','4')) {
                    if (-not (Test-Path $dev.RegPrioPath)) { New-Item -Path $dev.RegPrioPath -Force | Out-Null }
                    $pVal = switch ($prioChoice) { '1'{3} '2'{2} '3'{1} '4'{0} }
                    Set-ItemProperty -Path $dev.RegPrioPath -Name "DevicePriority" -Value $pVal -Type DWord -Force
                    Write-Host "   -> Priority Updated" -ForegroundColor Green
                } else {
                    Write-Host "   -> Kept current Priority" -ForegroundColor Gray
                }

                # 3. Core Affinity
                Write-Host "`n[3/3] CPU Core Affinity Selection:" -ForegroundColor White
                if ($dev.Class -eq 'Net' -and $dev.DriverType -eq 'NDIS') {
                    Write-Host "   [!] NDIS Network Driver Detected: Core affinity locked to Default to preserve RSS." -ForegroundColor Yellow
                    if (Test-Path $dev.RegPrioPath) {
                        Remove-ItemProperty -Path $dev.RegPrioPath -Name "DevicePolicy" -ErrorAction SilentlyContinue
                        Remove-ItemProperty -Path $dev.RegPrioPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue
                    }
                    Write-Host "   -> Core Affinity locked to System Default" -ForegroundColor Gray
                } else {
                    if ($dev.Class -eq 'Net' -and $dev.DriverType -eq 'WDF') {
                        Write-Host "   [i] WDF Network Driver Detected: Custom Core Selection AVAILABLE." -ForegroundColor Green
                    }
                    Write-Host "   Available P-Cores Primary Logical IDs: ($(($cpu.PCores.PrimaryLogicalCore) -join ', '))" -ForegroundColor Gray
                    Write-Host "   - Enter Core Number (1 to 63) to lock to that Core"
                    Write-Host "   - Enter 0 to Reset to System Default (All Cores)"
                    Write-Host "   - Press [ENTER] to Keep Current ($($dev.Core))"
                    $coreChoice = Read-Host "Choice [Core #, 0, or ENTER]"

                    if ($coreChoice -eq '0') {
                        if (Test-Path $dev.RegPrioPath) {
                            Remove-ItemProperty -Path $dev.RegPrioPath -Name "DevicePolicy" -ErrorAction SilentlyContinue
                            Remove-ItemProperty -Path $dev.RegPrioPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue
                        }
                        Write-Host "   -> Reset Core Affinity to System Default" -ForegroundColor Yellow
                    } elseif ($coreChoice -match '^\d+$' -and [int]$coreChoice -ge 1 -and [int]$coreChoice -lt 64) {
                        $cNum = [int]$coreChoice
                        if (-not (Test-Path $dev.RegPrioPath)) { New-Item -Path $dev.RegPrioPath -Force | Out-Null }
                        Set-ItemProperty -Path $dev.RegPrioPath -Name "DevicePolicy" -Value 4 -Type DWord -Force
                        $cBytes = Get-AssignmentSetBytes -coreNum $cNum
                        Set-ItemProperty -Path $dev.RegPrioPath -Name "AssignmentSetOverride" -Value $cBytes -Type Binary -Force
                        Write-Host "   -> Locked device to Logical Core $cNum" -ForegroundColor Green
                    } else {
                        Write-Host "   -> Kept current Core Affinity" -ForegroundColor Gray
                    }
                }

                # Enforce Tree Priority
                Set-TreeHighPriority -Device $dev -Indent "   "
            }

            $currentDevNum++
            Start-Sleep -Seconds 1
        }

        Write-Host "`n==================================================================================" -ForegroundColor Cyan
        Write-Host "[SUCCESS] Manual wizard completed for all devices!" -ForegroundColor Green
        Write-Host "RESTART REQUIRED: Reboot Windows or disable/enable devices in Device Manager." -ForegroundColor Yellow
        Write-Host "==================================================================================" -ForegroundColor Cyan
        pause
        continue
    }

    # MANUAL DEVICE SELECTION
    if ($selection -match '^\d+$') {
        $idx = [int]$selection - 1
        if ($idx -ge 0 -and $idx -lt $devList.Count) {
            $targetDev = $devList[$idx]
            
            Clear-Host
            Write-Host "==================================================================================" -ForegroundColor Cyan
            Write-Host " CONFIGURE DEVICE: $($targetDev.Name)" -ForegroundColor Yellow
            $classInfo = if ($targetDev.Class -eq 'Net') { "$($targetDev.Class) ($($targetDev.DriverType))" } else { $targetDev.Class }
            $infStatus = if ($null -ne $targetDev.InfMsiValue) { "Explicit ($($targetDev.InfMsiValue))" } else { "Unknown" }
            Write-Host " Class: $classInfo | PNP ID: $($targetDev.PNPID) | INF: $($targetDev.InfName) ($infStatus)" -ForegroundColor Gray
            Write-Host " Current MSI: $($targetDev.MSIMode) | Priority: $($targetDev.Priority) | Core: $($targetDev.Core)" -ForegroundColor Gray
            Write-Host "==================================================================================" -ForegroundColor Cyan

            $changed = $false

            Write-Host "`n[0/4] Reset Option:" -ForegroundColor White
            Write-Host "   R. Reset Device to System Default (INF-based MSI, Clear Priority, and Core Affinity)"
            Write-Host "   [ENTER] Proceed to configure options sequentially"
            $resetChoice = Read-Host "Choice [R or ENTER]"

            if ($resetChoice -eq 'R' -or $resetChoice -eq 'r') {
                if (-not (Test-Path $targetDev.RegMSIPath)) { New-Item -Path $targetDev.RegMSIPath -Force | Out-Null }
                if ($null -ne $targetDev.InfMsiValue) {
                    Set-ItemProperty -Path $targetDev.RegMSIPath -Name "MSISupported" -Value $targetDev.InfMsiValue -Type DWord -Force
                    $statusMsg = if ($targetDev.InfMsiValue -eq 1) { "ENABLED" } else { "DISABLED" }
                    Write-Host "   -> MSI Mode updated from INF: $statusMsg" -ForegroundColor Gray
                } else {
                    Set-ItemProperty -Path $targetDev.RegMSIPath -Name "MSISupported" -Value 0 -Type DWord -Force
                    Write-Host "   -> MSI Mode DISABLED (Fallback)" -ForegroundColor Gray
                }

                if (Test-Path $targetDev.RegPrioPath) { 
                    Remove-ItemProperty -Path $targetDev.RegPrioPath -Name "DevicePriority" -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $targetDev.RegPrioPath -Name "DevicePolicy" -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $targetDev.RegPrioPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue
                    if ((Get-Item $targetDev.RegPrioPath).PropertyCount -eq 0) { 
                        Remove-Item -Path $targetDev.RegPrioPath -Force -ErrorAction SilentlyContinue 
                    }
                    Write-Host "   -> Core Affinity & Priority Restored to Default" -ForegroundColor Gray
                }
                Write-Host "   -> Reset device completely to INF/System Defaults" -ForegroundColor Yellow
                $changed = $true
            } else {
                # 1. MSI Mode Selection
                Write-Host "`n[1/3] MSI Mode Selection:" -ForegroundColor White
                if (-not $targetDev.HwMsiSupport -and $targetDev.InfMsiValue -ne 1) {
                    Write-Host "   [!] WARNING: Hardware/INF indicates it only supports legacy Line-Based Interrupts." -ForegroundColor Red
                }
                Write-Host "   1. Enable MSI Mode (MSISupported = 1)"
                Write-Host "   2. Disable MSI Mode (MSISupported = 0)"
                Write-Host "   [ENTER] Keep Current ($($targetDev.MSIMode))"
                $msiChoice = Read-Host "Choice [1, 2, or ENTER]"

                if ($msiChoice -eq '1') {
                    if (-not (Test-Path $targetDev.RegMSIPath)) { New-Item -Path $targetDev.RegMSIPath -Force | Out-Null }
                    Set-ItemProperty -Path $targetDev.RegMSIPath -Name "MSISupported" -Value 1 -Type DWord -Force
                    Write-Host "   -> Set MSI Mode to ENABLED" -ForegroundColor Green
                    $changed = $true
                } elseif ($msiChoice -eq '2') {
                    if (-not (Test-Path $targetDev.RegMSIPath)) { New-Item -Path $targetDev.RegMSIPath -Force | Out-Null }
                    Set-ItemProperty -Path $targetDev.RegMSIPath -Name "MSISupported" -Value 0 -Type DWord -Force
                    Write-Host "   -> Set MSI Mode to DISABLED" -ForegroundColor Yellow
                    $changed = $true
                } else {
                    Write-Host "   -> Kept current MSI mode" -ForegroundColor Gray
                }

                # 2. Priority Selection
                Write-Host "`n[2/3] Priority Selection:" -ForegroundColor White
                Write-Host "   1. High Priority (3)"
                Write-Host "   2. Normal Priority (2)"
                Write-Host "   3. Low Priority (1)"
                Write-Host "   4. Undefined / Default (0)"
                Write-Host "   [ENTER] Keep Current ($($targetDev.Priority))"
                $prioChoice = Read-Host "Choice [1-4 or ENTER]"

                if ($prioChoice -in @('1','2','3','4')) {
                    if (-not (Test-Path $targetDev.RegPrioPath)) { New-Item -Path $targetDev.RegPrioPath -Force | Out-Null }
                    $pVal = switch ($prioChoice) { '1'{3} '2'{2} '3'{1} '4'{0} }
                    Set-ItemProperty -Path $targetDev.RegPrioPath -Name "DevicePriority" -Value $pVal -Type DWord -Force
                    Write-Host "   -> Priority Updated" -ForegroundColor Green
                    $changed = $true
                } else {
                    Write-Host "   -> Kept current Priority" -ForegroundColor Gray
                }

                # 3. Core Affinity Selection
                Write-Host "`n[3/3] CPU Core Affinity Selection:" -ForegroundColor White
                if ($targetDev.Class -eq 'Net' -and $targetDev.DriverType -eq 'NDIS') {
                    Write-Host "   [!] NDIS Network Driver Detected: Core affinity locked to Default to preserve RSS." -ForegroundColor Yellow
                    if (Test-Path $targetDev.RegPrioPath) {
                        Remove-ItemProperty -Path $targetDev.RegPrioPath -Name "DevicePolicy" -ErrorAction SilentlyContinue
                        Remove-ItemProperty -Path $targetDev.RegPrioPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue
                    }
                    Write-Host "   -> Core Affinity locked to System Default" -ForegroundColor Gray
                } else {
                    if ($targetDev.Class -eq 'Net' -and $targetDev.DriverType -eq 'WDF') {
                        Write-Host "   [i] WDF Network Driver Detected: Custom Core Selection AVAILABLE." -ForegroundColor Green
                    }
                    Write-Host "   Available P-Cores Primary Logical IDs: ($(($cpu.PCores.PrimaryLogicalCore) -join ', '))" -ForegroundColor Gray
                    Write-Host "   - Enter Core Number (1 to 63) to lock to that Core"
                    Write-Host "   - Enter 0 to Reset to System Default (All Cores)"
                    Write-Host "   - Press [ENTER] to Keep Current ($($targetDev.Core))"
                    $coreChoice = Read-Host "Choice [Core #, 0, or ENTER]"

                    if ($coreChoice -eq '0') {
                        if (Test-Path $targetDev.RegPrioPath) {
                            Remove-ItemProperty -Path $targetDev.RegPrioPath -Name "DevicePolicy" -ErrorAction SilentlyContinue
                            Remove-ItemProperty -Path $targetDev.RegPrioPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue
                        }
                        Write-Host "   -> Reset Core Affinity to System Default" -ForegroundColor Yellow
                        $changed = $true
                    } elseif ($coreChoice -match '^\d+$' -and [int]$coreChoice -ge 1 -and [int]$coreChoice -lt 64) {
                        $cNum = [int]$coreChoice
                        if (-not (Test-Path $targetDev.RegPrioPath)) { New-Item -Path $targetDev.RegPrioPath -Force | Out-Null }
                        Set-ItemProperty -Path $targetDev.RegPrioPath -Name "DevicePolicy" -Value 4 -Type DWord -Force
                        $cBytes = Get-AssignmentSetBytes -coreNum $cNum
                        Set-ItemProperty -Path $targetDev.RegPrioPath -Name "AssignmentSetOverride" -Value $cBytes -Type Binary -Force
                        Write-Host "   -> Locked device to Logical Core $cNum" -ForegroundColor Green
                        $changed = $true
                    } else {
                        Write-Host "   -> Kept current Core Affinity" -ForegroundColor Gray
                    }
                }
            }

            if ($changed) {
                Set-TreeHighPriority -Device $targetDev -Indent "  "
                Write-Host "`n==================================================================================" -ForegroundColor Cyan
                Write-Host "[SUCCESS] Device configuration updated successfully!" -ForegroundColor Green
                Write-Host "RESTART REQUIRED: Reboot Windows or disable/enable the device in Device Manager." -ForegroundColor Yellow
                Write-Host "==================================================================================" -ForegroundColor Cyan
            } else {
                Write-Host "`nNo changes were made." -ForegroundColor Gray
            }
            pause
        }
    }
} while ($true)