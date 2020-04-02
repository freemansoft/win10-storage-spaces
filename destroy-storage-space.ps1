#Variables names here MUST MATCH create-storage-space.ps1
$StoragePoolName = "My Storage Pool"
$SSDTierName = "SSDTier"
$HDDTierName = "HDDTier"
$TieredSpaceName = "My Tiered VirtualDisk"

# In reverse order of creation
Get-VirtualDisk -FriendlyName $TieredSpaceName
Remove-virtualdisk -friendlyName $TieredSpaceName -Confirm:$false

# Remove Storage Tier
Get-StorageTier
Remove-StorageTier -FriendlyName $HDDTierName -Confirm:$false
Remove-StorageTier -FriendlyName $SSDTierName -Confirm:$false
Get-StorageTier

# Remove the Storage Pool
Get-StoragePool -FriendlyName $StoragePoolName | Get-PhysicalDisk | Select FriendlyName, MediaType
Remove-StoragePool -FriendlyName $StoragePoolName -Confirm:$false
# Show just the primoridal pool
Get-StoragePool
Get-StoragePool | Get-PhysicalDisk -CanPool:$True

Write-Output "Operation complete"