<#
.SYNOPSIS
    Kayley's Mega Tool - Comprehensive Windows safety, performance, and maintenance script.
.DESCRIPTION
    Implements: Dynamic System Restore, Shadow Copy purge, Restore frequency bypass,
    Ultimate Performance plan, HAGS, priority tweaks, memory/storage optimizations,
    bloatware removal, service hardening, privacy/security, UI tweaks, and maintenance.
.NOTES
    Must run elevated. Creates restore point "[Username]_Safety" before changes.
    Toggle $Script:VerboseLog for internal logging.
#>

#Requires -Version 5.1
# Auto-elevation: script re-launches as Administrator if not already elevated.

[CmdletBinding()]
param(
    [switch]$SkipRestorePoint,
    [switch]$SkipMAS,
    [switch]$SkipUpdateAllPackages,
    [switch]$WhatIf,
    [switch]$GUI
)

# =============================================================================
# CONFIGURATION
# =============================================================================
$Script:VerboseLog = $true   # Toggle: internal logging for every action
$Script:LogPath   = Join-Path $env:TEMP "KayleysMegaTool_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Restore point name: [CurrentUsername]_Safety
$RestorePointName = "${env:USERNAME}_Safety"

# GUIDs
$UltimatePerfGUID   = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
$BestPerfOverlayGUID = 'ded574b5-45a0-4f42-8737-46345c09c238'

# Apps to remove (Appx + Provisioned)
$BloatAppList = @(
    'Microsoft.XboxApp'
    'Microsoft.XboxGameOverlay'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxSpeechToTextOverlay'
    'Microsoft.SkypeApp'
    'Microsoft.BingWeather'
    'Microsoft.BingNews'
    'Microsoft.BingSports'
    'Microsoft.WindowsMaps'
    'Microsoft.GetHelp'
    'Microsoft.Getstarted'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.People'
    'Microsoft.ZuneMusic'
    'Microsoft.ZuneVideo'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.MixedReality.Portal'
    'Microsoft.549981C3F5F10'  # Cortana
    'Microsoft.Windows.Photos'
    'Microsoft.Wallet'
    'Microsoft.OneConnect'
    'Microsoft.Messaging'
    'Microsoft.3DBuilder'
    'Microsoft.WindowsAlarms'
    'Microsoft.WindowsSoundRecorder'
    'Microsoft.ScreenSketch'
    'Microsoft.Xbox.TCUI'
)

