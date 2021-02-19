#Variables names here MUST MATCH create-storage-space.ps1
$StoragePoolName = "My Storage Pool"
$SSDTierName = "SSDTier"
$HDDTierName = "HDDTier"
$TieredDiskName = "My Tiered VirtualDisk"

#TODO: Config file ingestion.

# Make sure they really want to do this!
$choices  = '&Yes', '&No'
$decision = $Host.UI.PromptForChoice('Remove Storage Space', 'Are you sure you wish to remove the storage space named "' + $TieredDiskName + '"?' + [Environment]::NewLine + 'ALL DATA WILL BE PERMANENTLY LOST', $choices, 1)
if ($decision -ne 0) {
    exit
}

# In reverse order of creation
if ($null -ne (Get-VirtualDisk -FriendlyName $TieredDiskName)){
    Write-Output "Removing drive: $TieredDiskName"
    Get-VirtualDisk -FriendlyName $TieredDiskName
    Remove-virtualdisk -friendlyName $TieredDiskName -Confirm:$false
} else {
    Write-Output "Drive does not exist: $TieredDiskName"
}

# Remove Storage Tier
if ($null -ne (Get-StorageTier -FriendlyName $HDDTierName)){
    Write-Output "Removing storage tiers: $HDDTierName"
    Get-StorageTier -FriendlyName $HDDTierName | Format-Table FriendlyName, MediaType, Size -AutoSize
    Remove-StorageTier -FriendlyName $HDDTierName -Confirm:$false
} else {
    Write-Output "Tier does not exist: $HDDTierName"
}
if ($null -ne (Get-StorageTier -FriendlyName $SSDTierName)){
    Write-Output "Removing storage tiers: $SSDTierName"
    Get-StorageTier -FriendlyName $SSDTierName | Format-Table FriendlyName, MediaType, Size -AutoSize
    Remove-StorageTier -FriendlyName $SSDTierName -Confirm:$false
} else {
    Write-Output "Tier does not exist: $SSDTierName"
}
Get-StorageTier

# Remove the Storage Pool
if ($null -ne (Get-StoragePool -FriendlyName $StoragePoolName)){
    Write-Output "Removing storage pool: $StoragePoolName"
    Get-StoragePool -FriendlyName $StoragePoolName | Get-PhysicalDisk | Format-Table FriendlyName, MediaType
    Remove-StoragePool -FriendlyName $StoragePoolName -Confirm:$false
} else {
    Write-Output "Storage Pool does not exist: $StoragePoolName"
}
# Show just the primoridal pool
Write-Output "Poolable drives after cleanup"
Get-StoragePool | Get-PhysicalDisk -CanPool:$True

Write-Output "Operation complete"