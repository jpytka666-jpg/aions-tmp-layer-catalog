#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$VmName = 'aions-proxmox-host'
$SwitchName = 'AIONS-External'
$Base = 'D:\AIONS_DEV\vm\proxmox-host'
$IsoPath = Join-Path $Base 'iso\proxmox-ve_9.2-1.iso'
$VhdPath = Join-Path $Base 'disks\aions-proxmox-host.vhdx'
$ExpectedIsoBytes = 1706178560

New-Item -ItemType Directory -Force -Path (Join-Path $Base 'iso'), (Join-Path $Base 'disks') | Out-Null

if (-not (Test-Path $IsoPath)) {
  Write-Error "Missing ISO: $IsoPath"
}
$isoSize = (Get-Item $IsoPath).Length
if ($isoSize -lt ($ExpectedIsoBytes - 1MB)) {
  Write-Error "ISO incomplete: $isoSize bytes (expected $ExpectedIsoBytes)"
}

if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
  Write-Error "Missing Hyper-V switch: $SwitchName"
}

$vm = Get-VM -Name $VmName -ErrorAction SilentlyContinue
if (-not $vm) {
  New-VM -Name $VmName -Generation 2 -MemoryStartupBytes 8GB `
    -NewVHDPath $VhdPath -NewVHDSizeBytes 80GB `
    -SwitchName $SwitchName -Path $Base | Out-Null
  Write-Host "Created VM $VmName"
} else {
  Write-Host "VM $VmName already exists (state: $($vm.State))"
}

Set-VM -Name $VmName -AutomaticCheckpointsEnabled $false
Set-VMProcessor -VMName $VmName -Count 4 -ExposeVirtualizationExtensions $true
Set-VMFirmware -VMName $VmName -EnableSecureBoot Off

if (-not (Get-VMDvdDrive -VMName $VmName -ErrorAction SilentlyContinue)) {
  Add-VMDvdDrive -VMName $VmName
}
Set-VMDvdDrive -VMName $VmName -Path $IsoPath
$dvd = Get-VMDvdDrive -VMName $VmName
Set-VMFirmware -VMName $VmName -FirstBootDevice $dvd

Write-Host "OK. ISO: $IsoPath"
Write-Host "Start-VM $VmName"