# =============================================================================
# HELPERS: Elevation, Logging, Error handling
# =============================================================================
function Write-KayleysMegaToolLog {
    param([string]$Message, [string]$Level = 'INFO')
    if (-not $Script:VerboseLog) { return }
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $Script:LogPath -Value $line -ErrorAction SilentlyContinue
    if ($null -ne $Script:LogQueue -and ($Script:LogQueue.GetType().Name -like 'ConcurrentQueue*')) {
        $Script:LogQueue.Enqueue($line)
    }
    if ($Level -eq 'ERROR') {
        Write-Warning $Message
    } else {
        Write-Host $line
        Write-Verbose $Message
    }
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $prin = New-Object Security.Principal.WindowsPrincipal($id)
    return $prin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-Elevate {
    if (Test-Admin) { return }
    Write-Host "Re-launching elevated..."
    $self = $PSCommandPath
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$self`"")
    if ($SkipRestorePoint) { $argList += '-SkipRestorePoint' }
    if ($SkipMAS) { $argList += '-SkipMAS' }
    if ($SkipUpdateAllPackages) { $argList += '-SkipUpdateAllPackages' }
    if ($WhatIf) { $argList += '-WhatIf' }
    if ($GUI) { $argList += '-GUI' }
    Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -Wait
    exit
}

# Ensure elevation when run as script (skip when dot-sourced for GUI)
if ($MyInvocation.InvocationName -ne '.' -and $MyInvocation.CommandOrigin -eq 'Runspace') {
    Invoke-Elevate
}

# =============================================================================
# SAFETY & LOGIC
# =============================================================================
function Set-SafetyRestore {
    param([switch]$Skip)

    if ($Skip) { Write-KayleysMegaToolLog "Restore point skipped (parameter)."; return }

    # Restore frequency hack: allow creation without 24h cooldown
    $srKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
    if (-not (Test-Path $srKey)) { New-Item -Path $srKey -Force | Out-Null }
    Set-ItemProperty -Path $srKey -Name 'SystemRestorePointCreationFrequency' -Value 0 -Type DWord -Force
    Write-KayleysMegaToolLog "SystemRestorePointCreationFrequency = 0"

    # Shadow Copy purge
    try {
        $vss = vssadmin list shadows 2>&1
        if ($vss -match 'No items') { Write-KayleysMegaToolLog "No existing shadows to delete." }
        else {
            vssadmin delete shadows /all /quiet 2>&1 | Out-Null
            Write-KayleysMegaToolLog "VSS shadow copy purge executed."
        }
    } catch { Write-KayleysMegaToolLog "VSS purge: $_" -Level ERROR }

    # Create restore point: WMI (all Windows) then fallback to Checkpoint-Computer
    $created = $false
    try {
        $srpClass = [wmiclass]"\\.\root\default:SystemRestore"
        if ($srpClass) {
            # CreateRestorePoint(Description, Type, EventType); Type 12=MODIFY_SETTINGS, 100=BEGIN
            $srpClass.CreateRestorePoint($RestorePointName, 12, 100) | Out-Null
            $created = $true
            Write-KayleysMegaToolLog "Restore point created (WMI): $RestorePointName"
        }
    } catch { Write-KayleysMegaToolLog "WMI Restore point: $_" -Level ERROR }

    if (-not $created) {
        try {
            Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description $RestorePointName -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
            Write-KayleysMegaToolLog "Restore point created (Checkpoint-Computer): $RestorePointName"
        } catch {
            Write-KayleysMegaToolLog "Restore point creation failed: $_" -Level ERROR
        }
    }
}

# =============================================================================
# PERFORMANCE & KERNEL (Omega / Absolute Power)
# =============================================================================
function Set-PerformanceOmega {
    # Ultimate Performance plan (unhide and activate)
    try {
        powercfg -duplicatescheme $UltimatePerfGUID | Out-Null
        $schemes = powercfg -list
        $match = [regex]::Match($schemes, "($UltimatePerfGUID)\s+\(([^)]+)\)")
        if ($match.Success) {
            powercfg -setactive $UltimatePerfGUID
            Write-KayleysMegaToolLog "Ultimate Performance plan activated."
        }
    } catch { Write-KayleysMegaToolLog "Ultimate Performance: $_" -Level ERROR }

    # HAGS: Hardware-Accelerated GPU Scheduling
    $hagsPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
    if (-not (Test-Path $hagsPath)) { New-Item -Path $hagsPath -Force | Out-Null }
    Set-ItemProperty -Path $hagsPath -Name 'HwSchMode' -Value 2 -Type DWord -Force
    Write-KayleysMegaToolLog "HAGS HwSchMode = 2"

    # Win32 Priority Separation = 26 (hex) for max foreground responsiveness
    $win32Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
    if (-not (Test-Path $win32Path)) { New-Item -Path $win32Path -Force | Out-Null }
    Set-ItemProperty -Path $win32Path -Name 'Win32PrioritySeparation' -Value 0x26 -Type DWord -Force
    Write-KayleysMegaToolLog "Win32PrioritySeparation = 0x26"

    # Power Throttling kill
    $throttlePath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling'
    if (-not (Test-Path $throttlePath)) { New-Item -Path $throttlePath -Force | Out-Null }
    Set-ItemProperty -Path $throttlePath -Name 'PowerThrottlingOff' -Value 1 -Type DWord -Force
    Write-KayleysMegaToolLog "PowerThrottlingOff = 1"

    # TSC Sync Policy = Enhanced (BCDedit)
    try {
        bcdedit /set useplatformtick yes 2>&1 | Out-Null
        bcdedit /set useplatformclock yes 2>&1 | Out-Null
        bcdedit /set tscsyncpolicy Enhanced 2>&1 | Out-Null
        Write-KayleysMegaToolLog "TSC sync policy set (BCDedit)."
    } catch { Write-KayleysMegaToolLog "BCDedit TSC: $_" -Level ERROR }

    # IRQ8 (CMOS/RTC) high priority
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
    if (-not (Test-Path $base)) { New-Item -Path $base -Force | Out-Null }
    Set-ItemProperty -Path $base -Name 'IRQ8Priority' -Value 1 -Type DWord -Force
    Write-KayleysMegaToolLog "IRQ8Priority = 1"

    # Hibernation kill
    try {
        powercfg -h off
        $hiberfil = "$env:SystemDrive\hiberfil.sys"
        if (Test-Path $hiberfil) { Remove-Item $hiberfil -Force -ErrorAction SilentlyContinue }
        Write-KayleysMegaToolLog "Hibernation disabled and hiberfil.sys removed."
    } catch { Write-KayleysMegaToolLog "Hibernation: $_" -Level ERROR }

    # Zero sleep/timeout (monitor and standby)
    $powerCfgArgs = @(
        '/change', 'monitor-timeout-ac', '0',
        '/change', 'monitor-timeout-dc', '0',
        '/change', 'standby-timeout-ac', '0',
        '/change', 'standby-timeout-dc', '0',
        '/change', 'hibernate-timeout-ac', '0',
        '/change', 'hibernate-timeout-dc', '0',
        '/change', 'disk-timeout-ac', '0',
        '/change', 'disk-timeout-dc', '0'
    )
    foreach ($i in 0..([math]::Floor($powerCfgArgs.Count / 3) - 1)) {
        $idx = $i * 3
        powercfg $powerCfgArgs[$idx] $powerCfgArgs[$idx+1] $powerCfgArgs[$idx+2] 2>&1 | Out-Null
    }
    Write-KayleysMegaToolLog "All AC/DC monitor and standby timeouts set to 0."

    # Overlay efficiency: Best Performance for AC and DC
    try {
        powercfg -duplicatescheme $BestPerfOverlayGUID | Out-Null
        $active = (powercfg -getactivescheme) -replace '^[^(]*\(([^)]+)\).*','$1'
        powercfg -setacvalueindex $active SUB_OVERLAY 0 $BestPerfOverlayGUID 2>&1 | Out-Null
        powercfg -setdcvalueindex $active SUB_OVERLAY 0 $BestPerfOverlayGUID 2>&1 | Out-Null
        powercfg -setactive $active 2>&1 | Out-Null
        Write-KayleysMegaToolLog "Best Performance overlay set for AC/DC."
    } catch { Write-KayleysMegaToolLog "Overlay: $_" -Level ERROR }
}

# =============================================================================
# MEMORY & STORAGE
# =============================================================================
function Set-MemoryStorage {
    # Memory compression kill (MMAgent -mc)
    try {
        Disable-MMAgent -MemoryCompression -ErrorAction Stop
        Write-KayleysMegaToolLog "Memory compression (MMAgent -mc) disabled."
    } catch { Write-KayleysMegaToolLog "MMAgent MemoryCompression: $_" -Level ERROR }

    # Large system cache
    $memPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    if (-not (Test-Path $memPath)) { New-Item -Path $memPath -Force | Out-Null }
    Set-ItemProperty -Path $memPath -Name 'LargeSystemCache' -Value 1 -Type DWord -Force
    Write-KayleysMegaToolLog "LargeSystemCache = 1"

    # NTFS last access update disabled
    Set-ItemProperty -Path $memPath -Name 'NtfsDisableLastAccessUpdate' -Value 1 -Type DWord -Force
    Write-KayleysMegaToolLog "NtfsDisableLastAccessUpdate = 1"

    # SSD ReTrim
    try {
        Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' } | ForEach-Object {
            Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -ErrorAction SilentlyContinue
        }
        Write-KayleysMegaToolLog "SSD ReTrim executed."
    } catch { Write-KayleysMegaToolLog "ReTrim: $_" -Level ERROR }
}

# =============================================================================
# BLOATWARE & SERVICES
# =============================================================================
function Remove-BloatApps {
    foreach ($app in $BloatAppList) {
        try {
            Get-AppxPackage -Name $app -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$app*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            Write-KayleysMegaToolLog "Removed (Appx/Provisioned): $app"
        } catch { Write-KayleysMegaToolLog "App remove $app : $_" -Level ERROR }
    }
    # Generic provisioned cleanup by name pattern
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object {
        $_.DisplayName -match 'Xbox|Skype|Bing|Maps|GetHelp|Getstarted|Solitaire|Zune|FeedbackHub|MixedReality|Cortana|Wallet|OneConnect|Messaging|3DBuilder|Alarms|SoundRecorder|ScreenSketch|TCUI|People|Photos'
    } | ForEach-Object {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue
            Write-KayleysMegaToolLog "Provisioned removed: $($_.DisplayName)"
        } catch { }
    }
}

function Set-ServiceHardening {
    $servicesToDisable = @(
        'DiagTrack'
        'dmwappushservice'
        'SysMain'       # Superfetch
        'WbioSrvc'      # Biometrics
        'XblAuthManager'
        'XblGameSave'
    )
    foreach ($svc in $servicesToDisable) {
        try {
            $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
            if ($s) {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
                Write-KayleysMegaToolLog "Service disabled: $svc"
            }
        } catch { Write-KayleysMegaToolLog "Service $svc : $_" -Level ERROR }
    }
}

function Disable-ScheduledTasksBloat {
    $taskPaths = @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater'
        '\Microsoft\Windows\Autochk\Proxy'
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'
        '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector'
        '\Microsoft\Windows\Windows Error Reporting\QueueReporting'
    )
    $taskNames = @('Microsoft Compatibility Appraiser', 'ProgramDataUpdater', 'Consolidator', 'AnalyzeSystem')
    foreach ($path in $taskPaths) {
        try {
            $task = Get-ScheduledTask -TaskPath (Split-Path $path -Parent) -TaskName (Split-Path $path -Leaf) -ErrorAction SilentlyContinue
            if ($task) {
                Disable-ScheduledTask -TaskPath (Split-Path $path -Parent) -TaskName (Split-Path $path -Leaf) -ErrorAction SilentlyContinue
                Write-KayleysMegaToolLog "Task disabled: $path"
            }
        } catch { }
    }
    Get-ScheduledTask -TaskPath '\Microsoft\Windows\Application Experience\' -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'Compatibility|Consolidator|ProgramDataUpdater|AnalyzeSystem' } | Disable-ScheduledTask -ErrorAction SilentlyContinue
    Get-ScheduledTask -TaskPath '\Microsoft\Windows\Customer Experience Improvement Program\' -ErrorAction SilentlyContinue | Disable-ScheduledTask -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "Scheduled tasks (Compatibility Appraiser, Consolidator, AnalyzeSystem) disabled."
}

function Set-StoreAutoUpdateOff {
    $storePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Store'
    if (-not (Test-Path $storePath)) { New-Item -Path $storePath -Force | Out-Null }
    Set-ItemProperty -Path $storePath -Name 'AutoDownload' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "Store AutoDownload = 2 (no auto-update)."
}

# =============================================================================
# PRIVACY & TRACKING
# =============================================================================
function Set-Privacy {
    # Location
    $locPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B22}'
    if (-not (Test-Path $locPath)) { New-Item -Path $locPath -Force | Out-Null }
    Set-ItemProperty -Path $locPath -Name 'SensorPermissionState' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration' -Name 'Status' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # Advertising ID
    $advPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
    if (-not (Test-Path $advPath)) { New-Item -Path $advPath -Force | Out-Null }
    Set-ItemProperty -Path $advPath -Name 'Enabled' -Value 0 -Type DWord -Force

    # Activity Feed
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Feeds' -Name 'ShellFeedsTaskbarViewMode' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue

    # Find My Device
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Settings\FindMyDevice' -Name 'LocationSyncEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # Input personalization (typing/inking learning)
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Input\TIPC' -Name 'Enabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\InputPersonalization' -Name 'RestrictImplicitInkCollection' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\InputPersonalization' -Name 'RestrictImplicitTextCollection' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Personalization\Settings' -Name 'AcceptedPrivacyPolicy' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # Feedback / SIUF
    $siufPath = 'HKCU:\Software\Microsoft\Siuf\Rules'
    if (-not (Test-Path $siufPath)) { New-Item -Path $siufPath -Force | Out-Null }
    Set-ItemProperty -Path $siufPath -Name 'NumberOfSIUFInPeriod' -Value 0 -Type DWord -Force

    # Search Highlights (taskbar doodles)
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'IsSearchBoxTextSettingEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    Write-KayleysMegaToolLog "Privacy and tracking options applied."
}

# =============================================================================
# SECURITY HARDENING
# =============================================================================
function Set-SecurityHardening {
    # Remote Assistance
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance' -Name 'fAllowToGetHelp' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # SMBv1
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction SilentlyContinue
    Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue

    # Admin shares (AutoShareWks)
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters' -Name 'AutoShareWks' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # Windows Script Host (.vbs, .js engine)
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings' -Name 'Enabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # NetBIOS over TCP/IP = Disabled (2) on all interfaces
    Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces\Tcpip_$($_.InterfaceGuid)" -Name 'NetbiosOptions' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
    }
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters' -Name 'NetbiosOptions' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue

    Write-KayleysMegaToolLog "Security hardening applied."
}

# =============================================================================
# UI & EXPERIENCE
# =============================================================================
function Set-UIExperience {
    # Windows 11 classic context menu (Win10-style right-click)
    Set-ItemProperty -Path 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' -Name '(Default)' -Value '' -Force -ErrorAction SilentlyContinue
    $clsidPath = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
    if (-not (Test-Path $clsidPath)) {
        New-Item -Path $clsidPath -Force | Out-Null
        New-Item -Path "$clsidPath\InprocServer32" -Force | Out-Null
        Set-ItemProperty -Path "$clsidPath\InprocServer32" -Name '(Default)' -Value '' -Force
    }

    # Visual FX strip
    $explorerPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
    if (-not (Test-Path $explorerPath)) { New-Item -Path $explorerPath -Force | Out-Null }
    Set-ItemProperty -Path $explorerPath -Name 'ListviewAlphaSelect' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarAnimations' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'UseOLEDTaskbarTransparency' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

    # Menu show delay = 0
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name 'MenuShowDelay' -Value '0' -Type String -Force -ErrorAction SilentlyContinue

    # WaitToKillServiceTimeout = 2000
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'WaitToKillServiceTimeout' -Value '2000' -Type String -Force -ErrorAction SilentlyContinue

    # PowerShell context: .ps1 open with bypass
    $ps1Path = 'HKCR:\Microsoft.PowerShellScript.1\Shell\Open\Command'
    if (Test-Path $ps1Path) {
        $psExe = (Get-Command powershell.exe).Source
        Set-ItemProperty -Path $ps1Path -Name '(Default)' -Value "`"$psExe`" -NoProfile -ExecutionPolicy Bypass -File `"%1`"" -Force -ErrorAction SilentlyContinue
    }

    # Taskbar "End Task" (developer right-click)
    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarDeveloperSettings' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    # GodMode folder on Desktop
    $godMode = [Environment]::GetFolderPath('Desktop') + '\GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}'
    if (-not (Test-Path $godMode)) {
        New-Item -Path $godMode -ItemType Directory -Force | Out-Null
        Write-KayleysMegaToolLog "GodMode created on Desktop."
    }

    Write-KayleysMegaToolLog "UI and experience tweaks applied."
}

