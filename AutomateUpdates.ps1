$ScriptPath = "C:\Windows\Setup\AutomateUpdates.ps1"
$ScriptLogFile = "C:\Windows\Setup\AutomateUpdates.log"

# Helper function for logging
function Log-Message {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $ScriptLogFile -Value "[$Timestamp] [$Level] $Message"
}

# Log start of the script
Log-Message "Starting AutomateUpdates script."

# Install NuGet Package Provider
Log-Message "Attempting to install NuGet Package Provider."
try {
    Install-PackageProvider -Name NuGet -Force -Scope AllUsers
    Log-Message "NuGet Package Provider installed successfully."
} catch {
    Log-Message "Failed to install NuGet Package Provider: $_" -Level "ERROR"
}

# Install PSWindowsUpdate Module
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

# Import the PSWindowsUpdate Module
Log-Message "Importing PSWindowsUpdate module."
try {
    Import-Module PSWindowsUpdate -Force
    Log-Message "PSWindowsUpdate module imported successfully."
} catch {
    Log-Message "Failed to import PSWindowsUpdate module: $_" -Level "ERROR"
}

# Run Windows Update and Automatically Reboot if Needed
Log-Message "Starting Windows Update."
$UpdatesInstalled = $false

try {
    $Updates = Get-WindowsUpdate -AcceptAll -Install -AutoReboot
    if ($Updates) {
        Log-Message "Updates installed successfully. Reboot may be required."
        $UpdatesInstalled = $true
    } else {
        Log-Message "No updates available to install."
    }
} catch {
    Log-Message "Error occurred while running Windows Update: $_" -Level "ERROR"
}

# If a reboot was triggered, set up the script to run on the next boot
if ($UpdatesInstalled) {
    Log-Message "Setting up RunOnce registry entry for script continuation after reboot."
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "CheckForUpdatesAfterReboot" -Value "Powershell.exe -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Log-Message "Rebooting the system to complete updates."
    Restart-Computer -Force
} else {
    # If no updates were installed, delete the script on next boot
    Log-Message "No updates installed. Scheduling script deletion at next boot."
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "DeleteAutomateUpdatesScript" -Value "cmd.exe /c del `"$ScriptPath`""
    Log-Message "Rebooting the system to clean up script."
    Restart-Computer -Force
}
