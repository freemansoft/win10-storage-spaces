# RUN AS ADMINISTRATOR
# https://nils.schimmelmann.us/post/153541254987/intel-smart-response-technology-vs-windows-10
#Tested with one SSD and two HDD
#
#Pool that will suck in all drives
$StoragePoolName = "My Storage Pool"
#Tiers in the storage pool
$SSDTierName = "SSDTier"
$HDDTierName = "HDDTier"
#Simple = striped.  Mirror only works if both can mirror AFIK
#https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn387076(v=ws.11)
# "the number of columns will be identical on both tiers"
$SSDTierResiliency = "Simple"
$HDDTierResiliency = "Simple"

#Virtual Disk Name made up of disks in both tiers
$TieredDiskName = "My Tiered VirtualDisk"
#Change to suit - drive later and the label name
$TieredDriveLetter = "Z"
$TieredDriveLabel = "StorageDrive"

#Comment these out if you want to try autozizng
#Set values for cache and data storage sizes - cache is size of SSD - storage will be sum of storage disks
#These must be Equal or smaller than the disk size available in that tier SSD and HDD
#$CacheSize = 210GB
#Size for data drive
#$StorageSize = 3.6TB

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

#Create two tiers in the Storage Pool created. One for SSD disks and one for HDD disks
$SSDTier = New-StorageTier -StoragePoolFriendlyName $StoragePoolName -FriendlyName $SSDTierName -MediaType SSD -ResiliencySettingName $SSDTierResiliency
$HDDTier = New-StorageTier -StoragePoolFriendlyName $StoragePoolName -FriendlyName $HDDTierName -MediaType HDD -ResiliencySettingName $HDDTierResiliency

#Identify tier sizes within this storage pool for auto sizing
$SSDTierSizes = (Get-StorageTierSupportedSize -FriendlyName $SSDTierName -ResiliencySettingName $SSDTierResiliency).TierSizeMax
$HDDTierSizes = (Get-StorageTierSupportedSize -FriendlyName $HDDTierName -ResiliencySettingName $HDDTierResiliency).TierSizeMax 
# need to size down.  this amount worked (!)
$SSDTierSizes = [int64]($SSDTierSizes * 0.95)
$HDDTierSizes = [int64]($HDDTierSizes * 0.95)

#Autosizing didn't work with my configuration 3/2020
if ($CacheSize -eq $null) {
    #Create a new virtual disk in the pool with a name of TieredSpace using the SSD and HDD tiers
    New-VirtualDisk -StoragePoolFriendlyName $StoragePoolName -FriendlyName $TieredDiskName -StorageTiers @($SSDTier, $HDDTier) -StorageTierSizes @($SSDTierSizes, $HDDTierSizes) -ResiliencySettingName $HDDTierResiliency  -AutoWriteCacheSize -AutoNumberOfColumns
}
else { 
    #Alternatively try adjusting the sizes manually:
    New-VirtualDisk -StoragePoolFriendlyName $StoragePoolName -FriendlyName $TieredDiskName -StorageTiers @($SSDTier, $HDDTier) -StorageTierSizes @($CacheSize, $StorageSize)  -ResiliencySettingName $HDDTierResiliency -AutoWriteCacheSize -AutoNumberOfColumns
}

# initialize the disk, format and mount as a single volume
Write-Output "preparing volume"
Get-VirtualDisk $TieredDiskName | Get-Disk | Initialize-Disk -PartitionStyle GPT
Get-VirtualDisk $TieredDiskName | Get-Disk | New-Partition -DriveLetter $TieredDriveLetter -UseMaximumSize
Initialize-Volume -DriveLetter $TieredDriveLetter -FileSystem NTFS -Confirm:$false -NewFileSystemLabel $TieredDriveLabel
Get-Volume -DriveLetter $TieredDriveLetter

Write-Output "Operation complete"