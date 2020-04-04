# Run as administrator
# INCOMPLETE
# original idea from https://docs.microsoft.com/en-us/archive/blogs/josebda/step-by-step-for-storage-spaces-tiering-in-windows-server-2012-r2
# Convert an SSD to 2 VHD SSD so we can run a mirrored storage pool with 1 SSD in a Hyper-V VM
# ASSUMPTION: only one RAW SSD in system
#Pool that will suck in all drives
$StoragePoolName = "My Cache Pool"
$SSDTierName = "SSDTier"
$CacheDriveName1 = "Cache Faux SSD 1"
$CacheDriveName2 = "Cache Faux SSD 2"
#
Remove-VirtualDisk -FriendlyName $CacheDriveName1 -Confirm:$false
Remove-VirtualDisk -FriendlyName $CacheDriveName2 - -Confirm:$false
Remove-StorageTier -FriendlyName $SSDTierName -Confirm:$false
Remove-StoragePool -FriendlyName $StoragePoolName -Confirm:$false