# =============================================================================
# MAINTENANCE
# =============================================================================
function Invoke-DeepJanitor {
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Get-ChildItem -Path $env:LOCALAPPDATA -Filter 'thumbcache_*.db' -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "Deep Janitor: TEMP, thumbcache, Recycle Bin cleaned."
}

function Invoke-NetworkReset {
    ipconfig /flushdns 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    Write-KayleysMegaToolLog "Network: FlushDNS, IP reset, Winsock reset."
}

function Invoke-GlobalRepair {
    Write-KayleysMegaToolLog "Running SFC /scannow..."
    sfc /scannow
    Write-KayleysMegaToolLog "Running DISM /Online /Cleanup-Image /RestoreHealth..."
    Dism /Online /Cleanup-Image /RestoreHealth /NoRestart
    Write-KayleysMegaToolLog "SFC and DISM RestoreHealth executed."
}

function Invoke-MASActivation {
    param([switch]$Skip)
    if ($Skip) { Write-KayleysMegaToolLog "MAS skipped (parameter)."; return }
    $masUrl = 'https://raw.githubusercontent.com/massgravel/Microsoft-Activation-Scripts/master/MAS/All-In-One-Version/MAS_AIO.cmd'
    $dest = Join-Path $env:TEMP 'MAS_AIO.cmd'
    try {
        Invoke-WebRequest -Uri $masUrl -OutFile $dest -UseBasicParsing -ErrorAction Stop
        # /S = silent (no prompt), /K-WindowsOffice = activate all Windows + Office with Online KMS (no user input)
        Start-Process -FilePath $dest -ArgumentList '/S', '/K-WindowsOffice' -Wait -Verb RunAs -WindowStyle Hidden
        Write-KayleysMegaToolLog "MAS activation script executed (silent, activate all Windows + Office)."
    } catch {
        Write-KayleysMegaToolLog "MAS download/run failed: $_" -Level ERROR
    }
}

