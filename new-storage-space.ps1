# RUN AS ADMINISTRATOR
# https://nils.schimmelmann.us/post/153541254987/intel-smart-response-technology-vs-windows-10
#Tested with one SSD and two HDD
#
#Pool that will suck in all drives
$StoragePoolName = "My Storage Pool"
#Tiers in the storage pool
$SSDTierName = "SSDTier"
$HDDTierName = "HDDTier"
#Virtual Disk Name made up of disks in both tiers
$TieredDiskName = "My Tiered VirtualDisk"

#Simple = striped.  Mirror only works if both can mirror AFIK
#https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn387076(v=ws.11)
$DriveTierResiliency = "Simple"

#Change to suit - drive later and the label name
$TieredDriveLetter = "Z"
$TieredDriveLabel = "StorageDrive"

#Override the default sizing here - useful if have two different size SSDs or HDDs - set to smallest of pair
#These must be Equal or smaller than the disk size available in that tier SSD and HDD
#SSD:cache  -    HDD:data
#set to null so copy/paste to command prompt doesn't have previous run values
$SSDTierSize = $null
$HDDTierSize = $null
#Drives cannot always be fully allocated - probably broken for drives < 10GB
$UsableSpace = 0.99

#Uncomment and put your HDD type here if it shows up as unspecified with "Get-PhysicalDisk -CanPool $True
#    If your HDDs show up as Unspecified instead of HDD
$UseUnspecifiedDriveIsHDD = "Yes"

#List all disks that can be pooled and output in table format (format-table)
Get-PhysicalDisk -CanPool $True | ft FriendlyName, OperationalStatus, Size, MediaType

#Store all physical disks that can be pooled into a variable, $PhysicalDisks
#    This assumes you want all raw / unpartitioned disks to end up in your pool - 
#    Add a clause like the example with your drive name to stop that drive from being included
#    Example  " | Where FriendlyName -NE "ATA LITEONIT LCS-256"
if ($UseUnspecifiedDriveIsHDD -ne $null){
    $DisksToChange = (Get-PhysicalDisk -CanPool $True | where MediaType -eq Unspecified)
    Get-PhysicalDisk -CanPool $True | where MediaType -eq Unspecified | Set-PhysicalDisk -MediaType HDD
    # show the type changed
    Get-PhysicalDisk -CanPool $True | ft FriendlyName, OperationalStatus, Size, MediaType
}
$PhysicalDisks = (Get-PhysicalDisk -CanPool $True | Where MediaType -NE UnSpecified)
if ($PhysicalDisks -eq $null){
    throw "Abort! No physical Disks available"
}       

#Create a new Storage Pool using the disks in variable $PhysicalDisks with a name of My Storage Pool
$SubSysName = (Get-StorageSubSystem).FriendlyName
New-StoragePool -PhysicalDisks $PhysicalDisks -StorageSubSystemFriendlyName $SubSysName -FriendlyName $StoragePoolName
#View the disks in the Storage Pool just created
Get-StoragePool -FriendlyName $StoragePoolName | Get-PhysicalDisk | Select FriendlyName, MediaType

#Set the number of columns used for each resiliency - This setting assumes you have at least 2-SSD and 2-HDD
# Get-StoragePool $StoragePoolName | Set-ResiliencySetting -Name Simple -NumberOfColumnsDefault 2
# Get-StoragePool $StoragePoolName | Set-ResiliencySetting -Name Mirror -NumberOfColumnsDefault 1

#Create two tiers in the Storage Pool created. One for SSD disks and one for HDD disks
$SSDTier = New-StorageTier -StoragePoolFriendlyName $StoragePoolName -FriendlyName $SSDTierName -ResiliencySettingName $DriveTierResiliency -MediaType SSD
$HDDTier = New-StorageTier -StoragePoolFriendlyName $StoragePoolName -FriendlyName $HDDTierName -ResiliencySettingName $DriveTierResiliency -MediaType HDD

#Calculate tier sizes within this storage pool
#Can override by setting sizes at top
if ($SSDTierSize -eq $null){
    $SSDTierSize = (Get-StorageTierSupportedSize -FriendlyName $SSDTierName -ResiliencySettingName $DriveTierResiliency).TierSizeMax
    $SSDTierSize = [int64]($SSDTierSize * $UsableSpace)
}
if ($HDDTierSize -eq $null){
    $HDDTierSize = (Get-StorageTierSupportedSize -FriendlyName $HDDTierName -ResiliencySettingName $DriveTierResiliency).TierSizeMax 
    $HDDTierSize = [int64]($HDDTierSize * $UsableSpace)
}
Write-Output "TierSizes: ( $SSDTierSize , $HDDTierSize )"

# you can end up with different number of columns in SSD - Ex: With Simple 1SSD and 2HDD could end up with SSD-1Col, HDD-2Col
New-VirtualDisk -StoragePoolFriendlyName $StoragePoolName -FriendlyName $TieredDiskName -StorageTiers @($SSDTier, $HDDTier) -StorageTierSizes @($SSDTierSize, $HDDTierSize) -ResiliencySettingName $DriveTierResiliency -AutoWriteCacheSize -AutoNumberOfColumns

# initialize the disk, format and mount as a single volume
Write-Output "preparing volume"
Get-VirtualDisk $TieredDiskName | Get-Disk | Initialize-Disk -PartitionStyle GPT
# This will be Partition 2.  Storage pool metadata is in Partition 1
Get-VirtualDisk $TieredDiskName | Get-Disk | New-Partition -DriveLetter $TieredDriveLetter -UseMaximumSize
Initialize-Volume -DriveLetter $TieredDriveLetter -FileSystem NTFS -Confirm:$false -NewFileSystemLabel $TieredDriveLabel
Get-Volume -DriveLetter $TieredDriveLetter

Write-Output "Operation complete"