# Run as administrator
# INCOMPLETE
# original idea from https://docs.microsoft.com/en-us/archive/blogs/josebda/step-by-step-for-storage-spaces-tiering-in-windows-server-2012-r2
# Convert an SSD to 2 VHD SSD so we can run a mirrored storage pool with 1 SSD in a Hyper-V VM
# ASSUMPTION: only one RAW SSD in system
#Pool that will suck in all drives
$StoragePoolName = "My Cache Pool"
$SSDTierName = "SSDTier"

$CacheDriveName1 = "Cache Faux SSD 1"
$CacheDriveLetter1 = "P"
$CacheDriveLabel1 = "Cache 1"

$CacheDriveName2 = "Cache Faux SSD 2"
$CacheDriveLetter2 = "Q"
$CacheDriveLabel2 = "Cache 2"
#
$PhysicalDisks = (Get-PhysicalDisk -CanPool $True | Where MediaType -eq SSD)
#
$SubSysName = (Get-StorageSubSystem).FriendlyName
New-StoragePool -PhysicalDisks $PhysicalDisks -StorageSubSystemFriendlyName $SubSysName -FriendlyName $StoragePoolName
#View the disks in the Storage Pool just created
Get-StoragePool -FriendlyName $StoragePoolName | Get-PhysicalDisk | Select FriendlyName, MediaType
# create a tier with it
$SSDTier = Get-StoragePool $StoragePoolName | New-StorageTier -FriendlyName $SSDTierName -MediaType SSD
# Size it for two drives
$SSDTierSize = (Get-StorageTierSupportedSize -FriendlyName $SSDTierName -ResiliencySettingName Simple).TierSizeMax
$SSDTierSize = [int64]($SSDTierSize * 0.45)
Write-Output "CacheDrive Sizes: ( $SSDTierSize , $SSDTierSize )"

# you can end up with different number of columns in SSD - Ex: With Simple 1SSD and 2HDD could end up with SSD-1Col, HDD-2Col
New-VirtualDisk -StoragePoolFriendlyName $StoragePoolName -FriendlyName $CacheDriveName1 -MediaType SSD -Size $SSDTierSize -ResiliencySettingName Simple -AutoWriteCacheSize -AutoNumberOfColumns

New-VirtualDisk -StoragePoolFriendlyName $StoragePoolName -FriendlyName $CacheDriveName2 -MediaType SSD -Size $SSDTierSize -ResiliencySettingName Simple -AutoWriteCacheSize -AutoNumberOfColumns

Remove-VirtualDisk -FriendlyName $CacheDriveName1
Remove-VirtualDisk -FriendlyName $CacheDriveName2