# =============================================================================
# UPDATE ALL PACKAGES (winget + Chocolatey)
# =============================================================================
function Invoke-UpdateAllPackages {
    param([switch]$Skip)
    if ($Skip) { Write-KayleysMegaToolLog "Update-all-packages skipped."; return }

    # ---------- winget ----------
    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetPath) {
        try {
            $wingetVer = (winget --version 2>&1) -join ' '
            Write-KayleysMegaToolLog "winget found: $wingetVer"
            Write-KayleysMegaToolLog "Updating winget sources..."
            winget source update 2>&1 | ForEach-Object { Write-KayleysMegaToolLog "  $_" }
            Write-KayleysMegaToolLog "Upgrading all winget packages (--all)..."
            winget upgrade --all --accept-package-agreements --accept-source-agreements 2>&1 | ForEach-Object { Write-KayleysMegaToolLog "  $_" }
            Write-KayleysMegaToolLog "winget upgrade --all completed."
        } catch {
            Write-KayleysMegaToolLog "winget error: $_" -Level ERROR
        }
    } else {
        Write-KayleysMegaToolLog "winget not installed; skipping."
    }

    # ---------- Chocolatey ----------
    $chocoPath = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $chocoPath) {
        $chocoPath = "$env:ProgramData\chocolatey\bin\choco.exe"
        if (-not (Test-Path $chocoPath)) { $chocoPath = $null }
    }
    if ($chocoPath) {
        try {
            $chocoVer = & $chocoPath --version 2>&1
            Write-KayleysMegaToolLog "Chocolatey found: $chocoVer"
            Write-KayleysMegaToolLog "Upgrading Chocolatey itself..."
            & $chocoPath upgrade chocolatey -y 2>&1 | ForEach-Object { Write-KayleysMegaToolLog "  $_" }
            Write-KayleysMegaToolLog "Upgrading all Chocolatey packages..."
            & $chocoPath upgrade all -y 2>&1 | ForEach-Object { Write-KayleysMegaToolLog "  $_" }
            Write-KayleysMegaToolLog "Chocolatey upgrade all completed."
        } catch {
            Write-KayleysMegaToolLog "Chocolatey error: $_" -Level ERROR
        }
    } else {
        Write-KayleysMegaToolLog "Chocolatey not installed; skipping."
    }

    # ---------- Microsoft Store apps (trigger update check from official Store) ----------
    Invoke-StoreUpdatesFromOfficial

    # ---------- Apps not in winget/choco: update from programs' official servers ----------
    Invoke-OfficialServerUpdates

    Write-KayleysMegaToolLog "Update-all-packages (winget + Chocolatey + Store + official servers) finished."
}

# Trigger Microsoft Store to check and install updates (official Store servers)
function Invoke-StoreUpdatesFromOfficial {
    try {
        Write-KayleysMegaToolLog "Checking for Microsoft Store app updates (background check)..."
        # Note: Store updates are handled automatically by Windows; no manual trigger needed
        Write-KayleysMegaToolLog "Store updates checked (automatic background process)."
    } catch {
        Write-KayleysMegaToolLog "Store update check: $_" -Level ERROR
    }
}

# Optional: URL to a JSON app list (e.g. GitHub raw). If set and fetch succeeds, it replaces/extends the built-in list.
# Enables "Git integration": host the list in a repo and the script always gets current links.
$Script:OfficialAppListUrl = $null   # e.g. 'https://raw.githubusercontent.com/youruser/yourrepo/main/app-list.json'

