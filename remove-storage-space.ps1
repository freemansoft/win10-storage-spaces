#Variables names here MUST MATCH create-storage-space.ps1
$StoragePoolName = "My Storage Pool"
$SSDTierName = "SSDTier"
$HDDTierName = "HDDTier"
$TieredDiskName = "My Tiered VirtualDisk"

# In reverse order of creation
Write-Output "Removing drive:"
Get-VirtualDisk -FriendlyName $TieredDiskName
Remove-virtualdisk -friendlyName $TieredDiskName -Confirm:$false

# Remove Storage Tier
Write-Output "Removing storage tiers:"
Get-StorageTier
Remove-StorageTier -FriendlyName $HDDTierName -Confirm:$false
Remove-StorageTier -FriendlyName $SSDTierName -Confirm:$false
Get-StorageTier

# Remove the Storage Pool
Write-Output "Removing storage pool:"
Get-StoragePool -FriendlyName $StoragePoolName | Get-PhysicalDisk | Select FriendlyName, MediaType
Remove-StoragePool -FriendlyName $StoragePoolName -Confirm:$false
# Show just the primoridal pool
Get-StoragePool
Get-StoragePool | Get-PhysicalDisk -CanPool:$True

Write-Output "Operation complete"