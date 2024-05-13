<#
.SYNOPSIS
Upgrade VM Hardware Compatibility Version:
Intended to orchestrate the VM Hardware Compatibility upgrade process by setting the VM to upgrade on next power cycle.

Author: Don Horrox (vChamp - https://www.vchamp.net)
Version: 1.0

.DESCRIPTION
 This script must be run on a system with the VMware PowerCli snap-in/module installed and
 authenticated with an account that has appropriate rights to connect to vCenter using PowerCLI.
 To install the PowerCLI module run
 Install-Module -Name VMware.PowerCLI

 Prerequisites:
 1) User must have adequate rights in vCenter retrieve and update the VM configuration.
 2) User must have adequate rights to save log output file to the working directory on the local system running the script. Run PowerShell with elevation (as Administrator) as needed.
 3) User must provide a list of scoped VMs in the form of a CSV file located in the same directory as the script.
    3a) The VM Name(s) must be listed beneath a column heading titled "Name". (i.e., Cell A1 should say "Name" and cells A2 and below should contain VM names)
 4) The VM name(s) must match according to vCenter, not the DNS hostname if different.

.NOTES
#>

# Prepare Logging
function Get-TimeStamp {
    return "[{0:MM/dd/yy}  {0:HH:mm:ss}]" -f (Get-Date)
}
$outputLog = ".\vm_hardware_upgrade.log"

# Set PowerShell to stop on all errors
$ErrorActionPreference = "Stop"

# Desired VM Hardware Version (Change as needed)
$desiredHardwareVersion = "v19"  # Example: "v19" for VMware ESXi 7.0.2 compatibility, referred to as vmx-19 in some documentation. Modify as needed.
$desiredVmxVersion = "vmx-$($desiredHardwareVersion -replace '[^\d]')"

# CSV file path for VM names
$csvFilePath = '.\vm_hardware_upgrade.csv'

## Initialize Script
Write-Output "$(Get-Timestamp) WARN: +++++++++++++++ Starting new session +++++++++++++++" | Out-File $outputLog -Append
Write-Output "$(Get-Timestamp) Initializing script." | Out-File $outputLog -Append

## Welcome message
Write-Host "############################################################################" -ForegroundColor Cyan
Write-Host "                  VMware Upgrade VM Hardware Version" -ForegroundColor Cyan
Write-Host "############################################################################" -ForegroundColor Cyan
Write-Host "`n"
Write-Host "Version: 1.0"
Write-Host "`n"
Write-Host "Objective:" -ForegroundColor Yellow
Write-Host "Orchestrate the VM Hardware Compatibility upgrade process by setting the VM to upgrade on next power cycle."
Write-Host "`n"
Write-Host "Requirements:" -ForegroundColor Yellow
Write-Host "  * CSV file named 'vm_hardware_upgrade.csv' located in the working directory."
Write-Host "  * Cell A1 value should equal 'Name' with VM Names on separate cells below."
Write-Host "`n"
Write-Host "`n"

## Connect to the vCenter
Write-Host "######################################" -ForegroundColor Yellow
Write-Host "        vCenter Authentication" -ForegroundColor Yellow
Write-Host "######################################" -ForegroundColor Yellow
Write-Host "`n"
Write-Host "Specify the FQDN of your vCenter Server below:" -ForegroundColor Yellow
Write-Output "$(Get-Timestamp) Waiting for user input - VCSA." | Out-File $outputLog -Append
$vCenterServer = Read-Host "Enter your vCenter FQDN"
Write-Output "$(Get-Timestamp) User provided vCenter FQDN of $vCenterServer." | Out-File $outputLog -Append
Write-Host "`n"
Write-Output "$(Get-Timestamp) Waiting for user credentials." | Out-File $outputLog -Append
Write-Host "Please enter your credentials below:" -ForegroundColor Yellow
$vCenterUser = Read-Host "Enter your username"
$vCenterPass = Read-Host "Enter password" -AsSecureString
try {
    Write-Host "`n"
    Write-Host "Authentication in-progress. Please wait." -ForegroundColor Cyan
    Write-Output "$(Get-Timestamp) Connecting to $vCenterServer as user $vCenterUser." | Out-File $outputLog -Append
    # Uncomment the -AllLinked argument below if you wish to scope all vCenter Server instances connected via Enhanced Linked Mode (ELM).
    $null = Connect-VIServer $vCenterServer <#-AllLinked#> -User $vCenterUser -Password ([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($vCenterPass))) -ErrorAction Stop
    Write-Output "$(Get-Timestamp) Connection established to vCenter server $vCenterServer successfully." | Out-File $outputLog -Append
} catch {
    Write-Output "$(Get-Timestamp) Error: Failed to connect to vCenter Server. $_" | Out-File $outputLog -Append
    exit
}