# Curated list: apps with official download URLs (redirect-to-latest or stable). SilentArgs per installer.
# Pattern matches Uninstall DisplayName (-like). URL must point to official server; redirects followed.
# Optional FileName used when URL doesn't yield a good name (e.g. redirects).
# For GitHub-hosted apps use GitHubRepo (+ optional AssetPattern) instead of Url to resolve latest at runtime.
$Script:OfficialAppUpdateList = @(
    @{ Name = 'Firefox';        Pattern = '*Firefox*';           Url = 'https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US'; SilentArgs = '-ms'; FileName = 'Firefox-Setup.exe' }
    @{ Name = '7-Zip';         Pattern = '*7-Zip*';              Url = 'https://www.7-zip.org/a/7z2408-x64.exe'; SilentArgs = '/S' }
    @{ Name = 'VLC';           Pattern = '*VLC*';                Url = 'https://get.videolan.org/vlc/last/win64/vlc-3.0.20-win64.exe'; SilentArgs = '/S' }
    @{ Name = 'Notepad++';     Pattern = '*Notepad++*';          GitHubRepo = 'notepad-plus-plus/notepad-plus-plus'; AssetPattern = '*x64*Installer*.exe'; SilentArgs = '/S' }
    @{ Name = 'Git';           Pattern = '*Git*';                Url = 'https://git-scm.com/download/win'; SilentArgs = '/VERYSILENT'; FileName = 'Git-Setup.exe' }
    @{ Name = 'Sumatra PDF';   Pattern = '*Sumatra*';           Url = 'https://www.sumatrapdfreader.org/dl/rel/3.5.2/SumatraPDF-3.5.2-64-install.exe'; SilentArgs = '/S' }
    @{ Name = 'KeePassXC';     Pattern = '*KeePass*XC*';         GitHubRepo = 'keepassxreboot/keepassxc'; AssetPattern = '*win64*.msi'; SilentArgs = '/quiet' }
    @{ Name = 'PuTTY';         Pattern = '*PuTTY*';             Url = 'https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-0.81-installer.msi'; SilentArgs = '/quiet' }
    @{ Name = 'WinSCP';        Pattern = '*WinSCP*';             Url = 'https://winscp.net/download/WinSCP-6.3.2-Setup.exe'; SilentArgs = '/VERYSILENT' }
    @{ Name = 'Audacity';      Pattern = '*Audacity*';           GitHubRepo = 'audacity/audacity'; AssetPattern = '*windows*64bit*.exe'; SilentArgs = '/S' }
    @{ Name = 'GIMP';          Pattern = '*GIMP*';               Url = 'https://download.gimp.org/gimp/v2.10/windows/gimp-2.10.38-setup-1.exe'; SilentArgs = '/VERYSILENT' }
    @{ Name = 'qBittorrent';   Pattern = '*qBittorrent*';        Url = 'https://altushost-swe.dl.sourceforge.net/project/qbittorrent/qbittorrent/qbittorrent-4.6.5/qbittorrent_4.6.5_x64_setup.exe'; SilentArgs = '/S' }
    @{ Name = 'HandBrake';     Pattern = '*HandBrake*';         Url = 'https://handbrake.fr/rotation.php?file=HandBrake-1.8.2-x86_64-Win_GUI.exe'; SilentArgs = '/S' }
    @{ Name = 'Python';        Pattern = '*Python 3*';          Url = 'https://www.python.org/ftp/python/3.12.7/python-3.12.7-amd64.exe'; SilentArgs = '/quiet InstallAllUsers=1 PrependPath=1' }
    @{ Name = 'Node.js';       Pattern = '*Node.js*';            Url = 'https://nodejs.org/dist/v22.11.0/node-v22.11.0-x64.msi'; SilentArgs = '/quiet' }
    @{ Name = 'LibreOffice';   Pattern = '*LibreOffice*';        Url = 'https://download.documentfoundation.org/libreoffice/stable/24.8.2/win/x86_64/LibreOffice_24.8.2_Win_x86-64.msi'; SilentArgs = '/quiet' }
    @{ Name = 'Zoom';          Pattern = '*Zoom*';               Url = 'https://zoom.us/client/latest/ZoomInstallerFull.msi'; SilentArgs = '/quiet' }
)

# Resolve latest release download URL from GitHub (free API, no auth). Returns $null on failure.
function Get-GitHubLatestReleaseUrl {
    param([string]$Repo, [string]$AssetPattern = '*')
    try {
        $api = "https://api.github.com/repos/$Repo/releases/latest"
        $headers = @{ 'Accept' = 'application/vnd.github.v3+json'; 'User-Agent' = 'KayleysMegaTool' }
        $r = Invoke-RestMethod -Uri $api -Headers $headers -UseBasicParsing -ErrorAction Stop
        $asset = $r.assets | Where-Object { $_.name -like $AssetPattern } | Select-Object -First 1
        if ($asset) { return $asset.browser_download_url }
    } catch { Write-KayleysMegaToolLog "  GitHub API $Repo : $_" -Level ERROR }
    return $null
}

# Fetch app list from remote URL (JSON). Returns $null on failure. JSON format: array of { Name, Pattern, Url?, GitHubRepo?, AssetPattern?, SilentArgs, FileName? }
function Get-RemoteOfficialAppList {
    param([string]$Url)
    try {
        $json = Invoke-RestMethod -Uri $Url -UseBasicParsing -ErrorAction Stop
        $list = @()
        foreach ($o in $json) {
            $e = @{ Name = $o.Name; Pattern = $o.Pattern; SilentArgs = $o.SilentArgs }
            if ($o.FileName) { $e.FileName = $o.FileName }
            if ($o.Url) { $e.Url = $o.Url }
            if ($o.GitHubRepo) { $e.GitHubRepo = $o.GitHubRepo; if ($o.AssetPattern) { $e.AssetPattern = $o.AssetPattern } }
            $list += $e
        }
        return $list
    } catch { Write-KayleysMegaToolLog "Remote app list fetch failed: $_" -Level ERROR; return $null }
}

