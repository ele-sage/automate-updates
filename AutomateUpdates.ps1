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

function Get-WindowsUpdateLog {
    Log-Message "Generating Windows Update log File. ($WindowsUpdateLog)"
    Get-WindowsUpdateLog -LogPath $WindowsUpdateLog
}

# Function that generates Windows Update log file and removes registry key and script file
function Cleanup-Script {
    param (
        [bool]$GenerateLog = $true
    )
    if ($GenerateLog) {
        Get-WindowsUpdateLog
    }
    Log-Message "Deleting registry key. ($RebootCountRegistryPath)"
    Remove-Item -Path $RebootCountRegistryPath -Recurse -Force
    Log-Message "Deleting script file. ($ScriptPath)"
    Remove-Item -Path $ScriptPath -Force
    Log-Message "Script cleanup completed. Exiting script."
    Exit
}

# Function that reschedules the script to run after reboot
function Reschedule-Script {
    param (
        [bool]$ForceReboot = $true
    )
    Log-Message "Rescheduling script to run after reboot."
    Set-ItemProperty -Path $RunOnceRegistryPath -Name "AutomateUpdates" -Value "Powershell.exe -ExecutionPolicy Bypass -File `"$ScriptPath`""
    if ($ForceReboot) {
        Log-Message "Rebooting the system to continue script execution."
        Restart-Computer -Force
    }
}

# Function that manages the reboot counter in the registry
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

# Function that syncs system time with Windows time servers to ensure that Windows Updates can be downloaded
function Sync-SystemTime {
    Log-Message "Syncing system time with Windows time servers."
    try {
        net stop w32time
        w32tm /unregister
        w32tm /register
        net start w32time
        w32tm /resync /nowait
        Log-Message "System time synced successfully."
    } catch {
        Log-Message "Failed to sync system time: $_" -Level "ERROR"
    }
}

# Function that installs NuGet Package Provider that is required for PSWindowsUpdate module
function Install-NuGetPackageProvider {
    Log-Message "Attempting to install NuGet Package Provider."
    try {
        Install-PackageProvider -Name NuGet -Force -Scope AllUsers
        # Check nuget package provider is present in the list of package providers
        $nugetProvider = Get-PackageProvider -ListAvailable | Where-Object { $_.Name -eq "NuGet" }
        if (-not $nugetProvider) {
            Log-Message "NuGet Package Provider not found in the list of package providers." -Level "ERROR"
            Read-Host "Voulez-vous receduler le script au prochain redemarrage ? (O/N)" -OutVariable response
            if ($response -eq "O") {
                Reschedule-Script -ForceReboot $false
                Remove-Item -Path $RebootCountRegistryPath -Recurse -Force
                Exit
            } else {
                Cleanup-Script -GenerateLog $false
            }
        }
        Log-Message "NuGet Package Provider installed successfully."
    } catch {
        Log-Message "Failed to install NuGet Package Provider: $_" -Level "ERROR"
    }
}

# Function that installs PSWindowsUpdate module to manage Windows Updates
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

# Function that imports PSWindowsUpdate module to use its cmdlets
function Import-PSWindowsUpdateModule {
    Log-Message "Importing PSWindowsUpdate module."
    try {
        Import-Module PSWindowsUpdate -Force
        Log-Message "PSWindowsUpdate module imported successfully."
    } catch {
        Log-Message "Failed to import PSWindowsUpdate module: $_" -Level "ERROR"
    }
}

# --- Main script logic --

# Check if maximum reboot limit has been reached. If so, cleanup the script and exit.
# This is to prevent the script from running indefinitely in case an update would keep reappearing after reboot.
$RebootCount = Manage-RebootCounter

# Check if maximum reboot limit has been reached. If so, cleanup the script and exit.
if ($RebootCount -ge $MaxReboots) {
    Log-Message "Maximum reboot limit ($MaxReboots) reached."
    Cleanup-Script
}

# Ensure system time is synced and required modules are installed before running Windows Update
# This step is only performed on the first run of the script
if ($RebootCount -eq 0) {
    Sync-SystemTime
    Install-NuGetPackageProvider
    Install-PSWindowsUpdateModule
    Import-PSWindowsUpdateModule
}

# Run Windows Update and handle any errors that occur
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
