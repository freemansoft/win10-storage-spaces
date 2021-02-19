# RUN AS ADMINISTRATOR
# https://nils.schimmelmann.us/post/153541254987/intel-smart-response-technology-vs-windows-10
#Tested with one SSD and two HDD
#Requires -RunAsAdministrator



[CmdletBinding()]
param (
    [Parameter(Mandatory = $False, ValueFromPipeline = $True)]
    [string[]]
    $ConfigFile
)

Begin{

    $Script:StorageSpacesParams = @()
    #Makes $PhysicalDisks a hashtable for easier management.
    $PhysicalDisks = @()

    function defaultPrompt {
        if ($null -eq $ConfigFile) {
            $DefaultPrompt = Read-Host = "Would you like to load the default values to the config file? (Y/N)" 
            if ($DefaultPrompt.ToUpper() -eq "Y" ) {
                $Script:StorageSpacesParams = setDefaultValues
                $Script:StorageSpacesParams | ConvertTo-Json | Out-File $PSScriptRoot + "\TieredStorageSpace-Config.json"
            }
            elseif ($DefaultPrompt.ToUpper() -eq "N") {
            
            }
            else {
                Write-Output "Invalid Selection."
                defaultPrompt
            }
        }
        if ($null -ne $ConfigFile) {
            
        }
    }

    defaultPrompt
    function setDefaultValues {
        @{
            #Pool that will suck in all drives
            StoragePoolFriendlyName  = "My Storage Pool"
            #Virtual Disk Name made up of disks in both tiers
            TieredDiskName           = "My Tiered VirtualDisk"
            #Simple = striped.  Mirror only works if both can mirror AFIK
            #https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn387076(v=ws.11)
            DriveTierResiliency      = "Simple"
            #Change to suit - drive later and the label name
            DriveLetter              = "Z"
            NewFileSystemLabel       = "StorageDrive"
            #Override the default sizing here - useful if have two different size SSDs or HDDs - set to smallest of pair
            #These must be Equal or smaller than the disk size available in that tier SSD and HDD
            #SSD:cache  -    HDD:data
            #set to null so copy/paste to command prompt doesn't have previous run values
            SSDTierSize              = $null
            HDDTierSize              = $null
            #Drives cannot always be fully allocated - probably broken for drives < 10GB
            UsableSpace              = 0.98 # I had an issue with 0.99, so I lowered it to 0.98.
            #Tiers in the storage pool
            SSDTierName              = "SSDTier"
            HDDTierName              = "HDDTier"
            #Uncomment and put your HDD type here if it shows up as unspecified with "Get-PhysicalDisk -CanPool $True
            #    If your HDDs show up as Unspecified instead of HDD
            UseUnspecifiedDriveIsHDD = "$True"
        }
    }
    function loadValuesFromParamsToVaribles {
        [CmdletBinding()]
        param (
            [Parameter()]
            $StorageSpacesParams
        )

    }
}

    #TODO: Allow a config file ingestion for varibles.


    #TODO: Write a pester test.

 
        
    

    #TODO: Set selectable $DriveTierResiliency.

    #TODO: Write defauls to config file for injestion for script use.

    #TODO: Add prompt to load global variable defaults.

    #TODO: Make interactive prompt for global varibles set to $null.

Process {
    #List all disks that can be pooled and output in table format (format-table)
    Get-PhysicalDisk -CanPool $True | Format-Table FriendlyName, OperationalStatus, Size, MediaType


    #TODO: Create selectable options to fine tune what disks are selected.
    #Store all physical disks that can be pooled into a variable, $PhysicalDisks
    #    This assumes you want all raw / unpartitioned disks to end up in your pool - 
    #    Add a clause like the example with your drive name to stop that drive from being included
    #    Example  " | Where FriendlyName -NE "ATA LITEONIT LCS-256"
    if ($null -ne $UseUnspecifiedDriveIsHDD) {
        Get-PhysicalDisk -CanPool $True | Where-Object MediaType -eq Unspecified | Set-PhysicalDisk -MediaType HDD
        # show the type changed
        Get-PhysicalDisk -CanPool $True | Format-Table FriendlyName, OperationalStatus, Size, MediaType
    }
    $PhysicalDisks = (Get-PhysicalDisk -CanPool $True | Where-Object MediaType -NE UnSpecified)
    if ($null -eq $PhysicalDisks) {
        throw "Abort! No physical Disks available"
    }       

    #Create a new Storage Pool using the disks in variable $PhysicalDisks with a name of My Storage Pool
    $SubSysName = (Get-StorageSubSystem).FriendlyName
    New-StoragePool -PhysicalDisks $PhysicalDisks -StorageSubSystemFriendlyName $SubSysName -FriendlyName $StoragePoolName
    #View the disks in the Storage Pool just created
    Get-StoragePool -FriendlyName $StoragePoolName | Get-PhysicalDisk | Select-Object FriendlyName, MediaType

    #Set the number of columns used for each resiliency - This setting assumes you have at least 2-SSD and 2-HDD
    # Get-StoragePool $StoragePoolName | Set-ResiliencySetting -Name Simple -NumberOfColumnsDefault 2
    # Get-StoragePool $StoragePoolName | Set-ResiliencySetting -Name Mirror -NumberOfColumnsDefault 1

    #Create two tiers in the Storage Pool created. One for SSD disks and one for HDD disks
    $SSDTier = New-StorageTier @StorageSpacesParams -FriendlyName $SSDTierName -MediaType SSD
    $HDDTier = New-StorageTier @StorageSpacesParams -FriendlyName $HDDTierName -MediaType HDD

    #Calculate tier sizes within this storage pool
    #Can override by setting sizes at top
    if ($null -eq $SSDTierSize) {
        $SSDTierSize = (Get-StorageTierSupportedSize -FriendlyName $SSDTierName -ResiliencySettingName $DriveTierResiliency).TierSizeMax
        $SSDTierSize = [int64]($SSDTierSize * $UsableSpace)
    }
    if ($null -eq $HDDTierSize) {
        $HDDTierSize = (Get-StorageTierSupportedSize -FriendlyName $HDDTierName -ResiliencySettingName $DriveTierResiliency).TierSizeMax 
        $HDDTierSize = [int64]($HDDTierSize * $UsableSpace)
    }
    Write-Output "TierSizes: ( $SSDTierSize , $HDDTierSize )"

    # you can end up with different number of columns in SSD - Ex: With Simple 1SSD and 2HDD could end up with SSD-1Col, HDD-2Col
    New-VirtualDisk @StorageSpacesParams -FriendlyName $TieredDiskName -StorageTiers @($SSDTier, $HDDTier) -StorageTierSizes @($SSDTierSize, $HDDTierSize) @StorageSpacesParams -AutoWriteCacheSize -AutoNumberOfColumns

    # initialize the disk, format and mount as a single volume
    Write-Output "Preparing volume..."
    Get-VirtualDisk $TieredDiskName | Get-Disk | Initialize-Disk -PartitionStyle GPT
    # This will be Partition 2.  Storage pool metadata is in Partition 1
    Get-VirtualDisk $TieredDiskName | Get-Disk | New-Partition @StorageSpacesParams -UseMaximumSize
    Initialize-Volume -FileSystem NTFS -Confirm:$false @StorageSpacesParams
    Get-Volume @StorageSpacesParams
}

End{
Write-Output "Operation complete"

Clear-Variable StorageSpacesParams -Scope Global
}