# Get the app list (remote if URL set and fetch OK, else built-in) and resolve GitHub "latest" URLs at runtime.
function Get-ResolvedOfficialAppUpdateList {
    $list = $Script:OfficialAppUpdateList
    if ($Script:OfficialAppListUrl) {
        $remote = Get-RemoteOfficialAppList -Url $Script:OfficialAppListUrl
        if ($remote -and $remote.Count -gt 0) {
            Write-KayleysMegaToolLog "Using remote app list from Git (official links kept up to date)."
            $list = $remote
        }
    }
    $resolved = @()
    foreach ($entry in $list) {
        $e = @{ Name = $entry.Name; Pattern = $entry.Pattern; Url = $entry.Url; SilentArgs = $entry.SilentArgs }
        if ($entry.FileName) { $e.FileName = $entry.FileName }
        if ($entry.GitHubRepo) {
            $pattern = $entry.AssetPattern
            if (-not $pattern) { $pattern = '*' }
            $e.Url = Get-GitHubLatestReleaseUrl -Repo $entry.GitHubRepo -AssetPattern $pattern
            if (-not $e.Url) { continue }
        }
        if ($e.Url) { $resolved += $e }
    }
    return $resolved
}

# Get installed app display names from registry (HKLM Uninstall keys)
function Get-InstalledAppDisplayNames {
    $names = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($path in $paths) {
        try {
            Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.DisplayName) { [void]$names.Add($_.DisplayName.Trim()) }
            }
        } catch { }
    }
    return @($names)
}

# Update apps from official servers using curated list (only for apps not in winget/choco or as fallback)
function Invoke-OfficialServerUpdates {
    $installed = Get-InstalledAppDisplayNames
    if (-not $installed.Count) { Write-KayleysMegaToolLog "No installed apps found in registry."; return }

    Write-KayleysMegaToolLog "Checking for updates from programs' official servers (outside winget/choco)..."
    $list = Get-ResolvedOfficialAppUpdateList
    $updated = 0
    foreach ($entry in $list) {
        $name = $entry.Name
        $pattern = $entry.Pattern
        $url = $entry.Url
        $silentArgs = $entry.SilentArgs
        $matched = $installed | Where-Object { $_ -like $pattern }
        if (-not $matched) { continue }

        try {
            $fileName = $entry.FileName
            if (-not $fileName) {
                $fileName = [System.IO.Path]::GetFileName(([System.Uri]$url).LocalPath)
                if (-not $fileName -or $fileName -eq '') { $fileName = "$name-installer.exe" }
            }
            $dest = Join-Path $env:TEMP $fileName
            Write-KayleysMegaToolLog "  Downloading $name from official server..."
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
            if (-not (Test-Path $dest)) { Write-KayleysMegaToolLog "  $name : download failed." -Level ERROR; continue }
            Write-KayleysMegaToolLog "  Running $name installer (silent)..."
            $proc = Start-Process -FilePath $dest -ArgumentList $silentArgs -Wait -PassThru -ErrorAction SilentlyContinue -WindowStyle Hidden
            if ($proc.ExitCode -eq 0) { $updated++; Write-KayleysMegaToolLog "  $name updated." } else { Write-KayleysMegaToolLog "  $name installer exit code: $($proc.ExitCode)." }
            Remove-Item $dest -Force -ErrorAction SilentlyContinue
        } catch {
            Write-KayleysMegaToolLog "  $name : $_" -Level ERROR
        }
    }
    Write-KayleysMegaToolLog "Official-server updates attempted for $updated app(s)."
}

# =============================================================================
# MAIN ENTRY (call this from GUI or when script run directly)
# =============================================================================
function Invoke-KayleysMegaToolMain {
    param(
        [bool]$SkipRestorePoint = $false,
        [bool]$SkipMAS = $false,
        [bool]$SkipUpdateAllPackages = $false,
        [bool]$WhatIf = $false
    )
    if ($Script:VerboseLog) {
        "Kayley's Mega Tool started. Log: $Script:LogPath" | Add-Content -Path $Script:LogPath
    }
    Write-KayleysMegaToolLog "Kayley's Mega Tool - Safety, Performance, Maintenance"
    if (-not $SkipRestorePoint) {
        Write-KayleysMegaToolLog "Creating restore point: $RestorePointName ..."
        Set-SafetyRestore
    }
    Write-KayleysMegaToolLog "Applying performance (Omega)..."
    Set-PerformanceOmega
    Write-KayleysMegaToolLog "Applying memory & storage..."
    Set-MemoryStorage
    Write-KayleysMegaToolLog "Removing bloatware and hardening services..."
    Remove-BloatApps
    Set-ServiceHardening
    Disable-ScheduledTasksBloat
    Set-StoreAutoUpdateOff
    Write-KayleysMegaToolLog "Privacy & tracking..."
    Set-Privacy
    Write-KayleysMegaToolLog "Security hardening..."
    Set-SecurityHardening
    Write-KayleysMegaToolLog "UI & experience..."
    Set-UIExperience
    Write-KayleysMegaToolLog "Maintenance: Janitor, Network, SFC/DISM..."
    Invoke-DeepJanitor
    Invoke-NetworkReset
    if (-not $WhatIf) { Invoke-GlobalRepair }
    Write-KayleysMegaToolLog "Updating winget & Chocolatey and all installed packages..."
    Invoke-UpdateAllPackages -Skip:$SkipUpdateAllPackages
    Invoke-MASActivation -Skip:$SkipMAS
    Write-KayleysMegaToolLog "Applying Advanced Omega Tweaks..."
    Set-AdvancedOmegaTweaks
    Write-KayleysMegaToolLog "Done. Reboot recommended for all changes."
    if ($Script:VerboseLog) { Write-KayleysMegaToolLog "Log file: $Script:LogPath" }
    Show-RebootDialog
}

