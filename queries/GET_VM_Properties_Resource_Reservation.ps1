<#
.SYNOPSIS
Get VMs with Resource Reservations
Intended to query vCenter to retrieve a list of VM's which have CPU/Memory Reservations set and export results to CSV or PS Grid.

Author: Don Horrox (vChamp - https://www.vchamp.net)
Version: 1.0

.DESCRIPTION
 This script must be run on a system with either the VMware PowerCli snap-in or module and an
 account that has appropriate rights to connect to vCenter using PowerCLI.
 To install the PowerCLI module run
 Install-Module -Name VMware.PowerCLI
 Install-Module -Name VMware.PowerCLI –Scope CurrentUser

.NOTES
N/A
#>

## Prepare Logging
function Get-TimeStamp {
    return "[{0:MM/dd/yy}  {0:HH:mm:ss}]" -f (Get-Date)
}
$outputLog = ".\get_vm_properties_reservation.log"

## Initialize Script
Write-Output "$(Get-Timestamp) Initializing script." | Out-File $outputLog -Append

# Main Menu
function Show-Menu
{
    param (
        [string]$Title = 'Get VMs with Resource Reservations'
    )
    Clear-Host
    Write-Host "================ $Title ================"
    Write-Host "Select your desired output format:"
    Write-Host "`n"
    Write-Host "1) CSV File"
    Write-Host "`n"
    Write-Host "2) PowerShell Table"
    Write-Host "`n"
    Write-Host "Q: Press 'Q' to quit."
    Write-Host "`n"
    Write-Host "`n"
}
Write-Output "$(Get-Timestamp) Waiting for user input." | Out-File $outputLog -Append

# Main Menu: Action
     Show-Menu -Title 'Main menu'
     $selection = Read-Host "Please make a selection"
     switch ($selection)
     {
         '1' {
            $OutputSelection = "CSV"
         } '2' {
             $OutputSelection = "PowerShell Table"
            } 'q' {
                $OutputSelection = "Exit"
                Write-Output "$(Get-Timestamp) User aborted script. Exiting." | Out-File $outputLog -Append
                Exit
            }
        }
        Write-Output "$(Get-Timestamp) User selected $OutputSelection." | Out-File $outputLog -Append

# Connect to vCenter
Clear-Host
Write-Host "$Outputselection output selected..." -ForegroundColor Yellow
Write-Output "$(Get-Timestamp) Waiting for credentials." | Out-File $outputLog -Append
$VCServer = Read-Host "Enter your vCenter FQDN"
$Username = Read-Host "Enter your username"
$Password = Read-Host "Enter password" -AsSecureString
$null = Connect-VIServer $VCServer -User $username -Password ([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)))
Write-Output "$(Get-Timestamp) Connecting to $VCServer as $Username ." | Out-File $outputLog -Append

# Query vCenter for VM's with a resource reservation
Write-Host "Executing query." -ForegroundColor Yellow
Write-Output "$(Get-Timestamp) Executing query." | Out-File $outputLog -Append
$Report = @()
$VMs = Get-VM | Where-Object {$_.ExtensionData.ResourceConfig.MemoryAllocation.Reservation -ne "0" -or $_.ExtensionData.ResourceConfig.CpuAllocation.Reservation -ne "0"} | Sort-Object -Property Name
ForEach ($VM in $VMs)
    { 
    $Report += "" | Select @{N="Name";E={$VM.Name}},
    @{N="CPU Reservation";E={$VM.ExtensionData.ResourceConfig.CpuAllocation.Reservation}},
    @{N="Memory Reservation";E={$VM.ExtensionData.ResourceConfig.MemoryAllocation.Reservation }} 
    }

# Output
if ($OutputSelection -eq "Powershell Table") {
    $report | Out-GridView
    Write-Output "$(Get-Timestamp) Presenting PowerShell Table to user." | Out-File $outputLog -Append }
    
    if ($OutputSelection -eq "CSV") {
    $report | Export-Csv -Path .\VM_Reservations.csv -NoTypeInformation
    Write-Output "$(Get-Timestamp) Exporting to CSV." | Out-File $outputLog -Append }

# Log out of PowerCLI
Write-Host "Disconnecting vCenter session." -ForegroundColor Yellow
Write-Output "$(Get-Timestamp) Disconnecting from $VCServer ." | Out-File $outputLog -Append
Disconnect-VIServer -Server $VCServer -Force -Confirm:$false
Write-Host "Session disconnected." -ForegroundColor DarkGreen
Write-Output "$(Get-Timestamp) vCenter session disconnected." | Out-File $outputLog -Append
Write-Host "Query complete. Please close terminal window." -ForegroundColor Green
