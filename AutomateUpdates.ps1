$ScriptPath = "C:\Windows\Setup\AutomateUpdates.ps1"
$ScriptLogFile = "C:\Windows\Setup\AutomateUpdates.log"
$WindowsUpdateLog = "C:\Windows\Setup\WindowsUpdates.log"
$RebootCountRegistryPath = "HKLM:\Software\AutomateUpdates"
$RunOnceRegistryPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
$MaxReboots = 5


function Log-Message {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $ScriptLogFile -Value "[$Timestamp] [$Level] $Message"
}

function Cleanup-Script {
    Log-Message "Generating Windows Update log File. ($WindowsUpdateLog)"
    Get-WindowsUpdateLog -LogPath $WindowsUpdateLog
    Log-Message "Deleting registry key. ($RebootCountRegistryPath)"
    Remove-Item -Path $RebootCountRegistryPath -Recurse -Force
    Log-Message "Deleting script file. ($ScriptPath)"
    Remove-Item -Path $ScriptPath -Force
    Log-Message "Script cleanup completed. Exiting script."
    Exit
}

function Manage-RebootCounter {
    if (-not (Test-Path -Path $RebootCountRegistryPath)) {
        New-Item -Path $RebootCountRegistryPath -Force | Out-Null
        New-ItemProperty -Path $RebootCountRegistryPath -Name "RebootCount" -Value 0 -PropertyType DWord -Force | Out-Null
        Log-Message "Reboot counter initialized to 0."
        return 0
    } else {
        $CurrentCount = (Get-ItemProperty -Path $RebootCountRegistryPath -Name "RebootCount").RebootCount
        $NewCount = $CurrentCount + 1
        Set-ItemProperty -Path $RebootCountRegistryPath -Name "RebootCount" -Value $NewCount
        Log-Message "Reboot counter incremented to $NewCount."
        return $NewCount
    }
}

$RebootCount = Manage-RebootCounter

if ($RebootCount -ge $MaxReboots) {
    Log-Message "Maximum reboot limit ($MaxReboots) reached."
    Cleanup-Script
}

function Sync-SystemTime {
    Log-Message "Syncing system time with Windows time servers."
    try {
        $W32tmService = Get-Service -Name "w32time" -ErrorAction SilentlyContinue
        if ($W32tmService.Status -ne "Running") {
            Log-Message "Starting w32time service."
            Start-Service -Name "w32time"
        }

        w32tm /config /manualpeerlist:"time.windows.com" /syncfromflags:manual /reliable:yes /update
        w32tm /resync
        Log-Message "System time synced successfully."

        Log-Message "Restarting w32time service."
        Restart-Service -Name "w32time"
        Log-Message "w32time service restarted successfully."
    } catch {
        Log-Message "Failed to sync system time: $_" -Level "ERROR"
    }
}

function Install-NuGetPackageProvider {
    Log-Message "Attempting to install NuGet Package Provider."
    try {
        Install-PackageProvider -Name NuGet -Force -Scope AllUsers
        Log-Message "NuGet Package Provider installed successfully."
    } catch {
        Log-Message "Failed to install NuGet Package Provider: $_" -Level "ERROR"
    }
}

function Install-PSWindowsUpdateModule {
    Log-Message "Checking for PSWindowsUpdate module."
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Log-Message "PSWindowsUpdate module not found. Attempting installation."
        try {
            Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers
            Log-Message "PSWindowsUpdate module installed successfully."
        } catch {
            Log-Message "Failed to install PSWindowsUpdate module: $_" -Level "ERROR"
        }
    } else {
        Log-Message "PSWindowsUpdate module already available."
    }
}

function Import-PSWindowsUpdateModule {
    Log-Message "Importing PSWindowsUpdate module."
    try {
        Import-Module PSWindowsUpdate -Force
        Log-Message "PSWindowsUpdate module imported successfully."
    } catch {
        Log-Message "Failed to import PSWindowsUpdate module: $_" -Level "ERROR"
    }
}

function Reschedule-Script {
    Log-Message "Rescheduling script to run after reboot."
    Set-ItemProperty -Path $RunOnceRegistryPath -Name "AutomateUpdates" -Value "Powershell.exe -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Log-Message "Rebooting the system to continue script execution."
    Restart-Computer -Force
}

# Ensure system time is synced and required modules are installed before running Windows Update
if ($RebootCount -eq 0) {
    Sync-SystemTime
    Install-NuGetPackageProvider
    Install-PSWindowsUpdateModule
    Import-PSWindowsUpdateModule
}

try {
    log-message "Starting Windows Update."
    $Updates = Get-WindowsUpdate -AcceptAll -Install -AutoReboot
    if ($Updates) {
        Reschedule-Script
    } else {
        Cleanup-Script
    }
} catch {
    Log-Message "Error occurred while running Windows Update: $_" -Level "ERROR"
}