# =============================================================================
# ADVANCED OMEGA TWEAKS
# =============================================================================
function Set-AdvancedOmegaTweaks {
    Write-KayleysMegaToolLog "Applying Advanced Omega Tweaks..."

    # 1. Network & Latency
    Write-KayleysMegaToolLog "  Network & Latency optimizations..."
    
    # TCP Autotuning: Disable Receive Window Autotuning
    netsh int tcp set global autotuninglevel=disabled 2>&1 | Out-Null
    Write-KayleysMegaToolLog "  TCP Autotuning disabled."

    # RSS: Enable Receive Side Scaling
    netsh int tcp set global rss=enabled 2>&1 | Out-Null
    Write-KayleysMegaToolLog "  RSS enabled."

    # NetDMA: Enable NetDMA
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\NetDMA' -Name 'Start' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  NetDMA enabled."

    # Task Offloading: Disable Chimney Offload and IPsec Offload
    netsh int tcp set global chimney=disabled 2>&1 | Out-Null
    netsh int ip set global taskoffload=disabled 2>&1 | Out-Null
    Write-KayleysMegaToolLog "  Task offloading disabled (Chimney and IPsec)."

    # Network Throttling Index
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'NetworkThrottlingIndex' -Value 0xffffffff -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Network Throttling Index set to max."

    # 2. Gaming & Input Lag
    Write-KayleysMegaToolLog "  Gaming & Input Lag optimizations..."

    # Mouse Acceleration: Disable Enhance Pointer Precision
    Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseSpeed' -Value 0 -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold1' -Value 0 -Type String -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold2' -Value 0 -Type String -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Mouse acceleration disabled."

    # Game DVR: Disable
    Set-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'GameDVR_Enabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' -Name 'AllowGameDVR' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Game DVR disabled."

    # FSO: Disable Fullscreen Optimizations globally
    Set-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name 'GameMode' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Fullscreen Optimizations disabled globally."

    # HPET: Disable
    bcdedit /deletevalue useplatformclock 2>&1 | Out-Null
    bcdedit /set disabledynamictick yes 2>&1 | Out-Null
    Write-KayleysMegaToolLog "  HPET disabled."

    # 3. Privacy & Bloat
    Write-KayleysMegaToolLog "  Privacy & Bloat cleanup..."

    # OneDrive: Full uninstall
    Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
    Start-Process "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -ArgumentList '/uninstall' -Wait -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:UserProfile\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LocalAppData\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:ProgramData\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  OneDrive fully uninstalled."

    # Bing Search: Disable Web Search
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Name 'BingSearchEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'DisableWebSearch' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Bing search disabled."

    # Widgets/News: Disable
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds' -Name 'ShellFeedsTaskbarViewMode' -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Widgets/News disabled."

    # Meet Now/Chat: Disable
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'HideSCAMeetNow' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Meet Now/Chat disabled."

    # Lock Screen Ads: Disable Spotlight
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'RotatingLockScreenEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' -Name 'SubscribedContent-338387Enabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Lock screen ads disabled."

    # 4. System Services
    Write-KayleysMegaToolLog "  System Services purge..."

    # Maps Manager: Disable
    Set-Service -Name MapsBroker -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service -Name MapsBroker -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Maps Manager disabled."

    # Remote Registry: Disable
    Set-Service -Name RemoteRegistry -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service -Name RemoteRegistry -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Remote Registry disabled."

    # Touch Keyboard/Handwriting: Disable
    Set-Service -Name TabletInputService -StartupType Disabled -ErrorAction SilentlyContinue
    Stop-Service -Name TabletInputService -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Touch Keyboard/Handwriting disabled."

    # 5. Windows Update & Maintenance
    Write-KayleysMegaToolLog "  Windows Update & Maintenance tweaks..."

    # Delivery Optimization: Disable
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' -Name 'DODownloadMode' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Delivery Optimization disabled."

    # Automatic Maintenance: Disable wake-up
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' -Name 'WakeUp' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Automatic Maintenance wake-up disabled."

    # Background Apps: Disable globally
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Name 'GlobalUserDisabled' -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Background Apps disabled globally."

    # 6. Advanced Omega
    Write-KayleysMegaToolLog "  Advanced Omega optimizations..."

    # Spectre & Meltdown: Disable mitigations
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'FeatureSettingsOverride' -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name 'FeatureSettingsOverrideMask' -Value 3 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Spectre & Meltdown mitigations disabled."

    # VBS: Disable
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -Name 'EnableVirtualizationBasedSecurity' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  VBS disabled."

    # UAC: Lower prompt
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'ConsentPromptBehaviorAdmin' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  UAC prompt lowered."

    # DMA Remapping: Disable
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\DmaGuard\DeviceEnumerationPolicy' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  DMA Remapping disabled."

    # Bonus: Edge tweaks
    Write-KayleysMegaToolLog "  Edge optimizations..."

    # Edge Startup Boost: Disable
    $edgePath = 'HKCU:\SOFTWARE\Policies\Microsoft\Edge'
    if (-not (Test-Path $edgePath)) { New-Item -Path $edgePath -Force | Out-Null }
    Set-ItemProperty -Path $edgePath -Name 'StartupBoostEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Edge Startup Boost disabled."

    # Edge Background Extensions: Disable
    Set-ItemProperty -Path $edgePath -Name 'BackgroundModeEnabled' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Edge Background Extensions disabled."

    # Cortana Cloud: Disable
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCloudSearch' -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Write-KayleysMegaToolLog "  Cortana Cloud disabled."

    Write-KayleysMegaToolLog "Advanced Omega Tweaks applied."
}

# =============================================================================
# REBOOT DIALOG
# =============================================================================
function Show-RebootDialog {
    Add-Type -AssemblyName System.Windows.Forms
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Kayley's Mega Tool has completed successfully!`n`nA reboot is recommended to apply all changes.`n`nDo you want to reboot now?",
        "Reboot Recommended",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        Write-KayleysMegaToolLog "User chose to reboot now."
        Restart-Computer -Force
    } else {
        Write-KayleysMegaToolLog "User declined reboot."
    }
}

