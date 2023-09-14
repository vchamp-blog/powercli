<#
.SYNOPSIS
VMware VM Storage vMotion from File
Script is used to migrate a scoped list of virtual machines to a destination datastore according to a user-provided CSV file.

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
$outputLog = ".\put_vm_vmotion_storage_from_file.log"

## Initialize Script
Write-Output "$(Get-Timestamp) WARN: +++++++++++++++ Starting new session +++++++++++++++" | Out-File $outputLog -Append
Write-Output "$(Get-Timestamp) Initializing script." | Out-File $outputLog -Append

## Set Target(s)
Write-Output "$(Get-Timestamp) Importing CSV." | Out-File $outputLog -Append
$ImportFile = ".\vm_vmotion_storage_list.csv"
$VMList = Import-Csv $ImportFile
Write-Output "$(Get-Timestamp) Source CSV is $ImportFile." | Out-File $outputLog -Append

## Welcome message
Write-Host "############################################################################" -ForegroundColor Cyan
Write-Host "                  VMware VM Storage vMotion from File" -ForegroundColor Cyan
Write-Host "############################################################################" -ForegroundColor Cyan
Write-Host "`n"
Write-Host "Version: 1.0"
Write-Host "`n"
Write-Host "Objective:" -ForegroundColor Yellow
Write-Host "Initiate a storage vMotion of scoped VMs provided by a CSV file."
Write-Host "`n"
Write-Host "Requirements:" -ForegroundColor Yellow
Write-Host "  * CSV file named 'vm_vmotion_storage_list.csv' located in the working directory."
Write-Host "  * Cell A1 value should equal 'VMName' with VM Names on separate cells below."
Write-Host "  * Cell B1 value should equal 'Datastore' with the name of each respective datastore on separate cells below."
Write-Host "`n"
Write-Host "`n"

## Connect to the vCenter
Write-Host "######################################" -ForegroundColor Yellow
Write-Host "        vCenter Authentication" -ForegroundColor Yellow
Write-Host "######################################" -ForegroundColor Yellow
Write-Host "`n"
Write-Host "Specify the FQDN of your vCenter Server below:" -ForegroundColor Yellow
Write-Output "$(Get-Timestamp) Waiting for user input - VCSA." | Out-File $outputLog -Append
$VCServer = Read-Host "Enter your vCenter FQDN"
Write-Output "$(Get-Timestamp) Waiting for user credentials." | Out-File $outputLog -Append
Write-Host "`n"
Write-Host "Please enter your credentials below:" -ForegroundColor Yellow
$Username = Read-Host "Enter your username"
$Password = Read-Host "Enter password" -AsSecureString
Write-Host "`n"
Write-Host "Authentication in-progress. Please wait." -ForegroundColor Cyan
Write-Output "$(Get-Timestamp) Connecting to $VCServer as user $Username..." | Out-File $outputLog -Append
$null = Connect-VIServer $VCServer <#-AllLinked#> -User $username -Password ([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)))

## Migrate VMs
Clear-Host
Write-Output "$(Get-Timestamp) Beginning storage vMotion loop." | Out-File $outputLog -Append
foreach ($item in $vmlist){
    $server = $item.vmname
    $destdatastore = $item.datastore
    # Check Current Datastore
    Write-Output "$(Get-Timestamp) Checking current storage location for $server." | Out-File $outputLog -Append
    $sourcedatastore = (Get-Datastore -RelatedObject $server).Name
    Write-Output "$(Get-Timestamp) Current datastore is $sourcedatastore." | Out-File $outputLog -Append
    # Logic to handle outcome of datastore query
    If($destdatastore -eq $sourcedatastore)
    # If VM is already located on destination datastore, do nothing
    {Write-Output "$(Get-Timestamp) VM $server is already located on datastore $sourcedatastore and user requested $destinationdatastore. Skipping." | Out-File $outputLog -Append
    Write-Host "$server is already located on datastore $sourcedatastore. Skipping." -ForegroundColor DarkGreen}
    # If VM is not located on destination datastore, perform storage vMotion
    else{
        Write-Output "$(Get-Timestamp) Sending storage vMotion command for VM $server." | Out-File $outputLog -Append
        Write-Host "Sending storage vMotion command for VM $server. Destination datastore is $destinationdatastore."
        try {
            Move-VM -VM $server -Datastore $destdatastore -VMotionPriority High -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Output "$(Get-Timestamp) ERROR: Failed to send migration command to $server. Check vCenter logs for details." | Out-File $outputLog -Append
            Write-Host "Failed to send migration command to $server. Check vCenter logs for details." -ForegroundColor DarkRed
        }
        
    }
}

## Disconnect from vCenter
Write-Host "`n"
Write-Output "$(Get-Timestamp) Disconnecting vCenter session." | Out-File $outputLog -Append
Write-Host "Disconnecting vCenter session." -ForegroundColor DarkGreen
Disconnect-VIServer -Server * -Force -Confirm:$false
Write-Host "All actions complete. Please close terminal window." -ForegroundColor White -BackgroundColor DarkGreen