# Process VMs from CSV
try {
    Clear-Host
    # Read contents of CSV file.
    $vmList = Import-Csv -Path $csvFilePath
    # Loop through each row of the CSV file.
    foreach ($vm in $vmList) {
        $vmName = $vm.Name
        Write-Output "$(Get-Timestamp) Starting analysis of VM: $vmName." | Out-File $outputLog -Append
        Write-Host "Starting analysis of VM: $vmName." -ForegroundColor Cyan
        
        $vmView = Get-VM -Name $vmName -ErrorAction SilentlyContinue
        # Check if VM exists in the target vCenter Server.
        if ($null -eq $vmView) {
            Write-Output "$(Get-Timestamp) Warning: VM named $vmName not found." | Out-File $outputLog -Append
            Write-Host "VM named $vmName not found." -ForegroundColor DarkRed
            continue
        }

        # Check current VM Hardware version for the scoped VM.
        $currentHardwareVersion = $vmView.HardwareVersion
        Write-Output "$(Get-Timestamp) Current Hardware Version for $vmName is $currentHardwareVersion." | Out-File $outputLog -Append
        Write-Host "Current Hardware Version for $vmName is $currentHardwareVersion."

        # Extract numerical part of the hardware version.
        $currentVersionNumber = [int]($currentHardwareVersion -replace '[^\d]', '')
        $desiredVersionNumber = [int]($desiredHardwareVersion -replace '[^\d]', '')

        # If VM hardware upgrade is necessary, set upgrade flag to execute on next power cycle, which can be soft via Guest OS reboot.
        if ($currentVersionNumber -lt $desiredVersionNumber) {
            Write-Output "$(Get-Timestamp) Upgrading hardware version of $vmName from $currentHardwareVersion to $desiredVmxVersion." | Out-File $outputLog -Append
            Write-Host "Upgrading hardware version of $vmName from $currentHardwareVersion to $desiredVmxVersion." -ForegroundColor Yellow
            $UpgVMH = New-Object -TypeName VMware.Vim.VirtualMachineConfigSpec
            $UpgVMH.ScheduledHardwareUpgradeInfo = New-Object -TypeName VMware.Vim.ScheduledHardwareUpgradeInfo
            $UpgVMH.ScheduledHardwareUpgradeInfo.UpgradePolicy = [VMware.Vim.ScheduledHardwareUpgradeInfoHardwareUpgradePolicy]::onSoftPowerOff
            $UpgVMH.ScheduledHardwareUpgradeInfo.VersionKey = $desiredVmxVersion
            $UpgVMH.Tools = New-Object VMware.Vim.ToolsConfigInfo
            $UpgVMH.Tools.ToolsUpgradePolicy = "UpgradeAtPowerCycle"
            $vmView.ExtensionData.ReconfigVM_Task($UpgVMH) | Out-Null
            Write-Output "$(Get-Timestamp) Set upgrade flag for $vmName. VM will upgrade on next power cycle." | Out-File $outputLog -Append
            Write-Host "Set upgrade flag for $vmName. VM will upgrade on next power cycle." -ForegroundColor DarkGreen
            Write-Host "`n"
        } else {
            Write-Output "$(Get-Timestamp) No upgrade needed for $vmName (current version: $currentHardwareVersion)." | Out-File $outputLog -Append
            Write-Host "No upgrade needed for $vmName (current version: $currentHardwareVersion)." -ForegroundColor DarkGreen
            Write-Host "`n"
        }
    }
} catch {
    Write-Output "$(Get-Timestamp) Error processing VMs: $_" | Out-File $outputLog -Append
    Write-Host "Error processing VMs: $_" -ForegroundColor DarkRed
} finally {
    # Disconnect the vCenter session
    Disconnect-VIServer -Server $vCenterServer -Confirm:$false
    Write-Output "$(Get-Timestamp) Disconnected vCenter session." | Out-File $outputLog -Append
    Write-Host "Disconnected vCenter session. Please close terminal window." -ForegroundColor Green
}