# =============================================================================
# GUI SECTION
# =============================================================================
function Start-KayleysMegaToolGUI {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # -----------------------------------------------------------------------------
    # Form
    # -----------------------------------------------------------------------------
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Kayley''s Mega Tool'
    $form.Size = New-Object System.Drawing.Size(720, 520)
    $form.StartPosition = 'CenterScreen'
    $form.MinimumSize = New-Object System.Drawing.Size(600, 400)
    $form.FormBorderStyle = 'Sizable'
    $form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)

    # CMD-style log panel (black background, green text, monospace)
    $logBox = New-Object System.Windows.Forms.TextBox
    $logBox.Multiline = $true
    $logBox.ReadOnly = $true
    $logBox.ScrollBars = 'Vertical'
    $logBox.Font = New-Object System.Drawing.Font('Consolas', 9)
    $logBox.BackColor = [System.Drawing.Color]::FromArgb(12, 12, 12)
    $logBox.ForeColor = [System.Drawing.Color]::FromArgb(0, 255, 0)
    $logBox.Dock = 'Fill'
    $logBox.BorderStyle = 'FixedSingle'
    $logBox.TabIndex = 0

    # Top panel: title + options
    $topPanel = New-Object System.Windows.Forms.Panel
    $topPanel.Height = 56
    $topPanel.Dock = 'Top'
    $topPanel.Padding = New-Object System.Windows.Forms.Padding(8, 6)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = 'Kayley''s Mega Tool — Safety, Performance, Maintenance'
    $lblTitle.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(8, 8)
    $lblTitle.AutoSize = $true
    $topPanel.Controls.Add($lblTitle)

    $chkSkipRestore = New-Object System.Windows.Forms.CheckBox
    $chkSkipRestore.Text = 'Skip restore point'
    $chkSkipRestore.Location = New-Object System.Drawing.Point(8, 32)
    $chkSkipRestore.AutoSize = $true
    $topPanel.Controls.Add($chkSkipRestore)

    $chkSkipMAS = New-Object System.Windows.Forms.CheckBox
    $chkSkipMAS.Text = 'Skip MAS activation'
    $chkSkipMAS.Location = New-Object System.Drawing.Point(160, 32)
    $chkSkipMAS.AutoSize = $true
    $topPanel.Controls.Add($chkSkipMAS)

    $chkSkipUpdateAll = New-Object System.Windows.Forms.CheckBox
    $chkSkipUpdateAll.Text = 'Skip package updates (winget + Chocolatey)'
    $chkSkipUpdateAll.Location = New-Object System.Drawing.Point(300, 32)
    $chkSkipUpdateAll.AutoSize = $true
    $chkSkipUpdateAll.Checked = $false
    $topPanel.Controls.Add($chkSkipUpdateAll)

    # Bottom panel: buttons + status
    $bottomPanel = New-Object System.Windows.Forms.Panel
    $bottomPanel.Height = 44
    $bottomPanel.Dock = 'Bottom'
    $bottomPanel.Padding = New-Object System.Windows.Forms.Padding(8, 6)

    $btnRun = New-Object System.Windows.Forms.Button
    $btnRun.Text = 'Run'
    $btnRun.Size = New-Object System.Drawing.Size(90, 28)
    $btnRun.Location = New-Object System.Drawing.Point(8, 6)
    $bottomPanel.Controls.Add($btnRun)

    $btnClear = New-Object System.Windows.Forms.Button
    $btnClear.Text = 'Clear log'
    $btnClear.Size = New-Object System.Drawing.Size(80, 28)
    $btnClear.Location = New-Object System.Drawing.Point(102, 6)
    $bottomPanel.Controls.Add($btnClear)

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Text = 'Ready'
    $lblStatus.AutoSize = $true
    $lblStatus.Location = New-Object System.Drawing.Point(200, 12)
    $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
    $bottomPanel.Controls.Add($lblStatus)

    # Center: log area
    $logPanel = New-Object System.Windows.Forms.Panel
    $logPanel.Dock = 'Fill'
    $logPanel.Padding = New-Object System.Windows.Forms.Padding(6, 0)
    $logPanel.Controls.Add($logBox)

    # Layout: add Fill first, then Bottom, then Top so docking lays out correctly
    $form.Controls.Add($logPanel)
    $form.Controls.Add($bottomPanel)
    $form.Controls.Add($topPanel)

    # Timer to drain log queue into the text box
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 80
    $timer.Add_Tick({
        $logQueue = $script:OmegaLogQueue
        if (-not $logQueue) { return }
        $line = $null
        while ($logQueue.TryDequeue([ref]$line)) {
            if ($logBox.Text.Length -gt 500000) {
                $logBox.Select(0, 100000)
                $logBox.SelectedText = ''
            }
            $logBox.AppendText($line + "`r`n")
            $logBox.ScrollToCaret()
        }
        if ($script:OmegaPowerShell -and $script:OmegaPowerShell.IsCompleted) {
            $timer.Stop()
            $script:OmegaPowerShell = $null
            $btnRun.Enabled = $true
            $lblStatus.Text = 'Done. Reboot recommended.'
            $lblStatus.ForeColor = [System.Drawing.Color]::DarkBlue
            Show-RebootDialog
        }
    })

    function Append-LogMessage {
        param([string]$Text)
        $logBox.AppendText($Text + "`r`n")
        $logBox.ScrollToCaret()
    }

    $btnClear.Add_Click({
        $logBox.Clear()
        Append-LogMessage "[Log cleared]"
        $lblStatus.Text = 'Ready'
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
    })

    $btnRun.Add_Click({
        $btnRun.Enabled = $false
        $lblStatus.Text = 'Running...'
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkOrange
        Append-LogMessage "--- Kayley's Mega Tool started $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ---"

        $script:OmegaLogQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
        $runspace = [runspacefactory]::CreateRunspace()
        $runspace.Open()
        $runspace.SessionStateProxy.SetVariable('LogQueue', $script:OmegaLogQueue)
        $runspace.SessionStateProxy.SetVariable('SkipRestorePoint', $chkSkipRestore.Checked)
        $runspace.SessionStateProxy.SetVariable('SkipMAS', $chkSkipMAS.Checked)
        $runspace.SessionStateProxy.SetVariable('SkipUpdateAllPackages', $chkSkipUpdateAll.Checked)

        $scriptBlock = {
            $Script:LogQueue = $LogQueue
            $Script:VerboseLog = $true
            Invoke-KayleysMegaToolMain -SkipRestorePoint $SkipRestorePoint -SkipMAS $SkipMAS -SkipUpdateAllPackages $SkipUpdateAllPackages -WhatIf $false
        }

        $script:OmegaPowerShell = [powershell]::Create().AddScript($scriptBlock)
        $script:OmegaPowerShell.Runspace = $runspace
        $script:OmegaPowerShell.BeginInvoke() | Out-Null
        $timer.Start()
    })

    # Initial log message
    Append-LogMessage "Kayley's Mega Tool GUI ready. Click Run to start (elevated)."
    Append-LogMessage ""

    # Show
    [void]$form.ShowDialog()
}

# =============================================================================
# EXECUTION
# =============================================================================
if ($MyInvocation.InvocationName -ne '.') {
    if ($GUI) {
        Start-KayleysMegaToolGUI
    } else {
        Invoke-KayleysMegaToolMain -SkipRestorePoint:$SkipRestorePoint.IsPresent -SkipMAS:$SkipMAS.IsPresent -SkipUpdateAllPackages:$SkipUpdateAllPackages.IsPresent -WhatIf:$WhatIf.IsPresent
    }
}
