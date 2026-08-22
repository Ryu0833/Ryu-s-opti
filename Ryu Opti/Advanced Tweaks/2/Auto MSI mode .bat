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

# Maximize the console window
try {
    Add-Type -Name Win32Console -Namespace Win32Functions -MemberDefinition '
        [DllImport("kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();

        [DllImport("user32.dll")]
        public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    ' -ErrorAction SilentlyContinue
    $consoleHandle = [Win32Functions.Win32Console]::GetConsoleWindow()
    if ($consoleHandle -ne [IntPtr]::Zero) {
        [Win32Functions.Win32Console]::ShowWindowAsync($consoleHandle, 3) | Out-Null  # 3 = SW_MAXIMIZE
    }
} catch {}

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

# Helper Function: Determine the color to highlight the "Enable MSI Mode" choice with,
# based on INF declared support, actual Hardware support, and whether the device
# currently has an IRQ conflict (sharing a legacy line-based interrupt).
#   - IRQ Conflict present AND Hardware supports MSI  -> Green  (strongly recommended fix)
#   - INF explicitly supports MSI (value = 1)          -> Green
#   - INF is N/A/Unknown AND Hardware supports MSI     -> Green
#   - INF explicitly does NOT support MSI (value = 0)
#       AND Hardware supports MSI                      -> DarkYellow (works, but off-spec)
#   - Hardware does NOT support MSI                     -> Red (not recommended)
function Get-MsiEnableColor ([PSCustomObject]$Device) {
    if ($Device.IrqConflict -and $Device.HwMsiSupport) { return 'Green' }

    if ($Device.InfMsiValue -eq 1) { return 'Green' }

    if ($null -eq $Device.InfMsiValue) {
        if ($Device.HwMsiSupport) { return 'Green' } else { return 'Red' }
    }

    if ($Device.InfMsiValue -eq 0) {
        if ($Device.HwMsiSupport) { return 'DarkYellow' } else { return 'Red' }
    }

    return 'White'
}

# Helper Function: Synchronize PCIe Tree Ports Priority to Match Device Priority
function Set-TreePriority ([PSCustomObject]$Device, [int]$PriorityValue, [string]$PriorityName, [string]$Indent = "   ") {
    if ($Device.TreePorts -and $Device.TreePorts.Count -gt 0) {
        foreach ($port in $Device.TreePorts) {
            if ($PriorityValue -eq 0) {
                if (Test-Path $port.RegPrioPath) {
                    Remove-ItemProperty -Path $port.RegPrioPath -Name "DevicePriority" -ErrorAction SilentlyContinue
                }
                Write-Host "$Indent-> PCIe Tree Priority: $($port.Name) -> Undefined (Default)" -ForegroundColor DarkGray
            } else {
                if (-not (Test-Path $port.RegPrioPath)) { New-Item -Path $port.RegPrioPath -Force | Out-Null }
                Set-ItemProperty -Path $port.RegPrioPath -Name "DevicePriority" -Value $PriorityValue -Type DWord -Force
                Write-Host "$Indent-> PCIe Tree Priority: $($port.Name) -> $PriorityName Priority" -ForegroundColor DarkCyan
            }
        }
    }
}

function Get-PciDevices {
    $devices = [System.Collections.Generic.List[object]]::new()

    # 1. Get All PnP Entities to verify conflict exclusions FIRST (CIM is faster than legacy WMI)
    $colAllDevices = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction SilentlyContinue
    if (-not $colAllDevices) { $colAllDevices = Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction SilentlyContinue -ComputerName $env:COMPUTERNAME }
    $devDictAll = @{}
    foreach ($d in $colAllDevices) { $devDictAll[$d.PNPDeviceID] = $d }

    # 1b. Bulk-resolve Parent IDs for every present device in ONE call instead of a
    #     separate Get-PnpDeviceProperty invocation per node during tree-walking.
    #     This is the single biggest cost in the original script (cmdlet startup
    #     overhead multiplied by hundreds of individual calls).
    $parentMap = @{}
    try {
        Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
            Get-PnpDeviceProperty -KeyName 'DEVPKEY_Device_Parent' -ErrorAction SilentlyContinue |
            ForEach-Object {
                if ($_.Data) { $parentMap[$_.InstanceId] = $_.Data }
            }
    } catch {}

    # 2. Map Global System IRQs for Conflict Detection
    # NOTE: this must stay on legacy Get-WmiObject. Win32_PnPAllocatedResource is an
    # association class, and Get-CimInstance formats its Antecedent/Dependent reference
    # strings differently (escaping/prefix), which breaks the regex parsing below and
    # silently produces an empty/wrong IRQ conflict map. Get-WmiObject is only called
    # once here (not per-device), so it isn't a meaningful perf cost anyway.
    $IrqMap = @{}
    $allocs = Get-WmiObject -Class Win32_PnPAllocatedResource -ErrorAction SilentlyContinue

    foreach ($r in $allocs) {
        if ($r.Antecedent -match 'Win32_IRQResource\.IRQNumber=(-?\d+)') {
            $rawIrq = [int64]$matches[1]
            if ($rawIrq -gt [int]::MaxValue) {
                $irqNum = [int]($rawIrq - 4294967296)
            } else {
                $irqNum = [int]$rawIrq
            }

            if ($irqNum -lt 0) { continue }

            if ($r.Dependent -match 'Win32_PnPEntity\.DeviceID="(.*?)"') {
                $rawId = $matches[1]
                $devId = $rawId.Replace('\\\\', '\').Replace('\\', '\')

                $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$devId\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
                $isMsi = $false
                if (Test-Path $regPath) {
                    $msiProp = Get-ItemProperty -Path $regPath -Name 'MSISupported' -ErrorAction SilentlyContinue
                    if ($null -ne $msiProp -and $msiProp.MSISupported -eq 1) {
                        $isMsi = $true
                    }
                }

                if (-not $isMsi) {
                    $name = "Unknown"
                    if ($devDictAll.ContainsKey($devId)) {
                        $name = $devDictAll[$devId].Name
                    }
                    if (-not $name) { $name = $devId }

                    if ($name -match "(?i)(PCI Express Root Port|High precision event timer|System timer)") {
                        continue
                    }

                    if (-not $IrqMap.ContainsKey($irqNum)) {
                        $IrqMap[$irqNum] = [System.Collections.Generic.List[string]]::new()
                    }

                    if (-not $IrqMap[$irqNum].Contains($devId)) {
                        $IrqMap[$irqNum].Add($devId)
                    }
                }
            }
        }
    }

    # 3. Filter down to PCI Devices for configuration
    $colDevices = @($colAllDevices | Where-Object { $_.PNPDeviceID -like 'PCI*' })

    # 3b. Bulk-resolve HW interrupt-support (MSI capability) for every candidate device
    #     in ONE call instead of one Invoke-CimMethod/Get-PnpDeviceProperty call per device.
    $interruptMap = @{}
    if ($colDevices.Count -gt 0) {
        try {
            $candidateIds = @($colDevices | ForEach-Object { $_.PNPDeviceID })
            Get-PnpDevice -InstanceId $candidateIds -ErrorAction SilentlyContinue |
                Get-PnpDeviceProperty -KeyName 'DEVPKEY_PciDevice_InterruptSupport' -ErrorAction SilentlyContinue |
                ForEach-Object {
                    if ($null -ne $_.Data) { $interruptMap[$_.InstanceId] = [int]$_.Data }
                }
        } catch {}
    }

    # 3c. Cache parsed INF MSI defaults so a driver shared by many devices (very common
    #     for USB hubs, storage controllers, etc.) is only parsed from disk once.
    $infCache = @{}

    foreach ($dev in $colDevices) {
        if ($dev.PNPClass -in @('Display', 'Net', 'USB', 'Media') -or ($dev.PNPClass -eq 'System' -and $dev.Name -match '(?i)audio')) {
            $pnpID = $dev.PNPDeviceID

            $enumRegProps = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpID" -ErrorAction SilentlyContinue
            $svcName = $enumRegProps.Service
            $drvPath = $enumRegProps.Driver

            $driverType = "N/A"
            if ($dev.PNPClass -eq 'Net') {
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

            $hwMsiSupported = $false
            $hwInterruptSupportValue = 0
            if ($interruptMap.ContainsKey($pnpID)) {
                $hwInterruptSupportValue = $interruptMap[$pnpID]
                if ($hwInterruptSupportValue -gt 1) { $hwMsiSupported = $true }
            }

            $infName = "N/A"
            $infMsiValue = $null
            if ($drvPath) {
                $infName = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$drvPath" -Name "InfPath" -ErrorAction SilentlyContinue).InfPath
                if (-not $infName) { $infName = "N/A" }
                else {
                    $infFullPath = Join-Path $env:windir "INF\$infName"
                    if ($infCache.ContainsKey($infFullPath)) {
                        $infMsiValue = $infCache[$infFullPath]
                    } elseif (Test-Path $infFullPath) {
                        try {
                            $infEnableMatch = Select-String -Path $infFullPath -Pattern '(?i)MessageSignaledInterruptProperties.*?MSISupported.*?0x00010001\s*,\s*1\b' -Quiet -ErrorAction SilentlyContinue
                            $infDisableMatch = Select-String -Path $infFullPath -Pattern '(?i)MessageSignaledInterruptProperties.*?MSISupported.*?0x00010001\s*,\s*0\b' -Quiet -ErrorAction SilentlyContinue

                            if ($infEnableMatch) {
                                $infMsiValue = 1
                            } elseif ($infDisableMatch) {
                                $infMsiValue = 0
                            }
                        } catch {}
                        $infCache[$infFullPath] = $infMsiValue
                    } else {
                        $infCache[$infFullPath] = $null
                    }
                }
            }

            $msiPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
            $regMsiVal = $null
            if (Test-Path $msiPath) {
                $regMsiVal = (Get-ItemProperty -Path $msiPath -Name "MSISupported" -ErrorAction SilentlyContinue).MSISupported
            }

            $isMsiActive = ($regMsiVal -eq 1)
            $hwSupportedStr = if ($hwInterruptSupportValue -ge 2 -or $hwMsiSupported) { "HW=supported" } else { "HW=N/A" }

            if ($isMsiActive) {
                if ($infMsiValue -eq 1) {
                    $msiMode = "Enable(Driver=E,$hwSupportedStr)"
                    $msiColor = "Green"
                } elseif ($null -eq $infMsiValue) {
                    $msiMode = "Enable(Driver=N/A,$hwSupportedStr)"
                    $msiColor = "Green"
                } else {
                    $msiMode = "Enable(Driver=D,$hwSupportedStr)"
                    $msiColor = "Green"
                }
            } else {
                if ($infMsiValue -eq 0) {
                    $msiMode = "Disable(Driver=D,$hwSupportedStr)"
                    $msiColor = "DarkYellow"
                } elseif ($null -eq $infMsiValue) {
                    $msiMode = "Disable(Driver=N/A,$hwSupportedStr)"
                    $msiColor = "DarkYellow"
                } else {
                    $msiMode = "Disable(Driver=D,$hwSupportedStr)"
                    $msiColor = "RED"
                }
            }

            $hasConflict = $false
            if (-not $isMsiActive) {
                foreach ($irqKey in $IrqMap.Keys) {
                    if ($IrqMap[$irqKey].Contains($pnpID)) {
                        if ($IrqMap[$irqKey].Count -gt 1) {
                            $hasConflict = $true
                            break
                        }
                    }
                }
            }

            $prioPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$pnpID\Device Parameters\Interrupt Management\Affinity Policy"
            $prioMode = "Undefined"
            $coreAssigned = "Default"

            if (Test-Path $prioPath) {
                $prioProps = Get-ItemProperty -Path $prioPath -ErrorAction SilentlyContinue
                $prioVal = $prioProps.DevicePriority
                switch ($prioVal) {
                    1 { $prioMode = "Low" }
                    2 { $prioMode = "Normal" }
                    3 { $prioMode = "High" }
                    0 { $prioMode = "Undefined" }
                }

                if ($prioProps.DevicePolicy -eq 4) {
                    $coreAssigned = Get-AssignedCoreFromBytes -bytes $prioProps.AssignmentSetOverride
                }
            }

            $normalizedClass = if ($dev.PNPClass -eq 'Media' -or $dev.Name -match '(?i)audio') { 'Audio' } else { $dev.PNPClass }

            $treePorts = [System.Collections.Generic.List[object]]::new()
            $treePortIds = [System.Collections.Generic.HashSet[string]]::new()
            $currId = $pnpID
            $visited = New-Object System.Collections.Generic.HashSet[string]

            while ($currId -and $visited.Add($currId)) {
                $parentId = $null

                if ($parentMap.ContainsKey($currId)) {
                    $parentId = $parentMap[$currId]
                } elseif ($devDictAll.ContainsKey($currId)) {
                    try { $parentId = $devDictAll[$currId].Parent } catch {}
                }

                if ([string]::IsNullOrWhiteSpace($parentId) -or -not $devDictAll.ContainsKey($parentId)) { break }

                $parentDev = $devDictAll[$parentId]
                $pName = $parentDev.Name

                $includeInTree = $false
                if ($normalizedClass -eq 'USB') {
                    if ($pName -match "(?i)(Upstream Switch Port|Downstream Switch Port|AMD.*PCI.*Express|Root)") {
                        $includeInTree = $true
                    }
                } elseif ($normalizedClass -eq 'Display') {
                    if ($pName -match "(?i)(Upstream Switch Port|Downstream Switch Port|AMD.*PCI.*Express|Root)") {
                        $includeInTree = $true
                    }
                } elseif ($normalizedClass -in @('Audio', 'Net')) {
                    if ($pName -match "(?i)(Upstream Switch Port|Downstream Switch Port|Root Complex)" -and $pName -notmatch "(?i)PCI.*Express.*Root|Root Port") {
                        $includeInTree = $true
                    }
                } else {
                    if ($pName -match "(?i)(Upstream Switch Port|Downstream Switch Port|AMD.*PCI.*Express)" -and $pName -notmatch "(?i)Root") {
                        $includeInTree = $true
                    }
                }

                if ($includeInTree -and $treePortIds.Add($parentId)) {
                    $portPrioPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$parentId\Device Parameters\Interrupt Management\Affinity Policy"
                    $treePorts.Add([PSCustomObject]@{
                        PNPID = $parentId
                        Name = $pName
                        RegPrioPath = $portPrioPath
                    })
                }
                $currId = $parentId
            }

            $devices.Add([PSCustomObject]@{
                PNPID         = $pnpID
                Class         = $normalizedClass
                Service       = $svcName
                DriverType    = $driverType
                Name          = $dev.Name
                MSIMode       = $msiMode
                MSIColor      = $msiColor
                IsMsiActive   = $isMsiActive
                Priority      = $prioMode
                Core          = $coreAssigned
                RegMSIPath    = $msiPath
                RegPrioPath   = $prioPath
                HwMsiSupport  = $hwMsiSupported
                InfName       = $infName
                InfMsiValue   = $infMsiValue
                IrqConflict   = $hasConflict
                TreePorts     = $treePorts
            })
        }
    }
    return $devices
}

$cpu = Get-CpuProfile

Clear-Host
$smtStr = if ($cpu.HasSMT) { "ENABLED" } else { "DISABLED" }
$archStr = if ($cpu.IsHybrid) { "HYBRID ($($cpu.PCores.Count) P-Cores / $($cpu.ECores.Count) E-Cores)" } else { "STANDARD ($($cpu.PCores.Count) Physical Cores)" }

Write-Host "==========================================================================================================================================================" -ForegroundColor Cyan
Write-Host "                                PCI DEVICE MSI MODE, PRIORITY AND CORE MANAGER                                                                            " -ForegroundColor Cyan
Write-Host "                                                Created by Ryu                                                                                            " -ForegroundColor Cyan
Write-Host "==========================================================================================================================================================" -ForegroundColor Cyan
Write-Host " CPU Architecture : $archStr" -ForegroundColor Gray
Write-Host " SMT / HyperThread: $smtStr" -ForegroundColor Gray
Write-Host ""
pause

do {
    Clear-Host
Write-Host " Loading..." -ForegroundColor Gray
    $devList = Get-PciDevices

    if ($devList.Count -eq 0) {
        Write-Host "No matching PCI devices found." -ForegroundColor Red
        pause
        break
    }

    Clear-Host
    Write-Host "==========================================================================================================================================================" -ForegroundColor Cyan
    Write-Host "                                PCI DEVICE MSI MODE, PRIORITY AND CORE MANAGER                                                                            " -ForegroundColor Cyan
    Write-Host "                                                Created by Ryu                                                                                            " -ForegroundColor Cyan
    Write-Host "==========================================================================================================================================================" -ForegroundColor Cyan
    Write-Host " CPU Arch: $archStr | SMT: $smtStr" -ForegroundColor Gray
    Write-Host ""
    
    $anyConflicts = ($devList | Where-Object { $_.IrqConflict }).Count -gt 0
    if ($anyConflicts) {
        Write-Host " [!] WARNING: Devices marked as Conflict are sharing Line-Based IRQs with other hardware. This increases latency." -ForegroundColor Red
        Write-Host ""
    }
    
    Write-Host ("{0,-4} | {1,-12} | {2,-39} | {3,-10} | {4,-10} | {5,-8} | {6,-12} | {7}" -f 'ID', 'CLASS', 'MSI MODE', 'PRIORITY', 'CPU CORE', 'IRQ', 'INF FILE', 'DEVICE NAME')
    Write-Host ('-' * 148)

    for ($i = 0; $i -lt $devList.Count; $i++) {
        $d = $devList[$i]
        
        if ($d.IrqConflict) {
            $conflictStr = 'Conflict'
            $conflictColor = 'Red'
        } elseif ($d.IsMsiActive) {
            $conflictStr = '-'
            $conflictColor = 'DarkGray'
        } else {
            $conflictStr = 'OK'
            $conflictColor = 'Green'
        }
        
        $msiColor = if ($d.MSIColor) { $d.MSIColor } else { 'DarkGray' }
        $coreColor = if ($d.Core -ne 'Default') { 'Yellow' } else { 'DarkGray' }
        $classStr = if ($d.Class -eq 'Net') { "$($d.Class) ($($d.DriverType))" } else { $d.Class }
        
        Write-Host ('[{0,2}] | {1,-12} | ' -f ($i + 1), $classStr) -NoNewline
        Write-Host ('{0,-39}' -f $d.MSIMode) -ForegroundColor $msiColor -NoNewline
        Write-Host (' | {0,-10} | ' -f $d.Priority) -NoNewline
        Write-Host ('{0,-10}' -f $d.Core) -ForegroundColor $coreColor -NoNewline
        Write-Host (' | ') -NoNewline
        Write-Host ('{0,-8}' -f $conflictStr) -ForegroundColor $conflictColor -NoNewline
        Write-Host (' | {0,-12} | {1}' -f $d.InfName, $d.Name)
    }

    Write-Host ""
    Write-Host "----------------------------------------------------------------------------------------------------------------------------------------------------------"
    Write-Host " [A]   AUTO-OPTIMIZE ALL : Dedicated Display Core + Shared Non-Display P-Cores (Always Excludes Core 0)" -ForegroundColor Green
    Write-Host " [B]   MANUAL SETUP ALL  : Guided step-by-step setup for every device" -ForegroundColor Yellow
    Write-Host " [R]   RESET ALL DEVICES : Revert devices to INF default MSI state, clear priority/core affinity" -ForegroundColor Red
    Write-Host " [1-N] SELECT DEVICE ID  : Edit a single specific device directly" -ForegroundColor White
    Write-Host " [Q]   QUIT SCRIPT" -ForegroundColor Gray
    Write-Host "----------------------------------------------------------------------------------------------------------------------------------------------------------"
    $selection = Read-Host "Choice (A, B, R, Device ID #, or Q)"
    
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
        $coreZeroMsg = "Core 0 EXCLUDED"

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
        Write-Host "Eligible P-Cores : Physical Cores ($($allEligiblePCores.PhysicalCoreIndex -join ', ')) [$coreZeroMsg]" -ForegroundColor Gray
        Write-Host "Display Core Reserved: Physical Core ($(($displayAssignedCores.Values.PhysicalCoreIndex | Select-Object -Unique) -join ', ')) [ISOLATED]" -ForegroundColor Green
        Write-Host "Other Core Pool      : Physical Cores ($($nonDisplayCorePool.PhysicalCoreIndex -join ', '))" -ForegroundColor Yellow
        Write-Host ""

        foreach ($dev in $displayDevs) {
            $msiStatusStr = "Skipped (No HW/INF Support)"
            if ($dev.IrqConflict -and $dev.HwMsiSupport) {
                if (-not (Test-Path $dev.RegMSIPath)) { New-Item -Path $dev.RegMSIPath -Force | Out-Null }
                Set-ItemProperty -Path $dev.RegMSIPath -Name "MSISupported" -Value 1 -Type DWord -Force
                $msiStatusStr = "MSI Enabled (Conflict Override - HW Support)"
            } elseif ($null -ne $dev.InfMsiValue) {
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
            Set-TreePriority -Device $dev -PriorityValue 3 -PriorityName "High" -Indent "        "
            Write-Host ""
        }

        $hdaudbusActive = ($otherDevs | Where-Object { $_.Class -eq 'Audio' -and $_.Service -match '(?i)hdaudbus' }).Count -gt 0
        $sharedAudioCore = $null
        
        if ($hdaudbusActive -and $nonDisplayCorePool.Count -gt 0) {
            Write-Host "[!] HDAUDBUS Detected: All Audio devices will dynamically group to the same Physical P-Core." -ForegroundColor Magenta
            Write-Host ""
        }

        $sortedOtherDevs = $otherDevs | Sort-Object {
            if ($_.Class -eq 'USB') { 1 }
            elseif ($_.Class -eq 'Audio') { 2 }
            elseif ($_.Class -eq 'Net') { 3 }
            else { 4 }
        }

        $otherPointer = 0
        foreach ($dev in $sortedOtherDevs) {
            $msiStatusStr = "Skipped (No HW/INF Support)"
            if ($dev.IrqConflict -and $dev.HwMsiSupport) {
                if (-not (Test-Path $dev.RegMSIPath)) { New-Item -Path $dev.RegMSIPath -Force | Out-Null }
                Set-ItemProperty -Path $dev.RegMSIPath -Name "MSISupported" -Value 1 -Type DWord -Force
                $msiStatusStr = "MSI Enabled (Conflict Override - HW Support)"
            } elseif ($null -ne $dev.InfMsiValue) {
                if (-not (Test-Path $dev.RegMSIPath)) { New-Item -Path $dev.RegMSIPath -Force | Out-Null }
                Set-ItemProperty -Path $dev.RegMSIPath -Name "MSISupported" -Value $dev.InfMsiValue -Type DWord -Force
                $msiStatusStr = if ($dev.InfMsiValue -eq 1) { "MSI Enabled (per INF)" } else { "MSI Disabled (per INF)" }
            } elseif ($dev.HwMsiSupport) {
                if (-not (Test-Path $dev.RegMSIPath)) { New-Item -Path $dev.RegMSIPath -Force | Out-Null }
                Set-ItemProperty -Path $dev.RegMSIPath -Name "MSISupported" -Value 1 -Type DWord -Force
                $msiStatusStr = "MSI Enabled (HW Support)"
            }

            $targetPriorityVal = 3
            $targetPriorityName = "High"
            if ($dev.Class -eq 'Audio') {
                $targetPriorityVal = 2
                $targetPriorityName = "Normal"
            }

            if (-not (Test-Path $dev.RegPrioPath)) { New-Item -Path $dev.RegPrioPath -Force | Out-Null }
            Set-ItemProperty -Path $dev.RegPrioPath -Name "DevicePriority" -Value $targetPriorityVal -Type DWord -Force

            if ($dev.Class -eq 'Net' -and $dev.DriverType -eq 'NDIS') {
                Remove-ItemProperty -Path $dev.RegPrioPath -Name "DevicePolicy" -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $dev.RegPrioPath -Name "AssignmentSetOverride" -ErrorAction SilentlyContinue
                Write-Host "[NET-NDIS] $($dev.Name)" -ForegroundColor Cyan
                Write-Host "        -> Mode: $msiStatusStr | Priority: $targetPriorityName | Core: Default (NDIS Driver - RSS Preserved)" -ForegroundColor Gray
                Set-TreePriority -Device $dev -PriorityValue $targetPriorityVal -PriorityName $targetPriorityName -Indent "        "
            } else {
                if ($dev.Class -eq 'Audio' -and $hdaudbusActive) {
                    if ($null -eq $sharedAudioCore) {
                        $sharedAudioCore = $nonDisplayCorePool[$otherPointer]
                        $otherPointer++
                        if ($otherPointer -ge $nonDisplayCorePool.Count) { $otherPointer = 0 }
                    }
                    $targetCoreObj = $sharedAudioCore
                } else {
                    $targetCoreObj = $nonDisplayCorePool[$otherPointer]
                    $otherPointer++
                    if ($otherPointer -ge $nonDisplayCorePool.Count) { $otherPointer = 0 }
                }

                $targetPhysIdx = $targetCoreObj.PhysicalCoreIndex
                $targetLogCore = $targetCoreObj.PrimaryLogicalCore

                Set-ItemProperty -Path $dev.RegPrioPath -Name "DevicePolicy" -Value 4 -Type DWord -Force
                $coreBytes = Get-AssignmentSetBytes -coreNum $targetLogCore
                Set-ItemProperty -Path $dev.RegPrioPath -Name "AssignmentSetOverride" -Value $coreBytes -Type Binary -Force

                $tag = if ($dev.Class -eq 'Net') { "[NET-WDF]" } elseif ($dev.Class -eq 'Audio') { "[AUDIO]" } elseif ($dev.Class -eq 'USB') { "[USB]" } else { "[DEV]" }
                Write-Host "$tag  $($dev.Name)" -ForegroundColor Yellow
                Write-Host "        -> Mode: $msiStatusStr | Priority: $targetPriorityName | Physical P-Core $targetPhysIdx (Logical Core $targetLogCore)" -ForegroundColor Yellow
                
                Set-TreePriority -Device $dev -PriorityValue $targetPriorityVal -PriorityName $targetPriorityName -Indent "        "
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
                Write-Host "`n[1/3] MSI Mode Selection:" -ForegroundColor White
                if (-not $dev.HwMsiSupport -and $dev.InfMsiValue -ne 1) {
                    Write-Host "   [!] WARNING: Hardware/INF indicates it only supports legacy Line-Based Interrupts." -ForegroundColor Red
                }
                if ($dev.IrqConflict -and $dev.HwMsiSupport) {
                    Write-Host "   [!] RECOMMENDED: This device has an IRQ Conflict. Enabling MSI Mode will resolve it." -ForegroundColor Green
                }
                $msiEnableColor = Get-MsiEnableColor -Device $dev
                Write-Host "   1. Enable MSI Mode (MSISupported = 1)" -ForegroundColor $msiEnableColor
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

                $targetPrioName = $dev.Priority
                $targetPrioVal = switch ($dev.Priority) { 'High'{3} 'Normal'{2} 'Low'{1} 'Undefined'{0} default{0} }

                Write-Host "`n[2/3] Priority Selection:" -ForegroundColor White
                Write-Host "   1. High Priority (3)"
                Write-Host "   2. Normal Priority (2)"
                Write-Host "   3. Low Priority (1)"
                Write-Host "   4. Undefined / Default (0)"
                Write-Host "   [ENTER] Keep Current ($($dev.Priority))"
                $prioChoice = Read-Host "Choice [1-4 or ENTER]"

                if ($prioChoice -in @('1','2','3','4')) {
                    if (-not (Test-Path $dev.RegPrioPath)) { New-Item -Path $dev.RegPrioPath -Force | Out-Null }
                    $targetPrioVal = switch ($prioChoice) { '1'{3} '2'{2} '3'{1} '4'{0} }
                    $targetPrioName = switch ($prioChoice) { '1'{"High"} '2'{"Normal"} '3'{"Low"} '4'{"Undefined"} }
                    Set-ItemProperty -Path $dev.RegPrioPath -Name "DevicePriority" -Value $targetPrioVal -Type DWord -Force
                    Write-Host "   -> Priority Updated to $targetPrioName" -ForegroundColor Green
                } else {
                    Write-Host "   -> Kept current Priority ($targetPrioName)" -ForegroundColor Gray
                }

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

                Set-TreePriority -Device $dev -PriorityValue $targetPrioVal -PriorityName $targetPrioName -Indent "   "
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
                Write-Host "`n[1/3] MSI Mode Selection:" -ForegroundColor White
                if (-not $targetDev.HwMsiSupport -and $targetDev.InfMsiValue -ne 1) {
                    Write-Host "   [!] WARNING: Hardware/INF indicates it only supports legacy Line-Based Interrupts." -ForegroundColor Red
                }
                if ($targetDev.IrqConflict -and $targetDev.HwMsiSupport) {
                    Write-Host "   [!] RECOMMENDED: This device has an IRQ Conflict. Enabling MSI Mode will resolve it." -ForegroundColor Green
                }
                $msiEnableColor = Get-MsiEnableColor -Device $targetDev
                Write-Host "   1. Enable MSI Mode (MSISupported = 1)" -ForegroundColor $msiEnableColor
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

                $targetPrioName = $targetDev.Priority
                $targetPrioVal = switch ($targetDev.Priority) { 'High'{3} 'Normal'{2} 'Low'{1} 'Undefined'{0} default{0} }

                Write-Host "`n[2/3] Priority Selection:" -ForegroundColor White
                Write-Host "   1. High Priority (3)"
                Write-Host "   2. Normal Priority (2)"
                Write-Host "   3. Low Priority (1)"
                Write-Host "   4. Undefined / Default (0)"
                Write-Host "   [ENTER] Keep Current ($($targetDev.Priority))"
                $prioChoice = Read-Host "Choice [1-4 or ENTER]"

                if ($prioChoice -in @('1','2','3','4')) {
                    if (-not (Test-Path $targetDev.RegPrioPath)) { New-Item -Path $targetDev.RegPrioPath -Force | Out-Null }
                    $targetPrioVal = switch ($prioChoice) { '1'{3} '2'{2} '3'{1} '4'{0} }
                    $targetPrioName = switch ($prioChoice) { '1'{"High"} '2'{"Normal"} '3'{"Low"} '4'{"Undefined"} }
                    Set-ItemProperty -Path $targetDev.RegPrioPath -Name "DevicePriority" -Value $targetPrioVal -Type DWord -Force
                    Write-Host "   -> Priority Updated to $targetPrioName" -ForegroundColor Green
                    $changed = $true
                } else {
                    Write-Host "   -> Kept current Priority ($targetPrioName)" -ForegroundColor Gray
                }

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
                Set-TreePriority -Device $targetDev -PriorityValue $targetPrioVal -PriorityName $targetPrioName -Indent "  "
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